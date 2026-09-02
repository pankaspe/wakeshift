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
* Every field here is edge-triggered — true only on the frame the key went
* down — except flip_held, which is a level: the Limen needs to know that
* the key is *still* down, not that it just went down.
*/
package core

Input :: struct {
	// --- Simulation input ---
	// The two fields the run itself depends on, and so the two a
	// RunManifest has to record (core/manifest.odin).
	flip:              bool, // SPACE went down: start a flip
	flip_held:         bool, // SPACE is still down: stop at the middle of the flip

	// flip_held is the *simulation's* view of the key, not the keyboard's:
	// it goes down on a press the run consumed and comes up when the key
	// is released, and it starts every run false. A key already held when
	// a run begins therefore does nothing until it is released and pressed
	// again — which is both the behaviour a player expects and what makes
	// the recorded press/release log a complete description of the input.
	// main.odin owns that latch; platform/input.odin only reports the raw
	// key.

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
