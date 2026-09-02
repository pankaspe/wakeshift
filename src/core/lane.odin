/*
* Lane
* The lanes anything in the game can occupy, and where each one sits
* vertically (Design Doc, sections 5-6). Kept free of behavior on purpose:
* this is the shared vocabulary every other package speaks, so it must not
* depend on any of them.
*/
package core

import rl "vendor:raylib/v55"

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
