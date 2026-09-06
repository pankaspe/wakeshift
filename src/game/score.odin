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

// Depth is how far the *character* travelled this step, which is not the
// same as how far the world scrolled.
//
// The world comes at them at scroll_speed; their own screen x moves too.
// Add the two and the arithmetic says the right thing at every moment
// without a single branch: pinned against a cube the character's x falls
// at exactly the scroll speed, the two cancel, and depth stops. Running
// back to their resting position they cover more ground per second than
// the world does, and the run they lost is repaid in score as well as in
// room. **Blocking costs depth, and nothing here had to be told that.**
update_score :: proc(score: ^Score, world: World, player: Player, delta_time: f32) {
	travelled := (world.scroll_speed + player.velocity_x) * delta_time
	score.value += max(travelled, 0) / PIXELS_PER_DEPTH
}
