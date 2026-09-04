/*
* World
* holds global world state, like scroll speed, and drives everything
* that moves automatically with it (floor, ceiling, obstacles)
*/
package game

import "../core"
import rl "vendor:raylib/v55"

// Initial scroll speed, in pixels per second (Design Doc, section 6: ~260-280 px/s)
INITIAL_SCROLL_SPEED :: 270

World :: struct {
	scroll_speed:  f32,
	scroll_offset: f32, // total distance scrolled so far, in pixels
	elapsed_time:  f32, // total seconds since this run started

	// The shape of the world itself: the two lanes, as a spine and a span
	// keyframed in time (core/track.odin). It lives in the World rather
	// than beside it because everything that asks "where is the ground"
	// already has a World, and because a Track is a plain value — render
	// copies the World forward by a fraction of a step and gets a track
	// it can read without anyone owning anything.
	//
	// Patterns author it (game/pattern.odin) exactly the way they author
	// obstacles, and for the same reason: the ground is level content, not
	// scenery that happens to be behind the level.
	track:         core.Track,

	// How many fixed simulation steps this run has taken. With a fixed
	// timestep the step count *is* the clock: unlike elapsed_time it
	// carries no floating point drift, so it is the stable way to say
	// "when" something happened — which is how a recorded input log
	// indexes its events (roadmap T2.8).
	tick:          u64,
}

new_world :: proc() -> World {
	return World {
		scroll_speed = INITIAL_SCROLL_SPEED,
		scroll_offset = 0,
		track = core.new_track(),
	}
}

// The world reduced to what the scrolling depends on (core/track.odin).
//
// The track is authored in time and asked about in screen x, so answering
// "where is the world here" needs the run's clock and its current speed —
// and nothing else. Handing over those two rather than the whole World is
// what lets core own the shape of the ground without importing anything.
get_ground :: proc(world: World) -> core.Ground {
	return core.Ground{time = world.elapsed_time, speed = world.scroll_speed}
}

// The two questions everything else asks about the ground, with the World
// already unpacked. Thin on purpose: the maths is core's, and these exist
// so that no caller has to hold a Track and a Ground in one hand.
get_lane_y :: proc(world: World, lane: core.Lane, x: f32, size: rl.Vector2) -> f32 {
	return core.get_lane_y(world.track, get_ground(world), lane, x, size)
}

get_surface_y :: proc(world: World, lane: core.Lane, x: f32) -> f32 {
	return core.track_surface_y(world.track, get_ground(world), lane, x)
}

// The corridor at the anchor, for anything that wants to sit with the
// world rather than on it — the background's horizon, most of all.
get_track_at_anchor :: proc(world: World) -> (spine, span: f32) {
	return core.track_sample(world.track, world.elapsed_time)
}

// How quickly scroll_speed eases toward a new target when the tier
// changes, in seconds — smaller is snappier, larger is smoother.
SCROLL_SPEED_EASE_TIME :: 1.0

// Advances the scroll offset and the run timer by exactly one simulation
// step. scroll_speed eases toward target_scroll_speed rather than
// snapping, so obstacles already generated (Section 8's time-based
// positioning) don't visibly jump when a difficulty tier changes
// (Section 18).
//
// delta_time is always core.FIXED_TIMESTEP in the running game; it stays
// a parameter so a test can step the world at whatever rate it wants.
update_world :: proc(world: ^World, delta_time: f32, target_scroll_speed: f32) {
	world.tick += 1

	ease_factor := delta_time / SCROLL_SPEED_EASE_TIME
	if ease_factor > 1 {
		ease_factor = 1
	}
	world.scroll_speed += (target_scroll_speed - world.scroll_speed) * ease_factor

	world.scroll_offset += world.scroll_speed * delta_time
	world.elapsed_time += delta_time

	// Keyframes the world has left behind. Kept here rather than beside
	// the obstacle cull because the track is part of the World and this
	// is the one procedure that advances it.
	core.track_prune(&world.track, world.elapsed_time - core.TRACK_HISTORY)
}
