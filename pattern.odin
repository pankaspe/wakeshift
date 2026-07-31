/*
* This is Pattern file, pattern.odin
* A pattern is a short, hand-authored sequence of obstacle events,
* expressed in time relative to the pattern's own start (Design Doc,
* section 6-7). entry_lane/exit_lane declare which lane the player must
* safely be in at the start and end of the pattern, so patterns can be
* chained without an unfair forced flip at the boundary.
*/
package main

// A single obstacle event within a pattern, in time relative to pattern start.
PatternEvent :: struct {
	time_offset: f32, // seconds since the pattern started
	lane:        Lane, // lane the obstacle occupies (player must be in the OTHER lane to survive)
}

Pattern :: struct {
	events:     []PatternEvent,
	duration:   f32, // total length of the pattern, in seconds
	entry_lane: Lane, // lane the player must be in when the pattern starts
	exit_lane:  Lane, // lane the player will be in when the pattern ends
}

// A single obstacle in the Real lane: player must be in Dream to survive.
pattern_steady_real := Pattern {
	events     = []PatternEvent{{time_offset = 1.0, lane = .Real}},
	duration   = 2.0,
	entry_lane = .Dream,
	exit_lane  = .Dream,
}

// A single obstacle in the Dream lane: player must be in Real to survive.
pattern_steady_dream := Pattern {
	events     = []PatternEvent{{time_offset = 1.0, lane = .Dream}},
	duration   = 2.0,
	entry_lane = .Real,
	exit_lane  = .Real,
}

// Two obstacles requiring a flip mid-pattern: Real first, then Dream.
pattern_double_switch := Pattern {
	events     = []PatternEvent {
		{time_offset = 0.8, lane = .Real},
		{time_offset = 1.8, lane = .Dream},
	},
	duration   = 2.6,
	entry_lane = .Dream,
	exit_lane  = .Real,
}

// Pool of hand-authored patterns for the Real World (Design Doc, section 7).
// Section 10 will pick from this pool randomly; for now we use it in a fixed order.
real_world_patterns := []Pattern{pattern_steady_real, pattern_steady_dream, pattern_double_switch}

// Expands a sequence of patterns into concrete, time-based obstacles,
// chaining each pattern's duration after the previous one.
// start_time shifts the whole sequence (e.g. give the player a couple
// of safe seconds before the first obstacle arrives).
build_obstacles_from_patterns :: proc(patterns: []Pattern, start_time: f32) -> [dynamic]Obstacle {
	obstacles := make([dynamic]Obstacle)

	cursor_time := start_time
	for pattern in patterns {
		for event in pattern.events {
			append(&obstacles, new_obstacle(cursor_time + event.time_offset, event.lane))
		}
		cursor_time += pattern.duration
	}

	return obstacles
}
