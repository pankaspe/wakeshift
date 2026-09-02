/*
* Input
* The one place in the project that asks raylib what the keyboard is
* doing. Everything downstream receives the resulting core.Input value
* instead of polling for itself (see core/input.odin for why).
*
* Keeping the poll in a single procedure is also what makes a replay
* possible later: feeding a recorded core.Input into the game instead of
* calling read_input needs no change anywhere else.
*/
package platform

import "../core"
import rl "vendor:raylib/v55"

// Samples every key the game cares about, once, for this frame.
read_input :: proc() -> core.Input {
	return core.Input {
		flip = rl.IsKeyPressed(.SPACE),

		// The raw key. main.odin turns this into the simulation's own
		// latched view of it (core/input.odin) before any step sees it.
		flip_held = rl.IsKeyDown(.SPACE),
		pause = rl.IsKeyPressed(.ESCAPE),
		confirm = rl.IsKeyPressed(.ENTER),
		menu_up = rl.IsKeyPressed(.UP),
		menu_down = rl.IsKeyPressed(.DOWN),
		menu_left = rl.IsKeyPressed(.LEFT),
		menu_right = rl.IsKeyPressed(.RIGHT),
		toggle_fullscreen = rl.IsKeyPressed(.F11),
	}
}
