/*
* Track
* Where the world is. The floor and the ceiling are not decoration and
* not a backdrop: they are the two lanes the player travels between, so
* their shape is simulation and it lives here where everything can see it
* (Design Doc, section 4).
*
* THE TRACK IS TWO NUMBERS
*
*   spine   where the centre of the corridor sits, vertically
*   span    how tall the corridor is
*
* The floor is spine + span/2 and the ceiling is spine - span/2, so the
* two lanes cannot disagree with each other — coherence is a consequence
* of the representation rather than a rule somebody has to remember. It is
* also two knobs with completely different jobs: moving the spine makes
* the whole world undulate, and moving the span tightens or opens the
* corridor, which the game never had before.
*
* Both are **keyframes in world time**, not a function of scrolled pixels.
* An obstacle is an event in time (game/obstacle.odin), and a track
* anchored to pixels would slide against the patterns the moment scroll
* speed changed — which in v2.0 it does, because the player buys it. Screen
* x becomes world time with exactly the mapping obstacles use in reverse.
* The visible price is that the undulation stretches as a run speeds up.
*
* Linear between keyframes, and that is load-bearing twice over: it is
* what lets track_support_y be exact rather than sampled (an extreme over
* a range can only sit at an end or at a keyframe inside it), and it is
* what makes clamping legal *on append* — clamp a keyframe and the
* function stays linear; clamp the sampler and it stops being.
*
* WHAT THE PLAYER FEELS, AND WHAT THEY MUST NOT
*
* The flip's duration is constant in *time* whatever the span is
* (game/player.odin). The corridor changes width; the gesture must not. A
* narrow corridor therefore reads as a short, snappy hop and a wide one as
* a long crossing, at the same 0.16 s — which is the whole point of having
* the span as a difficulty knob at all.
*/
package core

import rl "vendor:raylib/v55"

// How many keyframes are kept live. The track only has to cover the
// screen plus the generator's lookahead — about ten seconds of world, or
// four patterns' worth — so this is generous by a factor of three. Fixed
// and inline rather than a dynamic array so that a Track is a plain value:
// World holds one, render copies the World forward by a fraction of a
// step, and nothing has to think about who owns what.
TRACK_CAPACITY :: 64

// How far back keyframes are kept before being pruned. Comfortably more
// than the screen behind the anchor at the slowest speed.
TRACK_HISTORY :: 3.0

// The corridor's limits. Below the minimum two cubes facing each other
// would leave no room to be anywhere; above the maximum a flip crosses so
// much screen in 0.16 s that it stops reading as a movement.
TRACK_SPAN_MIN :: 250
TRACK_SPAN_MAX :: 430
TRACK_SPAN_DEFAULT :: 340

// How much sky is always left outside the corridor, so the background has
// somewhere to be and the world does not read as a box.
TRACK_SKY_MARGIN :: 70

// The spine a run opens at and every pattern returns to (see
// validate_pattern_pool): the middle of the screen.
TRACK_SPINE_DEFAULT :: SCREEN_HEIGHT / 2

// How fast the corridor is allowed to move, in pixels per second of world
// time. Enforced on authored patterns rather than clamped at runtime,
// because the fix for a track that lurches is to author it differently,
// not to have the sampler quietly disagree with what was written.
//
// At the opening scroll speed the spine limit is about a 35 degree slope,
// which a character walks down rather than falls off.
TRACK_MAX_SPINE_RATE :: 190
TRACK_MAX_SPAN_RATE :: 240

TrackPoint :: struct {
	time:  f32, // world time this keyframe describes
	spine: f32,
	span:  f32,
}

Track :: struct {
	points: [TRACK_CAPACITY]TrackPoint,
	count:  int,
}

// A run opens flat. One keyframe is enough: sampling before the first
// point returns the first point, so this covers everything up to whatever
// the first pattern authors.
new_track :: proc() -> Track {
	track := Track{}
	track.points[0] = TrackPoint {
		time  = 0,
		spine = TRACK_SPINE_DEFAULT,
		span  = TRACK_SPAN_DEFAULT,
	}
	track.count = 1
	return track
}

// Forces a keyframe into a shape the world can actually hold: a legal
// span, and a spine that keeps both surfaces inside the screen with sky
// to spare.
//
// Applied when a point is appended, never when one is sampled. Clamping
// on append leaves the sampled function linear between its keyframes,
// which is what track_support_y's exactness depends on; clamping in the
// sampler would put a kink between two points and quietly break it.
track_clamp :: proc(point: TrackPoint) -> TrackPoint {
	clamped := point
	clamped.span = clamp(point.span, TRACK_SPAN_MIN, TRACK_SPAN_MAX)

	half := clamped.span * 0.5
	low := f32(TRACK_SKY_MARGIN) + half
	high := f32(SCREEN_HEIGHT - TRACK_SKY_MARGIN) - half
	clamped.spine = clamp(point.spine, low, high)
	return clamped
}

// Adds a keyframe. Points arrive in ascending time; a point that is not
// is dropped rather than sorted in, because it would mean the generator
// went backwards and quietly reordering that would hide the bug.
track_append :: proc(track: ^Track, point: TrackPoint) {
	if track.count > 0 && point.time <= track.points[track.count - 1].time {
		return
	}
	if track.count >= TRACK_CAPACITY {
		return
	}
	track.points[track.count] = track_clamp(point)
	track.count += 1
}

// Drops keyframes the world has left behind, keeping exactly one from
// before the cutoff so the segment covering it still has a start.
track_prune :: proc(track: ^Track, before_time: f32) {
	keep := 0
	for i in 0 ..< track.count {
		if track.points[i].time <= before_time {
			keep = i
		} else {
			break
		}
	}
	if keep == 0 {
		return
	}
	for i in keep ..< track.count {
		track.points[i - keep] = track.points[i]
	}
	track.count -= keep
}

// The corridor at a world time. Constant before the first keyframe and
// after the last, linear in between.
track_sample :: proc(track: Track, time: f32) -> (spine, span: f32) {
	if track.count == 0 {
		return TRACK_SPINE_DEFAULT, TRACK_SPAN_DEFAULT
	}
	if time <= track.points[0].time {
		return track.points[0].spine, track.points[0].span
	}

	for i in 1 ..< track.count {
		next := track.points[i]
		if time > next.time {
			continue
		}
		previous := track.points[i - 1]
		width := next.time - previous.time
		t := width > 0 ? (time - previous.time) / width : 1
		return previous.spine + (next.spine - previous.spine) * t,
			previous.span + (next.span - previous.span) * t
	}

	last := track.points[track.count - 1]
	return last.spine, last.span
}

// The scrolling state the track depends on, and nothing more.
//
// It exists so that core can answer "where is the world here" without
// knowing what a World is: game builds one from its world, render passes
// the same thing through, and a test can make one up. Both fields are
// needed because the track is authored in time while the caller asks in
// screen x, and the conversion between them is the scroll speed.
Ground :: struct {
	time:  f32, // world elapsed time, in seconds
	speed: f32, // current scroll speed, in px/s
}

// The world time of the track currently under screen x.
//
// The same mapping get_obstacle_position uses in reverse: an obstacle at
// x reaches the anchor in (x - WORLD_ANCHOR_X) / speed seconds.
//
// Anchored, never read off the player. The player's x moves (R2.1), and a
// world that followed it would slide against the patterns every time they
// lost or won back a stride.
ground_time_at_x :: proc(ground: Ground, x: f32) -> f32 {
	return ground.time + (x - WORLD_ANCHOR_X) / max(ground.speed, 1)
}

// The surface of one lane at a screen x. This is where the world *is*, as
// opposed to where a body standing on it sits.
track_surface_y :: proc(track: Track, ground: Ground, lane: Lane, x: f32) -> f32 {
	spine, span := track_sample(track, ground_time_at_x(ground, x))
	half := span * 0.5
	switch lane {
	case .Real:
		return spine + half
	case .Dream:
		return spine - half
	}
	return spine
}

// The surface a body spanning [x, x + width] actually rests against: the
// *highest* floor under it, or the *lowest* ceiling over it. Resting on
// the surface under one chosen point would sink a corner of anything
// standing on a slope by up to a third of its height.
//
// Exact rather than sampled. The track is linear between keyframes, so an
// extreme over a range can only sit at one of the two ends or at a
// keyframe inside it, and those are few enough to visit.
track_support_y :: proc(track: Track, ground: Ground, lane: Lane, x, width: f32) -> f32 {
	best := track_surface_y(track, ground, lane, x)
	end := track_surface_y(track, ground, lane, x + width)
	best = lane == .Real ? min(best, end) : max(best, end)

	start_time := ground_time_at_x(ground, x)
	end_time := ground_time_at_x(ground, x + width)
	for i in 0 ..< track.count {
		point := track.points[i]
		if point.time <= start_time {
			continue
		}
		if point.time >= end_time {
			break
		}
		half := point.span * 0.5
		surface := lane == .Real ? point.spine + half : point.spine - half
		best = lane == .Real ? min(best, surface) : max(best, surface)
	}
	return best
}

// Where a body of the given size rests against one lane at screen x.
//
// Real: the feet stand on the floor, so the box's bottom is the surface.
// Dream: the head hangs from the ceiling, so the box's top is.
get_lane_y :: proc(track: Track, ground: Ground, lane: Lane, x: f32, size: rl.Vector2) -> f32 {
	surface := track_support_y(track, ground, lane, x, size.x)
	switch lane {
	case .Real:
		return surface - size.y
	case .Dream:
		return surface
	}
	return surface
}
