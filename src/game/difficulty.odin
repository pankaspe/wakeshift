/*
* Difficulty
* One continuous function of **distance**, and that is the whole file
* (Design Doc, section 18).
*
* WHY DISTANCE AND NOT TIME
*
* It used to be three tiers on a clock: at 25 seconds the world got
* faster, at 55 it got faster again, and each step unlocked a handful of
* patterns. C3 replaced all of it with `get_difficulty(scroll_offset)`.
*
* Distance is what makes buying speed honest. From roadmap R6 the player
* buys Slancio, and depth is the distance travelled (score.odin) — so a
* faster run earns score and meets difficulty at exactly the same rate,
* automatically and with no line of code that knows it does. On a clock
* the two would come apart: going faster would buy score for free, and
* going slower would be a way to farm an easy world. It also puts the
* curve on the same measure the Corruption already used, which was the
* only part of the game that had it right (corruption.odin).
*
* WHY SPEED IS NOT A KNOB HERE ANY MORE
*
* Because it never worked as one, and that was measured long before C3.
* Obstacles are events in time, so reaction time *inside* a pattern does
* not move with speed at all: replaying every pattern at 270, 330 and 400
* px/s gives the same set of surviving answers. What speed does change is
* two things that pull against each other — you can see 920 px ahead,
* which is 3.4 s of warning at 270 and 2.5 at 370, harder; and a wide
* obstacle passes in width/speed seconds, which is easier. A run scrolls
* at INITIAL_SCROLL_SPEED now and only the player moves it.
*
* THE TWO KNOBS
*
*   gap    seconds of empty air after each pattern. The density knob, and
*          since C2 the *only* one — a pattern holds its own windows and
*          carries no lead-in, so all the air in the game is here.
*   bias   how hard the draw leans on patterns that ask more. A pattern
*          of demand d is drawn with weight bias^d, so one number covers
*          the whole range: under 1 it prefers the quiet ones, at 1 the
*          draw is even, and at 4 a burst is sixty-four times likelier
*          than a bump.
*
* They are deliberately on **different curves**, because a single curve
* saturates and a saturated curve is what a player calls "it stops
* getting harder". The air is spent early (quadratic out) so the opening
* minute changes fast; the bias bites late (quadratic in) so there is
* still something moving when the air has run out. On top of both, every
* pattern declares the distance it becomes available at (Pattern.min_depth),
* spread across the whole curve, so a long run keeps meeting things it
* has not met before.
*/
package game

import "core:math"
import "core:math/ease"

// Pixels of world scrolled at which the curve tops out.
//
// C3 set this at 50000 and gave the reason: a curve that finishes while
// the player is still alive is what "it stops getting harder" means. The
// F playtest found the opposite failure and it is worse — measured, **ten
// of thirty patterns were never drawn in a whole run**, including every
// floating platform and every demand-3 shape. The curve was calibrated
// for a run length that the economy had since taken away, so the hardest
// two thirds of the pool were dead content and the game had nothing left
// to ask of an attentive player.
//
// 20000 px is about where a good run now ends, so the world reaches full
// density and full lean *inside* a run instead of past it. What C3 was
// protecting against is handled elsewhere now: the Corruption's appetite
// has its own, much longer distance (CORRUPTION_FULL_DISTANCE), so the
// thing that keeps growing after the world has finished growing is the
// price of standing still.
DIFFICULTY_FULL_DISTANCE :: 20000

// The air between patterns, at the opening and at the top.
//
// The top was zero until the F playtest, on C2's reasoning: a pattern
// holds its own windows, so no gap is too small to be *fair*
// (pattern.odin). That is still true and it is not the whole story —
// since F3 the air is also what a **fragment** is taken in. A diamond
// sits just after its pattern's last Dream closure and is paid for with
// a round trip to the ceiling, and at zero gap the next pattern starts
// before that trip can happen. Measured, the collecting bot went from
// 7.2 fragments a run to 8.1 by opening the top of this from 0 to 0.25.
//
// So this is now a floor as well as a knob: however dense the world
// gets, it never closes past the point where its own reward can be
// reached. "I can't collect the diamonds any more" was the first thing
// the playtest said.
DIFFICULTY_GAP_OPEN :: 0.90
DIFFICULTY_GAP_TOP :: 0.25

// How the draw leans, as the base of bias^demand.
//
// Under one at the opening, so a run starts on the quiet half of the pool
// without anything having to be locked: at 0.45 a burst is drawn a
// tenth as often as a bump. Four at the top, where it is sixty-four times
// as often.
DIFFICULTY_BIAS_OPEN :: 0.45
DIFFICULTY_BIAS_TOP :: 4.0

// Everything a run's current difficulty is, as one value.
//
// A plain struct computed from one number, so the generator can be handed
// its knobs without knowing what a curve is, and a test can make one up.
Difficulty :: struct {
	t:     f32, // 0..1, how far along the curve this run is
	depth: f32, // pixels of world scrolled, for the unlock thresholds
	gap:   f32,
	bias:  f32,
}

// The curve. A pure function of distance, which is what lets a replay
// reach the same difficulty at the same point without storing anything.
get_difficulty :: proc(scroll_offset: f32) -> Difficulty {
	t := clamp(scroll_offset / DIFFICULTY_FULL_DISTANCE, 0, 1)

	// Curves from core:math/ease rather than hand-rolled ones (CLAUDE.md).
	// Both are pure and contextless, so they are safe inside a step.
	air := ease.quadratic_out(t)
	lean := ease.quadratic_in(t)

	return Difficulty {
		t = t,
		depth = scroll_offset,
		gap = DIFFICULTY_GAP_OPEN + (DIFFICULTY_GAP_TOP - DIFFICULTY_GAP_OPEN) * air,
		bias = DIFFICULTY_BIAS_OPEN + (DIFFICULTY_BIAS_TOP - DIFFICULTY_BIAS_OPEN) * lean,
	}
}

// How likely one pattern is to be drawn, relative to the others.
//
// bias^demand, so a single number says how hard the game is leaning. It
// is the exponent that makes it a *lean* rather than a threshold: no
// pattern is ever excluded, the easy ones simply become rare, which is
// what keeps a late run varied instead of collapsing onto the four
// hardest things in the pool.
pattern_weight :: proc(pattern: Pattern, bias: f32) -> f32 {
	return math.pow(bias, f32(clamp(pattern.demand, 0, DEMAND_LEVELS - 1)))
}

// Points the generator at everything the curve changes, in one call, so
// that the main loop never has to know difficulty has more than one knob.
set_generator_difficulty :: proc(generator: ^PatternGenerator, difficulty: Difficulty) {
	generator.gap = difficulty.gap
	generator.bias = difficulty.bias
	generator.depth = difficulty.depth
}
