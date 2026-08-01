/*
* UI
* Draws each application screen (Design Doc, section 9): main menu,
* in-game HUD, pause overlay, game over screen.
*/
package main

import "core:fmt"
import rl "vendor:raylib/v55"

draw_main_menu :: proc(menu: Menu) {
	draw_centered_text("WAKE SHIFT", 220, 50, rl.BLACK)
	draw_menu(menu, 340, 50, 28)
	draw_centered_text("SPACE to flip, once in a run", 500, 18, rl.DARKGRAY)
}

// In-game score readout. Real HUD polish (Design Doc section 9 styling)
// comes later; for now this replaces the plain text that used to live
// directly in main.odin.
draw_hud :: proc(score: Score) {
	score_text := fmt.ctprintf("Depth: %.0f", score.value)
	rl.DrawText(score_text, 20, 20, 24, rl.BLACK)
}

// Drawn on top of the frozen gameplay frame when paused.
draw_pause_overlay :: proc(menu: Menu) {
	draw_centered_text("PAUSED", 260, 40, rl.BLACK)
	draw_menu(menu, 340, 50, 28)
}

// Drawn on top of the frozen gameplay frame on game over.
draw_game_over :: proc(score: Score) {
	draw_centered_text("AWAKENED", 260, 40, rl.RED)

	final_score_text := fmt.ctprintf("Depth reached: %.0f", score.value)
	draw_centered_text(final_score_text, 320, 20, rl.DARKGRAY)

	draw_centered_text("Press ENTER to try again", 360, 20, rl.DARKGRAY)
}
