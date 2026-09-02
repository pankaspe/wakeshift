/*
* This is Pattern file, pattern.odin
* A pattern is a short, hand-authored sequence of obstacle events,
* expressed in time relative to the pattern's own start (Design Doc,
* section 6-7). entry_lane/exit_lane declare which lane the player must
* safely be in at the start and end of the pattern, so patterns can be
* chained without an unfair forced flip at the boundary.
*/
package game

import "../core"
import "core:fmt"
import "core:math/rand"

// A single obstacle event within a pattern, in time relative to pattern start.
PatternEvent :: struct {
	time_offset:   f32, // seconds since the pattern started
	lane:          core.Lane, // lane the obstacle occupies (player must be in the OTHER lane to survive)
	obstacle_type: ObstacleType,

	// Where an animated obstacle is in its cycle when it reaches the
	// player, in turns (0..1). This is the pattern *saying what it is
	// asking*: a Patroller at 0 is at the ceiling when it gets there, at
	// 0.25 in the middle, at 0.5 on the floor. Ignored by types that do
	// not animate.
	phase_offset:  f32,
}

Pattern :: struct {
	events:     []PatternEvent,
	duration:   f32, // total length of the pattern, in seconds
	entry_lane: core.Lane, // lane the player must be in when the pattern starts
	exit_lane:  core.Lane, // lane the player will be in when the pattern ends
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
	events     = []PatternEvent {
		{time_offset = 1.0, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
	},
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
		{time_offset = 1.8, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
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
		{time_offset = 0.8, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
		{time_offset = 1.8, lane = .Real, obstacle_type = .Chasm},
	},
	duration   = 2.6,
	entry_lane = .Real,
	exit_lane  = .Dream,
}

// --- Anticipatory patterns (Design Doc, section 5) ---
//
// What makes an obstacle feel intelligent is not reacting to the player —
// that reads as unfair even when it is survivable — but *anticipating the
// obvious answer*. All three archetypes below are fully authored and
// fully visible in advance. The player who reads survives; the player who
// reacts to the first thing they see does not.

// The Echo: something arrives in the lane you are in, and the lane you
// would flip into closes half a second later. The panic flip is exactly
// wrong, and there are two right answers — two flips timed tightly, or
// one hold through the middle, which is the pattern that first gives the
// Limen a reason to exist.
//
// exit_lane names where the two-flip answer ends up. A player who solves
// it by suspending comes out in the other lane instead, which is why the
// duration leaves over a second of slack afterwards: the next pattern's
// first obstacle is at least that far in, so either answer has time to
// be somewhere safe. Making the contract itself understand the Limen is
// roadmap T7.1.
pattern_echo := Pattern {
	events     = []PatternEvent {
		{time_offset = 1.0, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
		{time_offset = 1.45, lane = .Real, obstacle_type = .Block},
	},
	duration   = 3.0,
	entry_lane = .Dream,
	exit_lane  = .Dream,
}

// The Feint: what looks like a block growing in your own lane is a bluff
// that retracts before it arrives, and the lane you would flip into is
// the one that is actually closed. Staying put is correct.
//
// The bluff resolves 0.6s before it would have reached the player
// (FEINT_GONE), which is more than the 0.24s a flip takes: the player who
// waits is never made to guess.
pattern_feint_real := Pattern {
	events     = []PatternEvent {
		{time_offset = 1.2, lane = .Real, obstacle_type = .Feint},
		{time_offset = 1.25, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
	},
	duration   = 2.6,
	entry_lane = .Real,
	exit_lane  = .Real,
}

pattern_feint_dream := Pattern {
	events     = []PatternEvent {
		{time_offset = 1.2, lane = .Dream, obstacle_type = .Feint},
		{time_offset = 1.25, lane = .Real, obstacle_type = .Block},
	},
	duration   = 2.6,
	entry_lane = .Dream,
	exit_lane  = .Dream,
}

// --- Harder patterns, unlocked at higher difficulty tiers (section 18) ---

// The Patroller sweeping up to the ceiling as it reaches the player: the
// low lane is the safe one, and the pattern says so a full cycle before
// it matters.
pattern_patrol_high := Pattern {
	events     = []PatternEvent {
		{time_offset = 1.3, lane = .Dream, obstacle_type = .Patroller, phase_offset = 0},
	},
	duration   = 2.6,
	entry_lane = .Real,
	exit_lane  = .Real,
}

// The Echo with the middle taken away: the Patroller is in the Limen at
// exactly the moment the hold would have been resting there, so the only
// answer left is the two flips. This is the pattern that closes the
// imbalance phase 5 shipped with — the centre stops being free.
pattern_echo_guarded := Pattern {
	events     = []PatternEvent {
		{time_offset = 1.0, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
		{time_offset = 1.2, lane = .Real, obstacle_type = .Patroller, phase_offset = 0.25},
		{time_offset = 1.45, lane = .Real, obstacle_type = .Block},
	},
	duration   = 3.2,
	entry_lane = .Dream,
	exit_lane  = .Dream,
}

// Tighter timing than pattern_double_switch_reverse: less reaction time
// between the two obstacles.
pattern_tight_double_switch := Pattern {
	events     = []PatternEvent {
		{time_offset = 0.5, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
		{time_offset = 1.1, lane = .Real, obstacle_type = .Chasm},
	},
	duration   = 1.6,
	entry_lane = .Real,
	exit_lane  = .Real,
}

// Three obstacles in quick succession, alternating lanes each time.
pattern_triple_switch := Pattern {
	events     = []PatternEvent {
		{time_offset = 0.6, lane = .Real, obstacle_type = .Block},
		{time_offset = 1.3, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
		{time_offset = 2.0, lane = .Real, obstacle_type = .Chasm},
	},
	duration   = 2.4,
	entry_lane = .Dream,
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
	pattern_feint_real,
	pattern_feint_dream,
}

// Picks a random pattern from the pool whose entry_lane matches the lane
// the player is currently required to be safe in — this is what guarantees
// two chained patterns never force an unfair flip at their boundary.
//
// Draws from the caller's generator rather than the global one, so the
// same seed always yields the same sequence of patterns.
pick_next_pattern :: proc(
	pool: []Pattern,
	required_entry_lane: core.Lane,
	rng: rand.Generator,
) -> Pattern {
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

	index := int(rand.float32(rng) * f32(len(candidates)))
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
	next_entry_lane: core.Lane, // lane required for the next pattern, for chain continuity

	// Every random choice a run makes — which pattern comes next, how wide
	// a chasm is — comes from here and nowhere else. Two runs given the
	// same seed generate byte-identical level content, which is what makes
	// a run replayable from seed plus input log (Design Doc, section 10).
	seed:            u64,
	rng_state:       rand.Default_Random_State,
}

new_pattern_generator :: proc(
	pool: []Pattern,
	start_time: f32,
	start_lane: core.Lane,
	seed: u64,
) -> PatternGenerator {
	return PatternGenerator {
		pool = pool,
		generated_until = start_time,
		next_entry_lane = start_lane,
		seed = seed,
		rng_state = rand.create(seed),
	}
}

// Wraps the generator's own PRNG state as a Generator to draw from.
//
// Built fresh on each call rather than cached in the struct on purpose:
// a Generator holds a pointer to its state, and PatternGenerator is
// assigned by value (see reset_run), so a stored one would keep pointing
// at the state of whichever copy it was built from.
@(private)
generator_rng :: proc(generator: ^PatternGenerator) -> rand.Generator {
	return rand.default_random_generator(&generator.rng_state)
}

// Appends new obstacles as needed, keeping the generated horizon at least
// GENERATION_LOOKAHEAD seconds ahead of current_time. Call this every frame.
generate_ahead :: proc(
	generator: ^PatternGenerator,
	obstacles: ^[dynamic]Obstacle,
	current_time: f32,
) {
	rng := generator_rng(generator)

	for generator.generated_until < current_time + GENERATION_LOOKAHEAD {
		pattern := pick_next_pattern(generator.pool, generator.next_entry_lane, rng)

		for event in pattern.events {
			append(
				obstacles,
				new_obstacle(
					generator.generated_until + event.time_offset,
					event.lane,
					event.obstacle_type,
					event.phase_offset,
					rng,
				),
			)
		}

		generator.generated_until += pattern.duration
		generator.next_entry_lane = pattern.exit_lane
	}
}

// Checks a pool for the two authoring mistakes that produce no error and
// no crash, only a game that is quietly wrong.
//
// The first is an obstacle in the lane it does not belong to. The second
// is a pool that cannot be chained: pick_next_pattern falls back to
// pool[0] when no pattern accepts the required entry lane, which silently
// hands the player a pattern they were never set up for. Every lane a
// pattern can *exit* into must have at least one pattern that *enters*
// from it, or the fallback is only a matter of time.
validate_pattern_pool :: proc(pool: []Pattern) {
	for lane in core.Lane {
		reachable := false
		for pattern in pool {
			if pattern.entry_lane == lane {
				reachable = true
				break
			}
		}
		if !reachable {
			fmt.printf("WARNING: no pattern in this pool can start from the %v lane\n", lane)
		}
	}

	for pattern, pattern_index in pool {
		for event in pattern.events {
			expected, bound := expected_lane_for_type(event.obstacle_type)
			if bound && event.lane != expected {
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
