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
* The tiers still measure themselves in seconds until roadmap R5.3, which
* moves them onto the same clock as this.
*/
package game

import "../core"

// Where the front starts: the left edge of the screen. A run opens with
// the whole runway between PLAYER_HOME_X and here.
CORRUPTION_START_X :: 0

// How close to the character's resting position the front is ever allowed
// to get. This is what an experienced run's margin for error settles at:
// at the opening speed it is about half a second of being blocked.
//
// It stops advancing rather than continuing to a kill, because the
// Corruption is not a timer. A player making no mistakes is never in
// danger from it, however long they last — what kills is mistakes, and
// this is only how expensive they have become.
CORRUPTION_MIN_RUNWAY :: 150

// Pixels of world scrolled before the front begins to move, and by which
// it has taken everything it will take. At the opening speed those are
// roughly 9 and 50 seconds in.
CORRUPTION_ONSET_DISTANCE :: 2500
CORRUPTION_FULL_DISTANCE :: 14000

Corruption :: struct {
	// Screen x of the boundary. Everything to the left of it has lost its
	// colour; a character whose trailing edge reaches it is out of room.
	front_x: f32,
}

new_corruption :: proc() -> Corruption {
	return Corruption{front_x = CORRUPTION_START_X}
}

// A pure function of how far the run has come, so it needs no state of
// its own to be reproduced — a replay that reaches the same distance
// finds the front in the same place.
update_corruption :: proc(corruption: ^Corruption, world: World) {
	span := f32(CORRUPTION_FULL_DISTANCE - CORRUPTION_ONSET_DISTANCE)
	t := clamp((world.scroll_offset - CORRUPTION_ONSET_DISTANCE) / span, 0, 1)

	limit := f32(core.PLAYER_HOME_X - CORRUPTION_MIN_RUNWAY)
	corruption.front_x = f32(CORRUPTION_START_X) + (limit - CORRUPTION_START_X) * t
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
