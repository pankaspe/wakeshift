/*
* Difficulty
* Discrete difficulty tiers (Design Doc, section 18).
*
* WHY SPEED IS NOT THE CURVE
*
* A tier used to be a scroll speed and a few unlocked patterns, and the
* curve came almost entirely from the speed. Working out what speed
* actually buys showed why that felt flat:
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
* So a tier moves three things, and speed is the smallest of them:
*
*   scroll_speed    how long you get to look at what is coming
*   gap             empty air between patterns — the density knob, and
*                   the only one that is honestly monotonic
*   demand_weights  which patterns get drawn, not merely which are legal
*
* The third is the one that was missing entirely. Unlocking a pattern is
* not the same as meeting it: an even draw over a growing pool serves the
* newest patterns about as rarely as on the day they became possible.
*
* **Two things here are placeholders until roadmap R5.3.** Speed will
* stop rising with the tier altogether and become something the player
* buys, and the thresholds will be measured in *distance* rather than in
* time — which is what makes buying speed buy difficulty along with it,
* for free and without a line of code that knows it does.
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
	// Awake opens with a full second of air between patterns.
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
		gap = 0.5,
		demand_weights = {3, 4, 3, 2},
		added_patterns = []Pattern {
			pattern_gap_then_cube,
			pattern_gap_then_cube_reverse,
			pattern_stagger,
			pattern_stagger_reverse,
		},
	},
	// The air is nearly gone and the draw is inverted: a breather is now
	// roughly one pattern in ten rather than six in ten.
	{
		name = "Deep Dream",
		start_time = 55,
		scroll_speed = 370,
		gap = 0.2,
		demand_weights = {1, 2, 4, 5},
		added_patterns = []Pattern{pattern_gap_pair, pattern_burst},
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
// pattern added at a higher tier still has to obey the fairness rule, and
// so does every seam it can now form with the patterns already there.
validate_tier_pools :: proc() {
	for _, i in tiers {
		validate_pattern_pool(get_pool_for_tier(i))
	}
}

// Warns when a tier weights a demand level it has nothing to serve.
//
// The v1.x version of this check was about something subtler that no
// longer exists: back when patterns chained on bands, the pool was
// entered from a wall and the two walls had separate stocks, so a tier
// could lean hard on demand 3 while having no demand-3 pattern a player
// standing on the floor could be given. Half the run got the curve and
// half got what was left. Nothing failed; the late game was simply only
// half as hard as authored, which never shows up as a bug and only ever
// shows up as "it feels uneven".
//
// Patterns no longer chain (game/pattern.odin), so a tier's whole pool is
// reachable from anywhere and the check collapses to counting.
validate_tier_balance :: proc() {
	for tier, tier_index in tiers {
		pool := get_pool_for_tier(tier_index)

		peak_demand := 0
		for weight, demand in tier.demand_weights {
			if weight > tier.demand_weights[peak_demand] {
				peak_demand = demand
			}
		}

		best := -1
		for pattern in pool {
			best = max(best, pattern.demand)
		}
		if best < peak_demand {
			fmt.printf(
				"WARNING: tier %d (%s) weights demand %d most heavily, but its pool tops out at demand %d\n",
				tier_index,
				tier.name,
				peak_demand,
				best,
			)
		}
	}
}
