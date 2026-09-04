/*
* Obstacle Render
* Draws the two dangers that are *things*: the Cube in all its forms, and
* the Sentinel. The Gap is not drawn here — it is the surface failing to
* exist, and the only code that knows where the surface is, is the
* terrain, so it cuts its own holes and this file returns early
* (render/terrain.odin). Drawing a hole here is what made it read as a box
* standing on the floor for the whole of the prototype.
*
* Every obstacle is a silhouette in the palette of its own world, lit
* along its edge by that world's light. Nothing here picks a colour of
* its own: an obstacle on the Dream lane goes violet, or washes out with
* the convergence, without this file knowing that happened.
*
* THE WHOLE CUBE VOCABULARY IS ONE BOX
*
* A stack is three of them in a column, a pyramid is three columns of
* different heights, a floating one is a single box held off its surface
* — and all of them are drawn from the same fill plus the same lit
* outline, at the same weights. That is not economy for its own sake: the
* player has to read "solid thing, this lane, this wide" in a fraction of
* a second (pillar 2), and a set of shapes that share a mark is read as a
* set. The only variety that is allowed to matter is the silhouette.
*
* The Sentinel breaks the pattern on purpose, because it is the one
* danger that is not on a lane. It rides the spine and takes a fixed
* fraction of the span, so it opens and closes with the corridor, and it
* is drawn out of the *neutral* palette — it belongs to neither world,
* which is exactly what makes it a rule about the space between them.
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

// The seams inside a stack, drawn dimmer than the outline: they say
// "three cubes" without competing with the shape's own edge.
STACK_SEAM_ALPHA :: 0.22

// The light a floating cube sits in. It is the only cube that is not
// resting on anything, and a halo underneath it is what says so before
// the player has watched it long enough to see it move.
FLOAT_GLOW_STRENGTH :: 0.30
FLOAT_GLOW_RADIUS :: 1.1

// How many places the beam asks the corridor where it is. The spine is
// linear between keyframes, so this only has to be fine enough that a
// keyframe falling between two samples does not visibly flatten a corner.
SENTINEL_SAMPLES :: 24
SENTINEL_GLOW_STRENGTH :: 0.55
SENTINEL_GLOW_SPREAD :: 6
SENTINEL_AXIS_ALPHA :: 0.85

draw_obstacle :: proc(obstacle: game.Obstacle, world: game.World, palettes: core.PaletteSet) {
	if game.is_gap(obstacle.obstacle_type) {
		return // drawn by the terrain, which owns where its own surface is
	}
	if obstacle.obstacle_type == .Sentinel {
		draw_sentinel(obstacle, world, palettes)
		return
	}

	position := game.get_obstacle_position(obstacle, world)
	size := game.get_obstacle_size(obstacle, world)

	is_real := obstacle.lane == .Real
	palette := is_real ? palettes.real : palettes.dream
	alive := is_real ? palettes.real_alive : palettes.dream_alive

	switch obstacle.cube {
	case .Stack:
		draw_stack(position, size, palette, alive)
	case .Pyramid:
		draw_pyramid(position, size, is_real, palette, alive)
	case .Float:
		draw_floating_cube(position, size, is_real, palette, alive)
	case .Standard, .Small, .Wide:
		draw_cube(position, size, palette, alive)
	}
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

// A column of cubes. One silhouette and one outline, because it is one
// obstacle; the seams are drawn inside it, dim, so the eye can count the
// boxes without the shape breaking into three.
@(private)
draw_stack :: proc(position, size: rl.Vector2, palette: core.Palette, alive: f32) {
	draw_cube(position, size, palette, alive)

	seam_color := core.with_alpha(palette.light, STACK_SEAM_ALPHA * (0.4 + 0.6 * alive))
	for offset := f32(game.CUBE_UNIT); offset < size.y - 1; offset += game.CUBE_UNIT {
		y := position.y + offset
		rl.DrawLineEx(
			rl.Vector2{position.x, y},
			rl.Vector2{position.x + size.x, y},
			core.RIM_THICKNESS,
			seam_color,
		)
	}
}

// Cubes in a staircase, rising away from the player. Filled column by
// column and then outlined as **one** stepped polygon, which is what
// makes it read as a single mass with a shaped edge rather than as three
// boxes that happen to be touching — the same technique the track's own
// relief uses (render/terrain.odin).
@(private)
draw_pyramid :: proc(
	position, size: rl.Vector2,
	is_real: bool,
	palette: core.Palette,
	alive: f32,
) {
	columns := max(int(size.x / game.CUBE_UNIT), 1)
	width := size.x / f32(columns)

	// The lane's own surface, which is the side every column grows from.
	base_y := is_real ? position.y + size.y : position.y
	grow := is_real ? f32(-1) : f32(1)

	outline := make([dynamic]rl.Vector2, 0, 2 * columns + 2, context.temp_allocator)
	append(&outline, rl.Vector2{position.x, base_y})

	for column in 0 ..< columns {
		height := f32(column + 1) * game.CUBE_UNIT
		left := position.x + f32(column) * width
		top := base_y + grow * height

		rl.DrawRectangleRec(
			rl.Rectangle{left, min(base_y, top), width, height},
			palette.silhouette,
		)

		append(&outline, rl.Vector2{left, top})
		append(&outline, rl.Vector2{left + width, top})
	}

	append(&outline, rl.Vector2{position.x + size.x, base_y})
	draw_lit_outline(outline[:], palette, alive)
}

// The one cube that is not standing on anything. Same box, plus the light
// it is suspended in: without the halo a floating cube two thirds of the
// way up reads as a cube on a lane the player has misjudged.
@(private)
draw_floating_cube :: proc(
	position, size: rl.Vector2,
	is_real: bool,
	palette: core.Palette,
	alive: f32,
) {
	center := rl.Vector2{position.x + size.x * 0.5, position.y + size.y * 0.5}
	draw_glow_circle(
		center,
		size.x * FLOAT_GLOW_RADIUS,
		palette.accent,
		FLOAT_GLOW_STRENGTH * (0.4 + 0.6 * alive),
	)
	draw_cube(position, size, palette, alive)
}

// --- The Sentinel ---
//
// A band across the middle of the corridor, following the spine for its
// whole length so that it is unmistakably *of* the world rather than laid
// over it. Drawn out of the neutral palette at full life: it belongs to
// neither lane, and the one thing it must never look like is an obstacle
// that only threatens the world it happens to be nearer.
//
// Mass with a lit axis, not a bar of light. *Danger is mass* holds for
// this as much as for a cube, and the axis is what says the mass is a
// beam — a solid rectangle of light would land in the same visual bucket
// as a Fragment, which is the one thing in the game the player is
// supposed to run into.
@(private)
draw_sentinel :: proc(obstacle: game.Obstacle, world: game.World, palettes: core.PaletteSet) {
	rect := game.get_obstacle_rect(obstacle, world)
	palette := palettes.neutral

	top: [SENTINEL_SAMPLES + 1]rl.Vector2
	bottom: [SENTINEL_SAMPLES + 1]rl.Vector2
	axis: [SENTINEL_SAMPLES + 1]rl.Vector2
	strip: [(SENTINEL_SAMPLES + 1) * 2]rl.Vector2

	for i in 0 ..= SENTINEL_SAMPLES {
		x := rect.x + rect.width * f32(i) / f32(SENTINEL_SAMPLES)
		spine, span := game.get_track_at_x(world, x)
		half := span * game.SENTINEL_BAND * 0.5

		top[i] = rl.Vector2{x, spine - half}
		bottom[i] = rl.Vector2{x, spine + half}
		axis[i] = rl.Vector2{x, spine}
		strip[i * 2] = top[i]
		strip[i * 2 + 1] = bottom[i]
	}

	rl.DrawTriangleStrip(raw_data(strip[:]), i32(len(strip)), palette.silhouette)

	edge := new_stroke(core.with_alpha(palette.light, 0.75), core.LIGHT_RIM_THICKNESS)
	edge.glow = SENTINEL_GLOW_STRENGTH
	edge.spread = SENTINEL_GLOW_SPREAD
	draw_stroke(top[:], edge)
	draw_stroke(bottom[:], edge)

	// The axis is the brightest thing on screen while it is up, and it is
	// meant to be: it is the line the player must not cross.
	core_line := new_stroke(core.with_alpha(palette.accent, SENTINEL_AXIS_ALPHA), core.RIM_THICKNESS)
	core_line.glow = SENTINEL_GLOW_STRENGTH
	core_line.spread = SENTINEL_GLOW_SPREAD
	core_line.core_light = 0.5
	draw_stroke(axis[:], core_line)
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
