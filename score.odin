/*
* This is Score file, score.odin
* Tracks "Dream Depth" — the run's score, which grows automatically over
* time, faster while the player is in the Dream lane than in the Real lane
* (Design Doc, section 8).
*/
package main

// Points per second, depending on which lane the player currently occupies.
SCORE_RATE_REAL  :: 10
SCORE_RATE_DREAM :: 25

Score :: struct {
	value: f32,
}

new_score :: proc() -> Score {
	return Score{value = 0}
}

// Grows the score based on the player's current lane.
// Note: player.lane only updates once a transition completes (Section 3),
// so during a flip the score keeps growing at the lane you're leaving,
// for the (short, ~0.12s) duration of the transition — negligible in
// practice, but worth knowing if the numbers ever need to be exact.
update_score :: proc(score: ^Score, player: Player, delta_time: f32) {
	rate := SCORE_RATE_REAL
	if player.lane == .Dream {
		rate = SCORE_RATE_DREAM
	}

	score.value += f32(rate) * delta_time
}
