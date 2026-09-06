/*
* Input
* One frame's worth of player input, as plain data. Gameplay and UI code
* receive this; nothing outside platform/input.odin is allowed to ask the
* keyboard anything directly.
*
* That rule is not tidiness. A simulation that queries live hardware
* cannot be replayed, and replay is what the whole of roadmap phase 2
* is building toward: server-side leaderboard validation, ghost runs, and
* balancing a change against the exact same run (Design Doc, section 10).
* Input has to be a value that can be recorded and fed back in.
*
* Most fields here are edge-triggered: true only on the frame the key went
* down. A key that means something *different* while it is held would be a
* second gesture by another name and is still forbidden (pillar 1); the
* four hold_* fields are not that, and say why they are not where they are
* declared.
*/
package core

Input :: struct {
	// --- Simulation input ---
	// The fields the run itself depends on. A press arriving during a
	// journey is not lost: game/player.odin latches it.
	move_up:           bool,
	move_down:         bool,
	move_left:         bool,
	move_right:        bool,

	// The same four keys, level-triggered, and the one exception to the
	// rule below.
	//
	// A held key does not mean something *different* from a pressed one —
	// it means exactly the same thing, again, when the body next comes to
	// rest. That is what makes it admissible: the control scheme is still
	// one gesture. Without it a run is four presses a second of typing,
	// which would make the question L1 exists to answer — can a maze be
	// read at this speed — impossible to answer, because the answer would
	// be about the fingers.
	//
	// It is simulation input like the four above, and a RunManifest that
	// records only the presses would not reproduce a run.
	hold_up:           bool,
	hold_down:         bool,
	hold_left:         bool,
	hold_right:        bool,

	// --- Meta input ---
	// Screen navigation and window control. Deliberately outside the
	// simulation: pausing or resizing must never change how a run plays
	// out, or a recorded run would not reproduce.
	pause:             bool, // ESCAPE
	confirm:           bool, // ENTER
	menu_up:           bool, // UP
	menu_down:         bool, // DOWN

	// Cycle the value of a settings row (roadmap T2.5.6). Meta input like
	// the rest of this block: the options screen can be opened mid-run from
	// the pause menu, and nothing it changes may reach the simulation or
	// the RunManifest.
	menu_left:         bool, // LEFT
	menu_right:        bool, // RIGHT

	toggle_fullscreen: bool, // F11
}
