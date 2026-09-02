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

// Where the Lucidity bar sits and how big it is. Left-aligned under the
// tier line, so the three readouts read as one column.
LUCIDITY_BAR_X :: 20
LUCIDITY_BAR_Y :: 80
LUCIDITY_BAR_WIDTH :: 210
LUCIDITY_BAR_HEIGHT :: 14

// In-game score readout, difficulty tier, and the Lucidity bar.
draw_hud :: proc(
	score: game.Score,
	lucidity: game.Lucidity,
	tier_name: string,
	palettes: core.PaletteSet,
) {
	score_text := fmt.ctprintf("Depth: %.0f", score.value)
	rl.DrawText(score_text, 20, 20, 24, core.with_alpha(palettes.current.light, TEXT_PRIMARY))

	tier_text := fmt.ctprintf("Tier: %s", tier_name)
	rl.DrawText(tier_text, 20, 50, 18, core.with_alpha(palettes.current.light, TEXT_SECONDARY))

	draw_lucidity_bar(lucidity, palettes)
}

// Lucidity as a tank, not a tally (roadmap T5.6). It has to say three
// things at a glance, and a number said none of them: how much is left,
// whether there is enough to enter the Limen at all, and that it is
// draining *right now* while suspended.
//
// The threshold is drawn as a notch in the bar rather than explained.
// Below it the fill goes pale instead of accent — the Limen's own
// washed-out color, which is precisely the state being denied.
draw_lucidity_bar :: proc(lucidity: game.Lucidity, palettes: core.PaletteSet) {
	fraction := game.get_lucidity_fraction(lucidity)
	usable := game.can_suspend(lucidity)

	// The tank itself.
	rl.DrawRectangle(
		LUCIDITY_BAR_X,
		LUCIDITY_BAR_Y,
		LUCIDITY_BAR_WIDTH,
		LUCIDITY_BAR_HEIGHT,
		core.with_alpha(palettes.limen.deep, 0.55),
	)

	fill_width := i32(f32(LUCIDITY_BAR_WIDTH) * fraction)
	if fill_width > 0 {
		fill_color := usable ? palettes.current.accent : core.with_alpha(palettes.limen.light, 0.45)

		// A payout brightens the fill for a moment. Without it the bar
		// creeps up in silence and the player cannot tell what earned it
		// — which is exactly how it read in playtest.
		flash := game.get_lucidity_flash(lucidity)
		fill_color = core.lerp_color(fill_color, palettes.limen.light, flash * 0.8)

		rl.DrawRectangle(
			LUCIDITY_BAR_X,
			LUCIDITY_BAR_Y,
			fill_width,
			LUCIDITY_BAR_HEIGHT,
			fill_color,
		)

		// ...and throws a halo off the bar, which is the part visible out
		// of the corner of an eye that is watching the character.
		if flash > 0 {
			glow := i32(6 * flash)
			rl.DrawRectangleLines(
				LUCIDITY_BAR_X - glow,
				LUCIDITY_BAR_Y - glow,
				LUCIDITY_BAR_WIDTH + glow * 2,
				LUCIDITY_BAR_HEIGHT + glow * 2,
				core.with_alpha(palettes.current.accent, flash),
			)
		}
	}

	// The notch: the point past which the Limen will open.
	threshold: f32 = f32(game.LUCIDITY_SUSPEND_MINIMUM) / f32(game.LUCIDITY_MAX)
	notch_x := LUCIDITY_BAR_X + i32(f32(LUCIDITY_BAR_WIDTH) * threshold)
	rl.DrawRectangle(
		notch_x,
		LUCIDITY_BAR_Y - 2,
		2,
		LUCIDITY_BAR_HEIGHT + 4,
		core.with_alpha(palettes.current.light, usable ? TEXT_SECONDARY : TEXT_PRIMARY),
	)

	rl.DrawRectangleLines(
		LUCIDITY_BAR_X,
		LUCIDITY_BAR_Y,
		LUCIDITY_BAR_WIDTH,
		LUCIDITY_BAR_HEIGHT,
		core.with_alpha(palettes.current.light, TEXT_MUTED),
	)

	// The multiplier the tank is currently paying, to the right of it:
	// the same number seen as a reward rather than as fuel.
	multiplier_text := fmt.ctprintf("x%.2f", game.get_score_multiplier(lucidity))
	rl.DrawText(
		multiplier_text,
		LUCIDITY_BAR_X + LUCIDITY_BAR_WIDTH + 12,
		LUCIDITY_BAR_Y - 2,
		18,
		usable ? palettes.current.accent : core.with_alpha(palettes.current.light, TEXT_SECONDARY),
	)
}

// Pushes the frozen gameplay frame back behind an overlay. Uses the
// Limen's deep background rather than plain black: dimming toward the
// threshold keeps the pause inside the game's own palette instead of
// dropping a grey sheet over it.
draw_overlay_scrim :: proc(palettes: core.PaletteSet) {
	rl.DrawRectangle(
		0,
		0,
		core.SCREEN_WIDTH,
		core.SCREEN_HEIGHT,
		core.with_alpha(palettes.limen.deep, OVERLAY_SCRIM_ALPHA),
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
