/*
* Obstacle Render
* What is left of the obstacle set once the world became a line.
*
* One thing is drawn here, and it is the one danger that is not part of a
* surface: the floating cube, the one cube that is not standing on its
* lane, so the terrain cannot weld it into its own line.
*
* Everything else has moved out. A cube standing on a lane is now a step
* in that lane's stroke and is drawn by render/terrain.odin, which is the
* only code that knows where its own surface is — the same reason the Gap
* has always been cut there rather than drawn here. Phase RL.2 emptied
* this file of the whole box vocabulary; what it lost is not readability
* but a stand-in for it, because a cube welded into the ground reads as
* "the world did this" instead of "something was put here".
*
* The rule that carries the weight now is geometric rather than about
* fill, which is why it survived the change of art direction intact:
*
*     the world curves, the danger corners
*
* The mark here is a closed stroke with right angles in it, and nothing
* else on screen has one.
*
* It also **truncates itself at both fronts** — written by the pen on the
* right (RL.5), eaten by the Corruption on the left (RL.6). A cube welded
* into the terrain gets that for free, because the terrain's spans are cut
* at both; this one is drawn on its own, so it builds its outline only
* across the stretch that currently exists and leaves the loop open
* wherever it was cut. That is the whole reveal and the whole decay: no
* per-obstacle animation, no state remembering how far along a shape is —
* just a shape built between two moving edges every frame.
*
* Where the loose ends land is the part that is easy to get backwards, so
* draw_cut_shape owns it: a shape cut on the right is open at the pen and
* closed at the end it finished, one cut on the left is the mirror, and
* one cut at both is not a loop at all — it is two marks.
*/
package render

import "../core"
import "../game"
import rl "vendor:raylib/v55"

// How strongly an obstacle's edge glows. Lower than the terrain's:
// obstacles are small and numerous, and a halo on each one would eat the
// contrast that makes them readable at speed (pillar 2).
OBSTACLE_GLOW_STRENGTH :: 0.30
OBSTACLE_GLOW_SPREAD :: 4

// How present an obstacle's line is when its world is dormant, and how
// much it gains once that world is the one being played in. Above the
// terrain's, because a danger has to be read before it is reached.
//
// And, unlike the terrain, an obstacle drawn here never *thins* with its
// lane (RL.4). The world is allowed to recede on the side the player is
// not on; a danger is not, because pillar 3 promises every one of them a
// visible arrival phase and the arrival happens while the lane is still
// the dormant one. The cube welded into the terrain's own line is the
// exception, and it is one by construction rather than by choice — it is
// the ground, and it is read by its two right angles rather than by its
// weight.
OBSTACLE_EDGE_DORMANT :: 0.55
OBSTACLE_EDGE_ALIVE :: 0.95

// The light a floating cube sits in. It is the only cube that is not
// resting on anything, and a halo underneath it is what says so before
// the player has watched it long enough to see it move.
FLOAT_GLOW_STRENGTH :: 0.30
FLOAT_GLOW_RADIUS :: 1.1

draw_obstacle :: proc(
	obstacle: game.Obstacle,
	world: game.World,
	palettes: core.PaletteSet,
	front_x: f32,
) {
	// The Gap is the surface failing to exist and every other cube is a
	// step in it: both belong to whoever owns the surface.
	if obstacle.obstacle_type != .Cube || obstacle.cube != .Float {
		return
	}

	is_real := obstacle.lane == .Real
	draw_floating_cube(
		game.get_obstacle_position(obstacle, world),
		game.get_obstacle_size(obstacle, world),
		front_x,
		is_real ? palettes.real : palettes.dream,
		is_real ? palettes.real_alive : palettes.dream_alive,
		glow_gain(palettes.world_t),
	)
}

// The stretch of a shape that exists right now, between the two fronts.
//
// `eaten` and `written` say which ends were cut, which is what decides
// where the outline's loose ends belong. `any` is false for a shape the
// pen has not reached yet or the Corruption has finished with.
@(private)
drawn_extent :: proc(
	left, width, front_x: f32,
) -> (
	from, to: f32,
	eaten, written, any: bool,
) {
	from = max(left, front_x)
	to = min(left + width, DRAW_FRONT_X)
	return from, to, from > left + 0.01, to < left + width - 0.01, to > from + 0.01
}

// Draws a shape given its two edges, both left to right, so that the
// loose ends land wherever it was cut.
//
// Cut on the right, the loose ends belong at the pen and the left end is
// a mark the pen already finished; cut on the left it is the mirror; cut
// at both there is no way round at all, so the two edges become two
// separate marks. Uncut, it closes.
@(private)
draw_cut_shape :: proc(top, bottom: []rl.Vector2, eaten, written: bool, stroke: Stroke) {
	mark := stroke

	if eaten && written {
		mark.closed = false
		draw_stroke(top, mark)
		draw_stroke(bottom, mark)
		return
	}

	path := make([dynamic]rl.Vector2, 0, len(top) + len(bottom), context.temp_allocator)
	if written {
		#reverse for point in top {
			append(&path, point)
		}
		for point in bottom {
			append(&path, point)
		}
	} else {
		for point in top {
			append(&path, point)
		}
		#reverse for point in bottom {
			append(&path, point)
		}
	}

	mark.closed = !eaten && !written
	draw_stroke(path[:], mark)
}

// The one cube that is not standing on anything: an open box of line,
// with the light it is suspended in underneath it. Without the halo a
// floating cube two thirds of the way up reads as a cube on a lane the
// player has misjudged — and now that the ground no longer has a fill to
// sit on, that is truer than it was.
//
// At the bottom of its bob the box's near edge lands exactly on the
// lane's own line, so it reads as resting on it and lifts away from it,
// which is the whole gesture of La Linea for free.
@(private)
draw_floating_cube :: proc(
	position, size: rl.Vector2,
	front_x: f32,
	palette: core.Palette,
	alive: f32,
	gain: GlowGain,
) {
	from, to, eaten, written, any := drawn_extent(position.x, size.x, front_x)
	if !any {
		return
	}

	// The halo is part of the object, so it arrives with it rather than
	// announcing it: it grows out of the front with the box, and goes with
	// it at the other end.
	center := rl.Vector2{(from + to) * 0.5, position.y + size.y * 0.5}
	draw_glow_circle(
		center,
		(to - from) * FLOAT_GLOW_RADIUS * gain.spread,
		palette.accent,
		FLOAT_GLOW_STRENGTH * (0.4 + 0.6 * alive) * gain.strength,
	)

	top := [2]rl.Vector2{{from, position.y}, {to, position.y}}
	bottom := [2]rl.Vector2{{from, position.y + size.y}, {to, position.y + size.y}}
	draw_cut_shape(top[:], bottom[:], eaten, written, obstacle_stroke(palette, alive, gain))
}

// The mark an obstacle is outlined with: one neon line in the world's
// light, which is what replaced the filled box plus border every obstacle
// used to carry. Whether it closes is draw_cut_shape's business.
@(private)
obstacle_stroke :: proc(palette: core.Palette, alive: f32, gain: GlowGain) -> Stroke {
	alpha := OBSTACLE_EDGE_DORMANT + (OBSTACLE_EDGE_ALIVE - OBSTACLE_EDGE_DORMANT) * alive

	edge := new_stroke(core.with_alpha(palette.light, alpha), TERRAIN_STROKE_THICKNESS)
	edge.glow = OBSTACLE_GLOW_STRENGTH * (0.4 + 0.6 * alive)
	edge.spread = OBSTACLE_GLOW_SPREAD
	edge.core_light = TERRAIN_CORE_LIGHT
	apply_glow_gain(&edge, gain)
	return edge
}
