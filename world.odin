/*
* World
* holds global world state, like scroll speed, and drives everything
* that moves automatically with it (floor, ceiling, obstacles)
*/
package main

// Initial scroll speed, in pixels per second (Design Doc, section 6: ~260-280 px/s)
INITIAL_SCROLL_SPEED :: 270

World :: struct {
	scroll_speed:  f32,
	scroll_offset: f32, // total distance scrolled so far, in pixels
	elapsed_time:  f32, // total seconds since this run started
}

new_world :: proc() -> World {
	return World{scroll_speed = INITIAL_SCROLL_SPEED, scroll_offset = 0}
}

// Advances the scroll offset and the run timer.
update_world :: proc(world: ^World, delta_time: f32) {
	world.scroll_offset += world.scroll_speed * delta_time
	world.elapsed_time += delta_time
}
