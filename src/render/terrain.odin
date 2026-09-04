/*
* Terrain
* Draws the floor and the ceiling — and, since phase 6, the places where
* they are not there.
*
* It no longer decides where they are. Since phase 7.5 the profile lives
* in core/terrain.odin, because the player and the obstacles stand on it:
* this file draws the surface the simulation is already using, and the
* two cannot drift apart because there is only one of them.
*
* A Gap is not an object standing on the ground: it is the ground failing
* to exist. It was once drawn as a dark box sitting *on top of* the floor
* line, which is why the design's central "full vs void" pairing never
* landed — both worlds only ever showed the player things that appeared.
* The terrain is the only code that knows where its own surface is, so
* cutting the holes is its job, and draw_obstacle deliberately draws
* nothing for them.
*
* How the cutting works: the surface is a function of x, not a fixed list
* of points, so a span of it can be drawn between any two arbitrary
* x values. The void obstacles are turned into gaps in screen space, the
* gaps are subtracted from the width of the screen, and what is left is
* drawn one span at a time. Vertices land exactly on the gap edges, so a
* hole is never snapped to the profile's 50px grid.
*
* The Step — the floor lifting into the lane — was drawn here too, and
* went with the rest of the v1.x obstacle set (roadmap R1.3). What
* survives it is the technique, because the track's own relief is built
* the same way (R3): a piece of surface at a different height, with the
* line running continuously up the vertical face and along the top. One
* mark, one silhouette, and no seam to give it away — which is what makes
* raised ground read as *the floor rising* rather than as a box on it.
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

// The lit edge: how bright it is when its world is dormant, and how much
// it gains once that world is the one being played in.
TERRAIN_RIM_DORMANT :: 0.30
TERRAIN_RIM_ALIVE :: 0.70
TERRAIN_GLOW_STRENGTH :: 0.35
TERRAIN_GLOW_SPREAD :: 5

// How far past each screen edge the terrain is built, so a hole whose
// edge is just off screen still cuts correctly. Comfortably more than one
// profile entry at the fastest tier, which is 74 px wide.
TERRAIN_MARGIN :: 100

// How deep the lit cross-section of a broken floor runs, in pixels.
CHASM_WALL_DEPTH :: 22

// How far a dissolving ceiling edge fades, in pixels.
DREAM_HOLE_FADE :: 30
DREAM_HOLE_FADE_STEP :: 3
DREAM_HOLE_GLOW :: 0.30

// The surface height at any screen x, from the shared profile.
//
// A thin wrapper on core rather than a copy of it: a hole can begin
// anywhere, so the spans on either side of it need a vertex exactly at
// its edge, and asking for the surface as a function of x is what makes
// that possible.
terrain_surface_y :: proc(world: game.World, is_floor: bool, x: f32) -> f32 {
	lane: core.Lane = is_floor ? .Real : .Dream
	return core.terrain_surface_y(game.get_ground(world), lane, x)
}

// A range of screen x at one height. lift is how far the floor is raised
// over it, which is zero everywhere except on a step.
Span :: struct {
	start: f32,
	end:   f32,
}

// Every stretch of one lane's surface that a hole has taken out of it, in
// screen x, sorted and merged.
//
// Merging matters: two gaps that touch have no ground between them, and
// drawing the zero-width span that separates them would put a lit rim
// line down the middle of a hole.
collect_gap_spans :: proc(
	world: game.World,
	obstacles: []game.Obstacle,
	lane: core.Lane,
	allocator := context.temp_allocator,
) -> [dynamic]Span {
	found := make([dynamic]Span, 0, 8, allocator)

	for obstacle in obstacles {
		if !game.is_gap(obstacle.obstacle_type) || obstacle.lane != lane {
			continue
		}
		rect := game.get_obstacle_rect(obstacle, world)
		start := max(rect.x, -TERRAIN_MARGIN)
		end := min(rect.x + rect.width, core.SCREEN_WIDTH + TERRAIN_MARGIN)
		if end > start {
			append(&found, Span{start = start, end = end})
		}
	}

	slice.sort_by(found[:], proc(a, b: Span) -> bool {return a.start < b.start})

	merged := make([dynamic]Span, 0, len(found), allocator)
	for span in found {
		if len(merged) > 0 && span.start <= merged[len(merged) - 1].end {
			last := &merged[len(merged) - 1]
			last.end = max(last.end, span.end)
			continue
		}
		append(&merged, span)
	}
	return merged
}

// What is left of one side once the gaps are taken out of it.
solid_spans :: proc(gaps: []Span, allocator := context.temp_allocator) -> [dynamic]Span {
	spans := make([dynamic]Span, 0, len(gaps) + 1, allocator)

	cursor := f32(-TERRAIN_MARGIN)
	for gap in gaps {
		if gap.start > cursor {
			append(&spans, Span{start = cursor, end = gap.start})
		}
		cursor = max(cursor, gap.end)
	}
	if cursor < core.SCREEN_WIDTH + TERRAIN_MARGIN {
		append(&spans, Span{start = cursor, end = core.SCREEN_WIDTH + TERRAIN_MARGIN})
	}
	return spans
}

// The x positions to sample a span at: both ends, plus every profile
// vertex inside it, so the drawn edge follows the same line the profile
// describes.
//
// The vertices are spaced in time, not in pixels, so how far apart they
// land on screen is the scroll speed — the undulation stretches as a run
// gets faster (core/terrain.odin).
@(private)
span_samples :: proc(
	world: game.World,
	span: Span,
	allocator := context.temp_allocator,
) -> [dynamic]f32 {
	samples := make([dynamic]f32, 0, 32, allocator)
	append(&samples, span.start)

	ground := game.get_ground(world)
	start_time := core.ground_time_at_x(ground, span.start)
	end_time := core.ground_time_at_x(ground, span.end)

	first := math.ceil(start_time / core.TERRAIN_SEGMENT_TIME) * core.TERRAIN_SEGMENT_TIME
	for boundary := first; boundary < end_time; boundary += core.TERRAIN_SEGMENT_TIME {
		x := span.start + (boundary - start_time) * max(ground.speed, 1)
		if x > span.start && x < span.end {
			append(&samples, x)
		}
	}

	append(&samples, span.end)
	return samples
}

// Fills one unbroken stretch of ground, from its surface to the screen
// edge, and runs the world's light along the surface.
//
// It takes a list of pieces rather than one span because the track's own
// relief will arrive that way (roadmap R3): consecutive pieces share an
// x, so the two points there differ only in height and a vertical face
// falls out of the polyline for free — for the fill and for the lit edge
// alike. Today every stretch is a single piece.
@(private)
draw_terrain_stretch :: proc(
	world: game.World,
	parts: []Span,
	palette: core.Palette,
	alive: f32,
	is_floor: bool,
) {
	outline := make([dynamic]rl.Vector2, 0, 64, context.temp_allocator)
	for part in parts {
		for x in span_samples(world, part) {
			append(&outline, rl.Vector2{x, terrain_surface_y(world, is_floor, x)})
		}
	}
	if len(outline) < 2 {
		return
	}

	edge_y: f32 = is_floor ? core.SCREEN_HEIGHT : 0

	strip := make([dynamic]rl.Vector2, 0, len(outline) * 2, context.temp_allocator)
	for point in outline {
		append(&strip, point)
		append(&strip, rl.Vector2{point.x, edge_y})
	}
	rl.DrawTriangleStrip(raw_data(strip[:]), i32(len(strip)), palette.silhouette)

	// The rim: the world's own light run along the surface, as one neon
	// stroke (stroke.odin) rather than as a segment per sample. Same
	// shape, three differences that only a single mark can have — the
	// turns weld instead of leaving a wedge, the ends round over the lip
	// of a hole, and the halo stops beading at every vertex, which it did
	// for as long as the rim was a row of separate glowing lines.
	//
	// The line is always drawn at full opacity even when its world is
	// dormant: it is the boundary between ground and air, and losing it
	// would cost readability (pillar 2) to buy mood.
	rim_alpha := TERRAIN_RIM_DORMANT + (TERRAIN_RIM_ALIVE - TERRAIN_RIM_DORMANT) * alive

	rim := new_stroke(core.with_alpha(palette.light, rim_alpha), core.LIGHT_RIM_THICKNESS)
	rim.glow = TERRAIN_GLOW_STRENGTH * alive
	rim.spread = TERRAIN_GLOW_SPREAD
	// The ground keeps the colour it had. A neon core lifted toward white
	// is what the sketch asks of a *plant*; on a rim that runs the whole
	// width of the screen it is a brightness change nobody asked for, and
	// the bloom would pick it up twice over. One number to turn up if the
	// terrain should join the rest of the style later.
	rim.core_light = 0
	draw_stroke(outline[:], rim)
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

	gaps := collect_gap_spans(world, obstacles, is_floor ? core.Lane.Real : core.Lane.Dream)

	for gap in gaps {
		if is_floor {
			draw_chasm_gap(world, gap, palette, alive)
		} else {
			draw_dream_hole_gap(world, gap, palette, alive)
		}
	}

	for span in solid_spans(gaps[:]) {
		piece := [1]Span{span}
		draw_terrain_stretch(world, piece[:], palette, alive, is_floor)
	}
}

draw_terrain :: proc(world: game.World, obstacles: []game.Obstacle, palettes: core.PaletteSet) {
	draw_terrain_side(world, obstacles, palettes, true) // floor
	draw_terrain_side(world, obstacles, palettes, false) // ceiling
}
