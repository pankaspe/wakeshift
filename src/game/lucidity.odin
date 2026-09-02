/*
* Lucidity
* The run's one resource, with two faces (Design Doc, section 8).
*
* It is *earned* by near-misses — settling into the right lane late,
* close to the wire, rather than safely in advance — and it is *spent*
* staying suspended in the Limen. At the same time it is the score
* multiplier. That is the whole tension the third state exists to create:
*
*     do I bank the multiplier, or burn it to stand where the score is
*     highest?
*
* It used to be a ratchet: a streak counter that only ever went up and
* was cleared by death. That version could not pose the question, because
* nothing was ever spent. One number, two uses, is also the answer to
* "how many resources should the game have" from section 8 — one.
*
* The numbers here are deliberately harsh. Until roadmap T6.6 there is no
* obstacle that threatens the middle, so the Limen is *safe*, and the
* only thing stopping "hold forever" from being the dominant strategy is
* the price of the fuel. Re-tune once the centre has its own dangers.
*/
package game

LUCIDITY_MAX :: 100

// What a single near-miss is worth. Roughly seven of them fill the tank.
LUCIDITY_PER_NEAR_MISS :: 14

// Cost of suspension, per second. A full tank buys about 3.3 seconds of
// the Limen, which at its score rate is worth ~130 depth — a little over
// what the same time on the ceiling pays, before the multiplier that is
// being burned to get it is taken into account.
LUCIDITY_DRAIN_RATE :: 30

// The Limen will not open below this. Without a floor the third state
// would flicker in and out on an empty tank, which reads as a bug rather
// than as a cost, and the player would never learn what it costs.
LUCIDITY_SUSPEND_MINIMUM :: 18

// How long the HUD celebrates a payout, in seconds. It exists because
// playtest could not tell whether Lucidity was working at all: a bar that
// creeps up in silence says nothing, and a resource nobody can see being
// earned is a resource nobody spends deliberately.
LUCIDITY_FLASH_DURATION :: 0.45

Lucidity :: struct {
	value:      f32, // 0 .. LUCIDITY_MAX

	// Highest value reached this run. Nothing reads it yet; the Dream
	// Report does (roadmap T13.2), and it is one line to keep honest now
	// versus impossible to recover later.
	peak:       f32,

	// Seconds left of the "just paid out" flash. Presentation only, but
	// it lives in simulation state so that it is part of what a replay
	// reproduces rather than something the HUD invents on its own.
	gain_flash: f32,
}

new_lucidity :: proc() -> Lucidity {
	return Lucidity{}
}

reset_lucidity :: proc(lucidity: ^Lucidity) {
	lucidity^ = new_lucidity()
}

gain_lucidity :: proc(lucidity: ^Lucidity, amount: f32) {
	lucidity.value = min(lucidity.value + amount, LUCIDITY_MAX)
	lucidity.peak = max(lucidity.peak, lucidity.value)
	lucidity.gain_flash = LUCIDITY_FLASH_DURATION
}

// Runs down the payout flash. Separate from spending and earning because
// it is the only part of Lucidity that moves on its own.
update_lucidity :: proc(lucidity: ^Lucidity, delta_time: f32) {
	lucidity.gain_flash = max(lucidity.gain_flash - delta_time, 0)
}

// 0..1, how recently a payout landed — for the HUD to pulse on.
get_lucidity_flash :: proc(lucidity: Lucidity) -> f32 {
	return lucidity.gain_flash / LUCIDITY_FLASH_DURATION
}

spend_lucidity :: proc(lucidity: ^Lucidity, amount: f32) {
	lucidity.value = max(lucidity.value - amount, 0)
}

// Whether there is enough in the tank to enter the Limen at all. Asked
// once per flip, at the moment the journey reaches its midpoint.
can_suspend :: proc(lucidity: Lucidity) -> bool {
	return lucidity.value >= LUCIDITY_SUSPEND_MINIMUM
}

// 0..1, for the HUD bar.
get_lucidity_fraction :: proc(lucidity: Lucidity) -> f32 {
	return lucidity.value / LUCIDITY_MAX
}

// How late the escape has to have been to count, in seconds.
NEAR_MISS_TIME_THRESHOLD :: 0.35

// Called exactly once per obstacle, the moment it passes the player
// without a collision. Pays out only for a genuine close call.
//
// What counts as one: **the obstacle arrived in the lane the player had
// just left**. That is the whole rule, and it is worth stating that
// plainly because the first version was not this and was subtly wrong.
// It asked whether the player had *settled somewhere* recently, without
// looking at where the obstacle was — so it paid for arriving in a safe
// lane while something harmless went past the other one, and it paid
// nothing at all if the flip happened to still be in the air when the
// obstacle went by. Once a journey lasted FLIP_DURATION rather than an
// eighth of a second, "still in the air" stopped being a rare case, and
// the resource started looking broken because half the dodges it was
// meant to pay for were the half it could not see.
//
// Anchoring on the departure fixes both: the payout is about the risk
// that was taken, and it does not care what state the player is in by
// the time the obstacle catches up. It also stays safe inside the Limen
// on its own — the window is measured from a departure that is receding
// into the past, so hovering cannot keep earning.
register_obstacle_passed :: proc(lucidity: ^Lucidity, player: Player, obstacle: Obstacle) {
	if obstacle.lane != player.left_lane {
		return // it was never coming for us
	}

	margin := obstacle.arrival_time - player.left_lane_at
	if margin < 0 {
		return // it went past before we moved: not an escape
	}
	if margin < NEAR_MISS_TIME_THRESHOLD {
		gain_lucidity(lucidity, LUCIDITY_PER_NEAR_MISS)
	}
}

// Score multiplier: a full tank doubles the rate. Spending fuel in the
// Limen therefore costs twice — the seconds cost fuel, and the fuel was
// the multiplier those seconds are being scored at.
LUCIDITY_MAX_SCORE_BONUS :: 1.0 // up to +100%

get_score_multiplier :: proc(lucidity: Lucidity) -> f32 {
	return 1 + get_lucidity_fraction(lucidity) * LUCIDITY_MAX_SCORE_BONUS
}
