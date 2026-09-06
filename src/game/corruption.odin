/*
* Corruption
* The dream going out behind the player, as a position on the screen
* (Design Doc, section 5).
*
* It is not a resource, not a meter and not a number in a corner. It is a
* **front**: everything to the left of it has lost its colour, it advances
* as a run goes deeper, and it ends the run when it touches the character.
* The distance between the two is therefore the entire health bar, drawn
* at full size in the picture the player is already looking at.
*
* WHY AN ADVANCING FRONT IS A MECHANIC HERE AND WAS NOT BEFORE
*
* The v1.x design considered exactly this and rejected it, correctly: in
* a game with one key and no control over speed, a chaser is not a
* mechanic, it is a countdown in a costume. There is nothing to interact
* with, because you cannot run faster.
*
* What changed is not the chaser, it is the cube. Since a cube blocks
* rather than kills (collision.odin), the *player's own mistakes* are what
* move them toward the front, and running clean is what carries them away
* from it. The chaser became a mechanic the moment the player was given a
* way to feed it.
*
* It also keeps pillar 3 better than any earlier version of the
* Corruption did. A number draining in the corner of the screen is a blow
* nobody sees coming; a thing crossing the screen toward you is visible
* for its entire approach.
*
* WHY IT MOVES WITH DISTANCE AND NOT WITH TIME
*
* This is the difficulty curve — the whole of it, since scroll speed is a
* purchase rather than a ramp (Design Doc, section 8). Measuring it in
* distance rather than in seconds is what makes buying Slancio (roadmap
* R6.3) buy difficulty along with the score, automatically and without a
* line of code that knows it does.
*
* The rest of the game caught up in C3: the difficulty curve is a function
* of scroll_offset now, on exactly the clock this has always used
* (difficulty.odin).
*
* --- F2: THE ECONOMY ---
*
* The front used to be a pure function of scroll_offset that slid to a
* fixed stop 150 px short of the character and waited there. Two of those
* three things are gone, and both were given up knowingly.
*
* **It accumulates now.** front_x is state advanced every step, because a
* refund cannot be expressed as a function of distance alone. It is still
* perfectly deterministic — the gain is a function of the curve and the
* refunds come from collisions a replay reproduces — so a recorded run
* still validates. What is lost is the ability to *ask* where the front
* is at a given depth without replaying to it, and nothing in the game
* ever asked.
*
* **It no longer stops.** "A player making no mistakes is never in danger
* from the Corruption" was true and is now false on purpose: it is what
* made the front decoration for anyone competent, and it is the whole
* reason F1's fragments had nothing to buy. The front comes all the way,
* and what holds it off is picking things up.
*
* WHAT THE PLAYER IS ACTUALLY TRADING
*
*   it gains   CORRUPTION_GAIN px of front per px of world scrolled, on
*              the difficulty curve. Always, from the first metre.
*   you pay    CORRUPTION_REFUND px back per fragment, handed over as a
*              retreat rather than a jump.
*
* So a fragment is worth "the ground the front takes in N pixels of
* world", and N shrinks as the run deepens: 2000 px of world at the
* opening — about seven seconds — and 330 px at the top of the curve.
* The reward does not get smaller; the world it is spent in gets more
* expensive, which is the same statement the difficulty curve makes about
* everything else.
*
* THE BANK IS THE SCREEN, AND SURPLUS IS THROWN AWAY
*
* front_x is clamped at CORRUPTION_START_X and any refund still owed at
* that moment is discarded. A player collecting more than they are
* spending does not bank room for later, they are simply safe now.
*
* That is not a limitation, it is the design's oldest promise kept: the
* runway *is* the health bar, drawn at full size, and a hidden surplus
* behind the left edge would be a meter nobody can see — the exact thing
* score.odin and the HUD both refuse. Verified: ten fragments handed to a
* full runway leave the front at 8 px and nothing owed.
*
* WHAT IT IS TUNED TO, MEASURED BY REPLAY
*
* 60 runs of the real simulation, driven by a bot that dodges one move
* ahead — median distance at which the run ended, and where the front sat
* while it lasted. Re-measured against F3's pool, which is the supply
* that actually exists:
*
*   collects nothing at all        8440 px  (31 s)   front mean 160, peak 355
*   dodges only, takes what it
*     happens to run into          8440 px  (31 s)   front mean 155, peak 353
*   collects, fragments unpaid     8440 px  (31 s)   front mean 160, peak 355
*   collects, fragments paid      16150 px  (60 s)   front mean  84, peak 244
*   the pre-F2 front, same bot    13850 px  (51 s)   front mean  83, peak 176
*
* The economy is worth **+91% of a run** to a player who works the
* ceiling, and the front's *average* pressure on that player lands within
* a pixel of where the old fixed slide held it — 84 against 83. That was
* the calibration F2 chose the gain on, and F3 changing the whole supply
* did not move it, so the constants below stayed where they were. What
* moves instead is the peak, 176 px to 244: the front is allowed to get
* close now, and getting it back is the play.
*
* The second row is F3's doing and it is the number that matters most
* here. Before F3 a bot that did not want fragments collected 16.6 of
* them a run anyway, because the prototypes put a cube opposite every
* diamond and the dodge already went there; it now collects **0.7**
* against a collector's 12.8. The reward stopped being free, which is
* what makes the front's appetite a question the player answers rather
* than a tax they pay.
*
* Three of the 60 collecting runs end in a hole, where none of the
* dodging ones do. That is the reward pulling a greedy answer into a bad
* one, which is the whole of F6 in miniature and arrived here for free.
*/
package game

import "../core"

// Where the front starts: the left edge of the screen. A run opens with
// the whole runway between PLAYER_HOME_X and here, and that is also the
// most room there ever is (see "the bank is the screen" above).
CORRUPTION_START_X :: 0

// Pixels of front gained per pixel of world scrolled, at the opening of
// the curve and at the top of it.
//
// Per pixel scrolled rather than per second, for the reason the whole
// file is written around: it keeps the front on the same measure as the
// difficulty curve and the score, so buying speed later buys pressure
// with it and no line of code has to know.
//
// The pair is a **straight line** in difficulty.t, deliberately unlike
// the two knobs in difficulty.odin: the air between patterns is spent
// early and the draw's lean bites late, so a third knob moving at a
// constant rate means there is always exactly one of the three actively
// changing under the player. C3's lesson was that one curve saturates;
// three curves that saturate together are the same mistake spread out.
//
// 0.030 costs a run that collects nothing its whole runway in 8440 px,
// about 31 seconds. 0.180 is six times that, and a good run reaches
// about t = 0.32 of the way to it — the top of the curve is where this
// is aimed, not where it is played (see the header).
//
// Held at these values through F3, which replaced the entire supply they
// were tuned against: the collecting bot's *average* pressure came out
// at 84 px where F2 measured 84, so the calibration survived the pool
// changing under it. Re-measure again whenever the supply moves; the
// anchor to check is the mean front, not the run length.
CORRUPTION_GAIN_OPEN :: 0.030
CORRUPTION_GAIN_TOP :: 0.180

// What one fragment buys back, in pixels of front.
//
// A sixth of the runway, and about one and a half bodies wide, which is
// the smallest retreat that still reads as the front *moving* rather
// than as the front flickering. Measured against the front's own gain,
// one fragment nets 54 px of the 60 back at the opening: the world does
// not stop being expensive while it is being paid for.
CORRUPTION_REFUND :: 60

// How fast the front hands that back, in pixels per second.
//
// It retreats rather than teleporting: 60 px in a single frame is a jump
// the eye reads as a glitch, and 0.23 s of motion is read as an event.
// It also makes a *line* of fragments into one continuous retreat, which
// is what the run-of-five pattern is for — the reward for staying is a
// front sliding away for a second, not five separate twitches.
//
// In seconds rather than in scrolled pixels, and it is the one thing
// here that is: everything else in this file describes how expensive the
// world is, which is a property of depth, while this describes how
// quickly a payment is drawn, which is a property of the eye.
CORRUPTION_REFUND_SPEED :: 260

Corruption :: struct {
	// Screen x of the boundary. Everything to the left of it has lost its
	// colour; a character whose trailing edge reaches it is out of room.
	front_x: f32,

	// Pixels of front still to be handed back from fragments already
	// collected. Paid down at CORRUPTION_REFUND_SPEED, and abandoned the
	// moment the front reaches the left edge.
	owed:    f32,
}

new_corruption :: proc() -> Corruption {
	return Corruption{front_x = CORRUPTION_START_X}
}

// How much ground the front takes per pixel of world, right now.
get_corruption_gain :: proc(difficulty: Difficulty) -> f32 {
	return CORRUPTION_GAIN_OPEN + (CORRUPTION_GAIN_TOP - CORRUPTION_GAIN_OPEN) * difficulty.t
}

// One step of the economy: the front takes its cut of the ground the
// world just covered, then pays back whatever it still owes.
//
// Gain first and refund second so that a fragment collected while the
// front is already at the left edge is discarded by the clamp at the
// bottom rather than by an ordering accident — the discarding is the
// rule, and it should be one line that says so.
update_corruption :: proc(
	corruption: ^Corruption,
	world: World,
	difficulty: Difficulty,
	delta_time: f32,
) {
	// The distance the world actually covered this step, so the front's
	// appetite follows the pace the player is setting (world.odin) with
	// nothing here having to know that it does.
	corruption.front_x += get_corruption_gain(difficulty) * get_scroll_rate(world) * delta_time

	if corruption.owed > 0 {
		paid := min(corruption.owed, f32(CORRUPTION_REFUND_SPEED) * delta_time)
		corruption.front_x -= paid
		corruption.owed -= paid
	}

	// The bank is the screen: room that would go behind the left edge is
	// not stored, and neither is a refund that was still owed when the
	// front got there.
	if corruption.front_x <= CORRUPTION_START_X {
		corruption.front_x = CORRUPTION_START_X
		corruption.owed = 0
	}
}

// Buys ground back. The caller says how many fragments were taken; what
// one is worth lives here, with the front it is spent against.
//
// It is owed rather than given, so a fragment taken on the step the
// front reaches the character does not rescue them — a payment that
// undoes a death after the fact would make the last instant of a run
// unreadable, and the retreat is visible from the very next step anyway.
repay_corruption :: proc(corruption: ^Corruption, fragments: int) {
	corruption.owed += f32(fragments) * CORRUPTION_REFUND
}

// True once the front has caught up: the run is over.
corruption_has_reached :: proc(corruption: Corruption, player: Player) -> bool {
	return player.position.x <= corruption.front_x
}

// 0..1, how much of the runway is gone. Presentation reads it; the
// simulation does not, because the thing that matters is the distance
// itself and this is only a way of describing it.
get_corruption_pressure :: proc(corruption: Corruption, player: Player) -> f32 {
	full := f32(core.PLAYER_HOME_X - CORRUPTION_START_X)
	return clamp(1 - get_player_runway(player, corruption.front_x) / full, 0, 1)
}
