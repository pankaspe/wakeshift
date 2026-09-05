/*
* Track
* Where the world is. The floor and the ceiling are not decoration and
* not a backdrop: they are the two lanes the player travels between, so
* their shape is simulation and it lives here where everything can see it
* (Design Doc, section 4).
*
* THE TRACK IS TWO CONSTANTS
*
*   spine   where the centre of the corridor sits, vertically
*   span    how tall the corridor is
*
* Both were keyframed in world time until C1, and patterns authored them:
* the corridor sagged, lifted, pinched and opened, and that undulation was
* content. It is gone, and what replaced it is not a simplification of the
* world but a change of *material*. The world is built out of bricks now
* (docs/inspiration/sketch.jpeg): flat floor, flat ceiling, and all the
* relief made of columns standing on them — staircases, towers, plateaus,
* canyons, and two facing columns wherever there used to be a pinch. One
* vocabulary for every piece of relief instead of two that could disagree
* about what a moment was for.
*
* So the floor is TRACK_FLOOR_Y and the ceiling is TRACK_CEILING_Y, both
* derived from the spine and the span so the two lanes still cannot
* disagree with each other. A body's support is not a constant — a cube it
* is already above is ground it stands on (game/world.odin) — but the
* *lane's own surface* is, everywhere and always.
*
* WHAT SURVIVED, AND WHY IT HAD TO
*
* Ground and ground_time_at_x. They are the map between scrolled pixels
* and world time, and that map is what makes an obstacle an **event in
* time** rather than a position on a screen: the generator authors a
* moment, ground_x_at_time turns it into an x, and ground_time_at_x turns
* an x back into the moment it belongs to. Scroll speed can change without
* redrawing a single pattern because of those two lines, and every
* difficulty decision the game has ever taken rests on them.
*
* WHAT THE PLAYER FEELS, AND WHAT THEY MUST NOT
*
* The flip's duration is constant in *time* (game/player.odin), and with
* the span fixed it is now also constant in *distance*: 390 px, always,
* in 0.167 s. The gesture never changes with the world, which used to be
* a rule about a corridor that moved and is now a property of one that
* does not.
*/
package core

import rl "vendor:raylib/v55"

// The corridor. One number for where it sits and one for how tall it is,
// exactly as before — they simply no longer move.
//
// The span opened from 340 to 390 on 5 September, when the two lanes were
// judged too close together to read as two places. It is the distance a
// flip crosses, and it is what CUBE_MAX_HEIGHT is derived from
// (game/obstacle.odin), so moving it moves the tallest legal column.
TRACK_SPINE :: SCREEN_HEIGHT / 2
TRACK_SPAN :: 390

// The two lanes. Derived rather than written, so that a change to the
// corridor cannot move one surface without moving the other.
TRACK_FLOOR_Y :: TRACK_SPINE + TRACK_SPAN / 2
TRACK_CEILING_Y :: TRACK_SPINE - TRACK_SPAN / 2

// How much screen lies outside the corridor, on each side. With the
// corridor fixed this is arithmetic — 165 px above the ceiling and the
// same below the floor — where it used to be a guarantee the track had to
// clamp every keyframe to keep.
TRACK_SKY :: TRACK_CEILING_Y

// The band of that sky the background is allowed to use, measured from
// each screen edge. Less than the whole of it on purpose: the parallax
// stays well clear of the corridor rather than up against it
// (render/parallax.odin).
TRACK_SKY_MARGIN :: 70

// The scrolling state the track depends on, and nothing more.
//
// It exists so that core can answer "where is this moment on screen" and
// "what moment is this x" without knowing what a World is: game builds
// one from its world, render passes the same thing through, and a test
// can make one up.
Ground :: struct {
	time:  f32, // world elapsed time, in seconds
	speed: f32, // current scroll speed, in px/s
}

// The screen x a world time is currently at.
//
// This is the mapping the whole design rests on. An obstacle is authored
// as a moment; where it is drawn, where it blocks and where it kills all
// come from here, so a run that speeds up moves every obstacle without
// re-authoring any of them.
//
// Anchored, never read off the player. The player's x moves (R2.1), and a
// world that followed it would slide against the patterns every time they
// lost or won back a stride.
ground_x_at_time :: proc(ground: Ground, time: f32) -> f32 {
	return WORLD_ANCHOR_X + (time - ground.time) * ground.speed
}

// The world time currently under screen x: the inverse of the above.
ground_time_at_x :: proc(ground: Ground, x: f32) -> f32 {
	return ground.time + (x - WORLD_ANCHOR_X) / max(ground.speed, 1)
}

// The surface of one lane. This is where the world *is*, as opposed to
// where a body standing on it sits.
//
// It takes no x and no ground since C1, and that is the whole of what the
// flat world buys: the sampler, its keyframes, its exact-extreme search
// and the "highest ground under the body's whole width" rule all collapse
// into two constants. The rule itself did not die — it moved to the
// columns, where a body straddling a staircase rests on the higher step
// (game/world.odin, get_support_y).
track_surface_y :: proc(lane: Lane) -> f32 {
	switch lane {
	case .Real:
		return TRACK_FLOOR_Y
	case .Dream:
		return TRACK_CEILING_Y
	}
	return TRACK_SPINE
}

// Where a body of the given size rests against one lane.
//
// Real: the feet stand on the floor, so the box's bottom is the surface.
// Dream: the head hangs from the ceiling, so the box's top is.
get_lane_y :: proc(lane: Lane, size: rl.Vector2) -> f32 {
	surface := track_surface_y(lane)
	switch lane {
	case .Real:
		return surface - size.y
	case .Dream:
		return surface
	}
	return surface
}
