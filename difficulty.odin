/*
* Difficulty
* Discrete difficulty tiers (Design Doc, section 18): each tier has a
* name, a start time, a target scroll speed, and optionally extra
* patterns unlocked from that point on. Future bonuses/maluses per tier
* can hang off this same struct without restructuring anything.
*/
package main

Tier :: struct {
	name:           string,
	start_time:     f32, // world.elapsed_time at which this tier begins
	scroll_speed:   f32, // target speed once this tier is reached (world eases toward it)
	added_patterns: []Pattern, // extra patterns available from this tier onward
}

tiers := []Tier {
	{name = "Awake", start_time = 0, scroll_speed = INITIAL_SCROLL_SPEED, added_patterns = nil},
	{
		name = "Drifting",
		start_time = 25,
		scroll_speed = 330,
		added_patterns = []Pattern{pattern_tight_double_switch},
	},
	{
		name = "Deep Dream",
		start_time = 55,
		scroll_speed = 400,
		added_patterns = []Pattern{pattern_triple_switch},
	},
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
	for _, i in tiers {
		validate_pattern_pool(get_pool_for_tier(i))
	}
}
