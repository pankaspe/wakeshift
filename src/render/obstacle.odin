/*
* Obstacle Render
* What is left of the obstacle set once the world became a line.
*
* Two things are drawn here, and they are exactly the two dangers that
* are not part of a surface:
*
*   the floating cube  the one cube that is not standing on its lane, so
*                      the terrain cannot weld it into its own line
*   the Sentinel       a band across the middle of the corridor, which
*                      belongs to neither lane
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
* Both marks here are closed strokes with right angles in them, and
* nothing else on screen has one.
*
* Both also **truncate themselves at both fronts** — written by the pen on
* the right (RL.5), eaten by the Corruption on the left (RL.6). A cube
* welded into the terrain gets that for free, because the terrain's spans
* are cut at both; these two are drawn on their own, so each builds its
* outline only across the stretch that currently exists and leaves the
* loop open wherever it was cut. That is the whole reveal and the whole
* decay: no per-obstacle animation, no state remembering how far along a
* shape is — just a shape built between two moving edges every frame.
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

// How much heavier the marks where the beam meets the two lanes are than
// the beam itself.
SENTINEL_FOOT_WEIGHT :: 1.9

SENTINEL_GLOW_STRENGTH :: 0.55
SENTINEL_GLOW_SPREAD :: 6
SENTINEL_EDGE_ALPHA :: 0.75
SENTINEL_AXIS_ALPHA :: 0.85

draw_obstacle :: proc(
	obstacle: game.Obstacle,
	world: game.World,
	palettes: core.PaletteSet,
	front_x: f32,
) {
	if obstacle.obstacle_type == .Sentinel {
		draw_sentinel(obstacle, world, palettes, front_x)
		return
	}
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

// --- The Sentinel ---
//
// A beam **across the corridor**, from the floor to the ceiling: three
// vertical marks rather than a horizontal band. The bright one is the
// middle of the window; the two faint ones are its edges, and they are
// what says how long the ban lasts — 0.7 s at the opening speed, which a
// single line could not tell you.
//
// It used to be drawn as a band taking 42% of the span, on the theory
// that a settled body was clear of it. Nothing was ever clear of it: the
// collision test is "are you moving while it is passing you" and has
// never looked at the beam's height (game/collision.odin). The band was a
// picture of a rule the game does not have, and a line crossing the
// corridor is a picture of the rule it does — *do not move now*.
//
// Drawn out of the neutral palette at full life: it belongs to neither
// lane, and the one thing it must never look like is an obstacle that
// only threatens the world it happens to be nearer.
@(private)
draw_sentinel :: proc(
	obstacle: game.Obstacle,
	world: game.World,
	palettes: core.PaletteSet,
	front_x: f32,
) {
	rect := game.get_obstacle_rect(obstacle, world)
	palette := palettes.neutral
	gain := glow_gain(palettes.world_t)

	from, to, _, _, any := drawn_extent(rect.x, rect.width, front_x)
	if !any {
		return
	}

	// Where the beam meets each lane, taken from the terrain's own surface
	// so the ends land on the lines rather than near them.
	beam :: proc(world: game.World, x: f32) -> [2]rl.Vector2 {
		return [2]rl.Vector2 {
			{x, terrain_surface_y(world, false, x)},
			{x, terrain_surface_y(world, true, x)},
		}
	}

	// The two edges of the window first, underneath: they are the quiet
	// half of the mark and the axis has to sit on top of them.
	edge := new_stroke(core.with_alpha(palette.light, SENTINEL_EDGE_ALPHA), core.RIM_THICKNESS)
	edge.glow = SENTINEL_GLOW_STRENGTH * 0.5
	edge.spread = SENTINEL_GLOW_SPREAD
	edge.core_light = 0
	apply_glow_gain(&edge, gain)

	// Only where the edge is really this beam's own end, not the pen's or
	// the Corruption's: a clipped end is where the world stops, and
	// marking it would say the ban starts there.
	if from <= rect.x + 0.01 {
		line := beam(world, from)
		draw_stroke(line[:], edge)
	}
	if to >= rect.x + rect.width - 0.01 {
		line := beam(world, to)
		draw_stroke(line[:], edge)
	}

	// The beam itself, down the middle of the window: the brightest thing
	// on screen while it is up, and it is meant to be — it is the line the
	// player must not cross.
	middle := clamp((rect.x + rect.width * 0.5), from, to)
	axis := beam(world, middle)
	core_line := new_stroke(core.with_alpha(palette.accent, SENTINEL_AXIS_ALPHA), core.LIGHT_RIM_THICKNESS)
	core_line.glow = SENTINEL_GLOW_STRENGTH
	core_line.spread = SENTINEL_GLOW_SPREAD
	core_line.core_light = 0.5
	apply_glow_gain(&core_line, gain)
	draw_stroke(axis[:], core_line)

	// And a mark where it touches each lane. The beam is the one thing in
	// the game that ends *on* both lines at once, and the two points are
	// what make it read as crossing them rather than as passing behind.
	foot := new_stroke(core.with_alpha(palette.accent, 1), core.LIGHT_RIM_THICKNESS * SENTINEL_FOOT_WEIGHT)
	foot.glow = SENTINEL_GLOW_STRENGTH
	foot.spread = SENTINEL_GLOW_SPREAD
	foot.core_light = 0.6
	apply_glow_gain(&foot, gain)
	for point in axis {
		draw_stroke_dot(point, foot)
	}
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
