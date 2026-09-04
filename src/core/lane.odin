/*
* Lane
* The two lanes anything in the game can occupy (Design Doc, section 3).
* Kept free of behaviour on purpose: this is the shared vocabulary every
* other package speaks, so it must not depend on any of them.
*
* Where a lane *is* lives in terrain.odin, because that is a question
* about the shape of the ground rather than about the edge of the screen.
*
* There used to be a second enum here — Band — with a third member for
* the Limen, plus a bit_set of them that the pattern contract was written
* in. All of it went with the third state (roadmap R1.1/R1.4). Two lanes,
* one enum, and a pattern says what it puts where rather than what it
* accepts.
*/
package core

Lane :: enum {
	Real, // the floor, the world below
	Dream, // the ceiling, the world above
}

// The lane opposite a given one — which, with two of them, is also the
// only place a flip can ever be going.
opposite_lane :: proc(lane: Lane) -> Lane {
	return .Dream if lane == .Real else .Real
}
