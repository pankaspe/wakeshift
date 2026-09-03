/*
* This is Pattern file, pattern.odin
* A pattern is a short, hand-authored sequence of obstacle events,
* expressed in time relative to the pattern's own start (Design Doc,
* section 6-7). Patterns are chained, and the contract at the seam is
* what stops the generator from ever handing the player a sequence that
* cannot be answered.
*
* THE CONTRACT (roadmap T7.1)
*
* Until phase 7 the contract was two single lanes and an equality: the
* next pattern's entry_lane had to equal the previous one's exit_lane.
* That was not wrong about the Limen so much as wrong about *patterns*:
* it assumed every pattern has exactly one correct answer. The Echo has
* two — two tight flips, or one hold through the middle — and they end
* at opposite walls, so exit_lane named one of them and the pattern paid
* for the lie with a second of trailing slack.
*
* So entry and exit are now *sets of bands*, and chaining is containment
* rather than equality:
*
*     entry   the bands this pattern poses a fair question from
*     exit    the bands a player who answered it as intended can be in
*             when it ends, over every answer the pattern offers
*     chain   prev.exit must be a subset of next.entry
*
* Containment is the whole point. The generator picks the next pattern
* before knowing which answer the player took, so it has to pick one that
* accepts *all* of them.
*
* WHY THE CONTRACT IS ABOUT WALLS, AND THE LIMEN IS NOT IN IT
*
* The first version of this went the obvious way: teach entry and exit
* the third state, so a pattern could say "you may arrive suspended" and
* "I leave you suspended". Replaying every pattern against the real
* simulation killed it (the throwaway harness described below). The
* measurement was blunt: for almost every pattern in the pool, pressing
* once and never letting go both survives and ends the pattern suspended.
* Holding is always available, it needs no permission from the pattern,
* and a full tank outlasts most pattern durations.
*
* So "the player is in the Limen at this seam" is not a thing the
* chaining contract can control, and a contract that claimed to control
* it would have had to put the Limen in every entry and every exit set —
* which is the same as having no contract at all.
*
* The exit set is therefore wall-valued, and validate_pattern_pool
* enforces that. What the Limen contributes to it is not a third member
* but a *second wall*: holding pauses a journey rather than starting a
* different one, so releasing lands the player at the wall they were
* already travelling toward. A pattern with a hold answer and a flip
* answer exits at both walls — which is exactly the mismatch T7.1 was
* opened to fix, and it needed sets, not a third band.
*
* WHAT THE PLAYER IS OWED IN THE MIDDLE, THEN
*
* Not safety — the Patroller exists to make the middle cost something,
* and pattern_echo_guarded exists to take the hold answer away. What they
* are owed is what pillar 3 actually promises: the threat is on screen
* before the commitment. A player suspended across a seam can see what is
* coming and let go.
*
* The one thing a pattern may never do is *require* the middle. Lucidity
* can be zero — it starts every run at zero — so a pattern whose only
* answer is a hold is unsolvable for a player who cannot afford it. Every
* pattern must have an answer made only of taps.
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
	events:   []PatternEvent,
	duration: f32, // total length of the pattern, in seconds
	entry:    core.Bands, // bands this pattern poses a fair question from
	exit:     core.Bands, // bands an intended answer can leave the player in

	// How much this pattern asks of the player, 0..DEMAND_LEVELS-1. It is
	// not a difficulty score for its own sake: it is what a tier draws on
	// to change *what the player meets* rather than only how fast it
	// arrives (see difficulty.odin).
	//
	//   0  one obstacle, one decision, and time to make it
	//   1  two decisions, or one that has to be read rather than reflexed
	//   2  the obvious answer is wrong, and the right one is timed
	//   3  three decisions, or an answer taken away
	demand:   int,
}

// How many demand levels a pattern can carry. Tiers weight the pool by
// this (Tier.demand_weights).
DEMAND_LEVELS :: 4

// A single Block in the Real lane: player must be in Dream to survive.
pattern_steady_real := Pattern {
	events   = []PatternEvent{{time_offset = 1.0, lane = .Real, obstacle_type = .Block}},
	duration = 2.0,
	entry    = {.Dream},
	exit     = {.Dream},
	demand   = 0,
}

// A single Chasm in the Real lane: same rule as Block, read inverted (Design Doc, section 5).
pattern_steady_chasm := Pattern {
	events   = []PatternEvent{{time_offset = 1.0, lane = .Real, obstacle_type = .Chasm}},
	duration = 2.0,
	entry    = {.Dream},
	exit     = {.Dream},
	demand   = 0,
}

// A single Pulsing Shape in the Dream lane: player must be in Real to survive.
pattern_steady_dream := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.0, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
	},
	duration = 2.0,
	entry    = {.Real},
	exit     = {.Real},
	demand   = 0,
}

// A single Dream Hole in the Dream lane: same rule as Pulsing Shape's lane, read inverted.
pattern_steady_dreamhole := Pattern {
	events   = []PatternEvent{{time_offset = 1.0, lane = .Dream, obstacle_type = .DreamHole}},
	duration = 2.0,
	entry    = {.Real},
	exit     = {.Real},
	demand   = 0,
}

// Two obstacles requiring a flip mid-pattern: Real first, then Dream.
pattern_double_switch := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.8, lane = .Real, obstacle_type = .Block},
		{time_offset = 1.8, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
	},
	duration = 2.6,
	entry    = {.Dream},
	exit     = {.Real},
	demand   = 1,
}

// Two obstacles requiring a flip mid-pattern: Dream first, then Real.
// Mirror of pattern_double_switch — without this, the generator's lane
// graph has a dead end (Real can never lead back to Dream).
pattern_double_switch_reverse := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.8, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
		{time_offset = 1.8, lane = .Real, obstacle_type = .Chasm},
	},
	duration = 2.6,
	entry    = {.Real},
	exit     = {.Dream},
	demand   = 1,
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
// This is the pattern the whole of T7.1 was written for. Its two answers
// end at opposite walls: the two flips come back to Dream, and the hold
// resolves into Real when the player lets go. Before the contract took
// sets it could only name one of them, and it bought the difference with
// over a second of trailing slack. Now it says both, and the slack is
// gone — the duration is the pattern, not an apology for it.
//
// Confirmed by replay: from Dream the cheapest surviving answer is the
// single press-and-hold, and the two-flip answer is the only two-press
// line that lives. Both are real, and they land on opposite walls.
pattern_echo := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.0, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
		{time_offset = 1.45, lane = .Real, obstacle_type = .Block},
	},
	duration = 2.4,
	entry    = {.Dream},
	exit     = {.Real, .Dream},
	demand   = 2,
}

// The Feint: what looks like a block growing in your own lane is a bluff
// that retracts before it arrives, and the lane you would flip into is
// the one that is actually closed. Staying put is correct.
//
// The bluff resolves 0.6s before it would have reached the player
// (FEINT_GONE), which is more than the 0.24s a flip takes: the player who
// waits is never made to guess.
pattern_feint_real := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.2, lane = .Real, obstacle_type = .Feint},
		{time_offset = 1.25, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
	},
	duration = 2.6,
	entry    = {.Real},
	exit     = {.Real},
	demand   = 1,
}

pattern_feint_dream := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.2, lane = .Dream, obstacle_type = .Feint},
		{time_offset = 1.25, lane = .Real, obstacle_type = .Block},
	},
	duration = 2.6,
	entry    = {.Dream},
	exit     = {.Dream},
	demand   = 1,
}

// --- Harder patterns, unlocked at higher difficulty tiers (section 18) ---

// The Patroller sweeping up to the ceiling as it reaches the player: the
// low lane is the safe one, and the pattern says so a full cycle before
// it matters.
pattern_patrol_high := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.3, lane = .Dream, obstacle_type = .Patroller, phase_offset = 0},
	},
	duration = 2.6,
	entry    = {.Real},
	exit     = {.Real},
	demand   = 1,
}

// The Echo with the middle taken away: the Patroller is in the Limen at
// exactly the moment the hold would have been resting there, so the only
// answer left is the two flips. This is the pattern that closes the
// imbalance phase 5 shipped with — the centre stops being free.
//
// One answer, so one exit — which is the other half of what makes the
// set-valued contract worth having. A pattern that takes an answer away
// gets a *narrower* exit than the one it is built from, and a narrow exit
// is what lets a tight pattern follow it.
pattern_echo_guarded := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.0, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
		{time_offset = 1.2, lane = .Real, obstacle_type = .Patroller, phase_offset = 0.25},
		{time_offset = 1.45, lane = .Real, obstacle_type = .Block},
	},
	duration = 3.2,
	entry    = {.Dream},
	exit     = {.Dream},
	demand   = 3,
}

// Tighter timing than pattern_double_switch_reverse: less reaction time
// between the two obstacles.
//
// The exit says Dream, and it used to say Real, which was simply wrong:
// the Chasm at 1.1 is up to 140px wide and takes most of half a second to
// pass, so a player who flips out of the floor to clear it cannot be back
// on the floor before the pattern ends. The generator has been picking
// Real-entry patterns to follow it and handing them to a player standing
// on the ceiling. The set contract did not find this — reading the
// pattern in order to write the set did.
pattern_tight_double_switch := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.5, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
		{time_offset = 1.1, lane = .Real, obstacle_type = .Chasm},
	},
	duration = 1.6,
	entry    = {.Real},
	exit     = {.Dream},
	demand   = 2,
}

// Three obstacles in quick succession, alternating lanes each time.
pattern_triple_switch := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.6, lane = .Real, obstacle_type = .Block},
		{time_offset = 1.3, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
		{time_offset = 2.0, lane = .Real, obstacle_type = .Chasm},
	},
	duration = 2.4,
	entry    = {.Dream},
	exit     = {.Dream},
	demand   = 3,
}

// --- Filling the hole the pool audit found (roadmap T7.2) ---
//
// Counting the pool by entry wall showed it was lopsided in a way no
// amount of tier weighting can fix: Dream had three patterns of demand 2
// or more and Real had one, and none at demand 3. A weight cannot draw a
// pattern that does not exist, so at the deepest tier a player standing
// on the floor met an easy pattern almost every time and the same player
// on the ceiling met the hardest ones. The three below are all entered
// from Real, and they are what makes the demand weights mean anything.

// The Echo from the floor. Same shape as pattern_echo and the same two
// answers landing on opposite walls — two flips come back to Real, the
// hold resolves into Dream — but asked of a player who is standing on
// the ground, where the panic answer is to go up.
pattern_echo_reverse := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.0, lane = .Real, obstacle_type = .Block},
		{time_offset = 1.45, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
	},
	duration = 2.4,
	entry    = {.Real},
	exit     = {.Real, .Dream},
	demand   = 2,
}

// The bluff that pushes you into a sweep. A Feint grows out of the floor
// you are standing on, and the Patroller is at the ceiling exactly when
// it arrives: the flip the bluff is asking for is the one thing that
// kills. Staying is right, and both halves of that are visible in
// advance.
//
// A different reading from pattern_feint_real, which answers the bluff
// with a static shape hanging in the other lane. Here the punishment is
// something *moving*, and it is at the top of a sweep the player has been
// watching for a full cycle.
pattern_feint_patrol := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.2, lane = .Real, obstacle_type = .Feint},
		{time_offset = 1.25, lane = .Dream, obstacle_type = .Patroller, phase_offset = 0},
	},
	duration = 2.6,
	entry    = {.Real},
	exit     = {.Real},
	demand   = 2,
}

// Three decisions entering from the floor: the mirror of
// pattern_triple_switch, and the pool's first demand-3 pattern that a
// player standing on the ground can be given.
//
// The middle beat is a Chasm rather than a Block on purpose. A chasm is
// up to 2.6 times as wide, so it holds the floor shut for most of a
// second at the slowest tier, and the pattern has to leave room for that
// before it asks for the third flip — which is why this one is longer
// than the pattern it mirrors rather than tighter.
pattern_triple_switch_reverse := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.6, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
		{time_offset = 1.4, lane = .Real, obstacle_type = .Chasm},
		{time_offset = 2.3, lane = .Dream, obstacle_type = .PulsingShape, phase_offset = 0.25},
	},
	duration = 2.9,
	entry    = {.Real},
	exit     = {.Real},
	demand   = 3,
}

// --- Convergers: the class the set-valued contract turned out to need ---
//
// These accept *both* walls, and the pool is unsound without them. The
// moment pattern_echo stopped pretending it had one answer, its exit set
// became {Real, Dream}, and nothing in a pool of single-wall entries can
// follow that — pick_next_pattern would have quietly fallen back to
// pool[0] after every Echo for the rest of the run. The pool validator
// found it on the first launch after the contract changed, which is the
// entire reason that check exists.
//
// So a pattern with two answers has to be followed by something that does
// not care which one was taken. That is a real design shape, not a patch:
// it is the beat where the game stops asking about walls.

// Nothing that can kill you, in either world — two bluffs, staggered, one
// per lane. A player on either wall is right to do nothing, and both of
// them get something to read while they do it.
//
// The pool's only true rest, and the cheapest possible converger: the
// answer from every band is the same answer.
pattern_drift := Pattern {
	events   = []PatternEvent {
		{time_offset = 0.9, lane = .Real, obstacle_type = .Feint},
		{time_offset = 1.8, lane = .Dream, obstacle_type = .Feint},
	},
	duration = 2.6,
	entry    = {.Real, .Dream},
	exit     = {.Real, .Dream},
	demand   = 0,
}

// The one pattern in the game that threatens the middle and nothing else:
// a Patroller crossing the column with the exact phase that puts it in
// the Limen as it arrives. Both walls are safe, and only the middle is
// not.
//
// It is the right thing to follow an Echo with, and not only structurally.
// The Echo is the pattern that first makes the Limen worth having; this
// is the one that takes it away again on the very next beat, whichever
// answer was used. Measured: over the window it overlaps the player it
// sweeps between 20% and 79% of the column, so it comes nowhere near
// either wall and passes straight through where a suspended player is.
pattern_crossing := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.4, lane = .Real, obstacle_type = .Patroller, phase_offset = 0.25},
	},
	duration = 2.6,
	entry    = {.Real, .Dream},
	exit     = {.Real, .Dream},
	demand   = 1,
}

// The two absences, one after the other, and the pool's first use of them
// as a pair — a hole in the floor, then a hole in the ceiling.
//
// Accepts either wall and resolves to one, which is the shape the pool was
// missing most: something that can follow an ambiguous answer and hand the
// next pattern a position it can be surgical about. Whichever wall the
// player arrives on, they leave standing on the floor.
//
// The spacing is set by the widest gap at the slowest tier: a long Chasm
// holds the floor shut for 0.69s at 270 px/s, so the ceiling cannot be
// asked for until that has passed.
pattern_void_pair := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.0, lane = .Real, obstacle_type = .Chasm},
		{time_offset = 1.8, lane = .Dream, obstacle_type = .DreamHole},
	},
	duration = 2.6,
	entry    = {.Real, .Dream},
	exit     = {.Real},
	demand   = 2,
}

// --- The floor as a wall (T7.5.5) ---

// A single raised stretch: the floor lifts into a wall and stays lifted
// for as long as it is wide. Same question as a Block and the same answer
// as a Chasm — be anywhere that is not the ground — but asked by the
// world instead of by something standing on it.
//
// It is in the opening pool on purpose. The step is the one obstacle the
// player has to be *told* about by seeing it early and slowly, because it
// is the only one that is made of scenery: everything else in the game
// announces itself by not being the background.
pattern_steady_step := Pattern {
	events   = []PatternEvent{{time_offset = 1.0, lane = .Real, obstacle_type = .Step}},
	duration = 2.2,
	entry    = {.Dream},
	exit     = {.Dream},
	demand   = 0,
}

// The same wall, but arriving at a player who might be on either side of
// the column: a converger, which is the class the pool is always short of
// (see the note on ambiguous exits above). From the ceiling it asks for
// nothing; from the floor it asks for one flip, with a second and a bit
// to make it in.
//
// Its width is the run's own choice, so the longest variant holds the
// floor shut for 0.60 s at the opening speed and 0.41 s at the deepest —
// which is why the pattern does not ask for the floor back afterwards.
pattern_rising_wall := Pattern {
	events   = []PatternEvent{{time_offset = 1.2, lane = .Real, obstacle_type = .Step}},
	duration = 2.4,
	entry    = {.Real, .Dream},
	exit     = {.Dream},
	demand   = 1,
}

// The floor rises, and then the ceiling opens. Full then void, and the
// two belong to opposite worlds, so the answer is a flip up followed by a
// flip down with the widest step and the widest hole both allowed for.
//
// The spacing is set by the slowest tier: a long step holds the floor
// shut until 1.60 s and a journey takes 0.24 s, so the ceiling cannot be
// asked for before roughly 1.9 s. It is asked for at 2.4.
pattern_step_then_hole := Pattern {
	events   = []PatternEvent {
		{time_offset = 1.0, lane = .Real, obstacle_type = .Step},
		{time_offset = 2.4, lane = .Dream, obstacle_type = .DreamHole},
	},
	duration = 3.2,
	entry    = {.Real, .Dream},
	exit     = {.Real},
	demand   = 2,
}

// Pool of hand-authored patterns (Design Doc, section 7).
// Every exit set must be accepted by at least one pattern's entry set, or
// the generator can get stuck (see pattern_double_switch_reverse, and the
// dead-end check in validate_pattern_pool).
all_patterns := []Pattern {
	pattern_steady_real,
	pattern_steady_chasm,
	pattern_steady_dream,
	pattern_steady_dreamhole,
	pattern_double_switch,
	pattern_double_switch_reverse,
	pattern_feint_real,
	pattern_feint_dream,
	pattern_drift,
	pattern_crossing,
	pattern_steady_step,
}

// Picks a random pattern from the pool that accepts every band the player
// might be arriving in — this is what guarantees two chained patterns
// never pose a question the player was not set up to answer.
//
// `arriving` is the previous pattern's exit set, so it can name more than
// one band: the generator commits to the next pattern before the player
// has finished answering the current one, and cannot know which answer
// they took. Containment is what makes that safe.
//
// Draws from the caller's generator rather than the global one, so the
// same seed always yields the same sequence of patterns.
//
// `weights` biases the draw by each pattern's demand, which is how a tier
// changes the *texture* of a run rather than only its speed. Unlocking a
// hard pattern is not the same as meeting it: at the deepest tier eight
// of the thirteen patterns are still the easy ones, so without weighting
// the hardest arrive about as rarely as they did the moment they became
// possible.
pick_next_pattern :: proc(
	pool: []Pattern,
	arriving: core.Bands,
	weights: [DEMAND_LEVELS]int,
	rng: rand.Generator,
) -> Pattern {
	candidates: [dynamic]Pattern
	defer delete(candidates)

	total := 0
	for pattern in pool {
		if arriving <= pattern.entry {
			append(&candidates, pattern)
			total += weights[clamp(pattern.demand, 0, DEMAND_LEVELS - 1)]
		}
	}

	if len(candidates) == 0 {
		// Safety net: shouldn't happen with a well-designed pool
		// (validate_pattern_pool checks for exactly this), but avoids a
		// crash if it ever does.
		return pool[0]
	}

	// A tier whose weights happen to zero out everything reachable falls
	// back to an even draw rather than to no pattern at all.
	if total <= 0 {
		index := int(rand.float32(rng) * f32(len(candidates)))
		return candidates[min(index, len(candidates) - 1)]
	}

	roll := int(rand.float32(rng) * f32(total))
	if roll >= total {
		roll = total - 1
	}
	for pattern in candidates {
		roll -= weights[clamp(pattern.demand, 0, DEMAND_LEVELS - 1)]
		if roll < 0 {
			return pattern
		}
	}
	return candidates[len(candidates) - 1]
}

// How far ahead (in seconds of game time) we keep obstacles generated.
// Large enough that the player never sees the generation "catch up".
GENERATION_LOOKAHEAD :: 6.0

PatternGenerator :: struct {
	pool:            []Pattern,
	generated_until: f32, // world time up to which obstacles already exist

	// Every band the player might be in when the next pattern starts:
	// the exit set of the one just generated.
	arriving:        core.Bands,

	// The current tier's two shaping knobs, kept here rather than looked
	// up, so that generation depends on nothing outside the generator.
	// set_generator_tier (difficulty.odin) is what moves them.
	gap:             f32, // seconds of empty air after each pattern
	weights:         [DEMAND_LEVELS]int, // draw bias by pattern demand

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
	start_bands: core.Bands,
	seed: u64,
) -> PatternGenerator {
	return PatternGenerator {
		pool = pool,
		generated_until = start_time,
		arriving = start_bands,
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
// GENERATION_LOOKAHEAD seconds ahead of current_time. Call this every frame.
generate_ahead :: proc(
	generator: ^PatternGenerator,
	obstacles: ^[dynamic]Obstacle,
	current_time: f32,
) {
	rng := generator_rng(generator)

	for generator.generated_until < current_time + GENERATION_LOOKAHEAD {
		pattern := pick_next_pattern(
			generator.pool,
			generator.arriving,
			generator.weights,
			rng,
		)

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

		// The gap is empty air, and it is contract-neutral: a player with
		// nothing to dodge stays where the last pattern left them unless
		// they choose to move, so it can only ever add safety. That is
		// what makes it the one difficulty knob that is honestly
		// monotonic — shortening it always asks for more.
		generator.generated_until += pattern.duration + generator.gap
		generator.arriving = pattern.exit
	}
}

// Checks a pool for the authoring mistakes that produce no error and no
// crash, only a game that is quietly wrong.
//
// The oldest one is an obstacle in the lane it does not belong to. The
// one that costs a run is a pool that cannot be chained: pick_next_pattern
// falls back to pool[0] when nothing accepts the arriving set, which
// silently hands the player a pattern they were never set up for. With a
// set-valued contract that check has to be per *exit set*, not per lane —
// a pool where every band is reachable individually can still have an
// exit set that no single pattern accepts in full, and lane-by-lane
// checking would call it healthy.
validate_pattern_pool :: proc(pool: []Pattern) {
	for pattern, pattern_index in pool {
		if pattern.exit == {} {
			fmt.printf("WARNING: pattern %d has an empty exit set\n", pattern_index)
		}

		// Exits name walls. The Limen is not a place a pattern can hand
		// the player to, because it is not a place the pattern controls:
		// holding is always available and always the player's own call.
		if pattern.exit - core.WALLS != {} {
			fmt.printf(
				"WARNING: pattern %d exits into %v, but an exit set can only name walls\n",
				pattern_index,
				pattern.exit,
			)
		}

		// Same reason from the other side: Lucidity starts a run at zero,
		// so a pattern reachable only by a player who can afford to
		// suspend is a pattern that is sometimes unsolvable.
		if pattern.entry & core.WALLS == {} {
			fmt.printf(
				"WARNING: pattern %d can only be entered from the Limen, which costs Lucidity the player may not have\n",
				pattern_index,
			)
		}

		// The dead end: is there anything at all that can follow this?
		followable := false
		for candidate in pool {
			if pattern.exit <= candidate.entry {
				followable = true
				break
			}
		}
		if !followable {
			fmt.printf(
				"WARNING: nothing in this pool can follow pattern %d, whose exit set is %v\n",
				pattern_index,
				pattern.exit,
			)
		}

		// The other half of the same question, and the one that costs
		// nothing visible when it fails: a pattern nobody can reach is
		// authored content the player will never be shown.
		reachable := false
		for candidate in pool {
			if candidate.exit <= pattern.entry {
				reachable = true
				break
			}
		}
		if !reachable {
			fmt.printf(
				"WARNING: nothing in this pool can lead to pattern %d, whose entry set is %v — it will never be drawn\n",
				pattern_index,
				pattern.entry,
			)
		}

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
