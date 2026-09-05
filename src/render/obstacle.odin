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

// How many places the ray asks the corridor where it is. The lane
// surfaces are linear between keyframes, so this only has to be fine
// enough that a keyframe between two samples does not flatten a bend.
SENTINEL_BEAM_SAMPLES :: 12

// The pulsar: heavier than the world's marks, because it is the thing
// that tells you which lane to leave and it has to be read before the ray
// arrives (pillar 3).
SENTINEL_PULSAR_WEIGHT :: 2.4
SENTINEL_PULSAR_ALPHA :: 0.95

SENTINEL_GLOW_STRENGTH :: 0.55
SENTINEL_GLOW_SPREAD :: 6

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
// A pulsar on one lane and the ray it fires across the corridor. Both are
// the game's own stroke — the pulsar a heavy round mark sitting on the
// line, the ray a stroke whose *thickness* is the height that kills — so
// nothing here is a shape the rest of the picture does not already use.
//
// It bends with the corridor. The ray is sampled along its length between
// the two lane surfaces rather than drawn as one straight bar, so a
// corridor that is undulating carries the ray with it instead of being
// cut across.
//
// Drawn out of the neutral palette: it belongs to neither lane, and the
// one thing it must never look like is a threat to only one of them.
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
	sweep := game.get_sentinel_sweep(obstacle, world)

	// The pulsar, on the lane the ray leaves from, at the middle of the
	// window — which is the x the ray is aimed through.
	muzzle := clamp(rect.x + rect.width * 0.5, from, to)
	pulsar_y := terrain_surface_y(world, obstacle.lane == .Real, muzzle)

	// It charges as the window closes on the anchor and is spent once the
	// ray has gone: brightest at the instant it fires.
	charge := 1 - abs(sweep * 2 - 1)
	node := new_stroke(
		core.with_alpha(palette.accent, SENTINEL_PULSAR_ALPHA),
		core.LIGHT_RIM_THICKNESS * SENTINEL_PULSAR_WEIGHT,
	)
	node.glow = SENTINEL_GLOW_STRENGTH * (0.5 + 0.5 * charge)
	node.spread = SENTINEL_GLOW_SPREAD * (1 + charge)
	node.core_light = 0.6
	apply_glow_gain(&node, gain)
	draw_stroke_dot(rl.Vector2{muzzle, pulsar_y}, node)

	// The ray is drawn for as long as it exists, never only while it is
	// moving. It is lethal from the instant its window touches the
	// character, which is before the sweep starts — measured, 0.17 s of a
	// kill nobody could see. A danger that is not drawn is the one thing
	// pillar 3 forbids outright, so the parked ray sitting on the pulsar's
	// lane is not a detail: it is the warning.
	//
	// Its thickness *is* the height that kills, so the mark and the hitbox
	// are the same thing — the same rule the cube's step follows
	// (render/terrain.odin).
	beam: [SENTINEL_BEAM_SAMPLES + 1]rl.Vector2
	for i in 0 ..= SENTINEL_BEAM_SAMPLES {
		x := from + (to - from) * f32(i) / f32(SENTINEL_BEAM_SAMPLES)
		beam[i] = rl.Vector2{x, game.get_sentinel_beam_y(obstacle, world, x)}
	}

	ray := new_stroke(core.with_alpha(palette.accent, 1), game.SENTINEL_BEAM_HEIGHT)
	ray.glow = SENTINEL_GLOW_STRENGTH
	ray.spread = SENTINEL_GLOW_SPREAD
	ray.core_light = 0.75
	apply_glow_gain(&ray, gain)
	draw_stroke(beam[:], ray)
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
