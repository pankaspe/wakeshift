/*
* UI
* Draws each application screen (Design Doc, section 9): main menu,
* in-game HUD, pause overlay, game over screen.
*/
package ui

import "../game"
import "core:fmt"
import rl "vendor:raylib/v55"

draw_main_menu :: proc(menu: Menu, high_score: f32) {
	draw_centered_text("WAKE SHIFT", 220, 50, rl.BLACK)
	draw_menu(menu, 340, 50, 28)

	best_text := fmt.ctprintf("Best Depth: %.0f", high_score)
	draw_centered_text(best_text, 470, 20, rl.DARKGRAY)
}

// In-game score readout, current difficulty tier, plus the Lucidity
// streak when it's active. Real HUD polish (Design Doc section 9 styling)
// comes later; for now this replaces the plain text that used to live
// directly in main.odin.
draw_hud :: proc(score: game.Score, lucidity: game.Lucidity, tier_name: string) {
	score_text := fmt.ctprintf("Depth: %.0f", score.value)
	rl.DrawText(score_text, 20, 20, 24, rl.BLACK)

	tier_text := fmt.ctprintf("Tier: %s", tier_name)
	rl.DrawText(tier_text, 20, 50, 18, rl.DARKGRAY)

	if lucidity.streak > 0 {
		multiplier := game.get_score_multiplier(lucidity)
		streak_text := fmt.ctprintf(
			"Lucidity x%d  (+%.0f%%)",
			lucidity.streak,
			(multiplier - 1) * 100,
		)
		rl.DrawText(streak_text, 20, 78, 20, rl.Color{180, 60, 200, 255})
	}
}

// Drawn on top of the frozen gameplay frame when paused.
draw_pause_overlay :: proc(menu: Menu) {
	draw_centered_text("PAUSED", 260, 40, rl.BLACK)
	draw_menu(menu, 340, 50, 28)
}

// Drawn on top of the frozen gameplay frame on game over — a small
// Dream Report (Design Doc, section 8-9): final depth, and whether it's
// a new personal best.
draw_game_over :: proc(score: game.Score, high_score: f32) {
	draw_centered_text("AWAKENED", 260, 40, rl.RED)

	final_score_text := fmt.ctprintf("Depth reached: %.0f", score.value)
	draw_centered_text(final_score_text, 320, 20, rl.DARKGRAY)

	if score.value >= high_score {
		draw_centered_text("NEW BEST!", 350, 22, rl.RED)
	} else {
		best_text := fmt.ctprintf("Best Depth: %.0f", high_score)
		draw_centered_text(best_text, 350, 20, rl.DARKGRAY)
	}

	draw_centered_text("Press ENTER to try again", 390, 20, rl.DARKGRAY)
}
