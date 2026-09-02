
/*
* Obstacle Render
* Draws each obstacle type with a shape that reads as what it represents,
* not a generic rectangle (Design Doc, section 12). Real lane obstacles
* are natural/solid (stone, cracked earth); Dream lane obstacles are
* organic/unnatural (pulsing membrane, torn rift) — section 15.3.
*/
package render

import "../core"
import "../game"
import rl "vendor:raylib/v55"

draw_obstacle :: proc(obstacle: game.Obstacle, world: game.World) {
	position := game.get_obstacle_position(obstacle, world)
	size := game.get_obstacle_size(obstacle, world)

	switch obstacle.obstacle_type {
	case .Block:
		draw_block(position, size)
	case .Chasm:
		draw_chasm(position, size)
	case .DreamHole:
		draw_dream_hole(position, size)
	case .PulsingShape:
		draw_pulsing_shape(position, size)
	}
}

// --- Block: an irregular stone ---

OBSTACLE_STONE_COLOR :: rl.Color{60, 58, 62, 255}
OBSTACLE_RIM_COLOR :: rl.BLACK
OBSTACLE_RIM_THICKNESS :: core.RIM_THICKNESS // shared border weight across every element

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

draw_block :: proc(position, size: rl.Vector2) {
	points: [8]rl.Vector2
	for point, i in block_shape_points {
		points[i] = rl.Vector2{position.x + point.x * size.x, position.y + point.y * size.y}
	}

	rl.DrawTriangleFan(raw_data(points[:]), i32(len(points)), OBSTACLE_STONE_COLOR)
	draw_polygon_outline(points[:], OBSTACLE_RIM_COLOR, OBSTACLE_RIM_THICKNESS)
}

// Draws a closed outline (last point connects back to the first) with a
// real thickness, unlike DrawLineStrip which is always 1px. Shared by
// every obstacle shape that needs a proper border.
draw_polygon_outline :: proc(points: []rl.Vector2, color: rl.Color, thickness: f32) {
	for i in 0 ..< len(points) {
		next := (i + 1) % len(points)
		rl.DrawLineEx(points[i], points[next], thickness, color)
	}
}

// --- Chasm: a crack in the ground, with a sense of depth ---

// Layered dark bands, each narrower and darker than the last, receding
// toward the bottom — a cheap depth illusion without real 3D.
CHASM_LAYER_COUNT :: 4
CHASM_TOP_COLOR :: rl.Color{25, 20, 18, 255}
CHASM_BOTTOM_COLOR :: rl.Color{5, 4, 4, 255}

draw_chasm :: proc(position, size: rl.Vector2) {
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

		color := rl.Color {
			u8(f32(CHASM_TOP_COLOR.r) + (f32(CHASM_BOTTOM_COLOR.r) - f32(CHASM_TOP_COLOR.r)) * t),
			u8(f32(CHASM_TOP_COLOR.g) + (f32(CHASM_BOTTOM_COLOR.g) - f32(CHASM_TOP_COLOR.g)) * t),
			u8(f32(CHASM_TOP_COLOR.b) + (f32(CHASM_BOTTOM_COLOR.b) - f32(CHASM_TOP_COLOR.b)) * t),
			255,
		}
		rl.DrawRectangleRec(layer_rect, color)
	}

	// A jagged top edge (a simple zigzag), reading as broken/cracked ground
	// rather than a clean rectangular hole.
	ZIGZAG_STEPS :: 5
	step_width := size.x / f32(ZIGZAG_STEPS)
	for i in 0 ..< ZIGZAG_STEPS {
		x1 := position.x + f32(i) * step_width
		x2 := x1 + step_width
		y_offset: f32 = i % 2 == 0 ? 0 : 5
		rl.DrawLineEx(
			rl.Vector2{x1, position.y + y_offset},
			rl.Vector2{x2, position.y + (5 - y_offset)},
			2,
			OBSTACLE_RIM_COLOR,
		)
	}
}

// --- Dream Hole: a jagged tear in the ceiling, glowing faintly ---

// Same layered-depth trick as the Chasm, but inverted (recedes upward)
// and with a cool glow instead of pure black, to read as unnatural/dreamlike
// rather than a simple mirrored crack.
DREAM_HOLE_LAYER_COUNT :: 4
DREAM_HOLE_EDGE_COLOR :: rl.Color{40, 30, 70, 255}
DREAM_HOLE_CORE_COLOR :: rl.Color{140, 110, 220, 255}

draw_dream_hole :: proc(position, size: rl.Vector2) {
	for i in 0 ..< DREAM_HOLE_LAYER_COUNT {
		t := f32(i) / f32(DREAM_HOLE_LAYER_COUNT - 1) // 0 at the ceiling, 1 deepest

		inset := size.x * 0.12 * t
		layer_rect := rl.Rectangle {
			position.x + inset,
			position.y,
			size.x - inset * 2,
			size.y * (1 - t * 0.5),
		}

		color := rl.Color {
			u8(
				f32(DREAM_HOLE_EDGE_COLOR.r) +
				(f32(DREAM_HOLE_CORE_COLOR.r) - f32(DREAM_HOLE_EDGE_COLOR.r)) * t,
			),
			u8(
				f32(DREAM_HOLE_EDGE_COLOR.g) +
				(f32(DREAM_HOLE_CORE_COLOR.g) - f32(DREAM_HOLE_EDGE_COLOR.g)) * t,
			),
			u8(
				f32(DREAM_HOLE_EDGE_COLOR.b) +
				(f32(DREAM_HOLE_CORE_COLOR.b) - f32(DREAM_HOLE_EDGE_COLOR.b)) * t,
			),
			255,
		}
		rl.DrawRectangleRec(layer_rect, color)
	}

	// Jagged bottom edge (the tear "hangs" from the ceiling), zigzag pattern.
	ZIGZAG_STEPS :: 5
	step_width := size.x / f32(ZIGZAG_STEPS)
	edge_y := position.y + size.y
	for i in 0 ..< ZIGZAG_STEPS {
		x1 := position.x + f32(i) * step_width
		x2 := x1 + step_width
		y_offset: f32 = i % 2 == 0 ? 0 : 5
		rl.DrawLineEx(
			rl.Vector2{x1, edge_y - y_offset},
			rl.Vector2{x2, edge_y - (5 - y_offset)},
			2,
			DREAM_HOLE_EDGE_COLOR,
		)
	}
}

// --- Pulsing Shape: an organic membrane hanging from the ceiling ---

// Drawn as a stack of overlapping circles, tapering toward the tip —
// reads as a soft, organic blob rather than a rigid mechanical shape.
// Size (especially size.y) is already animated by get_obstacle_size
// (Section 11), so this just needs to render whatever height it's given.
PULSING_LAYER_COUNT :: 5
PULSING_BASE_COLOR :: rl.Color{60, 30, 80, 255} // near the ceiling: dark violet
PULSING_TIP_COLOR :: rl.Color{230, 120, 200, 255} // at the tip: bright glowing pink

draw_pulsing_shape :: proc(position, size: rl.Vector2) {
	center_x := position.x + size.x * 0.5

	for i in 0 ..< PULSING_LAYER_COUNT {
		t := f32(i) / f32(PULSING_LAYER_COUNT - 1) // 0 at ceiling, 1 at tip
		radius := size.x * 0.5 * (1 - t * 0.3) // tapers slightly toward the tip
		center_y := position.y + size.y * t

		color := rl.Color {
			u8(
				f32(PULSING_BASE_COLOR.r) +
				(f32(PULSING_TIP_COLOR.r) - f32(PULSING_BASE_COLOR.r)) * t,
			),
			u8(
				f32(PULSING_BASE_COLOR.g) +
				(f32(PULSING_TIP_COLOR.g) - f32(PULSING_BASE_COLOR.g)) * t,
			),
			u8(
				f32(PULSING_BASE_COLOR.b) +
				(f32(PULSING_TIP_COLOR.b) - f32(PULSING_BASE_COLOR.b)) * t,
			),
			255,
		}
		rl.DrawCircleV(rl.Vector2{center_x, center_y}, radius, color)
	}

	// A faint dark rim around the base, where it meets the ceiling,
	// so it doesn't look like it's just floating in front of it.
	rl.DrawCircleLinesV(rl.Vector2{center_x, position.y}, size.x * 0.5, OBSTACLE_RIM_COLOR)
}
