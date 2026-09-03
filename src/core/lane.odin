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

// Where the *player* can be, as opposed to where an obstacle hangs from.
//
// Deliberately a second enum rather than a third member of Lane, because
// the two answer different questions. A Lane is a wall an obstacle is
// anchored to, and there is no such thing as an obstacle anchored in the
// middle — the Patroller crosses the column, held by nothing but its own
// cosine. A Band is a place the player can occupy, and there are three.
// Merging them would give get_lane_y a case with no answer and hand every
// obstacle switch a branch it can never take.
Band :: enum {
	Real,
	Limen,
	Dream,
}

// A set of bands. This is what a pattern speaks in: what it accepts, and
// what it leaves behind (see game/pattern.odin).
Bands :: bit_set[Band]

// The two bands that are walls. The Limen is not one of them, and that
// distinction is load-bearing: a wall is somewhere the player can stay
// for free, and the Limen is somewhere they are always paying to be.
WALLS :: Bands{.Real, .Dream}

ALL_BANDS :: Bands{.Real, .Limen, .Dream}

// The band a wall corresponds to.
band_of_lane :: proc(lane: Lane) -> Band {
	switch lane {
	case .Real:
		return .Real
	case .Dream:
		return .Dream
	}
	return .Real
}

// The wall opposite a given one. Used by patterns whose answer is to
// suspend: releasing completes the journey the hold interrupted, so a
// pattern that can be solved by holding leaves the player at the wall
// they were travelling toward, which is the opposite of the one they
// were on.
opposite_lane :: proc(lane: Lane) -> Lane {
	return .Dream if lane == .Real else .Real
}
