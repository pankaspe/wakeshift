/*
* Lucidity
* Tracks a streak of near-misses — obstacles passed by settling into the
* correct lane late, close to the wire, rather than safely in advance.
* Distinct from Score (Section 12), which only measures survival time:
* Lucidity measures deliberate risk-taking (Design Doc, section 8).
*/
package game

Lucidity :: struct {
	streak: int,
}

new_lucidity :: proc() -> Lucidity {
	return Lucidity{streak = 0}
}

// How close to an obstacle's arrival the player must have settled into
// the correct lane for it to count as a risky near-miss, in seconds.
NEAR_MISS_TIME_THRESHOLD :: 0.35

// Called exactly once per obstacle, the moment it passes the player
// without a collision. Increases the streak only for a genuine close call.
register_obstacle_passed :: proc(lucidity: ^Lucidity, player: Player, obstacle: Obstacle) {
	if player.state == .Transitioning {
		// Still mid-flip when the obstacle arrived: survived on invulnerability,
		// not skillful timing — doesn't count as a near-miss.
		return
	}

	margin := obstacle.arrival_time - player.lane_since
	if margin < NEAR_MISS_TIME_THRESHOLD {
		lucidity.streak += 1
	}
}

reset_lucidity :: proc(lucidity: ^Lucidity) {
	lucidity.streak = 0
}

// Score multiplier derived from the current streak, capped so it can't
// grow unbounded (balancing exact numbers is Section 19's job).
LUCIDITY_SCORE_BONUS_PER_STREAK :: 0.03
LUCIDITY_MAX_SCORE_BONUS :: 1.0 // up to +100%

get_score_multiplier :: proc(lucidity: Lucidity) -> f32 {
	bonus := f32(lucidity.streak) * LUCIDITY_SCORE_BONUS_PER_STREAK
	if bonus > LUCIDITY_MAX_SCORE_BONUS {
		bonus = LUCIDITY_MAX_SCORE_BONUS
	}
	return 1 + bonus
}
