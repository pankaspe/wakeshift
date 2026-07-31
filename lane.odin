/*
* This is Lane file, lane.odin
* shared concepts for the two-lane world: the lane enum, screen reference
* size, and lane-to-position math. Used by both player and obstacles.
*/
package main

import rl "vendor:raylib/v55"

// Screen reference resolution (Design Doc, section 6)
SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720

// The two lanes anything in the game can occupy (Design Doc, section 5-6)
Lane :: enum {
	Real,
	Dream,
}

// Returns the vertical position for a given lane.
// Real lane: bottom edge touches the floor (bottom of the screen).
// Dream lane: top edge touches the ceiling (top of the screen).
get_lane_y :: proc(lane: Lane, size: rl.Vector2) -> f32 {
	switch lane {
	case .Real:
		return SCREEN_HEIGHT - size.y
	case .Dream:
		return 0
	}
	return 0
}
