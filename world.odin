/*
* World
* holds global world state, like scroll speed, and drives everything
* that moves automatically with it (floor, ceiling, obstacles)
*/
package main

import "core:math"
import rl "vendor:raylib/v55"

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

// Visual spacing between floor/ceiling tick marks, in pixels.
LANE_MARK_SPACING :: 60
LANE_MARK_WIDTH :: 30
LANE_MARK_HEIGHT :: 4

// Draws scrolling tick marks along the floor and ceiling,
// so the automatic scroll is visible even with no obstacles yet.
draw_world :: proc(world: World) {
	// mod() keeps the offset within a single spacing interval,
	// so the tick marks appear to loop seamlessly forever.
	offset := math.mod(world.scroll_offset, LANE_MARK_SPACING)

	x := -offset
	for x < SCREEN_WIDTH {
		// Floor marks (bottom edge)
		rl.DrawRectangle(
			i32(x),
			SCREEN_HEIGHT - LANE_MARK_HEIGHT,
			LANE_MARK_WIDTH,
			LANE_MARK_HEIGHT,
			rl.DARKGRAY,
		)
		// Ceiling marks (top edge)
		rl.DrawRectangle(i32(x), 0, LANE_MARK_WIDTH, LANE_MARK_HEIGHT, rl.DARKGRAY)

		x += LANE_MARK_SPACING
	}
}
