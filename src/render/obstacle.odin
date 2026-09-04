/*
* Obstacle Render
* Draws the Cube. That is the whole file, and it is deliberate: the whole
* obstacle vocabulary is meant to be built out of one primitive at
* different sizes and arrangements (Design Doc, section 6), so a second
* shape here should be argued for before it is written.
*
* Every obstacle is a silhouette in the palette of its own world, lit
* along its edge by that world's light. Nothing here picks a colour of
* its own: an obstacle on the Dream lane goes violet, or washes out with
* the convergence, without this file knowing that happened.
*
* The Gap is **not drawn here**. It is the surface failing to exist, and
* the only code that knows where the surface is, is the terrain — so it
* cuts its own holes and this file returns early (render/terrain.odin).
* Drawing a hole here is what made it read as a box standing on the floor
* for the whole of the prototype.
*
* The cube variants — stacks, pyramids, the floating one, the mirrored
* pair — are roadmap R4.1 and R4.2. What arrives with them is a *look*
* for the cube; the flat square below is a placeholder that says "solid
* thing on this lane" and nothing more.
*/
package render

import "../core"
import "../game"
import rl "vendor:raylib/v55"

// How strongly an obstacle's lit edge glows. Lower than the terrain's:
// obstacles are small and numerous, and a halo on each one would eat the
// contrast that makes them readable at speed (pillar 2).
OBSTACLE_GLOW_STRENGTH :: 0.22
OBSTACLE_GLOW_SPREAD :: 4

draw_obstacle :: proc(obstacle: game.Obstacle, world: game.World, palettes: core.PaletteSet) {
	if game.is_gap(obstacle.obstacle_type) {
		return // drawn by the terrain, which owns where its own surface is
	}

	position := game.get_obstacle_position(obstacle, world)
	size := game.get_obstacle_size(obstacle, world)

	is_real := obstacle.lane == .Real
	palette := is_real ? palettes.real : palettes.dream
	alive := is_real ? palettes.real_alive : palettes.dream_alive

	draw_cube(position, size, palette, alive)
}

// --- The Cube ---
//
// A filled dark square with a lit edge: *danger is mass* (art direction).
// The corners are the whole read — a cube is the one thing in the world
// with straight lines and right angles, so it cannot be mistaken for the
// scenery, which is all curves and hollow outlines.
draw_cube :: proc(position, size: rl.Vector2, palette: core.Palette, alive: f32) {
	points := [4]rl.Vector2 {
		{position.x, position.y},
		{position.x + size.x, position.y},
		{position.x + size.x, position.y + size.y},
		{position.x, position.y + size.y},
	}

	rl.DrawRectangleV(position, size, palette.silhouette)
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
