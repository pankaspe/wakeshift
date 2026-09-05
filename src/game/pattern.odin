/*
* Pattern
* A pattern is a short, hand-authored sequence of obstacle events,
* expressed in time relative to the pattern's own start (Design Doc,
* section 6). The generator strings them together for as long as a run
* lasts.
*
* THE FAIRNESS RULE (roadmap R1.4)
*
* There is exactly one, and it is the whole contract:
*
*     At every instant at least one lane must be non-lethal.
*
* Note the word. A cube does not kill, it blocks — so a cube on both
* lanes at once is **legal**, and it is the design's centrepiece: no
* escape, only a choice about which price to pay. Only the Gap is
* lethal, and it takes the lane it is on.
*
* validate_pattern_pool enforces all of it by arithmetic rather than by
* authorial care. For every pattern, and for every ordered pair of
* patterns across the seam between them, it works out the window of time
* each event owns and checks three things:
*
*   * a Real lethal window never overlaps a Dream one;
*   * two cubes facing each other across the corridor are each between
*     MIRROR_MIN_WIDTH and MIRROR_MAX_WIDTH, which is what bounds the
*     price of the one encounter that has no way out;
*   * two cubes on the *same* lane never overlap in x, because the
*     renderer welds them into one polyline and drops the second one
*     rather than tearing the line — a mark and a hitbox that disagree.
*
* A PATTERN CONTAINS ITS OWN WINDOWS
*
* The composability rule, and since C2 it is the only one there is. Every
* event's window — the stretch of time it can touch a body at the anchor —
* lies inside [0, duration]. Two consequences fall out of it:
*
*   * **the seam cannot produce a conflict at any gap.** If both patterns
*     hold their windows, then whatever order the generator strings them
*     in and however small the air between them, no window of one can
*     reach a window of the other. The seam check still runs, because a
*     rule worth having is worth verifying rather than believing.
*   * **a pattern's own boundaries are not its warning.** The warning is
*     the screen: an obstacle is visible from x = 1280 and arrives at
*     x = 360, which is 2.5 to 3.4 seconds of looking at it whatever
*     pattern it belongs to, and the pattern before it is still on screen
*     while it comes. So a lead-in inside a pattern buys nothing and is
*     simply dead air — which is what C2 found the old pool was mostly
*     made of, and what it cut to reach the density the design asks for.
*     The air between patterns is the tier's gap and nothing else, which
*     leaves density with exactly one knob.
*
* WHY PATTERNS NO LONGER CHAIN
*
* Until the design rewrite this was a much bigger machine. Patterns
* declared the set of bands they were fair to *enter* from and the set
* they could *leave* the player in, and the generator only ever picked a
* next pattern whose entry set contained the previous one's exit set.
*
* Measuring the result is what ended the v1.x design. That contract
* *guarantees* the player enters every pattern from a band where the
* pattern is fair — and for a pattern with a single threat, "fair" means
* the band the threat is not in. So the correct answer to most of the
* pool was to do nothing, and 161 of 200 simulated runs that never once
* touched the key survived the entire first difficulty tier.
*
* The rule above needs no chaining because it is a property of the
* *pattern*, not of the seam: if one lane is always open, then whichever
* lane the player happens to be on when a pattern starts, there is
* something they can do about it. What they have to do is look and move,
* which is the game.
*
* The lesson generalises, and it is in CLAUDE.md because it will come up
* again: **a contract that guarantees you start safe is a contract that
* rewards standing still.** Any future rule has to be checked against
* "does doing nothing survive this".
*/
package game

import "../core"
import "core:fmt"
import "core:math/rand"

// A single obstacle event within a pattern, in time relative to pattern start.
PatternEvent :: struct {
	time_offset:   f32, // seconds since the pattern started
	lane:          core.Lane,
	obstacle_type: ObstacleType,

	// Cube only, and the zero value means "the primitive": an event that
	// says nothing about its cube gets one column one unit tall, resting
	// on its lane.
	//
	// It is a **declaration, not a shape** (skyline.odin). The pattern
	// says what form the thing is and how big it is allowed to be; the
	// run's own generator draws the columns inside those bounds, so an
	// authored moment is a different ridge on every seed and the pattern
	// still knows exactly what it is asking. Everything the fairness
	// check needs from it is a bound rather than an outcome, which is how
	// a pool can be validated before any seed exists.
	//
	// Floating is orthogonal to it rather than one of its forms, which is
	// what lets a pattern lift any cube it likes and is why the phase
	// only means anything alongside it.
	shape:         Skyline,
	floating:      bool,
	cube_phase:    f32, // floating only: 0 is down and blocking, 0.5 is up and open
}

Pattern :: struct {
	events:   []PatternEvent,

	duration: f32, // total length of the pattern, in seconds

	// How much this pattern asks of the player, 0..DEMAND_LEVELS-1. Not a
	// difficulty score for its own sake: it is what a tier draws on to
	// change *what the player meets* rather than only how fast it arrives
	// (see difficulty.odin).
	//
	//   0  one obstacle, one decision, and time to make it
	//   1  two decisions, or one that has to be read rather than reflexed
	//   2  three decisions, or two that arrive close together
	//   3  a burst: no time to settle between answers
	demand:   int,
}

// How many demand levels a pattern can carry. Tiers weight the pool by
// this (Tier.demand_weights).
DEMAND_LEVELS :: 4

// --- The pool ---
//
// The world of the sketch, built out of the bricks: bumps, towers,
// plateaus, staircases, canyons, ridges, facing constrictions, and the
// one block that floats. Every cube here is a *declaration* — a form and
// the bounds around it — and the columns are drawn per obstacle, so no
// two runs meet the same ridge twice (skyline.odin).
//
// TWO THINGS THAT SHAPED EVERY PATTERN BELOW
//
// **A wide cube on one lane forbids a cube on the other for most of a
// second.** Two facing cubes have to be between MIRROR_MIN_WIDTH and
// MIRROR_MAX_WIDTH, which is exactly two columns, so anything wider than
// that has to be clear in time of everything on the far lane. A ridge's
// window runs from 0.17 s before its arrival to 0.6 s after it, and that
// spacing is why the busy patterns run along one lane rather than across
// the corridor.
//
// **A hole must stay away from a pattern's ends.** The seam check runs
// every ordered pair of patterns at the smallest gap any tier uses, and a
// long hole owns 0.69 s of its lane. A lethal event inside about half a
// second of either end is how two patterns that are fair apart become
// unanswerable together, so none of them are.

// --- Awake: one thing at a time ---

// The floor of the pool: a single brick. It is narrower than the body, so
// it reads as a bump rather than as a wall, and the answer is one flip.
pattern_bump_real := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Cube, shape = SHAPE_BUMP},
	},
	duration = 0.3,
	demand   = 0,
}

pattern_bump_dream := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_BUMP},
	},
	duration = 0.3,
	demand   = 0,
}

// A hole asks a different question from a cube — not "move now" but "do
// not be down here for this stretch" — and it is the only thing in the
// game that ends the run.
// **Demand 1 rather than 0, and that is about the draw and not about the
// hole.** It asks no more of the hand than a bump does. But it is the only
// lethal thing in the game, and the opening tier weights demand 0 six to
// one — measured with the hole at demand 0, more than a quarter of every
// pattern a new run met was a hole, and the first tier came out deadlier
// than the last. A demand level is what a tier draws on, so it is also
// where "how often" is said.
pattern_gap_real := Pattern {
	events   = []PatternEvent{{time_offset = 0.2, lane = .Real, obstacle_type = .Gap}},
	duration = 0.72,
	demand   = 1,
}

pattern_gap_dream := Pattern {
	events   = []PatternEvent{{time_offset = 0.2, lane = .Dream, obstacle_type = .Gap}},
	duration = 0.72,
	demand   = 1,
}

// An isolated tower: tall enough to read from across the screen, narrow
// enough that the answer is still one flip. The height is what the eye
// gets and the width is what the hand gets, and they are deliberately
// different sizes.
pattern_tower_real := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Cube, shape = SHAPE_TOWER},
	},
	duration = 0.5,
	demand   = 0,
}

pattern_tower_dream := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_TOWER},
	},
	duration = 0.5,
	demand   = 0,
}

// A staircase presenting its low step first — the one form that can be
// entered rather than only dodged. Land on the low step and the wall
// becomes the next column along; a body is 45 px and a column is 27, so
// it always straddles two and rests on the higher.
pattern_stairs_real := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Cube, shape = SHAPE_STAIRS_UP},
	},
	duration = 0.7,
	demand   = 1,
}

pattern_stairs_dream := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_STAIRS_UP},
	},
	duration = 0.7,
	demand   = 1,
}

// Two threats on opposite lanes: whichever lane you start on you move at
// least once, and if you start on the wrong one you move twice.
pattern_alternate := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Cube, shape = SHAPE_TOWER},
		{time_offset = 1, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_TOWER},
	},
	duration = 1.3,
	demand   = 1,
}

pattern_alternate_reverse := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_TOWER},
		{time_offset = 1, lane = .Real, obstacle_type = .Cube, shape = SHAPE_TOWER},
	},
	duration = 1.3,
	demand   = 1,
}

// --- Drifting: the shapes start meaning things ---

// A plateau: flat on top and wide enough that flipping onto it is a real
// answer rather than an accident. The bump after it is on the same lane,
// so the pattern is read along one wall instead of across the corridor.
pattern_plateau_real := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Cube, shape = SHAPE_PLATEAU},
		{time_offset = 1.1, lane = .Real, obstacle_type = .Cube, shape = SHAPE_BUMP},
	},
	duration = 1.2,
	demand   = 1,
}

pattern_plateau_dream := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_PLATEAU},
		{time_offset = 1.1, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_BUMP},
	},
	duration = 1.2,
	demand   = 1,
}

// A canyon: two towers with the lane's own surface between them. The
// middle is a place to *stand*, which is what makes it not a hole, and
// the whole shape is wide enough that the answer is "be somewhere for a
// while" rather than "move once".
pattern_canyon_real := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Cube, shape = SHAPE_CANYON},
	},
	duration = 0.9,
	demand   = 1,
}

pattern_canyon_dream := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_CANYON},
	},
	duration = 0.9,
	demand   = 1,
}

// A hole then a shape on the other side: the answer to the first is the
// place the second is waiting.
pattern_gap_then_cube := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Gap},
		{time_offset = 1.1, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_TOWER},
	},
	duration = 1.4,
	demand   = 1,
}

pattern_gap_then_cube_reverse := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Dream, obstacle_type = .Gap},
		{time_offset = 1.1, lane = .Real, obstacle_type = .Cube, shape = SHAPE_TOWER},
	},
	duration = 1.4,
	demand   = 1,
}

// Three in a row, tighter: the first answer has to be the setup for the
// second, because there is no room to settle in between.
pattern_stagger := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Cube, shape = SHAPE_BUMP},
		{time_offset = 0.9, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_TOWER},
		{time_offset = 1.6, lane = .Real, obstacle_type = .Cube, shape = SHAPE_TOWER},
	},
	duration = 1.9,
	demand   = 2,
}

pattern_stagger_reverse := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_BUMP},
		{time_offset = 0.9, lane = .Real, obstacle_type = .Cube, shape = SHAPE_TOWER},
		{time_offset = 1.6, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_TOWER},
	},
	duration = 1.9,
	demand   = 2,
}

// A bump, then a ridge on the other lane. The two ends of what a cube can
// be, and the pattern that says what width actually buys: **nothing, on
// its own**. A lone cube of any width costs one flip, because the other
// lane is open and one flip is one flip. Width becomes a price only where
// there is no free lane, which is the facing pair and nowhere else — so
// these two are here for the eye, not the hand, and that is a legitimate
// job. They are how the set stops looking like one object repeated.
pattern_bump_and_ridge := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Cube, shape = SHAPE_BUMP},
		{time_offset = 1, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_RIDGE},
	},
	duration = 1.8,
	demand   = 1,
}

// **The constriction.** Two facing towers of unequal height, which is
// what a pinch is now that the corridor no longer pinches: the same
// bricks as everything else, on both lanes at once.
//
// Mechanically it is a mirrored pair — both lanes held, no dodge, only a
// price — so both halves are SHAPE_FACING, whose two columns are the only
// width MIRROR_MIN_WIDTH and MIRROR_MAX_WIDTH leave legal. The heights
// are drawn independently, so it comes out lopsided far more often than
// not, and a lopsided pair reads as a place where the world closes in
// rather than as one object cut in half.
pattern_narrows := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.3, lane = .Real, obstacle_type = .Cube, shape = SHAPE_FACING},
		{time_offset = 0.3, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_FACING},
	},
	duration = 0.5,
	demand   = 2,
}

// A cube that floats: it is up when it reaches the anchor, so a character
// who is where they should be runs under it and one who has lost ground
// meets it on the way down. The only obstacle in the game whose answer
// depends on how much room you have left.
pattern_float_open := Pattern {
	events   = []PatternEvent {
		{
			time_offset = 0.35,
			lane = .Dream,
			obstacle_type = .Cube,
			floating = true,
			cube_phase = 0.5,
		},
		{time_offset = 1.3, lane = .Real, obstacle_type = .Cube, shape = SHAPE_TOWER},
	},
	duration = 1.6,
	demand   = 1,
}

// --- Deep Dream: no room to settle ---

// Two holes on alternating lanes: long stretches rather than instants, so
// the answer is to be somewhere for a while rather than to move once.
pattern_gap_pair := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Gap},
		{time_offset = 1.1, lane = .Dream, obstacle_type = .Gap},
	},
	duration = 1.62,
	demand   = 2,
}

// The burst: four answers, no room at all.
pattern_burst := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Cube, shape = SHAPE_BUMP},
		{time_offset = 0.75, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_BUMP},
		{time_offset = 1.3, lane = .Real, obstacle_type = .Cube, shape = SHAPE_TOWER},
		{time_offset = 1.85, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_TOWER},
	},
	duration = 2.15,
	demand   = 3,
}

// A ridge on one lane and a ridge on the other, far enough apart in time
// to be legal and close enough to be one thought. It is the longest
// stretch in the game where a lane is simply gone, and the pattern that
// most looks like the sketch: a skyline you read rather than a thing you
// dodge.
pattern_ridge_run := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Cube, shape = SHAPE_RIDGE},
		{time_offset = 1.25, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_RIDGE},
	},
	duration = 2.05,
	demand   = 3,
}

// A staircase down into a canyon and back up, all on one wall. Three
// shapes back to back with nothing on the far lane, so the whole pattern
// is read along one side of the corridor — the answer is to leave, and
// the question is when.
pattern_ravine_real := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Real, obstacle_type = .Cube, shape = SHAPE_STAIRS_DOWN},
		{time_offset = 1, lane = .Real, obstacle_type = .Cube, shape = SHAPE_CANYON},
		{time_offset = 1.9, lane = .Real, obstacle_type = .Cube, shape = SHAPE_STAIRS_UP},
	},
	duration = 2.4,
	demand   = 3,
}

pattern_ravine_dream := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.2, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_STAIRS_DOWN},
		{time_offset = 1, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_CANYON},
		{time_offset = 1.9, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_STAIRS_UP},
	},
	duration = 2.4,
	demand   = 3,
}

// The constriction, then a hole, then somewhere to land. The hardest
// thing the pool says: pay, move, and be right about which side.
pattern_gauntlet := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.3, lane = .Real, obstacle_type = .Cube, shape = SHAPE_FACING},
		{time_offset = 0.3, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_FACING},
		{time_offset = 1.2, lane = .Real, obstacle_type = .Gap},
		{time_offset = 2.1, lane = .Dream, obstacle_type = .Cube, shape = SHAPE_PLATEAU},
	},
	duration = 2.7,
	demand   = 3,
}

// Two of them, out of phase: the first is up as it passes and the second
// is down. Same obstacle, opposite answers, and the only way to tell is
// to watch them.
pattern_float_pair := Pattern {
	events   = []PatternEvent {
		{
			time_offset = 0.35,
			lane = .Dream,
			obstacle_type = .Cube,
			floating = true,
			cube_phase = 0.5,
		},
		{time_offset = 1.2, lane = .Dream, obstacle_type = .Cube, floating = true},
		{time_offset = 2.1, lane = .Real, obstacle_type = .Cube, shape = SHAPE_PLATEAU},
	},
	duration = 2.7,
	demand   = 2,
}

all_patterns := []Pattern {
	pattern_bump_real,
	pattern_bump_dream,
	pattern_gap_real,
	pattern_gap_dream,
	pattern_tower_real,
	pattern_tower_dream,
	pattern_stairs_real,
	pattern_stairs_dream,
	pattern_alternate,
	pattern_alternate_reverse,
}

// --- Generation ---

// Picks a random pattern from the pool, biased by each pattern's demand.
//
// There is no longer anything to satisfy at the seam (see the file
// header), so this is a weighted draw and nothing more. The weighting is
// how a tier changes the *texture* of a run rather than only its speed:
// unlocking a hard pattern is not the same as meeting it, and an even
// draw over a growing pool serves the newest patterns about as rarely as
// on the day they became possible.
//
// Draws from the caller's generator rather than the global one, so the
// same seed always yields the same sequence of patterns.
pick_next_pattern :: proc(
	pool: []Pattern,
	weights: [DEMAND_LEVELS]int,
	rng: rand.Generator,
) -> Pattern {
	total := 0
	for pattern in pool {
		total += weights[clamp(pattern.demand, 0, DEMAND_LEVELS - 1)]
	}

	// A tier whose weights happen to zero out its whole pool falls back to
	// an even draw rather than to no pattern at all.
	if total <= 0 {
		index := int(rand.float32(rng) * f32(len(pool)))
		return pool[min(index, len(pool) - 1)]
	}

	roll := int(rand.float32(rng) * f32(total))
	if roll >= total {
		roll = total - 1
	}
	for pattern in pool {
		roll -= weights[clamp(pattern.demand, 0, DEMAND_LEVELS - 1)]
		if roll < 0 {
			return pattern
		}
	}
	return pool[len(pool) - 1]
}

// How far ahead (in seconds of game time) we keep obstacles generated.
// Large enough that the player never sees the generation "catch up".
GENERATION_LOOKAHEAD :: 6.0

PatternGenerator :: struct {
	pool:            []Pattern,
	generated_until: f32, // world time up to which obstacles already exist

	// The current tier's two shaping knobs, kept here rather than looked
	// up, so that generation depends on nothing outside the generator.
	// set_generator_tier (difficulty.odin) is what moves them.
	gap:             f32, // seconds of empty air after each pattern
	weights:         [DEMAND_LEVELS]int, // draw bias by pattern demand

	// Every random choice a run makes — which pattern comes next, how wide
	// a hole is — comes from here and nowhere else. Two runs given the
	// same seed generate byte-identical level content, which is what makes
	// a run replayable from seed plus input log (Design Doc, section 13).
	seed:            u64,
	rng_state:       rand.Default_Random_State,
}

new_pattern_generator :: proc(pool: []Pattern, start_time: f32, seed: u64) -> PatternGenerator {
	return PatternGenerator {
		pool = pool,
		generated_until = start_time,
		gap = tiers[0].gap,
		weights = tiers[0].demand_weights,
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
// GENERATION_LOOKAHEAD seconds ahead of current_time. Call this every step.
generate_ahead :: proc(
	generator: ^PatternGenerator,
	obstacles: ^[dynamic]Obstacle,
	current_time: f32,
) {
	rng := generator_rng(generator)

	for generator.generated_until < current_time + GENERATION_LOOKAHEAD {
		pattern := pick_next_pattern(generator.pool, generator.weights, rng)

		for event in pattern.events {
			append(
				obstacles,
				new_obstacle(
					generator.generated_until + event.time_offset,
					event.lane,
					event.obstacle_type,
					event.shape,
					event.floating,
					event.cube_phase,
					rng,
				),
			)
		}

		generator.generated_until += pattern.duration + generator.gap
	}
}

// --- Validation ---

// The window of time, relative to the pattern's start, during which an
// event makes its lane lethal at the character.
//
// An obstacle of width w arriving at time a spans screen x from
// WORLD_ANCHOR_X + (a - t) * v to that plus w, and a character at rest
// spans WORLD_ANCHOR_X to WORLD_ANCHOR_X + PLAYER_SIZE. Solving for
// overlap gives [a - PLAYER_SIZE/v, a + w/v].
//
// A character who has lost ground sits to the *left* of the anchor and
// meets everything later — but by the same amount on both lanes, so
// every window shifts together and their overlaps do not change. The
// rule therefore holds wherever the player happens to be, which is why
// this can go on being checked once, statically, against the anchor.
//
// Deliberately measured at the *slowest* speed a run ever uses and with
// the *widest* width a type can roll: both make the window longer, so a
// pool that passes here passes at every speed and on every seed.
//
// **A floating cube drifts along its lane, so its window is wider at both
// ends by the swing.** This is the whole reason the horizontal drift
// needed the validator touched at all. Redo the arithmetic with a drift
// d in [-A, A] added to the obstacle's x and the two conditions become
// (a - t)v + d < PLAYER_SIZE and (a - t)v + d + w > 0; the worst case of
// the first is d = -A and of the second is d = +A, which pushes the start
// back by A/v and the end out by A/v. Leave it out and two events that
// never overlap where they were authored can overlap where they actually
// are — legal apart, illegal together, and nothing would say so.
//
// Checked against the truth rather than derived and trusted: sweeping
// sixty authored phases and asking when a floating cube's x-span really
// overlaps a body at the anchor gives [-0.3147, +0.2480] around the
// arrival, the widened window gives [-0.3148, +0.2481], and the old one
// gave [-0.1667, +0.1000] — too narrow at *both* ends. The widening is
// exact to a ten-thousandth of a second, so it is the right bound and not
// padding.
@(private)
event_window :: proc(event: PatternEvent) -> (start, end: f32) {
	v := f32(INITIAL_SCROLL_SPEED)
	w := get_max_width(event.obstacle_type, event.shape)
	swing: f32 = event.floating ? CUBE_FLOAT_DRIFT : 0
	return event.time_offset - (f32(PLAYER_SIZE) + swing) / v,
		event.time_offset + (w + swing) / v
}

// Do two half-open intervals overlap?
@(private)
overlapping :: proc(a_start, a_end, b_start, b_end: f32) -> bool {
	return a_start < b_end && b_start < a_end
}

// Checks a pool against the fairness rule, and against the one authoring
// mistake that produces no error and no crash: a moment where both lanes
// are lethal, which is a pattern the player cannot answer at all.
//
// It checks the seam as well as the pattern. The containment rule in the
// file header means a seam *cannot* conflict, but that is a property of
// what is authored rather than of the type, so it is verified rather than
// assumed. The seam is checked at the *smallest* gap any tier uses, since
// a smaller gap can only bring the two closer together.
validate_pattern_pool :: proc(pool: []Pattern) {
	smallest_gap := tiers[0].gap
	for tier in tiers {
		smallest_gap = min(smallest_gap, tier.gap)
	}

	for pattern, index in pool {
		if len(pattern.events) == 0 {
			fmt.printf("WARNING: pattern %d has no events\n", index)
		}
		for event in pattern.events {
			report_containment_faults(pattern, index, event)
			report_skyline_faults(event, index)
		}
		report_conflicts(pattern, index, pattern, index, 0)
	}

	for first, first_index in pool {
		for second, second_index in pool {
			report_conflicts(
				first,
				first_index,
				second,
				second_index,
				first.duration + smallest_gap,
			)
		}
	}
}

// Checks that an event's window lies inside its own pattern.
//
// This is what makes the seam safe at every gap, and it is the rule that
// replaced the old one — every pattern opening and closing at the neutral
// corridor — when C1 took the corridor away. It is stricter than "the
// event happens during the pattern": the *window* is what has to fit,
// which means a pattern owes its first event the time a body takes to
// reach it and its last one the time the widest draw takes to pass.
//
// Measured at the slowest speed a run ever uses, because that is where a
// window is longest. A pool that fits here fits everywhere.
//
// The tolerance is for f32 and nothing else. A pattern authored exactly
// on the bound — last event plus the widest draw it can make — is the
// intended case rather than a mistake, and in single precision that sum
// lands a few ten-millionths over. A millisecond is 0.3 px at the opening
// speed, which is far below anything the game can express.
CONTAINMENT_TOLERANCE :: f32(0.001)

@(private)
report_containment_faults :: proc(pattern: Pattern, index: int, event: PatternEvent) {
	start, end := event_window(event)
	if start < -CONTAINMENT_TOLERANCE {
		fmt.printf(
			"WARNING: pattern %d has an event at %.2fs whose window starts at %.2fs, before the pattern does — it would reach back into whatever came before\n",
			index, event.time_offset, start,
		)
	}
	if end > pattern.duration + CONTAINMENT_TOLERANCE {
		fmt.printf(
			"WARNING: pattern %d has an event at %.2fs whose window ends at %.2fs, past its own %.2fs — it would reach into whatever comes next\n",
			index, event.time_offset, end, pattern.duration,
		)
	}
}

// Checks a declared skyline.
//
// This is the other half of "the shape is data". A declaration is free —
// a pattern may ask for any form at any size it likes — so the thing that
// keeps it safe is arithmetic here rather than a closed set of shapes
// somewhere else. Since C1 it is the *only* half: the corridor is a
// constant and the columns are all the relief there is, so this check is
// where every piece of the world's shape is held to its limits.
//
// It checks the **bounds and never an outcome**, which is what lets it
// run once, at startup, against a pool no seed has touched. A declaration
// whose widest draw is legal is legal on every seed, and the same is true
// of its tallest. That is the property C2 was built to keep, and it is
// the same one the hole's width has always had.
//
// The height bound is the one with a failure behind it rather than a
// taste. An obstacle belongs to a lane and blocks only bodies on that
// lane, so a floor cube tall enough to reach a character hanging from the
// ceiling would slide straight through them: a mark that does not do what
// it looks like it does, which is worse than a mark that is merely hard.
// The corridor is TRACK_SPAN tall and no longer moves, so anything over
// CUBE_MAX_HEIGHT reaches the other lane — always, rather than at some
// legal span.
@(private)
report_skyline_faults :: proc(event: PatternEvent, index: int) {
	shape := event.shape

	if event.obstacle_type != .Cube {
		// A hole has no shape to declare, so a skyline on one is a line
		// that silently does nothing — the kind of authoring mistake that
		// survives review precisely because it has no effect.
		if shape != (Skyline{}) || event.floating {
			fmt.printf(
				"WARNING: pattern %d gives a %v at %.2fs a cube's shape — skylines and floating belong to cubes\n",
				index, event.obstacle_type, event.time_offset,
			)
		}
		return
	}

	if shape == (Skyline{}) {
		return // the primitive, which is always legal
	}

	if shape.columns.high < shape.columns.low || shape.height.high < shape.height.low {
		fmt.printf(
			"WARNING: pattern %d declares an empty range at %.2fs (columns %v..%v, height %v..%v) — the generator would have nothing to draw from\n",
			index, event.time_offset,
			shape.columns.low, shape.columns.high, shape.height.low, shape.height.high,
		)
	}

	if skyline_max_columns(shape) > CUBE_MAX_COLUMNS {
		fmt.printf(
			"WARNING: pattern %d may draw a %d-column cube at %.2fs, over the %v-column limit\n",
			index, skyline_max_columns(shape), event.time_offset, CUBE_MAX_COLUMNS,
		)
	}

	if skyline_max_height(shape) > CUBE_MAX_HEIGHT {
		fmt.printf(
			"WARNING: pattern %d may draw a column %v units tall at %.2fs, over the %v-unit limit — it would reach a body on the other lane without blocking it\n",
			index, skyline_max_height(shape), event.time_offset, CUBE_MAX_HEIGHT,
		)
	}

	// A canyon is two towers with something between them. Two columns
	// would be a pair of walls touching, which is a plateau with a lie in
	// its name; draw_skyline floors it at three, and a declaration that
	// needs flooring is a declaration that says the wrong thing.
	if shape.form == .Canyon && skyline_min_columns(shape) < 3 {
		fmt.printf(
			"WARNING: pattern %d declares a canyon as narrow as %d columns at %.2fs — a canyon needs three to have a middle\n",
			index, skyline_min_columns(shape), event.time_offset,
		)
	}

	// A floating cube is drawn as its bounding box (render/obstacle.odin),
	// so a skyline lifted off its lane would be a box that does not match
	// the columns the collision uses. One column keeps the two the same,
	// on every draw and not merely on the lucky ones.
	if event.floating && skyline_max_columns(shape) > 1 {
		fmt.printf(
			"WARNING: pattern %d floats a cube that may reach %d columns at %.2fs — a lifted cube is drawn as one box, so it must be one column\n",
			index, skyline_max_columns(shape), event.time_offset,
		)
	}
}

// The width bounds on a cube that faces another cube across the corridor
// — the one encounter the player cannot dodge, only pay for.
//
// **Never narrower than the body**, because the only way out of a
// mirrored pair is to work through it a flip at a time (see
// advance_ground), and while that is happening the character overlaps the
// box they are pushing past. A box narrower than the character disappears
// inside them, and an obstacle that cannot be seen while it is costing
// you is a bug however correct the arithmetic is.
//
// **Never wider than 54 px**, because the price is the width, and
// mirror_flip_cost counts it in flips: at the opening speed one flip buys
// 28.5 px, so 54 px costs four flips, 81 would cost five and 108 six —
// which turns one encounter into most of the runway.
//
// **That is the model, and the simulation currently disagrees with it.**
// Replayed, a mirrored pair costs one pinned step — 4.5 px — at 27, 54
// and 108 px alike: the flip lands the character *on top of* the far
// cube, which since 5 September is ground they may stand on, so they
// never work through the pair a flip at a time and never pay its width.
// The bound is kept because it is the right bound for the encounter the
// design wants, and because it costs nothing to hold the pool inside it
// until landing-on-top is priced (it is in CLAUDE.md's known issues). Do
// not quote the four flips as something the game charges today.
//
// **Both bounds are absolute pixels, and neither is a multiple of
// CUBE_UNIT any more.** The ceiling used to be written as the primitive's
// own width, which read as though the rule were about the unit; it is
// not, and the unit dropping to 27 is what proved it. The floor is the
// *body*, and the ceiling is a *price* — 54 px is four flips whatever a
// box happens to be built out of. Tied to the unit, halving it would have
// made the legal band [45, 27], which is empty: every mirrored pair in
// the game would have become illegal at once. This is the "the total
// width of a mirrored pair is limited" of Design Doc section 6, made into
// a number.
MIRROR_MIN_WIDTH :: f32(PLAYER_SIZE)
MIRROR_MAX_WIDTH :: f32(54)

// Reports every way `first` and `second`, offset by `shift`, break the
// fairness rule together. With shift = 0 and the same pattern on both
// sides this is the within-pattern check.
@(private)
report_conflicts :: proc(first: Pattern, first_index: int, second: Pattern, second_index: int, shift: f32) {
	same_pattern := shift == 0
	moment := same_pattern ? "at once" : "across the seam"

	for a, a_index in first.events {
		a_start, a_end := event_window(a)

		for b, b_index in second.events {
			// The within-pattern pass compares a pattern with itself, so
			// an event must not be checked against its own entry.
			if same_pattern && a_index == b_index {
				continue
			}

			b_start, b_end := event_window(b)
			b_start += shift
			b_end += shift

			report_same_lane_overlap(first_index, a, second_index, b, shift)

			if !is_lethal(a.obstacle_type) || !is_lethal(b.obstacle_type) {
				// Nothing lethal in play. A mirrored pair, which is legal
				// and bounded, is the only rule left.
				if blocks_lane(a.obstacle_type) &&
				   blocks_lane(b.obstacle_type) &&
				   a.lane != b.lane &&
				   overlapping(a_start, a_end, b_start, b_end) {
					report_mirror_width(first_index, a)
					report_mirror_width(second_index, b)
				}
				continue
			}

			// Two lethal lanes at the same instant: nowhere to be.
			if a.lane != b.lane && overlapping(a_start, a_end, b_start, b_end) {
				fmt.printf(
					"WARNING: pattern %d and pattern %d threaten both lanes %s (%v at %.2fs vs %v at %.2fs+%.2f) — unanswerable\n",
					first_index, second_index, moment,
					a.obstacle_type, a.time_offset, b.obstacle_type, b.time_offset, shift,
				)
			}
		}
	}
}

// Two cubes on one lane that overlap in x.
//
// A new failure mode as of C2, because the shapes got wide: the terrain
// welds every cube into the lane's own polyline, and an overlapping one is
// **dropped** rather than merged, since the outline walks x forward and
// cannot go back (render/terrain.odin). The collision would still see it.
// A danger that is not drawn is the one thing pillar 3 forbids outright,
// and this is the quiet way to author one.
//
// Measured at the slowest speed, where two events of a given spacing sit
// closest together in x — the separation is (t2 - t1) * speed and the
// widths are fixed, so every faster tier only pulls them further apart.
//
// A floating cube is exempt at both ends: it is the one cube the terrain
// does not weld in, so it is drawn whatever it overlaps.
@(private)
report_same_lane_overlap :: proc(
	first_index: int,
	a: PatternEvent,
	second_index: int,
	b: PatternEvent,
	shift: f32,
) {
	if a.lane != b.lane || !blocks_lane(a.obstacle_type) || !blocks_lane(b.obstacle_type) {
		return
	}
	if a.floating || b.floating {
		return
	}

	a_time := a.time_offset
	b_time := b.time_offset + shift
	if b_time < a_time {
		return // the ordered pass reaches this pair the other way round
	}

	separation := (b_time - a_time) * f32(INITIAL_SCROLL_SPEED)
	width := get_max_width(a.obstacle_type, a.shape)
	if separation < width {
		fmt.printf(
			"WARNING: pattern %d at %.2fs and pattern %d at %.2fs put two cubes %.0f px apart on the same lane, closer than the first can be wide (%.0f px) — the second would be dropped from the line and drawn nowhere\n",
			first_index, a_time, second_index, b.time_offset, separation, width,
		)
	}
}

// **Both ends of the declaration, not one.** A skyline is drawn per
// obstacle, so a pattern whose facing cube is legal at its widest and
// illegal at its narrowest would be fair on some seeds and not on others
// — the exact failure mode a static check exists to make impossible.
@(private)
report_mirror_width :: proc(index: int, event: PatternEvent) {
	narrow := get_min_width(event.obstacle_type, event.shape)
	wide := get_max_width(event.obstacle_type, event.shape)
	if narrow < MIRROR_MIN_WIDTH || wide > MIRROR_MAX_WIDTH {
		fmt.printf(
			"WARNING: pattern %d faces a cube of %.0f..%.0f px across the corridor at %.2fs — a mirrored pair must be between %.0f and %.0f px wide on every draw\n",
			index, narrow, wide, event.time_offset, MIRROR_MIN_WIDTH, MIRROR_MAX_WIDTH,
		)
	}
}
