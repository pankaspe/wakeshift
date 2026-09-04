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

// Depth is derived from the distance the world has scrolled this step.
// Deliberately not read off world.scroll_offset directly: once the
// player's own screen x becomes game state (roadmap R2.1), distance
// travelled and world scroll stop being the same number, and this is the
// procedure that will have to know the difference.
update_score :: proc(score: ^Score, world: World, delta_time: f32) {
	score.value += world.scroll_speed * delta_time / PIXELS_PER_DEPTH
}
