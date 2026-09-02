/*
* World
* holds global world state, like scroll speed, and drives everything
* that moves automatically with it (floor, ceiling, obstacles)
*/
package game

// Initial scroll speed, in pixels per second (Design Doc, section 6: ~260-280 px/s)
INITIAL_SCROLL_SPEED :: 270

World :: struct {
	scroll_speed:  f32,
	scroll_offset: f32, // total distance scrolled so far, in pixels
	elapsed_time:  f32, // total seconds since this run started

	// How many fixed simulation steps this run has taken. With a fixed
	// timestep the step count *is* the clock: unlike elapsed_time it
	// carries no floating point drift, so it is the stable way to say
	// "when" something happened — which is how a recorded input log
	// indexes its events (roadmap T2.8).
	tick:          u64,
}

new_world :: proc() -> World {
	return World{scroll_speed = INITIAL_SCROLL_SPEED, scroll_offset = 0}
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
}
