/*
* Score
* Tracks "Dream Depth" — the run's score, and the only one there is
* (Design Doc, section 9).
*
* It is the **distance travelled**, nothing else. No per-lane rate, no
* multiplier, no streak: the v1.x version had three scoring systems
* stacked on each other and none of them could be felt, because a player
* watching for obstacles has no attention left for a number that is
* computed out of three inputs they cannot see.
*
* Distance has the property none of those had: it is the same thing the
* player is already looking at. How far along the world has scrolled *is*
* the score, so it can be read off the screen without being read off the
* HUD — and it is what makes Slancio (roadmap R6.3) an honest purchase,
* since buying speed buys depth per second directly.
*/
package game

// Pixels of world scrolled per point of depth. Purely a readability
// choice: at the opening speed this puts a first run in the low
// hundreds rather than the tens of thousands.
PIXELS_PER_DEPTH :: 10.0

Score :: struct {
	value: f32,
}

new_score :: proc() -> Score {
	return Score{value = 0}
}

// The furthest the *body* has got, not how far the camera has travelled.
//
// The two used to be nearly the same thing and are not any more: the
// camera advances whatever the player does, so scoring it would pay a
// player who stood still. Taking the maximum rather than accumulating
// also means sliding back to reach a branch costs nothing and buys
// nothing — the ground is scored once, the first time it is reached.
update_score :: proc(score: ^Score, player: Player) {
	score.value = max(score.value, get_player_world(player).x / PIXELS_PER_DEPTH)
}
