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
* each event owns and checks two things:
*
*   * a Real lethal window never overlaps a Dream one;
*   * two cubes facing each other across the corridor are each between
*     MIRROR_MIN_WIDTH and MIRROR_MAX_WIDTH, which is what bounds the
*     price of the one encounter that has no way out.
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

	// Cube only, and both have a zero value that means "the primitive":
	// an event that says nothing about its cube gets a standard one, low
	// in its bob. Authoring a floating cube is therefore two words —
	// the form, and where in its rise it meets the anchor.
	cube:          CubeForm,
	cube_phase:    f32, // Float only: 0 is down and blocking, 0.5 is up and open
}

Pattern :: struct {
	events:   []PatternEvent,

	// Where the world itself goes for the length of this pattern
	// (core/track.odin), keyframed in time relative to its start. A
	// pattern is a piece of world, not a list of things suspended over a
	// neutral backdrop: the corridor sagging, lifting, pinching or opening
	// *is* content, and authoring it anywhere else would mean the ground
	// and the obstacles could disagree about what the moment is for.
	//
	// Every pattern starts and ends at the neutral corridor — enforced by
	// validate_pattern_pool — which is what lets patterns be strung
	// together in any order with a continuous world and no seam check.
	// The rhythm that falls out of it is a happy accident worth knowing:
	// the track is flat for the whole gap between patterns, so as the
	// tiers squeeze that gap the world undulates more and more
	// continuously, without a line of code that intends it.
	track:    []core.TrackPoint,

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
// Deliberately small for R1. This phase is demolition: the pool that the
// game ships with is authored in R5.2, once the Cube blocks instead of
// killing, because that changes what a pattern can even ask.

// One cube, one lane, plenty of time. The floor of the pool.
pattern_cube_real := Pattern {
	events   = []PatternEvent{{time_offset = 0.9, lane = .Real, obstacle_type = .Cube}},
	track    = []core.TrackPoint{
		{time = 0, spine = 360, span = 340},
		{time = 0.9, spine = 392, span = 340},
		{time = 1.9, spine = 360, span = 340},
	},
	duration = 1.9,
	demand   = 0,
}

pattern_cube_dream := Pattern {
	events   = []PatternEvent{{time_offset = 0.9, lane = .Dream, obstacle_type = .Cube}},
	track    = []core.TrackPoint{
		{time = 0, spine = 360, span = 340},
		{time = 0.9, spine = 328, span = 340},
		{time = 1.9, spine = 360, span = 340},
	},
	duration = 1.9,
	demand   = 0,
}

// A hole is wider than a cube and asks a different question — not "move
// now" but "do not be down here for this stretch".
pattern_gap_real := Pattern {
	events   = []PatternEvent{{time_offset = 0.9, lane = .Real, obstacle_type = .Gap}},
	track    = []core.TrackPoint{
		{time = 0, spine = 360, span = 340},
		{time = 0.9, spine = 384, span = 376},
		{time = 1.9, spine = 360, span = 340},
	},
	duration = 1.9,
	demand   = 0,
}

pattern_gap_dream := Pattern {
	events   = []PatternEvent{{time_offset = 0.9, lane = .Dream, obstacle_type = .Gap}},
	track    = []core.TrackPoint{
		{time = 0, spine = 360, span = 340},
		{time = 0.9, spine = 336, span = 376},
		{time = 1.9, spine = 360, span = 340},
	},
	duration = 1.9,
	demand   = 0,
}

// Two threats on opposite lanes: whichever lane you start on, you move
// at least once, and if you start on the wrong one you move twice.
pattern_alternate := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.8, lane = .Real, obstacle_type = .Cube},
		{time_offset = 1.7, lane = .Dream, obstacle_type = .Cube},
	},
	track    = []core.TrackPoint{
		{time = 0, spine = 360, span = 340},
		{time = 0.8, spine = 360, span = 286},
		{time = 1.7, spine = 360, span = 286},
		{time = 2.6, spine = 360, span = 340},
	},
	duration = 2.6,
	demand   = 1,
}

pattern_alternate_reverse := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.8, lane = .Dream, obstacle_type = .Cube},
		{time_offset = 1.7, lane = .Real, obstacle_type = .Cube},
	},
	track    = []core.TrackPoint{
		{time = 0, spine = 360, span = 340},
		{time = 0.8, spine = 330, span = 286},
		{time = 1.7, spine = 330, span = 286},
		{time = 2.6, spine = 360, span = 340},
	},
	duration = 2.6,
	demand   = 1,
}

// A hole then a cube on the other side: the answer to the first is the
// place the second is waiting.
pattern_gap_then_cube := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.9, lane = .Real, obstacle_type = .Gap},
		{time_offset = 2.0, lane = .Dream, obstacle_type = .Cube},
	},
	track    = []core.TrackPoint{
		{time = 0, spine = 360, span = 340},
		{time = 0.9, spine = 392, span = 382},
		{time = 2.0, spine = 336, span = 318},
		{time = 2.9, spine = 360, span = 340},
	},
	duration = 2.9,
	demand   = 1,
}

pattern_gap_then_cube_reverse := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.9, lane = .Dream, obstacle_type = .Gap},
		{time_offset = 2.0, lane = .Real, obstacle_type = .Cube},
	},
	track    = []core.TrackPoint{
		{time = 0, spine = 360, span = 340},
		{time = 0.9, spine = 328, span = 382},
		{time = 2.0, spine = 384, span = 318},
		{time = 2.9, spine = 360, span = 340},
	},
	duration = 2.9,
	demand   = 1,
}

// Three in a row, tighter: the first answer has to be the setup for the
// second, because there is no room to settle in between.
pattern_stagger := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.8, lane = .Real, obstacle_type = .Cube},
		{time_offset = 1.5, lane = .Dream, obstacle_type = .Cube},
		{time_offset = 2.2, lane = .Real, obstacle_type = .Cube},
	},
	track    = []core.TrackPoint{
		{time = 0, spine = 360, span = 340},
		{time = 0.8, spine = 392, span = 320},
		{time = 1.5, spine = 328, span = 320},
		{time = 2.2, spine = 392, span = 320},
		{time = 3.0, spine = 360, span = 340},
	},
	duration = 3.0,
	demand   = 2,
}

pattern_stagger_reverse := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.8, lane = .Dream, obstacle_type = .Cube},
		{time_offset = 1.5, lane = .Real, obstacle_type = .Cube},
		{time_offset = 2.2, lane = .Dream, obstacle_type = .Cube},
	},
	track    = []core.TrackPoint{
		{time = 0, spine = 360, span = 340},
		{time = 0.8, spine = 328, span = 320},
		{time = 1.5, spine = 392, span = 320},
		{time = 2.2, spine = 328, span = 320},
		{time = 3.0, spine = 360, span = 340},
	},
	duration = 3.0,
	demand   = 2,
}

// Two holes on alternating lanes: long stretches rather than instants,
// so the answer is to be somewhere for a while rather than to move once.
pattern_gap_pair := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.9, lane = .Real, obstacle_type = .Gap},
		{time_offset = 2.2, lane = .Dream, obstacle_type = .Gap},
	},
	track    = []core.TrackPoint{
		{time = 0, spine = 360, span = 340},
		{time = 0.9, spine = 360, span = 412},
		{time = 2.2, spine = 360, span = 412},
		{time = 3.1, spine = 360, span = 340},
	},
	duration = 3.1,
	demand   = 2,
}

// The burst: four answers, no room at all.
pattern_burst := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.8, lane = .Real, obstacle_type = .Cube},
		{time_offset = 1.4, lane = .Dream, obstacle_type = .Cube},
		{time_offset = 2.0, lane = .Real, obstacle_type = .Cube},
		{time_offset = 2.6, lane = .Dream, obstacle_type = .Cube},
	},
	track    = []core.TrackPoint{
		{time = 0, spine = 360, span = 340},
		{time = 0.7, spine = 360, span = 264},
		{time = 2.7, spine = 360, span = 264},
		{time = 3.4, spine = 360, span = 340},
	},
	duration = 3.4,
	demand   = 3,
}

// The corridor pinches to nearly its narrowest with one cube inside it.
// The cube is the same cube; what makes this hard is that there is less
// world to be elsewhere in.
pattern_narrows := Pattern {
	events   = []PatternEvent{{time_offset = 1.4, lane = .Real, obstacle_type = .Cube}},
	track    = []core.TrackPoint {
		{time = 0, spine = 360, span = 340},
		{time = 1.0, spine = 360, span = 254},
		{time = 1.8, spine = 360, span = 254},
		{time = 2.6, spine = 360, span = 340},
	},
	duration = 2.6,
	demand   = 1,
}

// The world itself rises and falls, a long way, while two holes ask which
// lane to be on. The only pattern where the answer is mostly about
// reading the ground rather than the things standing on it.
pattern_swell := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.4, lane = .Dream, obstacle_type = .Gap},
		{time_offset = 2.6, lane = .Real, obstacle_type = .Gap},
	},
	track    = []core.TrackPoint {
		{time = 0, spine = 360, span = 340},
		{time = 1.1, spine = 286, span = 300},
		{time = 2.2, spine = 434, span = 300},
		{time = 3.2, spine = 360, span = 340},
	},
	duration = 3.2,
	demand   = 2,
}

// --- The three dangers, and what they say together (roadmap R4) ---

// A tower on the floor. Mechanically it is the primitive: three cubes
// stacked cost exactly what one costs, because the price is the width and
// the height is rhetoric. It earns its place by being read as *worse* at
// a glance, which is the cheapest variety in the whole set.
pattern_stack := Pattern {
	events   = []PatternEvent{{time_offset = 0.9, lane = .Real, obstacle_type = .Cube, cube = .Stack}},
	track    = []core.TrackPoint {
		{time = 0, spine = 360, span = 340},
		{time = 0.9, spine = 376, span = 340},
		{time = 2.0, spine = 360, span = 340},
	},
	duration = 2.0,
	demand   = 0,
}

// Cubes in a staircase, hanging from the ceiling. Wide — three units, so
// it holds a lane for most of a second — and it announces its own shape
// early, which is the point of it: the silhouette says which side of the
// corridor is going to be worth being on before the mass arrives.
pattern_pyramid := Pattern {
	events   = []PatternEvent{{time_offset = 1.2, lane = .Dream, obstacle_type = .Cube, cube = .Pyramid}},
	track    = []core.TrackPoint {
		{time = 0, spine = 360, span = 340},
		{time = 1.0, spine = 344, span = 340},
		{time = 1.8, spine = 344, span = 340},
		{time = 2.6, spine = 360, span = 340},
	},
	duration = 2.6,
	demand   = 1,
}

// A bump, then a wall. The two ends of the single cube's range on
// opposite lanes, and the pattern that says what width actually buys:
// **nothing, on its own**. A lone cube of any width costs exactly one
// flip, because the other lane is open and one flip is one flip. Width
// only becomes a price where there is no free lane to flip to — which is
// the mirrored pair below, and nowhere else.
//
// So the small and the wide cube are here for the eye, not the hand, and
// that is a legitimate job: they are how the set stops looking like one
// object repeated.
pattern_bump_and_wall := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.9, lane = .Real, obstacle_type = .Cube, cube = .Small},
		{time_offset = 1.9, lane = .Dream, obstacle_type = .Cube, cube = .Wide},
	},
	track    = []core.TrackPoint {
		{time = 0, spine = 360, span = 340},
		{time = 0.9, spine = 376, span = 340},
		{time = 1.9, spine = 336, span = 340},
		{time = 2.8, spine = 360, span = 340},
	},
	duration = 2.8,
	demand   = 1,
}

// **The mirrored pair.** The same cube on both lanes at the same instant,
// and the first thing in the project's history that threatens both
// answers at once without being unfair — legal precisely because a cube
// does not kill.
//
// There is no way out and there is no way round: pinned, the character
// holds station in the world, and only a flip buys ground. So the answer
// is to work through it, a flip at a time, and what it costs is the
// width. The corridor opens for it so the two boxes read as a pair rather
// than as a pinch.
//
// **Wide rather than the primitive, and that is not a strengthening.**
// Wide is two units — 54 px, exactly what a standard cube was before the
// unit halved — so the encounter is the same size and the same four
// flips it has always been. What changed underneath it is that the
// primitive is now narrower than the body, and a box that disappears
// inside the character while it is costing them ground is the one thing
// MIRROR_MIN_WIDTH exists to forbid. The pair is about width, so it has
// to be authored out of a form wide enough to be seen paying for.
pattern_mirror := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.0, lane = .Real, obstacle_type = .Cube, cube = .Wide},
		{time_offset = 1.0, lane = .Dream, obstacle_type = .Cube, cube = .Wide},
	},
	track    = []core.TrackPoint {
		{time = 0, spine = 360, span = 340},
		{time = 0.9, spine = 360, span = 400},
		{time = 1.5, spine = 360, span = 400},
		{time = 2.3, spine = 360, span = 340},
	},
	duration = 2.3,
	demand   = 2,
}

// A cube that floats: it is up when it reaches the anchor, so a character
// who is where they should be runs under it and one who has lost ground
// meets it on the way down. The only obstacle in the game whose answer
// depends on how much room you have left.
pattern_float_open := Pattern {
	events   = []PatternEvent {
		{
			time_offset = 1.3,
			lane = .Dream,
			obstacle_type = .Cube,
			cube = .Float,
			cube_phase = 0.5,
		},
	},
	track    = []core.TrackPoint {
		{time = 0, spine = 360, span = 340},
		{time = 1.2, spine = 360, span = 300},
		{time = 2.4, spine = 360, span = 340},
	},
	duration = 2.4,
	demand   = 1,
}

// Two of them, out of phase: the first is up as it passes and the second
// is down. Same obstacle, opposite answers, and the only way to tell is
// to watch them.
pattern_float_pair := Pattern {
	events   = []PatternEvent {
		{
			time_offset = 1.0,
			lane = .Dream,
			obstacle_type = .Cube,
			cube = .Float,
			cube_phase = 0.5,
		},
		{time_offset = 2.1, lane = .Dream, obstacle_type = .Cube, cube = .Float},
	},
	track    = []core.TrackPoint {
		{time = 0, spine = 360, span = 340},
		{time = 1.0, spine = 360, span = 310},
		{time = 2.2, spine = 360, span = 310},
		{time = 3.0, spine = 360, span = 340},
	},
	duration = 3.0,
	demand   = 2,
}

all_patterns := []Pattern {
	pattern_cube_real,
	pattern_cube_dream,
	pattern_gap_real,
	pattern_gap_dream,
	pattern_alternate,
	pattern_alternate_reverse,

	// A stack asks nothing a single cube does not, so it belongs in the
	// opening tier: it is the same question wearing a bigger silhouette.
	pattern_stack,
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
	track: ^core.Track,
	current_time: f32,
) {
	rng := generator_rng(generator)

	for generator.generated_until < current_time + GENERATION_LOOKAHEAD {
		pattern := pick_next_pattern(generator.pool, generator.weights, rng)

		// The world's own shape, laid down the same way and on the same
		// clock as the things standing on it.
		for point in pattern.track {
			core.track_append(
				track,
				core.TrackPoint {
					time = generator.generated_until + point.time,
					spine = point.spine,
					span = point.span,
				},
			)
		}

		for event in pattern.events {
			append(
				obstacles,
				new_obstacle(
					generator.generated_until + event.time_offset,
					event.lane,
					event.obstacle_type,
					event.cube,
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
@(private)
event_window :: proc(event: PatternEvent) -> (start, end: f32) {
	v := f32(INITIAL_SCROLL_SPEED)
	w := get_max_width(event.obstacle_type, event.cube)
	return event.time_offset - f32(PLAYER_SIZE) / v, event.time_offset + w / v
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
// It checks the seam as well as the pattern. A wide hole at the end of
// one pattern and a cube at the start of the next are authored in
// different files' worth of thinking and meet only at runtime, which is
// exactly the kind of overlap nobody spots by reading. The seam is
// checked at the *smallest* gap any tier uses, since a smaller gap can
// only bring the two closer together.
validate_pattern_pool :: proc(pool: []Pattern) {
	smallest_gap := tiers[0].gap
	for tier in tiers {
		smallest_gap = min(smallest_gap, tier.gap)
	}

	for pattern, index in pool {
		if len(pattern.events) == 0 {
			fmt.printf("WARNING: pattern %d has no events\n", index)
		}
		report_track_faults(pattern, index)
		for event in pattern.events {
			if event.time_offset < 0 || event.time_offset > pattern.duration {
				fmt.printf(
					"WARNING: pattern %d has an event at %.2fs, outside its own %.2fs duration\n",
					index,
					event.time_offset,
					pattern.duration,
				)
			}
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

// Checks a pattern's authored track.
//
// The endpoint rule is what replaces a seam check. If every pattern both
// begins and ends at the neutral corridor, then whatever order the
// generator strings them in, the world is continuous and the segment
// across a gap is flat — so there is nothing to verify at a seam, and no
// pair of patterns can be illegal together that is legal apart.
//
// The rate limits are enforced on the authored numbers rather than
// clamped at runtime, because the fix for a track that lurches is to
// author it differently. A sampler that quietly disagreed with what was
// written would also stop being linear, which is what track_support_y's
// exactness rests on (core/track.odin).
@(private)
report_track_faults :: proc(pattern: Pattern, index: int) {
	if len(pattern.track) < 2 {
		fmt.printf("WARNING: pattern %d has no track — it must at least declare its two ends\n", index)
		return
	}

	first := pattern.track[0]
	last := pattern.track[len(pattern.track) - 1]
	if first.time != 0 || first.spine != core.TRACK_SPINE_DEFAULT || first.span != core.TRACK_SPAN_DEFAULT {
		fmt.printf(
			"WARNING: pattern %d opens its track at t=%.2f spine %.0f span %.0f, but every pattern must open neutral (0, %v, %v)\n",
			index, first.time, first.spine, first.span,
			core.TRACK_SPINE_DEFAULT, core.TRACK_SPAN_DEFAULT,
		)
	}
	if last.time != pattern.duration ||
	   last.spine != core.TRACK_SPINE_DEFAULT ||
	   last.span != core.TRACK_SPAN_DEFAULT {
		fmt.printf(
			"WARNING: pattern %d closes its track at t=%.2f spine %.0f span %.0f, but every pattern must close neutral (%.2f, %v, %v)\n",
			index, last.time, last.spine, last.span,
			pattern.duration, core.TRACK_SPINE_DEFAULT, core.TRACK_SPAN_DEFAULT,
		)
	}

	for i in 1 ..< len(pattern.track) {
		previous := pattern.track[i - 1]
		point := pattern.track[i]
		width := point.time - previous.time
		if width <= 0 {
			fmt.printf(
				"WARNING: pattern %d has track keyframes out of order at t=%.2f\n",
				index, point.time,
			)
			continue
		}

		spine_rate := abs(point.spine - previous.spine) / width
		if spine_rate > core.TRACK_MAX_SPINE_RATE {
			fmt.printf(
				"WARNING: pattern %d moves its spine at %.0f px/s between t=%.2f and t=%.2f, over the %v limit\n",
				index, spine_rate, previous.time, point.time, core.TRACK_MAX_SPINE_RATE,
			)
		}
		span_rate := abs(point.span - previous.span) / width
		if span_rate > core.TRACK_MAX_SPAN_RATE {
			fmt.printf(
				"WARNING: pattern %d changes its span at %.0f px/s between t=%.2f and t=%.2f, over the %v limit\n",
				index, span_rate, previous.time, point.time, core.TRACK_MAX_SPAN_RATE,
			)
		}

		// Clamping happens on append, so an authored point outside the
		// legal envelope is silently corrected at runtime — which means
		// the pattern on screen is not the pattern that was written.
		if core.track_clamp(point) != point {
			corrected := core.track_clamp(point)
			fmt.printf(
				"WARNING: pattern %d authors an illegal corridor at t=%.2f (spine %.0f span %.0f), clamped to spine %.0f span %.0f\n",
				index, point.time, point.spine, point.span, corrected.spine, corrected.span,
			)
		}
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

@(private)
report_mirror_width :: proc(index: int, event: PatternEvent) {
	width := get_max_width(event.obstacle_type, event.cube)
	if width < MIRROR_MIN_WIDTH || width > MIRROR_MAX_WIDTH {
		fmt.printf(
			"WARNING: pattern %d faces a %v cube (%.0f px) across the corridor at %.2fs — a mirrored pair must be between %.0f and %.0f px wide\n",
			index, event.cube, width, event.time_offset, MIRROR_MIN_WIDTH, MIRROR_MAX_WIDTH,
		)
	}
}
