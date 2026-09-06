/*
* World
* The camera, and the run's clock.
*
* THE CAMERA IS THE PRESSURE
*
* It advances at a constant speed whether the player is making progress or
* not, and that is the entire source of tension: standing still is not a
* neutral act, it is ground given away. Nothing else in the game has to
* punish hesitation, because the arithmetic already does.
*
* It is dragged faster in exactly one case, which is not a difficulty
* knob but a framing one: a player who has run far enough right would
* otherwise reach the edge of what has been drawn. Past
* RUNNER_MAX_SCREEN_X the camera follows them instead. What being ahead
* buys is the distance to the Corruption behind, not an emptier screen.
*/
package game

// Pixels of world per second. Constant for the whole of L1: speed is a
// level knob (Design Doc §12), and there is one level yet.
INITIAL_SCROLL_SPEED :: 270

World :: struct {
	scroll_speed:  f32,
	scroll_offset: f32, // where the camera's left edge is, in world px
	elapsed_time:  f32, // seconds since this run started

	// Completed simulation steps. With a fixed timestep the step count
	// *is* the clock: unlike elapsed_time it carries no floating point
	// drift, so it is the stable way to say when something happened —
	// which is how a recorded input log indexes its events.
	tick:          u64,
}

new_world :: proc() -> World {
	return World{scroll_speed = INITIAL_SCROLL_SPEED}
}

// Advances the camera and the run timer by exactly one simulation step.
//
// delta_time is always core.FIXED_TIMESTEP in the running game; it stays a
// parameter so a test can step the world at whatever rate it wants.
update_world :: proc(world: ^World, delta_time: f32, player_world_x: f32) {
	world.tick += 1
	world.scroll_offset += world.scroll_speed * delta_time

	// Never backwards: the camera may be dragged forward by a player who
	// has got ahead, and it may not be pulled back by one who has fallen
	// behind. Falling behind is what the Corruption is for.
	carried := MAZE_ORIGIN_X + player_world_x - RUNNER_MAX_SCREEN_X
	world.scroll_offset = max(world.scroll_offset, carried)

	world.elapsed_time += delta_time
}

