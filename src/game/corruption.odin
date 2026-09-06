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
* ahead and works its way out of a pin, after the F playtest recalibrated
* everything:
*
*   collects nothing at all         880 px  ( 3 s)
*   dodges only, takes what it
*     happens to run into           9330 px  (35 s)   front mean 168
*   collects                       12920 px  (48 s)   front mean  60
*
* **The front is no longer what ends a good run, and that is the point of
* the recalibration.** For the collecting bot it sits at 60 px of a 360
* px runway and the run ends in a cube instead: measured, the lowest x a
* run ever reaches *is* the x it dies at, so the fatal event is one pin
* it cannot get out of rather than a front that caught up. Difficulty
* went back to the bricks, which is where the playtest asked for it.
*
* Two consequences worth knowing before touching anything here:
*
*   * the gain constants are nearly inert for a competent collector.
*     Sweeping the pair over 0.030..0.100 and 0.040..0.140 moved the
*     bot's median by 23 px in 10700. They still matter for everyone who
*     collects *badly*, which is the whole point of them.
*   * so is PLAYER_RECOVERY_RATIO, for the same reason and it is
*     recorded there.
*
* THE BOT UNDERSTATES SOME THINGS AND ONE OF THEM IS ITS OWN
*
* It reacts in one step and never looks ahead, so warning distance is
* worth almost nothing to it. And it had to be *taught* to flip out of a
* pin: until the F playtest it sat in a facing pair until it died, which
* silently invalidated every run-length number measured in a pool where
* mirrored pairs were common. Check the death mode before trusting a
* median.
*/
package game

import "../core"

// Where the front starts: the left edge of the screen. A run opens with
// the whole runway between PLAYER_HOME_X and here, and that is also the
// most room there ever is (see "the bank is the screen" above).
//
// It may not go negative to buy a longer runway, however tempting that
// looks: the player travels through the runway, so a front off the left
// edge is a health bar the player walks off the screen to reach.
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
// THESE WERE NOT UNTUNED, THEY WERE TUNED FOR A GAME THAT NO LONGER EXISTS
//
// 0.040 and 0.140 were drawn against what a player could *collect*: a
// supply of 0.9 to 1.3 fragments per 1000 px, each buying CORRUPTION_REFUND
// pixels back, arranged so a good collector broke even around 30000 px and
// the front still always won in the end. In the maze that income is
// exactly **zero** — nothing hands ground back yet — so the appetite has
// to be the appetite of a run with no economy at all. Half a curve
// calibrated against the other half of a mechanism that was deleted is
// worse than an arbitrary number, because it looks justified.
//
// THE FRONT WAS NEVER THE FAST THING
//
// Measured at the old numbers, at the opening speed: the front took
// **10.8 px/s** while the camera took **270 px/s** for every second the
// player was not sliding right — and in a maze that is every vertical
// move, every wrong branch and every moment spent reading. Around 96% of
// the ground a player loses is the camera. The first maze playtest
// reported the Corruption as far too fast, and it was reading the sum of
// the two and blaming the half with a name.
//
// So the fix is three numbers and only one of them is in this file: the
// runway grew (core/screen.odin), the world slowed (game/world.odin), and
// the appetite came down to what a run with no income can pay. At 220 px/s
// the front now takes 3.1 px/s, which is 141 seconds to cross the opening
// runway on its own — the front is the clock the player can see, and it is
// not supposed to be the thing that kills them while they are still
// playing well.
//
// **When fragments land (L3/L4) these have to be redrawn against the new
// income, not nudged.** That is the same mistake as above, one phase later.
CORRUPTION_GAIN_OPEN :: 0.014
CORRUPTION_GAIN_TOP :: 0.050

// The distance the gain takes to travel between those two, and it is
// **not** DIFFICULTY_FULL_DISTANCE any more.
//
// They shared one number until the F playtest, and sharing it was a
// mistake that only showed up when the pool had to be made visible. The
// world's density has to reach full early — a run that ends before it
// has met the ridge, the ravine and the gauntlet has never played the
// game — while the front's appetite has to grow across the *whole* of a
// long run, or the same compression that reveals the pool starves the
// player before they reach it. Measured: with one shared curve, pulling
// it in far enough to show the deep patterns cut the median run from
// 17000 px to 10160 and the deep patterns still never appeared.
//
// So the two are separate axes now: this one is long and the density one
// is short. They were only ever the same because it was tidy.
CORRUPTION_FULL_DISTANCE :: 50000

// What one fragment buys back, in pixels of front.
//
// Between a quarter and a third of the runway, and about two and a half
// bodies wide. It was 60 until the F playtest, and it went up rather
// than the gain coming down because a bigger payment is the half of the
// trade the player can *see*: the front visibly slides back when a
// diamond is taken, and that is what makes collecting read as the thing
// keeping you alive.
//
// Diminishing returns are real and they are the clamp's doing: the
// bigger the payment, the more of it lands on a front already at the
// left edge and is thrown away. Going from 60 to 100 bought the bot 900
// px of run, not 1600.
CORRUPTION_REFUND :: 100

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
//
// A straight line in distance on its own scale.
get_corruption_gain :: proc(depth: f32) -> f32 {
	t := clamp(depth / CORRUPTION_FULL_DISTANCE, 0, 1)
	return CORRUPTION_GAIN_OPEN + (CORRUPTION_GAIN_TOP - CORRUPTION_GAIN_OPEN) * t
}

// One step of the economy: the front takes its cut of the ground the
// world just covered, then pays back whatever it still owes.
//
// Gain first and refund second so that a fragment collected while the
// front is already at the left edge is discarded by the clamp at the
// bottom rather than by an ordering accident — the discarding is the
// rule, and it should be one line that says so.
update_corruption :: proc(corruption: ^Corruption, world: World, delta_time: f32) {
	corruption.front_x += get_corruption_gain(world.scroll_offset) * world.scroll_speed * delta_time

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
corruption_has_reached :: proc(corruption: Corruption, player: Player, world: World) -> bool {
	return get_player_screen_x(player, world) - PLAYER_SIZE * 0.5 <= corruption.front_x
}

// 0..1, how much of the runway is gone. Presentation reads it; the
// simulation does not, because the thing that matters is the distance
// itself and this is only a way of describing it.
get_corruption_pressure :: proc(corruption: Corruption, player: Player, world: World) -> f32 {
	full := f32(core.PLAYER_HOME_X - CORRUPTION_START_X)
	return clamp(1 - get_player_runway(player, world, corruption.front_x) / full, 0, 1)
}
