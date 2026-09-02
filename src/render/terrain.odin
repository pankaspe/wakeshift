/*
* Terrain
* Draws the floor and the ceiling — and, since phase 6, the places where
* they are not there.
*
* A Chasm and a Dream Hole are not objects standing on the ground: they
* are the ground failing to exist. Until now they were drawn as dark
* boxes sitting *on top of* the floor line, which is why the design doc's
* central "full vs void" pairing never actually landed — both worlds only
* ever showed the player things that appeared. The terrain is the only
* code that knows where its own surface is, so cutting the holes is its
* job, and draw_obstacle deliberately draws nothing for those two types.
*
* How the cutting works: the surface is a function of x, not a fixed list
* of points, so a span of it can be drawn between any two arbitrary
* x values. The void obstacles are turned into gaps in screen space, the
* gaps are subtracted from the width of the screen, and what is left is
* drawn one span at a time. Vertices land exactly on the gap edges, so a
* hole is never snapped to the profile's 50px grid.
*
* The two sides break differently, which is the whole point of them:
*
*   the floor  ends. A hard edge, a lit cross-section down each wall of
*              the pit, and darkness under it. Concrete, and broken.
*   the ceiling dissolves. Its edges fade out over some tens of pixels
*              instead of stopping, and the gap glows faintly, because
*              in the Dream world an absence is a way through rather
*              than a fall (Design Doc, section 5).
*/
package render

import "../core"
import "../game"
import "core:math"
import "core:slice"
import rl "vendor:raylib/v55"

TERRAIN_SEGMENT_WIDTH :: 50
TERRAIN_BASE_HEIGHT :: 14 // minimum protrusion from the screen edge
TERRAIN_PROFILE := [6]f32{0, 12, 4, 16, 6, 9} // extra height per segment, hand-authored once

// The lit edge: how bright it is when its world is dormant, and how much
// it gains once that world is the one being played in.
TERRAIN_RIM_DORMANT :: 0.30
TERRAIN_RIM_ALIVE :: 0.70
TERRAIN_GLOW_STRENGTH :: 0.35
TERRAIN_GLOW_SPREAD :: 5

// How far past each screen edge the terrain is built, so a hole whose
// edge is just off screen still cuts correctly.
TERRAIN_MARGIN :: TERRAIN_SEGMENT_WIDTH

// How deep the lit cross-section of a broken floor runs, in pixels.
CHASM_WALL_DEPTH :: 22

// How far a dissolving ceiling edge fades, in pixels.
DREAM_HOLE_FADE :: 30
DREAM_HOLE_FADE_STEP :: 3
DREAM_HOLE_GLOW :: 0.30

// The surface height at any screen x, sampled from the scrolling profile.
//
// A function rather than a list of points, because a hole can begin
// anywhere: the spans on either side of it need a vertex exactly at its
// edge, not at the nearest multiple of the segment width. Linear between
// profile entries, which is exactly what the straight lines between the
// old sample points already drew.
terrain_surface_y :: proc(world: game.World, is_floor: bool, x: f32) -> f32 {
	position := (world.scroll_offset + x) / TERRAIN_SEGMENT_WIDTH
	index := int(math.floor(position))
	t := position - f32(index)

	count := len(TERRAIN_PROFILE)
	// Odin's % keeps the sign of the dividend, and x can be slightly
	// negative at the left margin.
	first := ((index % count) + count) % count
	second := (first + 1) % count
	variation := TERRAIN_PROFILE[first] + (TERRAIN_PROFILE[second] - TERRAIN_PROFILE[first]) * t

	if is_floor {
		return core.SCREEN_HEIGHT - TERRAIN_BASE_HEIGHT - variation
	}
	return TERRAIN_BASE_HEIGHT + variation
}

// A range of screen x, used for both gaps and the solid spans between them.
Span :: struct {
	start: f32,
	end:   f32,
}

// Every hole in one side of the world, in screen x, sorted and merged.
//
// Merging matters: two gaps that touch have no ground between them, and
// drawing the zero-width span that separates them would put a lit rim
// line in the middle of a hole.
collect_gaps :: proc(
	world: game.World,
	obstacles: []game.Obstacle,
	is_floor: bool,
    allocator := context.temp_allocator,
) -> [dynamic]Span {
	gaps := make([dynamic]Span, 0, 8, allocator)

	wanted: game.ObstacleType = is_floor ? .Chasm : .DreamHole
	for obstacle in obstacles {
		if obstacle.obstacle_type != wanted {
			continue
		}
		rect := game.get_obstacle_rect(obstacle, world)
		start := max(rect.x, -TERRAIN_MARGIN)
		end := min(rect.x + rect.width, core.SCREEN_WIDTH + TERRAIN_MARGIN)
		if end > start {
			append(&gaps, Span{start, end})
		}
	}

	slice.sort_by(gaps[:], proc(a, b: Span) -> bool {return a.start < b.start})

	merged := make([dynamic]Span, 0, len(gaps), allocator)
	for gap in gaps {
		if len(merged) > 0 && gap.start <= merged[len(merged) - 1].end {
			last := &merged[len(merged) - 1]
			last.end = max(last.end, gap.end)
			continue
		}
		append(&merged, gap)
	}
	return merged
}

// What is left of one side once the gaps are taken out of it.
solid_spans :: proc(gaps: []Span, allocator := context.temp_allocator) -> [dynamic]Span {
	spans := make([dynamic]Span, 0, len(gaps) + 1, allocator)

	cursor := f32(-TERRAIN_MARGIN)
	for gap in gaps {
		if gap.start > cursor {
			append(&spans, Span{cursor, gap.start})
		}
		cursor = max(cursor, gap.end)
	}
	if cursor < core.SCREEN_WIDTH + TERRAIN_MARGIN {
		append(&spans, Span{cursor, core.SCREEN_WIDTH + TERRAIN_MARGIN})
	}
	return spans
}

// The x positions to sample a span at: both ends, plus every profile
// boundary inside it, so the drawn edge follows the same line the
// profile describes.
@(private)
span_samples :: proc(span: Span, allocator := context.temp_allocator) -> [dynamic]f32 {
	samples := make([dynamic]f32, 0, 32, allocator)
	append(&samples, span.start)

	first := math.ceil(span.start / TERRAIN_SEGMENT_WIDTH) * TERRAIN_SEGMENT_WIDTH
	for x := first; x < span.end; x += TERRAIN_SEGMENT_WIDTH {
		if x > span.start {
			append(&samples, x)
		}
	}

	append(&samples, span.end)
	return samples
}

// Fills one unbroken stretch of ground, from its surface to the screen
// edge, and runs the world's light along the surface.
@(private)
draw_terrain_span :: proc(
	world: game.World,
	span: Span,
	palette: core.Palette,
	alive: f32,
	is_floor: bool,
) {
	samples := span_samples(span)
	if len(samples) < 2 {
		return
	}

	edge_y: f32 = is_floor ? core.SCREEN_HEIGHT : 0

	strip := make([dynamic]rl.Vector2, 0, len(samples) * 2, context.temp_allocator)
	for x in samples {
		append(&strip, rl.Vector2{x, terrain_surface_y(world, is_floor, x)})
		append(&strip, rl.Vector2{x, edge_y})
	}
	rl.DrawTriangleStrip(raw_data(strip[:]), i32(len(strip)), palette.silhouette)

	// The rim: a hard line in the world's own light, plus an additive halo
	// that only really shows on the live side. The line is always drawn at
	// full opacity even when dormant — it is the boundary between ground
	// and air, and losing it would cost readability (pillar 2) to buy mood.
	rim_alpha := TERRAIN_RIM_DORMANT + (TERRAIN_RIM_ALIVE - TERRAIN_RIM_DORMANT) * alive
	rim_color := core.with_alpha(palette.light, rim_alpha)

	for i in 0 ..< len(samples) - 1 {
		a := rl.Vector2{samples[i], terrain_surface_y(world, is_floor, samples[i])}
		b := rl.Vector2{samples[i + 1], terrain_surface_y(world, is_floor, samples[i + 1])}
		draw_glow_line(
			a,
			b,
			core.LIGHT_RIM_THICKNESS,
			TERRAIN_GLOW_SPREAD,
			palette.light,
			TERRAIN_GLOW_STRENGTH * alive,
		)
		rl.DrawLineEx(a, b, core.LIGHT_RIM_THICKNESS, rim_color)
	}
}

// A break in the floor: the ground stops, and you can see down into it.
// The two vertical walls catch the world's light, which is what says
// "this has depth" rather than "this is a dark rectangle".
@(private)
draw_chasm_gap :: proc(world: game.World, gap: Span, palette: core.Palette, alive: f32) {
	// Darker than any background the palette produces, so the hole reads
	// as a hole rather than as a patch of distant sky.
	void_color := core.lerp_color(palette.silhouette, rl.Color{0, 0, 0, 255}, 0.85)

	left_y := terrain_surface_y(world, true, gap.start)
	right_y := terrain_surface_y(world, true, gap.end)

	rl.DrawRectangleRec(
		rl.Rectangle{gap.start, min(left_y, right_y), gap.end - gap.start, core.SCREEN_HEIGHT},
		void_color,
	)

	// The cross-section of the broken ground, lit at the top and fading
	// into the dark as it goes down.
	wall_color := core.with_alpha(palette.light, 0.20 + 0.35 * alive)
	rl.DrawLineEx(
		rl.Vector2{gap.start, left_y},
		rl.Vector2{gap.start, left_y + CHASM_WALL_DEPTH},
		core.RIM_THICKNESS,
		wall_color,
	)
	rl.DrawLineEx(
		rl.Vector2{gap.end, right_y},
		rl.Vector2{gap.end, right_y + CHASM_WALL_DEPTH},
		core.RIM_THICKNESS,
		wall_color,
	)

	// The lip: the last of the surface line, turned down into the break.
	lip_color := core.with_alpha(palette.light, TERRAIN_RIM_DORMANT + 0.4 * alive)
	rl.DrawCircleV(rl.Vector2{gap.start, left_y}, core.LIGHT_RIM_THICKNESS, lip_color)
	rl.DrawCircleV(rl.Vector2{gap.end, right_y}, core.LIGHT_RIM_THICKNESS, lip_color)
}

// A break in the ceiling, which does not break: it dissolves. The edges
// fade out into the gap instead of stopping at it, and what is behind
// glows, because in the Dream world an absence is an opening.
@(private)
draw_dream_hole_gap :: proc(world: game.World, gap: Span, palette: core.Palette, alive: f32) {
	width := gap.end - gap.start
	fade := min(f32(DREAM_HOLE_FADE), width * 0.5)

	// The light behind the dissolved ceiling.
	center := rl.Vector2{(gap.start + gap.end) * 0.5, terrain_surface_y(world, false, (gap.start + gap.end) * 0.5)}
	draw_glow_circle(center, width * 0.7, palette.accent, DREAM_HOLE_GLOW * (0.4 + 0.6 * alive))

	// The two dissolving edges, drawn as columns of the ceiling's own
	// silhouette thinning out into the gap.
	for offset := f32(0); offset < fade; offset += DREAM_HOLE_FADE_STEP {
		strength := 1 - offset / fade
		color := core.with_alpha(palette.silhouette, strength)

		left_x := gap.start + offset
		rl.DrawRectangleRec(
			rl.Rectangle{left_x, 0, DREAM_HOLE_FADE_STEP, terrain_surface_y(world, false, left_x)},
			color,
		)

		right_x := gap.end - offset - DREAM_HOLE_FADE_STEP
		rl.DrawRectangleRec(
			rl.Rectangle{right_x, 0, DREAM_HOLE_FADE_STEP, terrain_surface_y(world, false, right_x)},
			color,
		)
	}
}

@(private)
draw_terrain_side :: proc(
	world: game.World,
	obstacles: []game.Obstacle,
	palettes: core.PaletteSet,
	is_floor: bool,
) {
	palette := is_floor ? palettes.real : palettes.dream
	alive := is_floor ? palettes.real_alive : palettes.dream_alive

	gaps := collect_gaps(world, obstacles, is_floor)

	for gap in gaps {
		if is_floor {
			draw_chasm_gap(world, gap, palette, alive)
		} else {
			draw_dream_hole_gap(world, gap, palette, alive)
		}
	}

	for span in solid_spans(gaps[:]) {
		draw_terrain_span(world, span, palette, alive, is_floor)
	}
}

draw_terrain :: proc(world: game.World, obstacles: []game.Obstacle, palettes: core.PaletteSet) {
	draw_terrain_side(world, obstacles, palettes, true) // floor
	draw_terrain_side(world, obstacles, palettes, false) // ceiling
}
