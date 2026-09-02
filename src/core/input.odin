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
* Every field is edge-triggered — true only on the frame the key went
* down, not while it is held. The Limen's hold gesture (roadmap T5.1)
* adds held/released state alongside these rather than changing them.
*/
package core

Input :: struct {
	// --- Simulation input ---
	// The only field the run itself depends on, and so the only one a
	// RunManifest needs to record (roadmap T2.8).
	flip:              bool, // SPACE

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
