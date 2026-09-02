/*
* Obstacle Render
* Draws each obstacle type with a shape that reads as what it represents,
* not a generic rectangle (Design Doc, section 12). Real lane obstacles
* are natural/solid (stone, cracked earth); Dream lane obstacles are
* organic/unnatural (pulsing membrane, torn rift).
*
* Every obstacle is a silhouette in the palette of its own world, lit
* along its edge by that world's light (roadmap T3.5). Nothing here picks
* a color of its own: an obstacle in the Dream lane goes violet or washes
* out with the convergence without this file knowing that happened.
*
* The shapes themselves are unchanged and still wrong in the two ways
* recorded in CLAUDE.md: a Chasm is drawn standing on the floor instead
* of cut into it, and it collides like a Block. Both are roadmap phase 6
* — this pass was about color, and repainting a shape does not make it
* the right shape.
*/
package render

import "../core"
import "../game"
import rl "vendor:raylib/v55"

// How strongly an obstacle's lit edge glows. Lower than the terrain's:
// obstacles are small and numerous, and a halo on each one would eat the
// contrast that makes them readable at 400 px/s (pillar 2).
OBSTACLE_GLOW_STRENGTH :: 0.22
OBSTACLE_GLOW_SPREAD :: 4

draw_obstacle :: proc(obstacle: game.Obstacle, world: game.World, palettes: core.PaletteSet) {
	position := game.get_obstacle_position(obstacle, world)
	size := game.get_obstacle_size(obstacle, world)

	is_real := obstacle.lane == .Real
	palette := is_real ? palettes.real : palettes.dream
	alive := is_real ? palettes.real_alive : palettes.dream_alive

	switch obstacle.obstacle_type {
	case .Block:
		draw_block(position, size, palette, alive)
	case .Chasm:
		draw_chasm(position, size, palette, alive)
	case .DreamHole:
		draw_dream_hole(position, size, palette, alive)
	case .PulsingShape:
		draw_pulsing_shape(position, size, palette, alive)
	}
}

// --- Block: an irregular stone ---

// Normalized (0..1) outline of an irregular rock, hand-authored once.
// Scaled and positioned to each obstacle's actual size/position at draw time.
block_shape_points := [8]rl.Vector2 {
	{0.65, 1.00},
	{0.95, 0.75},
	{1.00, 0.35},
	{0.75, 0.05},
	{0.45, 0.00},
	{0.20, 0.15},
	{0.00, 0.55},
	{0.10, 1.00},
}

draw_block :: proc(position, size: rl.Vector2, palette: core.Palette, alive: f32) {
	points: [8]rl.Vector2
	for point, i in block_shape_points {
		points[i] = rl.Vector2{position.x + point.x * size.x, position.y + point.y * size.y}
	}

	rl.DrawTriangleFan(raw_data(points[:]), i32(len(points)), palette.silhouette)
	draw_lit_outline(points[:], palette, alive)
}

// Draws a closed outline (last point connects back to the first) in the
// world's light: a hard line always, plus an additive halo that grows
// with how alive that world is. This is what replaces the flat black
// border every shape used to carry.
draw_lit_outline :: proc(points: []rl.Vector2, palette: core.Palette, alive: f32) {
	rim_color := core.with_alpha(palette.light, 0.35 + 0.45 * alive)

	for i in 0 ..< len(points) {
		next := (i + 1) % len(points)
		draw_glow_line(
			points[i],
			points[next],
			core.RIM_THICKNESS,
			OBSTACLE_GLOW_SPREAD,
			palette.light,
			OBSTACLE_GLOW_STRENGTH * alive,
		)
	}
	for i in 0 ..< len(points) {
		next := (i + 1) % len(points)
		rl.DrawLineEx(points[i], points[next], core.RIM_THICKNESS, rim_color)
	}
}

// --- Chasm: a crack in the ground, with a sense of depth ---

// Layered dark bands, each narrower and darker than the last, receding
// toward the bottom — a cheap depth illusion without real 3D. A hole is
// an absence of world, so the layers run from the world's silhouette
// down to nothing at all rather than to another color.
CHASM_LAYER_COUNT :: 4
CHASM_VOID_COLOR :: rl.Color{0, 0, 0, 255}

draw_chasm :: proc(position, size: rl.Vector2, palette: core.Palette, alive: f32) {
	for i in 0 ..< CHASM_LAYER_COUNT {
		t := f32(i) / f32(CHASM_LAYER_COUNT - 1) // 0 at top, 1 at bottom

		// Each layer is narrower than the last, centered horizontally,
		// so the crack appears to taper as it goes down.
		inset := size.x * 0.12 * t
		layer_rect := rl.Rectangle {
			position.x + inset,
			position.y + size.y * t * 0.5,
			size.x - inset * 2,
			size.y * (1 - t * 0.5),
		}

		rl.DrawRectangleRec(layer_rect, core.lerp_color(palette.silhouette, CHASM_VOID_COLOR, t))
	}

	// A jagged top edge (a simple zigzag), reading as broken/cracked ground
	// rather than a clean rectangular hole.
	ZIGZAG_STEPS :: 5
	step_width := size.x / f32(ZIGZAG_STEPS)
	edge_color := core.with_alpha(palette.light, 0.30 + 0.40 * alive)
	for i in 0 ..< ZIGZAG_STEPS {
		x1 := position.x + f32(i) * step_width
		x2 := x1 + step_width
		y_offset: f32 = i % 2 == 0 ? 0 : 5
		rl.DrawLineEx(
			rl.Vector2{x1, position.y + y_offset},
			rl.Vector2{x2, position.y + (5 - y_offset)},
			core.RIM_THICKNESS,
			edge_color,
		)
	}
}

// --- Dream Hole: a jagged tear in the ceiling, glowing faintly ---

// Same layered-depth trick as the Chasm, but inverted (recedes upward)
// and lit from inside instead of going black: the Real world's absence is
// a void, the Dream world's is a way through — same structure, opposite
// reading, which is the "full vs void" pairing of Design Doc section 5.
DREAM_HOLE_LAYER_COUNT :: 4
DREAM_HOLE_GLOW_STRENGTH :: 0.30

draw_dream_hole :: proc(position, size: rl.Vector2, palette: core.Palette, alive: f32) {
	for i in 0 ..< DREAM_HOLE_LAYER_COUNT {
		t := f32(i) / f32(DREAM_HOLE_LAYER_COUNT - 1) // 0 at the ceiling, 1 deepest

		inset := size.x * 0.12 * t
		layer_rect := rl.Rectangle {
			position.x + inset,
			position.y,
			size.x - inset * 2,
			size.y * (1 - t * 0.5),
		}

		rl.DrawRectangleRec(layer_rect, core.lerp_color(palette.silhouette, palette.accent, t))
	}

	// The light that leaks out of the tear, centered on its deepest part.
	draw_glow_circle(
		rl.Vector2{position.x + size.x * 0.5, position.y + size.y * 0.3},
		size.x * 0.8,
		palette.accent,
		DREAM_HOLE_GLOW_STRENGTH * (0.4 + 0.6 * alive),
	)

	// Jagged bottom edge (the tear "hangs" from the ceiling), zigzag pattern.
	ZIGZAG_STEPS :: 5
	step_width := size.x / f32(ZIGZAG_STEPS)
	edge_y := position.y + size.y
	edge_color := core.with_alpha(palette.light, 0.35 + 0.45 * alive)
	for i in 0 ..< ZIGZAG_STEPS {
		x1 := position.x + f32(i) * step_width
		x2 := x1 + step_width
		y_offset: f32 = i % 2 == 0 ? 0 : 5
		rl.DrawLineEx(
			rl.Vector2{x1, edge_y - y_offset},
			rl.Vector2{x2, edge_y - (5 - y_offset)},
			core.RIM_THICKNESS,
			edge_color,
		)
	}
}

// --- Pulsing Shape: an organic membrane hanging from the ceiling ---

// Drawn as a stack of overlapping circles, tapering toward the tip —
// reads as a soft, organic blob rather than a rigid mechanical shape.
// Size (especially size.y) is already animated by get_obstacle_size, so
// this just needs to render whatever height it's given.
PULSING_LAYER_COUNT :: 5
PULSING_TIP_GLOW :: 0.35

draw_pulsing_shape :: proc(position, size: rl.Vector2, palette: core.Palette, alive: f32) {
	center_x := position.x + size.x * 0.5

	for i in 0 ..< PULSING_LAYER_COUNT {
		t := f32(i) / f32(PULSING_LAYER_COUNT - 1) // 0 at ceiling, 1 at tip
		radius := size.x * 0.5 * (1 - t * 0.3) // tapers slightly toward the tip
		center_y := position.y + size.y * t

		// Dark where it grows out of the ceiling, lit at the tip: the tip
		// is the part that reaches into the lane, so it is the part that
		// has to announce itself.
		rl.DrawCircleV(
			rl.Vector2{center_x, center_y},
			radius,
			core.lerp_color(palette.silhouette, palette.accent, t * 0.85),
		)
	}

	tip := rl.Vector2{center_x, position.y + size.y}
	draw_glow_circle(
		tip,
		size.x * 0.9,
		palette.accent,
		PULSING_TIP_GLOW * (0.4 + 0.6 * alive),
	)

	// A faint lit rim where it meets the ceiling, so it doesn't look like
	// it's floating in front of it.
	rl.DrawCircleLinesV(
		rl.Vector2{center_x, position.y},
		size.x * 0.5,
		core.with_alpha(palette.light, 0.25 + 0.35 * alive),
	)
}
