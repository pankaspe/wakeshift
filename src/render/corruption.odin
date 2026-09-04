/*
* Corruption Render
* The boundary itself: one lit vertical edge where the colour stops.
*
* The colour dying is a post-process on the finished frame
* (fx/corruption.odin). This is the other half, and it is drawn in the
* world rather than filtered onto it for two reasons.
*
* **Readability.** A gradient of falling saturation is a subtle thing on a
* dark picture, and what the player has to see in two seconds is not "the
* colour is a bit lower over there" but "the edge is *this* far away".
* Pillar 2 wants a line.
*
* **It must not depend on a shader.** If the desaturation pass fails to
* compile the game keeps running, and a lethal front nobody can see would
* be the one thing in this game that kills without showing the blow
* coming (pillar 3). This is drawn with primitives and cannot fail.
*
* What it deliberately is *not* is a wall. The design considered and
* rejected a solid chaser: in a game where you cannot run faster, a wall
* is a countdown in a costume. So this is an edge and a glow, and the
* mass on the far side of it stays whatever the world already was — only
* drained of colour.
*/
package render

import "../core"
import "../game"
import rl "vendor:raylib/v55"

// The edge's own weight, and how far its halo reaches.
CORRUPTION_EDGE_THICKNESS :: 2.2
CORRUPTION_EDGE_SPREAD :: 26

// How present the edge is when it is far away, and how much it gains as
// it closes in. It has to be legible from the moment it starts moving,
// and insistent by the time it is a real threat — the same information
// twice, which is what a cue the player must not miss is allowed to do.
CORRUPTION_EDGE_BASE :: 0.30
CORRUPTION_EDGE_PRESSURE :: 0.55
CORRUPTION_GLOW_STRENGTH :: 0.45

draw_corruption :: proc(
	corruption: game.Corruption,
	player: game.Player,
	palettes: core.PaletteSet,
) {
	x := corruption.front_x
	if x <= 0 {
		return // still off the left edge: nothing to draw
	}

	pressure := game.get_corruption_pressure(corruption, player)
	presence := CORRUPTION_EDGE_BASE + CORRUPTION_EDGE_PRESSURE * pressure

	top := rl.Vector2{x, 0}
	bottom := rl.Vector2{x, core.SCREEN_HEIGHT}

	// The neutral palette's light, not the current world's: the front
	// belongs to neither world, and it is the one thing on screen that
	// must not change colour when the player flips.
	draw_glow_line(
		top,
		bottom,
		CORRUPTION_EDGE_THICKNESS,
		CORRUPTION_EDGE_SPREAD,
		palettes.neutral.light,
		CORRUPTION_GLOW_STRENGTH * presence,
	)
	rl.DrawLineEx(
		top,
		bottom,
		CORRUPTION_EDGE_THICKNESS,
		core.with_alpha(palettes.neutral.light, presence),
	)
}
