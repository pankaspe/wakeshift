/*
* Terrain
* Where the ground is. The floor and the ceiling are not decoration any
* more: they are the two walls the player travels between, so the shape
* of them is simulation, and it lives here where everything can see it.
*
* Until phase 7.5 the profile lived in render/terrain.odin and nothing
* else knew about it. The lanes were pinned to the screen edges instead,
* which is why the player ran with 14 to 30 px of a 45 px body below the
* ground it was supposed to be standing on.
*
* Two decisions shape this file.
*
* The profile is a function of *time*, not of scrolled pixels. An
* obstacle is an event in time (game/obstacle.odin), so a terrain
* anchored to pixels would slide against the patterns the moment scroll
* speed changed, and the property that lets speed be rebalanced without
* redrawing anything would be gone. Screen x is converted to world time
* with exactly the mapping obstacles already use, so the ground under an
* obstacle is the ground that obstacle was authored on. The visible
* consequence is that the undulation stretches as a run speeds up: one
* profile entry is TERRAIN_SEGMENT_TIME wide, which is 50 px at the
* opening speed and 74 px at the fastest tier.
*
* A body rests on the *highest* ground under its whole width, not on the
* ground under one chosen point. Sampling a single x would sink one
* corner of anything standing on a slope by up to a third of its height.
*
* Both walls currently carry the same profile, so the corridor between
* them has a constant height. That was load-bearing while the midpoint of
* a journey was a playable state; it no longer is, and roadmap R3
* replaces this whole file with a track described by a *spine* (where the
* corridor's centre sits) and a *span* (how tall it is), which can move
* independently. The one rule that survives the rewrite is the one below:
* the profile is a function of time, not of scrolled pixels.
*/
package core

import "core:math"
import rl "vendor:raylib/v55"

// How much of the profile one entry covers, in seconds. Chosen as
// 50 px at the run's opening speed of 270 px/s, which is the width the
// segments had when the profile was drawn by hand against pixels.
TERRAIN_SEGMENT_TIME :: 0.1852

// How far the ground protrudes from its screen edge at its lowest.
TERRAIN_BASE_HEIGHT :: 14

// Extra protrusion per profile entry, hand-authored once. Repeats.
TERRAIN_PROFILE := [6]f32{0, 12, 4, 16, 6, 9}

// The scrolling state the ground depends on, and nothing more.
//
// It exists so that core can answer "where is the ground" without
// knowing what a World is: game builds one from its world (get_ground),
// render passes the same thing through, and a test can make one up. Both
// fields are needed because the profile is authored in time while the
// caller asks in screen x, and the conversion between them is the scroll
// speed.
Ground :: struct {
	time:  f32, // world elapsed time, in seconds
	speed: f32, // current scroll speed, in px/s
}

// The world time of the ground currently under screen x.
//
// The same mapping get_obstacle_position uses in reverse: an obstacle at
// x reaches the anchor in (x - WORLD_ANCHOR_X) / speed seconds.
//
// Anchored, never read off the player. The player's x moves (R2.1), and
// a ground that followed it would slide the terrain against the patterns
// every time they lost or won back a stride.
ground_time_at_x :: proc(ground: Ground, x: f32) -> f32 {
	return ground.time + (x - WORLD_ANCHOR_X) / max(ground.speed, 1)
}

// How far the surface protrudes from its screen edge at a world time.
// Linear between profile entries, which is what the straight lines
// between the old sample points already drew.
terrain_height_at :: proc(time: f32) -> f32 {
	position := time / TERRAIN_SEGMENT_TIME
	index := int(math.floor(position))
	t := position - f32(index)

	count := len(TERRAIN_PROFILE)
	// Odin's % keeps the sign of the dividend, and time is negative for
	// anything to the left of the player at the start of a run.
	first := ((index % count) + count) % count
	second := (first + 1) % count
	variation := TERRAIN_PROFILE[first] + (TERRAIN_PROFILE[second] - TERRAIN_PROFILE[first]) * t

	return TERRAIN_BASE_HEIGHT + variation
}

// The surface line of one wall at a screen x. This is where the ground
// *is*, as opposed to where a body standing on it sits.
terrain_surface_y :: proc(ground: Ground, lane: Lane, x: f32) -> f32 {
	height := terrain_height_at(ground_time_at_x(ground, x))
	switch lane {
	case .Real:
		return SCREEN_HEIGHT - height
	case .Dream:
		return height
	}
	return height
}

// The highest ground under a body spanning [x, x + width]: what it
// actually rests against.
//
// Exact rather than sampled. The profile is linear between its entries,
// so an extreme over a range can only sit at one of the two ends or at
// an entry boundary inside it, and those are few enough to visit — a
// player's width covers at most one boundary, the widest chasm three.
terrain_support_height :: proc(ground: Ground, x, width: f32) -> f32 {
	start := ground_time_at_x(ground, x)
	end := ground_time_at_x(ground, x + width)

	height := max(terrain_height_at(start), terrain_height_at(end))
	first := math.ceil(start / TERRAIN_SEGMENT_TIME) * TERRAIN_SEGMENT_TIME
	for boundary := first; boundary < end; boundary += TERRAIN_SEGMENT_TIME {
		height = max(height, terrain_height_at(boundary))
	}
	return height
}

// Returns the vertical position of a body of the given size resting
// against a wall at screen x.
//
// Real lane: the feet stand on the floor. Dream lane: the head hangs
// from the ceiling. Both follow the terrain rather than the screen edge,
// so every endpoint of a flip — and with it the world_t the palette reads
// off the player's height — moves with the ground (Design Doc, section 4).
get_lane_y :: proc(ground: Ground, lane: Lane, x: f32, size: rl.Vector2) -> f32 {
	height := terrain_support_height(ground, x, size.x)
	switch lane {
	case .Real:
		return SCREEN_HEIGHT - height - size.y
	case .Dream:
		return height
	}
	return height
}
