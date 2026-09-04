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
* Every field here is edge-triggered: true only on the frame the key went
* down. There is no level-triggered field and there must not be one — the
* whole control scheme is a single gesture, and a key that means something
* different while it is *held* is the second gesture by another name
* (Design Doc, pillar 1).
*/
package core

Input :: struct {
	// --- Simulation input ---
	// The one field the run itself depends on, and so the only one a
	// RunManifest has to record (core/manifest.odin). A press during a
	// journey is not lost: game/player.odin queues it.
	flip:              bool, // SPACE went down: change lane

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
