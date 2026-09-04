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
* Both also **truncate themselves at the draw front** (RL.5). A cube
* welded into the terrain gets that for free, because the terrain's spans
* are cut there; these two are drawn on their own, so each builds its
* outline only as far as the pen has reached and leaves the loop open
* there. That is the whole reveal: no per-obstacle animation, no state
* remembering how far along a shape is — just a shape built to a
* different right edge every frame (render/draw_front.odin).
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

// How many places the beam asks the corridor where it is. The spine is
// linear between keyframes, so this only has to be fine enough that a
// keyframe falling between two samples does not visibly flatten a corner.
SENTINEL_SAMPLES :: 24
SENTINEL_GLOW_STRENGTH :: 0.55
SENTINEL_GLOW_SPREAD :: 6
SENTINEL_EDGE_ALPHA :: 0.75
SENTINEL_AXIS_ALPHA :: 0.85

draw_obstacle :: proc(obstacle: game.Obstacle, world: game.World, palettes: core.PaletteSet) {
	if obstacle.obstacle_type == .Sentinel {
		draw_sentinel(obstacle, world, palettes)
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
		is_real ? palettes.real : palettes.dream,
		is_real ? palettes.real_alive : palettes.dream_alive,
		glow_gain(palettes.world_t),
	)
}

// Where a shape's right edge is right now: its own, or the pen, whichever
// has been reached. Returns false when the pen has not got to the shape
// at all, which is a shape that has simply not been drawn yet.
@(private)
drawn_extent :: proc(left, width: f32) -> (right: f32, whole: bool, any: bool) {
	right = min(left + width, DRAW_FRONT_X)
	return right, right >= left + width - 0.01, right > left + 0.01
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
	palette: core.Palette,
	alive: f32,
	gain: GlowGain,
) {
	right, whole, any := drawn_extent(position.x, size.x)
	if !any {
		return
	}

	// The halo is part of the object, so it arrives with it rather than
	// announcing it: it grows out of the front with the box.
	center := rl.Vector2{(position.x + right) * 0.5, position.y + size.y * 0.5}
	draw_glow_circle(
		center,
		(right - position.x) * FLOAT_GLOW_RADIUS * gain.spread,
		palette.accent,
		FLOAT_GLOW_STRENGTH * (0.4 + 0.6 * alive) * gain.strength,
	)

	top := position.y
	bottom := position.y + size.y

	if whole {
		box := [4]rl.Vector2 {
			{position.x, top},
			{right, top},
			{right, bottom},
			{position.x, bottom},
		}
		draw_obstacle_outline(box[:], palette, alive, gain, true)
		return
	}

	// Half written: the loop stays open at the pen, so the box reads as a
	// line that has not finished going round yet.
	partial := [4]rl.Vector2 {
		{right, top},
		{position.x, top},
		{position.x, bottom},
		{right, bottom},
	}
	draw_obstacle_outline(partial[:], palette, alive, gain, false)
}

// --- The Sentinel ---
//
// A band across the middle of the corridor, following the spine for its
// whole length so that it is unmistakably *of* the world rather than laid
// over it. Drawn out of the neutral palette at full life: it belongs to
// neither lane, and the one thing it must never look like is an obstacle
// that only threatens the world it happens to be nearer.
//
// An outline and a lit axis, with nothing inside. The outline is where
// the band stops being safe, and drawing it as a closed stroke is what
// says the band is a *thing* with two square ends rather than a pair of
// extra lanes: the corners are the read (art direction, "the world
// curves, the danger corners"). The axis is the brightest mark on screen
// while it is up, and it is meant to be — it is the line the player must
// not cross.
@(private)
draw_sentinel :: proc(obstacle: game.Obstacle, world: game.World, palettes: core.PaletteSet) {
	rect := game.get_obstacle_rect(obstacle, world)
	palette := palettes.neutral

	// The beam is 189 px wide, which is 0.7 s of crossing the pen at the
	// opening speed. Popping it into existence whole would be the one
	// place in the picture where something plainly did not get drawn.
	right, whole, any := drawn_extent(rect.x, rect.width)
	if !any {
		return
	}

	// The path runs *away* from the pen and back: the top edge from the
	// drawn end to the left, round the left end, and the bottom edge back
	// to the drawn end. Both loose ends are therefore at the pen, so
	// closing the loop draws the beam's right end and leaving it open
	// stops exactly where the ink stops. Built the other way round — which
	// is how it read before RL.5 — a half-written beam would be capped at
	// the pen and open at the end it had already finished.
	outline: [(SENTINEL_SAMPLES + 1) * 2]rl.Vector2
	axis: [SENTINEL_SAMPLES + 1]rl.Vector2

	for i in 0 ..= SENTINEL_SAMPLES {
		x := right - (right - rect.x) * f32(i) / f32(SENTINEL_SAMPLES)
		spine, span := game.get_track_at_x(world, x)
		half := span * game.SENTINEL_BAND * 0.5

		outline[i] = rl.Vector2{x, spine - half}
		outline[len(outline) - 1 - i] = rl.Vector2{x, spine + half}
		axis[i] = rl.Vector2{x, spine}
	}

	gain := glow_gain(palettes.world_t)

	edge := new_stroke(core.with_alpha(palette.light, SENTINEL_EDGE_ALPHA), core.LIGHT_RIM_THICKNESS)
	edge.glow = SENTINEL_GLOW_STRENGTH
	edge.spread = SENTINEL_GLOW_SPREAD
	edge.closed = whole
	apply_glow_gain(&edge, gain)
	draw_stroke(outline[:], edge)

	// The gain is the scene's, not a lane's, so applying it here does not
	// give the beam a world: it burns with everything else on screen.
	core_line := new_stroke(core.with_alpha(palette.accent, SENTINEL_AXIS_ALPHA), core.RIM_THICKNESS)
	core_line.glow = SENTINEL_GLOW_STRENGTH
	core_line.spread = SENTINEL_GLOW_SPREAD
	core_line.core_light = 0.5
	apply_glow_gain(&core_line, gain)
	draw_stroke(axis[:], core_line)
}

// A closed outline in the world's light: one neon mark welded back to its
// own first point, so a right angle is a mitre rather than two lines that
// happen to meet. This is what replaced the filled box plus border every
// obstacle used to carry.
@(private)
draw_obstacle_outline :: proc(
	points: []rl.Vector2,
	palette: core.Palette,
	alive: f32,
	gain: GlowGain,
	closed: bool,
) {
	alpha := OBSTACLE_EDGE_DORMANT + (OBSTACLE_EDGE_ALIVE - OBSTACLE_EDGE_DORMANT) * alive

	edge := new_stroke(core.with_alpha(palette.light, alpha), TERRAIN_STROKE_THICKNESS)
	edge.glow = OBSTACLE_GLOW_STRENGTH * (0.4 + 0.6 * alive)
	edge.spread = OBSTACLE_GLOW_SPREAD
	edge.core_light = TERRAIN_CORE_LIGHT
	edge.closed = closed
	apply_glow_gain(&edge, gain)
	draw_stroke(points, edge)
}
