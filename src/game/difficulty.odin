/*
* Difficulty
* Discrete difficulty tiers (Design Doc, section 18).
*
* WHY SPEED IS NOT THE CURVE (roadmap T7.3)
*
* Until phase 7 a tier was a scroll speed and a few unlocked patterns,
* and the curve came almost entirely from the speed. Working out what
* speed actually buys showed why that felt flat:
*
* Obstacles are events in time, not positions (obstacle.odin). A Block
* authored at time_offset 1.0 arrives one second after its pattern starts
* at 270 px/s and at 400 px/s alike, so *reaction time inside a pattern
* does not move with speed at all*. Replaying every pattern at all three
* speeds says the same thing: the set of answers that survive does not
* change.
*
* What speed does change is two things that pull in opposite directions.
* The player can see 1080 px ahead (SCREEN_WIDTH - PLAYER_X), which is
* 4.0 seconds of warning at 270 and 2.7 at 400 — harder. And a wide
* obstacle passes in width/speed seconds, so the longest chasm blocks the
* floor for 0.69s at 270 and 0.46s at 400 — easier. Speed is a real knob,
* but it is a *reading* knob, and it partly cancels itself.
*
* So a tier now moves three things, and speed is the smallest of them:
*
*   scroll_speed    how long you get to look at what is coming
*   gap             empty air between patterns — the density knob, and
*                   the only one that is honestly monotonic
*   demand_weights  which patterns get drawn, not merely which are legal
*
* The third is the one that was missing entirely. Unlocking a pattern is
* not the same as meeting it: at the deepest tier eight of the thirteen
* patterns are still the easy ones, so an even draw served the hardest
* two about as rarely as on the day they became possible.
*/
package game

import "../core"
import "core:fmt"

Tier :: struct {
	name:           string,
	start_time:     f32, // world.elapsed_time at which this tier begins
	scroll_speed:   f32, // target speed once this tier is reached (world eases toward it)
	gap:            f32, // seconds of empty air after each pattern
	demand_weights: [DEMAND_LEVELS]int, // how often a pattern of each demand is drawn
	added_patterns: []Pattern, // extra patterns available from this tier onward
}

tiers := []Tier {
	// Awake opens with a full second of air between patterns, which is
	// looser than the game has ever started: until now every tier ran at
	// the density that used to be the only density there was.
	{
		name = "Awake",
		start_time = 0,
		scroll_speed = INITIAL_SCROLL_SPEED,
		gap = 1.0,
		demand_weights = {6, 2, 1, 1},
		added_patterns = nil,
	},
	{
		name = "Drifting",
		start_time = 25,
		scroll_speed = 320,
		gap = 0.45,
		demand_weights = {3, 4, 3, 2},
		added_patterns = []Pattern {
			pattern_tight_double_switch,
			pattern_echo,
			pattern_echo_reverse,
			pattern_feint_patrol,
			pattern_void_pair,
			pattern_patrol_high,
		},
	},
	// The air is gone and the draw is inverted: a breather is now roughly
	// one pattern in ten rather than eight in thirteen.
	{
		name = "Deep Dream",
		start_time = 55,
		scroll_speed = 370,
		gap = 0.1,
		demand_weights = {1, 2, 4, 5},
		added_patterns = []Pattern {
			pattern_triple_switch,
			pattern_triple_switch_reverse,
			pattern_echo_guarded,
		},
	},
}

// Points the generator at everything a tier changes, in one call, so that
// the main loop never has to know a tier has more than one knob — and so
// that adding a fourth knob later touches this file only.
set_generator_tier :: proc(generator: ^PatternGenerator, tier_index: int) {
	generator.pool = get_pool_for_tier(tier_index)
	generator.gap = tiers[tier_index].gap
	generator.weights = tiers[tier_index].demand_weights
}

// Returns the index of the current tier, given how much time has passed.
// Assumes tiers is sorted by start_time ascending.
get_current_tier_index :: proc(elapsed_time: f32) -> int {
	index := 0
	for tier, i in tiers {
		if elapsed_time >= tier.start_time {
			index = i
		}
	}
	return index
}

// One cumulative pool per tier, built once at startup: tier_pools[i]
// contains every pattern from tiers[0..i], including the base pool.
tier_pools: [dynamic][dynamic]Pattern

build_tier_pools :: proc() {
	cumulative := make([dynamic]Pattern)
	for pattern in all_patterns {
		append(&cumulative, pattern)
	}

	for tier in tiers {
		for pattern in tier.added_patterns {
			append(&cumulative, pattern)
		}

		// snapshot the cumulative pool as it stands after this tier's additions
		snapshot := make([dynamic]Pattern, len(cumulative))
		copy(snapshot[:], cumulative[:])
		append(&tier_pools, snapshot)
	}
}

get_pool_for_tier :: proc(tier_index: int) -> []Pattern {
	return tier_pools[tier_index][:]
}

// Validates every tier's cumulative pool, not just the base one — a
// pattern added at a higher tier could still break the lane graph
// (see the lesson learned in Section 10).
validate_tier_pools :: proc() {
	for tier, i in tiers {
		pool := get_pool_for_tier(i)
		validate_pattern_pool(pool)
		validate_tier_balance(tier, pool, i)
	}
}

// Catches the defect that made T7.2 necessary, so that it cannot come
// back quietly.
//
// A tier's weights say what it wants the player to meet, and its pool
// says what it *can* serve — but the pool is entered from a wall, and the
// two walls have separate stocks. Before phase 7 the deepest tier leaned
// hardest on demand 3 while having no demand-3 pattern a player standing
// on the floor could be given, so half the run got the weights and half
// got whatever was left. Nothing failed; the curve was simply only half
// applied, which is exactly the kind of thing that never shows up as a
// bug and only ever shows up as "the late game feels uneven".
//
// The check is deliberately narrow: it looks only at the demand the tier
// weights most heavily, so a tier that keeps a token weight on a level it
// has no patterns for stays quiet.
@(private)
validate_tier_balance :: proc(tier: Tier, pool: []Pattern, tier_index: int) {
	peak_demand := 0
	for weight, demand in tier.demand_weights {
		if weight > tier.demand_weights[peak_demand] {
			peak_demand = demand
		}
	}

	for wall in ([]core.Band{.Real, .Dream}) {
		best := -1
		for pattern in pool {
			if (core.Bands{wall}) <= pattern.entry {
				best = max(best, pattern.demand)
			}
		}
		if best < peak_demand {
			fmt.printf(
				"WARNING: tier %d (%s) weights demand %d most heavily, but a player arriving in %v can only be given demand %d at best\n",
				tier_index,
				tier.name,
				peak_demand,
				wall,
				best,
			)
		}
	}
}
