
/*
* Terrain
* Draws the floor and ceiling as an irregular, scrolling profile instead
* of flat tick marks — the Voragine/Buco Onirico obstacles finally have
* real ground to interrupt (Design Doc, section 12).
* Real and Dream terrain share the same look for now; differentiating
* them stylistically is deferred to Section 20's dedicated asset pass.
*/
package render

import "../core"
import "../game"
import "core:math"
import rl "vendor:raylib/v55"

TERRAIN_SEGMENT_WIDTH :: 50
TERRAIN_BASE_HEIGHT :: 14 // minimum protrusion from the screen edge
TERRAIN_PROFILE := [6]f32{0, 12, 4, 16, 6, 9} // extra height per segment, hand-authored once

TERRAIN_COLOR :: rl.Color{45, 36, 30, 255}
TERRAIN_RIM_COLOR :: rl.BLACK
TERRAIN_RIM_THICKNESS :: core.RIM_THICKNESS

// Computes the (x, surface_y) points describing the terrain's irregular
// edge across the visible screen width. world.scroll_offset drives which
// part of the profile is currently on screen, so it scrolls smoothly
// instead of jittering — same technique as the old tick marks, extended
// to also track a stable segment index (not just the phase offset).
compute_terrain_points :: proc(world: game.World, is_floor: bool) -> [dynamic]rl.Vector2 {
	points := make([dynamic]rl.Vector2, 0, 16)

	offset := math.mod(world.scroll_offset, TERRAIN_SEGMENT_WIDTH)
	start_index := int(world.scroll_offset / TERRAIN_SEGMENT_WIDTH)

	x := -offset
	index := start_index
	for x < core.SCREEN_WIDTH + TERRAIN_SEGMENT_WIDTH {
		variation := TERRAIN_PROFILE[index % len(TERRAIN_PROFILE)]

		y: f32
		if is_floor {
			y = core.SCREEN_HEIGHT - TERRAIN_BASE_HEIGHT - variation
		} else {
			y = TERRAIN_BASE_HEIGHT + variation
		}

		append(&points, rl.Vector2{x, y})
		x += TERRAIN_SEGMENT_WIDTH
		index += 1
	}

	return points
}

// Draws one side (floor or ceiling): a filled strip from the irregular
// surface line to the screen edge, plus a crisp rim line along the surface.
draw_terrain_side :: proc(world: game.World, is_floor: bool) {
	points := compute_terrain_points(world, is_floor)
	defer delete(points)

	if len(points) < 2 {
		return
	}

	// Build an alternating [surface, edge, surface, edge, ...] strip:
	// DrawTriangleStrip fills the zigzag ribbon between the two rows.
	strip := make([dynamic]rl.Vector2, 0, len(points) * 2)
	defer delete(strip)

	edge_y: f32 = is_floor ? core.SCREEN_HEIGHT : 0
	for p in points {
		append(&strip, p)
		append(&strip, rl.Vector2{p.x, edge_y})
	}

	rl.DrawTriangleStrip(raw_data(strip[:]), i32(len(strip)), TERRAIN_COLOR)

	for i in 0 ..< len(points) - 1 {
		rl.DrawLineEx(points[i], points[i + 1], TERRAIN_RIM_THICKNESS, TERRAIN_RIM_COLOR)
	}
}

draw_terrain :: proc(world: game.World) {
	draw_terrain_side(world, true) // floor
	draw_terrain_side(world, false) // ceiling
}
