/*
* Dream
* One bar with two opposite verbs, and the phase it buys (Design Doc §7).
*
*   In the Real it **fills**: every fragment adds a share, and at full the
*   world turns.
*   In the Dream it **drains**, at a constant rate, and at empty the world
*   turns back. Lucids picked up there push it back up.
*
* So there is no second timer. The bar is the charge and the countdown,
* which is why a Lucid needs no rule of its own — it is the same number
* going the other way — and why the player reads one thing rather than
* two.
*
* WHAT CHANGES UP THERE, AND WHY ONLY TWO THINGS
*
*   **A slide pierces one wall.** The move does not stop at the first
*   wall, it goes through it and runs on to the next. It is literally the
*   dream, and it is still a puzzle: the player has to choose *which* wall
*   and read two cells further than they were reading.
*
*   **The Corruption retreats.** This is the half that closes the loop.
*   Fragments do not touch the front any more — the *state of the world*
*   moves it, and fragments are the only way to change state. Without this
*   the whole of L3 would be a collectathon with no payout and the run
*   would stay a countdown however the numbers were set.
*
* Rejected, and why: **bounce** takes the move out of the player's hands
* and breaks pillar 1; **diagonals** are a second control scheme to learn
* under pressure, in a phase that lasts a few seconds.
*
* PILLAR 6 IS PAID BY THE MECHANIC, NOT BY THE PALETTE
*
* Three channels say which world is running, and only one of them is
* colour: the body goes through walls, the maze visibly swaps what it is
* offering (fragments vanish, Lucids appear), and pierced walls stay open
* behind the body like a wake. With the colour turned off entirely the
* state is still legible from what the body does.
*
* THE NUMBERS, AND WHAT THEY WERE DRAWN AGAINST
*
* A cell is 60 px and a slide covers 900 px/s, so **15 cells is one
* second**. A chunk's cheapest crossing measures 1.50 cells per column
* (game/maze.odin), so 32 columns is ~48 cells, 3.2 s. Three fragments a
* chunk at 3-18 cells of detour is roughly 10 cells of detour each.
*
* Filling the bar is therefore about two chunks of ground — 6.4 s — plus
* ~4 s spent on the detours themselves, and it buys 6 s of Dream. Against
* the front:
*
*   at the opening (190 px/s) the detours cost ~760 px of ground and the
*     retreat gives 1800 back: the loop is worth entering, comfortably.
*   at the top of the curve (500 px/s) the same detours cost ~2000 and the
*     retreat still gives 1800: it stops paying for itself, which is the
*     sawtooth tipping over and the front winning in the end.
*
* **Every number here is a first draft and is meant to be played, not
* read.** Design Doc §17 lists all four of them as open questions. What is
* not a draft is that they were drawn against an income that exists — the
* mistake this file is here to avoid repeating is the one the archive
* records, where the Corruption was calibrated against a fragment economy
* that had already been deleted.
*
* AND WHAT THE REPLAY SAYS ABOUT THEM, WHICH IS NOT WHAT THE ARITHMETIC
* ABOVE SAYS
*
* 48 runs of the real simulation, driven by a bot that plans on the whole
* world and refuses to enter a cell it cannot cross from, 120 s each:
*
*   ignoring every fragment   depth 4488, 9.7 cells/s, died in 10 of 24
*   collecting them           depth 3058, 7.7 cells/s, died in 20 of 24
*                             9.6 fragments, 2.7 Lucids, 13.1 s of Dream
*
* **Collecting is a loss at the opening, and the reason is not the price
* of a fragment.** It is CORRUPTION_MAX_LEAD. At the opening the front
* takes 190 px/s against a good line's 582, so a player who never detours
* is pinned against the cap almost the whole time — and a retreat that
* runs into the same cap is a reward being thrown away. The Dream can only
* pay for ground that was actually lost.
*
* So the loop the design describes — the Dream as the only source of
* ground (§3) — is built and it runs, and it is **not yet true**, because
* at L1 the Real is comfortably net positive. Making it true means the
* front redraw §6 asks for, and that redraw changes how L1 plays, which a
* playtest has already passed judgement on. It is the author's call and it
* belongs with the level curve (L8), not here.
*
* The arithmetic for whoever makes it: with a good line at v and a Dream
* duty cycle d, collecting pays when v - F + d*(F + R) > 0 and ignoring
* dies when v > F. At the measured d of 0.12 that wants a retreat near
* 700 px/s, which is more than a full bar's worth of lead; at d = 0.30 the
* 300 here is already enough. **The duty cycle is the lever, not the
* retreat** — which means FRAGMENTS_TO_FILL and DREAM_DURATION, not
* CORRUPTION_DREAM_RETREAT.
*/
package game

// How many fragments fill the bar from empty.
//
// Six, against three per chunk: two chunks of collecting, which is long
// enough that entering the Dream is an achievement and short enough that
// a first run gets there.
FRAGMENTS_TO_FILL :: 6

DREAM_CHARGE_PER_FRAGMENT :: f32(1) / f32(FRAGMENTS_TO_FILL)

// How long a full bar lasts up there, in seconds.
//
// Long enough to be a phase with decisions in it rather than a flourish:
// at 900 px/s it is around 5400 px of travel, three and a half chunks,
// so there is time to spot a Lucid, decide which wall to go through, and
// get there.
DREAM_DURATION :: 6.0

// What a Lucid puts back, as a share of the bar — a little under two
// seconds. Deliberately less than a fragment is worth in the Real: up
// there the player is already being paid in ground, so a Lucid extends
// the reward rather than doubling it.
LUCID_EXTENSION :: 0.30

// How long the world takes to cross between Real and Dream, in seconds.
//
// The *mechanics* switch on the instant the bar fills — a pierce that
// half worked would be unreadable — and this is only how long the
// picture takes to agree. It is a crossing rather than a chase, so it
// arrives at exactly this time instead of asymptotically: a 6 s phase
// cannot afford a colour that is still catching up a second in.
DREAM_CROSSING_TIME :: 0.35

DreamPhase :: enum u8 {
	Real,
	Dream,
}

Dream :: struct {
	phase:     DreamPhase,

	// 0..1. Charge in the Real, time remaining in the Dream.
	charge:    f32,

	// 0 in the Real, 1 in the Dream, sweeping between them across
	// DREAM_CROSSING_TIME. It is what core.PaletteSet's world_t is fed
	// from, and the only reason it is simulation state rather than
	// presentation is that the Corruption's velocity reads it: the front
	// decelerates, stops and reverses across the crossing instead of
	// flipping sign in one step, and a run's outcome may not depend on a
	// value the frame clock owns.
	world_t:   f32,

	// The run's tally, for the report at the end. Nothing reads these:
	// what a fragment is *worth* is said by the front sliding backwards,
	// which the player is already looking at.
	fragments: int,
	lucids:    int,
}

new_dream :: proc() -> Dream {
	return Dream{}
}

// True while the Dream's rules are the ones in force.
dream_is_active :: proc(dream: Dream) -> bool {
	return dream.phase == .Dream
}

add_charge :: proc(dream: ^Dream, amount: f32) {
	dream.charge = min(dream.charge + amount, 1)
}

// One simulation step of the bar and the crossing.
//
// The phase is decided before the crossing is advanced, so a fragment
// that fills the bar starts the world turning on the same step it was
// taken rather than on the next one.
update_dream :: proc(dream: ^Dream, delta_time: f32) {
	switch dream.phase {
	case .Real:
		if dream.charge >= 1 {
			dream.charge = 1
			dream.phase = .Dream
		}
	case .Dream:
		dream.charge -= delta_time / DREAM_DURATION
		if dream.charge <= 0 {
			dream.charge = 0
			dream.phase = .Real
		}
	}

	target: f32 = dream.phase == .Dream ? 1 : 0
	step := delta_time / DREAM_CROSSING_TIME
	dream.world_t += clamp(target - dream.world_t, -step, step)
}
