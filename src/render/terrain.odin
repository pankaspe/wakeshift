/*
* Terrain
* Draws the floor and ceiling as an irregular, scrolling profile instead
* of flat tick marks — the Chasm/Dream Hole obstacles finally have real
* ground to interrupt (Design Doc, section 12).
*
* Both sides are the same dark silhouette; what tells them apart is the
* light along their edge, which takes the color of its own world and
* brightens as that world becomes the live one (roadmap T3.4). That is
* the palette's rule applied to the largest shape on screen: same body,
* different lighting.
*
* The two sides still share one profile. Giving the Dream ceiling a shape
* of its own belongs with the layers in roadmap phase 10, where the
* scenery is generated rather than hand-authored.
*/
package render

import "../core"
import "../game"
import "core:math"
import rl "vendor:raylib/v55"

TERRAIN_SEGMENT_WIDTH :: 50
TERRAIN_BASE_HEIGHT :: 14 // minimum protrusion from the screen edge
TERRAIN_PROFILE := [6]f32{0, 12, 4, 16, 6, 9} // extra height per segment, hand-authored once

// The lit edge: how bright it is when its world is dormant, and how much
// it gains once that world is the one being played in.
TERRAIN_RIM_DORMANT :: 0.30
TERRAIN_RIM_ALIVE :: 0.70

// The glow along the surface is the strongest single hint of which world
// is live, so it is worth more than the line itself.
TERRAIN_GLOW_STRENGTH :: 0.35
TERRAIN_GLOW_SPREAD :: 5

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

// Draws one side (floor or ceiling): a filled silhouette from the
// irregular surface line to the screen edge, then the light running
// along that surface.
draw_terrain_side :: proc(
	world: game.World,
	palettes: core.PaletteSet,
	is_floor: bool,
) {
	points := compute_terrain_points(world, is_floor)
	defer delete(points)

	if len(points) < 2 {
		return
	}

	palette := is_floor ? palettes.real : palettes.dream
	alive := is_floor ? palettes.real_alive : palettes.dream_alive

	// Build an alternating [surface, edge, surface, edge, ...] strip:
	// DrawTriangleStrip fills the zigzag ribbon between the two rows.
	strip := make([dynamic]rl.Vector2, 0, len(points) * 2)
	defer delete(strip)

	edge_y: f32 = is_floor ? core.SCREEN_HEIGHT : 0
	for p in points {
		append(&strip, p)
		append(&strip, rl.Vector2{p.x, edge_y})
	}

	rl.DrawTriangleStrip(raw_data(strip[:]), i32(len(strip)), palette.silhouette)

	// The rim: a hard line in the world's own light, plus an additive
	// halo that only really shows on the live side. The line is always
	// drawn at full opacity even when dormant — it is the boundary
	// between ground and air, and losing it would cost readability
	// (pillar 2) to buy mood.
	rim_alpha := TERRAIN_RIM_DORMANT + (TERRAIN_RIM_ALIVE - TERRAIN_RIM_DORMANT) * alive
	rim_color := core.with_alpha(palette.light, rim_alpha)

	for i in 0 ..< len(points) - 1 {
		draw_glow_line(
			points[i],
			points[i + 1],
			core.LIGHT_RIM_THICKNESS,
			TERRAIN_GLOW_SPREAD,
			palette.light,
			TERRAIN_GLOW_STRENGTH * alive,
		)
	}
	for i in 0 ..< len(points) - 1 {
		rl.DrawLineEx(points[i], points[i + 1], core.LIGHT_RIM_THICKNESS, rim_color)
	}
}

draw_terrain :: proc(world: game.World, palettes: core.PaletteSet) {
	draw_terrain_side(world, palettes, true) // floor
	draw_terrain_side(world, palettes, false) // ceiling
}
