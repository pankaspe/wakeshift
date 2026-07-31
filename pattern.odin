/*
* This is Pattern file, pattern.odin
* A pattern is a short, hand-authored sequence of obstacle events,
* expressed in time relative to the pattern's own start (Design Doc,
* section 6-7). entry_lane/exit_lane declare which lane the player must
* safely be in at the start and end of the pattern, so patterns can be
* chained without an unfair forced flip at the boundary.
*/
package main

import "core:fmt"
import "core:math/rand"

// A single obstacle event within a pattern, in time relative to pattern start.
PatternEvent :: struct {
	time_offset:   f32, // seconds since the pattern started
	lane:          Lane, // lane the obstacle occupies (player must be in the OTHER lane to survive)
	obstacle_type: ObstacleType,
}

Pattern :: struct {
	events:     []PatternEvent,
	duration:   f32, // total length of the pattern, in seconds
	entry_lane: Lane, // lane the player must be in when the pattern starts
	exit_lane:  Lane, // lane the player will be in when the pattern ends
}

// A single Block in the Real lane: player must be in Dream to survive.
pattern_steady_real := Pattern {
	events     = []PatternEvent{{time_offset = 1.0, lane = .Real, obstacle_type = .Block}},
	duration   = 2.0,
	entry_lane = .Dream,
	exit_lane  = .Dream,
}

// A single Chasm in the Real lane: same rule as Block, read inverted (Design Doc, section 5).
pattern_steady_chasm := Pattern {
	events     = []PatternEvent{{time_offset = 1.0, lane = .Real, obstacle_type = .Chasm}},
	duration   = 2.0,
	entry_lane = .Dream,
	exit_lane  = .Dream,
}

// A single Pulsing Shape in the Dream lane: player must be in Real to survive.
pattern_steady_dream := Pattern {
	events     = []PatternEvent{{time_offset = 1.0, lane = .Dream, obstacle_type = .PulsingShape}},
	duration   = 2.0,
	entry_lane = .Real,
	exit_lane  = .Real,
}

// A single Dream Hole in the Dream lane: same rule as Pulsing Shape's lane, read inverted.
pattern_steady_dreamhole := Pattern {
	events     = []PatternEvent{{time_offset = 1.0, lane = .Dream, obstacle_type = .DreamHole}},
	duration   = 2.0,
	entry_lane = .Real,
	exit_lane  = .Real,
}

// Two obstacles requiring a flip mid-pattern: Real first, then Dream.
pattern_double_switch := Pattern {
	events     = []PatternEvent {
		{time_offset = 0.8, lane = .Real, obstacle_type = .Block},
		{time_offset = 1.8, lane = .Dream, obstacle_type = .PulsingShape},
	},
	duration   = 2.6,
	entry_lane = .Dream,
	exit_lane  = .Real,
}

// Two obstacles requiring a flip mid-pattern: Dream first, then Real.
// Mirror of pattern_double_switch — without this, the generator's lane
// graph has a dead end (Real can never lead back to Dream).
pattern_double_switch_reverse := Pattern {
	events     = []PatternEvent {
		{time_offset = 0.8, lane = .Dream, obstacle_type = .PulsingShape},
		{time_offset = 1.8, lane = .Real, obstacle_type = .Chasm},
	},
	duration   = 2.6,
	entry_lane = .Real,
	exit_lane  = .Dream,
}

// Pool of hand-authored patterns (Design Doc, section 7).
// Every entry_lane must have at least one pattern leading back to the
// other lane, or the generator can get stuck (see pattern_double_switch_reverse).
all_patterns := []Pattern {
	pattern_steady_real,
	pattern_steady_chasm,
	pattern_steady_dream,
	pattern_steady_dreamhole,
	pattern_double_switch,
	pattern_double_switch_reverse,
}

// Expands a sequence of patterns into concrete, time-based obstacles,
// chaining each pattern's duration after the previous one.
// start_time shifts the whole sequence (e.g. give the player a couple
// of safe seconds before the first obstacle arrives).
build_obstacles_from_patterns :: proc(patterns: []Pattern, start_time: f32) -> [dynamic]Obstacle {
	obstacles := make([dynamic]Obstacle)

	cursor_time := start_time
	for pattern in patterns {
		for event in pattern.events {
			append(
				&obstacles,
				new_obstacle(cursor_time + event.time_offset, event.lane, event.obstacle_type),
			)
		}
		cursor_time += pattern.duration
	}
	return obstacles
}

// Picks a random pattern from the pool whose entry_lane matches the lane
// the player is currently required to be safe in — this is what guarantees
// two chained patterns never force an unfair flip at their boundary.
pick_next_pattern :: proc(pool: []Pattern, required_entry_lane: Lane) -> Pattern {
	candidates: [dynamic]Pattern
	defer delete(candidates)

	for pattern in pool {
		if pattern.entry_lane == required_entry_lane {
			append(&candidates, pattern)
		}
	}

	if len(candidates) == 0 {
		// Safety net: shouldn't happen with a well-designed pool
		// (every lane should have at least one matching pattern),
		// but avoids a crash if it ever does.
		return pool[0]
	}

	index := int(rand.float32() * f32(len(candidates)))
	if index >= len(candidates) {
		index = len(candidates) - 1
	}
	return candidates[index]
}

// How far ahead (in seconds of game time) we keep obstacles generated.
// Large enough that the player never sees the generation "catch up".
GENERATION_LOOKAHEAD :: 6.0

PatternGenerator :: struct {
	pool:            []Pattern,
	generated_until: f32, // world time up to which obstacles already exist
	next_entry_lane: Lane, // lane required for the next pattern, for chain continuity
}

new_pattern_generator :: proc(
	pool: []Pattern,
	start_time: f32,
	start_lane: Lane,
) -> PatternGenerator {
	return PatternGenerator {
		pool = pool,
		generated_until = start_time,
		next_entry_lane = start_lane,
	}
}

// Appends new obstacles as needed, keeping the generated horizon at least
// GENERATION_LOOKAHEAD seconds ahead of current_time. Call this every frame.
generate_ahead :: proc(
	generator: ^PatternGenerator,
	obstacles: ^[dynamic]Obstacle,
	current_time: f32,
) {
	for generator.generated_until < current_time + GENERATION_LOOKAHEAD {
		pattern := pick_next_pattern(generator.pool, generator.next_entry_lane)

		for event in pattern.events {
			append(
				obstacles,
				new_obstacle(
					generator.generated_until + event.time_offset,
					event.lane,
					event.obstacle_type,
				),
			)
		}

		generator.generated_until += pattern.duration
		generator.next_entry_lane = pattern.exit_lane
	}
}

// Checks that every event in every pattern uses an obstacle_type consistent
// with its lane (see expected_lane_for_type). Meant to be called once at
// startup, in debug builds, to catch pattern-authoring mistakes immediately
// instead of relying on noticing it during a playtest.
validate_pattern_pool :: proc(pool: []Pattern) {
	for pattern, pattern_index in pool {
		for event in pattern.events {
			expected := expected_lane_for_type(event.obstacle_type)
			if event.lane != expected {
				fmt.printf(
					"WARNING: pattern %d has a %v obstacle in the %v lane, expected %v\n",
					pattern_index,
					event.obstacle_type,
					event.lane,
					expected,
				)
			}
		}
	}
}
