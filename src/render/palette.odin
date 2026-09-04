/*
* Scene Palette
* Turns game state into the two numbers the palette system runs on
* (core/palette.odin): where the player is vertically, and how deep into
* the run we are.
*
* The colors themselves live in core, because ui samples them too and is
* not allowed to import render. What is here is the half that genuinely
* needs to know about a Player and a World.
*/
package render

import "../core"
import "../game"
import "core:math"

// Depth is measured in seconds rather than in score, so the convergence
// lands on the same beat as the difficulty tiers and, later, the layers
// (Design Doc, section 3): the two worlds start blurring together as the
// run leaves the first layer, and are nearly one by the time it reaches
// what the doc calls Dissolution.
CONVERGENCE_START_TIME :: 30
CONVERGENCE_FULL_TIME :: 100

// Design Doc, section 12: world_t is how far up the column the player is,
// 0 on the floor and 1 at the ceiling. Reads the drawn box rather than the
// lane, so it sweeps continuously through the flip instead of snapping
// when the lane changes.
//
// Measured between the two lanes rather than between the two screen
// edges, and that matters more now that the corridor moves: normalising
// against the screen would make the colour of a player standing still
// depend on where the track happens to have carried them, which is not
// something the palette has any business knowing about.
get_world_t :: proc(player: game.Player, world: game.World) -> f32 {
	half := player.size.y * 0.5

	center := player.position.y + half
	real_center := game.get_lane_y(world, .Real, player.position.x, player.size) + half
	dream_center := game.get_lane_y(world, .Dream, player.position.x, player.size) + half

	return clamp((real_center - center) / (real_center - dream_center), 0, 1)
}

get_depth_t :: proc(world: game.World) -> f32 {
	span := f32(CONVERGENCE_FULL_TIME - CONVERGENCE_START_TIME)
	return clamp((world.elapsed_time - CONVERGENCE_START_TIME) / span, 0, 1)
}

// The palette of a live run: the player's height picks the blend between
// the two worlds, and the elapsed time converges them toward the neutral
// palette.
//
// The Corruption is absent from this on purpose. It is a *place*, not a
// level — the world is gone to the left of a front and whole to its
// right — so it cannot be a number applied to a palette the whole screen
// shares. It is applied to the finished frame instead
// (fx/corruption.odin), which is the only stage that knows what x a pixel
// is at.
new_scene_palette :: proc(player: game.Player, world: game.World) -> core.PaletteSet {
	return core.new_palette_set(get_world_t(player, world), get_depth_t(world))
}

// The palette for a screen with no run behind it (menus, options). It
// drifts slowly between the two worlds instead of picking one, so the
// menu breathes the same way the game does — and so the first thing the
// player ever sees already states the premise.
MENU_DRIFT_PERIOD :: 14.0 // seconds for a full Real -> Dream -> Real cycle
MENU_DRIFT_RANGE :: 0.42 // how far either side of the midpoint it travels

new_menu_palette :: proc(display_time: f32) -> core.PaletteSet {
	phase := display_time / MENU_DRIFT_PERIOD * 2 * math.PI
	return core.new_palette_set(0.5 + MENU_DRIFT_RANGE * math.sin(phase), 0)
}
