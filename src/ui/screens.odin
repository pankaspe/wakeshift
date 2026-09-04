/*
* UI
* Draws each application screen (Design Doc, section 9): main menu,
* in-game HUD, pause overlay, game over screen.
*
* Every color here is sampled from the palette the caller hands in
* (core/palette.odin) — the screens sit on the same dark, drifting
* background the game does, and go violet or wash out with it. That is
* also why the palette lives in core: ui may not import render, and a
* menu drawn in system colors on top of the game's own background was
* the last place the prototype was still visible (roadmap T3.8).
*
* The font is still raylib's default bitmap one. Now that everything
* drawn from primitives is crisp at native resolution, it is the one
* thing on screen that isn't — a real font is roadmap T13.3.
*/
package ui

import "../core"
import "../game"
import "core:fmt"
import rl "vendor:raylib/v55"

// How far the frozen gameplay behind an overlay is pushed back, so the
// text on top of it stays readable without hiding the run entirely.
OVERLAY_SCRIM_ALPHA :: 0.62

// Text weights, as opacities of the current world's light. Three of them
// is enough: what you are on, what you could move to, and what is merely
// informative.
TEXT_PRIMARY :: 0.92
TEXT_SECONDARY :: 0.62
TEXT_MUTED :: 0.40

draw_main_menu :: proc(menu: Menu, high_score: f32, palettes: core.PaletteSet) {
	draw_centered_text("WAKE SHIFT", 220, 50, palettes.current.accent)
	draw_menu(menu, 340, 50, 28, palettes)

	// Below the last menu row: the menu starts at 340 with 50 between
	// rows, and gained a third row when the options screen arrived.
	best_text := fmt.ctprintf("Best Depth: %.0f", high_score)
	draw_centered_text(best_text, 520, 20, core.with_alpha(palettes.current.light, TEXT_MUTED))
}

// In-game readout. Depth and the difficulty tier, and that is the whole
// HUD (Design Doc, section 11).
//
// There used to be a Lucidity bar here. There is no bar now and there is
// not meant to be one: from roadmap R2 the distance between the character
// and the Corruption front is the only meter the run has, drawn at full
// size in the world itself. A player watching for obstacles has no
// attention left for the bottom of the screen.
draw_hud :: proc(score: game.Score, tier_name: string, palettes: core.PaletteSet) {
	score_text := fmt.ctprintf("Depth: %.0f", score.value)
	rl.DrawText(score_text, 20, 20, 24, core.with_alpha(palettes.current.light, TEXT_PRIMARY))

	tier_text := fmt.ctprintf("Tier: %s", tier_name)
	rl.DrawText(tier_text, 20, 50, 18, core.with_alpha(palettes.current.light, TEXT_SECONDARY))
}

// Pushes the frozen gameplay frame back behind an overlay. Uses the
// neutral palette's deep background rather than plain black: dimming toward the
// threshold keeps the pause inside the game's own palette instead of
// dropping a grey sheet over it.
draw_overlay_scrim :: proc(palettes: core.PaletteSet) {
	rl.DrawRectangle(
		0,
		0,
		core.SCREEN_WIDTH,
		core.SCREEN_HEIGHT,
		core.with_alpha(palettes.neutral.deep, OVERLAY_SCRIM_ALPHA),
	)
}

// Drawn on top of the frozen gameplay frame when paused.
draw_pause_overlay :: proc(menu: Menu, palettes: core.PaletteSet) {
	draw_overlay_scrim(palettes)
	draw_centered_text("PAUSED", 260, 40, palettes.current.accent)
	draw_menu(menu, 340, 50, 28, palettes)
}

// Drawn on top of the frozen gameplay frame on game over — a small
// Dream Report (Design Doc, section 8-9): final depth, and whether it's
// a new personal best. The full report is roadmap T13.2.
draw_game_over :: proc(score: game.Score, high_score: f32, palettes: core.PaletteSet) {
	draw_overlay_scrim(palettes)

	// Waking up is a return to the Real world, so the screen that says so
	// is lit by it, whichever world the run ended in.
	draw_centered_text("AWAKENED", 260, 40, palettes.real.accent)

	final_score_text := fmt.ctprintf("Depth reached: %.0f", score.value)
	draw_centered_text(
		final_score_text,
		320,
		20,
		core.with_alpha(palettes.current.light, TEXT_PRIMARY),
	)

	if score.value >= high_score {
		draw_centered_text("NEW BEST!", 350, 22, palettes.dream.accent)
	} else {
		best_text := fmt.ctprintf("Best Depth: %.0f", high_score)
		draw_centered_text(
			best_text,
			350,
			20,
			core.with_alpha(palettes.current.light, TEXT_SECONDARY),
		)
	}

	draw_centered_text(
		"Press ENTER to try again",
		390,
		20,
		core.with_alpha(palettes.current.light, TEXT_MUTED),
	)
}
