/*
* This is Score file, score.odin
* Tracks "Dream Depth" — the run's score, which grows automatically over
* time, faster while the player is in the Dream lane than in the Real lane
* (Design Doc, section 8).
*/
package game

// Points per second, depending on where the player currently is (Design
// Doc, section 8). The rates rise with the risk: the floor is safe and
// pays least, the ceiling is the unstable world, and the Limen pays most
// because it is also burning Lucidity the whole time it is scoring.
SCORE_RATE_REAL :: 10
SCORE_RATE_DREAM :: 25
SCORE_RATE_LIMEN :: 40

Score :: struct {
	value: f32,
}

new_score :: proc() -> Score {
	return Score{value = 0}
}

// Grows the score based on where the player is, scaled by the Lucidity
// multiplier — riskier play is directly rewarded.
//
// Note: player.lane only updates once a journey completes, so while
// crossing, the score keeps paying at the wall being left. That is worth
// a little more thought now that a journey lasts FLIP_DURATION: a player
// flipping constantly is paid as if they never left the floor, which is
// the right way round — the crossing is not where the risk is, the walls
// are. The Limen is the exception, and it is checked first because
// "which lane" has no answer there.
update_score :: proc(score: ^Score, player: Player, delta_time: f32, multiplier: f32) {
	rate := SCORE_RATE_REAL
	switch {
	case is_suspended(player):
		rate = SCORE_RATE_LIMEN
	case player.lane == .Dream:
		rate = SCORE_RATE_DREAM
	}

	score.value += f32(rate) * multiplier * delta_time
}
