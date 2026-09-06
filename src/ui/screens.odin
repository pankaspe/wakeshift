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

// In-game readout: the depth, and nothing else (Design Doc, section 11).
//
// There used to be a Lucidity bar here, and a tier name under it. Neither
// is coming back. The game already draws its own state at full size —
// the distance between the character and the Corruption front *is* the
// health bar, and how deep you are is the one number a player has any
// attention left to read. A tier name told them something they could
// already feel.
// F1 put a fragment counter under it and F2 took it out again, on F1's
// own instruction: what a fragment is worth is said by the Corruption's
// front sliding backwards, which is a thing the player is already
// looking at, and a number in a corner was the stand-in until that was
// true. The run's total is on the Dream Report instead, where a tally
// belongs.
draw_hud :: proc(score: game.Score, palettes: core.PaletteSet) {
	score_text := fmt.ctprintf("Depth: %.0f", score.value)
	rl.DrawText(score_text, 20, 20, 24, core.with_alpha(palettes.current.light, TEXT_PRIMARY))
}

// C5 — the one instruction the game ever gives: how to change lane.
// Centred in the corridor, drawn only while actually playing, and gone
// within a few seconds. It fades in at the start of every run and fades
// out again the instant the player first flips (dismissed_at >= 0), or
// after INTRO_PROMPT_HOLD if they never do.
//
// It is not a tutorial and it is not a pause. The run is live underneath
// it and the first obstacle is already on its way — a screen where
// nothing happens while the player reads is exactly what killed v1.3, so
// the text sits on top of a running game and never in front of it. Keep
// it short for the same reason (pillar 2).
INTRO_PROMPT_Y :: 342
INTRO_PROMPT_SIZE :: 30
INTRO_PROMPT_FADE :: 0.5
INTRO_PROMPT_HOLD :: 3.0
INTRO_PROMPT_ALPHA :: 0.92

draw_intro_prompt :: proc(elapsed: f32, dismissed_at: f32, palettes: core.PaletteSet) {
	// A negative dismissed_at means the player has not flipped yet, so the
	// prompt holds for its full lifetime; once they have, the hold ends at
	// the moment they did and the fade-out follows from there.
	hold_end: f32 = dismissed_at >= 0 ? dismissed_at : INTRO_PROMPT_HOLD

	fade_in := clamp(elapsed / INTRO_PROMPT_FADE, 0, 1)
	fade_out := 1 - clamp((elapsed - hold_end) / INTRO_PROMPT_FADE, 0, 1)
	alpha := min(fade_in, fade_out) * INTRO_PROMPT_ALPHA
	if alpha <= 0 {
		return
	}

	draw_centered_text(
		"WASD OR ARROWS - YOU SLIDE UNTIL A WALL",
		INTRO_PROMPT_Y,
		INTRO_PROMPT_SIZE,
		core.with_alpha(palettes.current.light, alpha),
	)
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
draw_game_over :: proc(
	score: game.Score,
	high_score: f32,
	palettes: core.PaletteSet,
) {
	draw_overlay_scrim(palettes)

	// Waking up is a return to the Real world, so the screen that says so
	// is lit by it, whichever world the run ended in.
	draw_centered_text("AWAKENED", 250, 40, palettes.real.accent)

	final_score_text := fmt.ctprintf("Depth reached: %.0f", score.value)
	draw_centered_text(
		final_score_text,
		312,
		20,
		core.with_alpha(palettes.current.light, TEXT_PRIMARY),
	)

	// The fragments' tally used to be reported here. They come back with
	// the Dream (Design Doc §8), and a line reading zero every time would
	// be worse than no line at all.

	if score.value >= high_score {
		draw_centered_text("NEW BEST!", 374, 22, palettes.dream.accent)
	} else {
		best_text := fmt.ctprintf("Best Depth: %.0f", high_score)
		draw_centered_text(
			best_text,
			374,
			20,
			core.with_alpha(palettes.current.light, TEXT_SECONDARY),
		)
	}

	draw_centered_text(
		"Press ENTER to try again",
		416,
		20,
		core.with_alpha(palettes.current.light, TEXT_MUTED),
	)
}
