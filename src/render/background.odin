/*
* Background
* The first layer of the scene: the two worlds seen at once, Dream above
* and Real below, meeting in a band of horizon at the middle (Design Doc,
* section 12 — "the blending").
*
* What changes as the player moves is not *which* world is on screen but
* which one is alive: the half being flown toward saturates and lights
* up, the other dims toward the neutral palette without ever
* disappearing. That is the whole reason the flip reads as a crossing
* rather than a toggle.
*
* The horizon sits at the middle of the screen, which is the midpoint of
* every flip: the character crosses its own horizon on the way over.
*
* Parallax silhouettes — the actual scenery — are roadmap phase 10. This
* is the sky they will stand in front of.
*/
package render

import "../core"
import "core:math"
import rl "vendor:raylib/v55"

// Where the two worlds hand over: the play area's own 30 / 40 / 30 split
// (core/screen.odin), written as whole pixels rather than as the ratios
// times the height, so the gradient bands start and end on exact pixel
// rows and cannot leave a seam between them.
BACKGROUND_DREAM_EDGE :: core.SCREEN_HEIGHT * 3 / 10 // 216, bottom of the Dream lane
BACKGROUND_HORIZON :: core.SCREEN_HEIGHT / 2 // 360, the middle of the neutral palette
BACKGROUND_REAL_EDGE :: core.SCREEN_HEIGHT * 7 / 10 // 504, top of the Real lane

// The horizon is never quite still: a slow brightening and dimming, so
// that even a paused frame does not look like a static image. Period in
// seconds.
HORIZON_BREATH_PERIOD :: 7.0

// How far the horizon glow reaches above and below the line, and how
// bright it gets: a floor it always has, plus what it gains when the
// player is near the middle, plus what it gains as the two worlds
// converge and the threshold takes over the picture.
HORIZON_GLOW_REACH :: 90
HORIZON_GLOW_BASE :: 0.06
HORIZON_GLOW_CROSSING :: 0.22
HORIZON_GLOW_DEPTH :: 0.12

// Draws the sky of both worlds. time drives only the horizon's breathing
// and nothing else, so it can be run time during a run and wall time on
// a menu without either looking wrong.
draw_background :: proc(palettes: core.PaletteSet, time: f32) {
	dream := core.dormant_palette(palettes.dream, palettes.neutral, palettes.dream_alive)
	real := core.dormant_palette(palettes.real, palettes.neutral, palettes.real_alive)

	breath := (math.sin(time / HORIZON_BREATH_PERIOD * 2 * math.PI) + 1) * 0.5

	// The horizon itself: the neutral palette's own background, warmed by whichever
	// world is currently alive. Warmed only slightly — the threshold is
	// washed out by definition, and it is the one part of the screen that
	// must not take a side.
	horizon_color := core.lerp_color(palettes.neutral.deep, palettes.neutral.near, 0.35 + 0.25 * breath)
	horizon_color = core.lerp_color(horizon_color, palettes.current.light, 0.10)

	// Four vertical gradients: edge -> deep on each side, deep -> horizon
	// on each side. The near colors sit at the screen edges, where the
	// terrain is, and the deep ones recede toward the middle.
	rl.DrawRectangleGradientV(0, 0, core.SCREEN_WIDTH, BACKGROUND_DREAM_EDGE, dream.near, dream.deep)
	rl.DrawRectangleGradientV(
		0,
		BACKGROUND_DREAM_EDGE,
		core.SCREEN_WIDTH,
		BACKGROUND_HORIZON - BACKGROUND_DREAM_EDGE,
		dream.deep,
		horizon_color,
	)
	rl.DrawRectangleGradientV(
		0,
		BACKGROUND_HORIZON,
		core.SCREEN_WIDTH,
		BACKGROUND_REAL_EDGE - BACKGROUND_HORIZON,
		horizon_color,
		real.deep,
	)
	rl.DrawRectangleGradientV(
		0,
		BACKGROUND_REAL_EDGE,
		core.SCREEN_WIDTH,
		core.SCREEN_HEIGHT - BACKGROUND_REAL_EDGE,
		real.deep,
		real.near,
	)

	// How close the player is to the threshold, 1 at the exact middle.
	// The horizon lights up as it is crossed, which is the flip's single
	// biggest visual event and costs one number to produce.
	crossing := 1 - abs(palettes.world_t - 0.5) * 2

	strength :=
		HORIZON_GLOW_BASE +
		HORIZON_GLOW_CROSSING * crossing * crossing +
		HORIZON_GLOW_DEPTH * palettes.depth_t
	strength *= 0.75 + 0.25 * breath

	draw_glow_band(
		f32(BACKGROUND_HORIZON),
		HORIZON_GLOW_REACH,
		0,
		core.SCREEN_WIDTH,
		palettes.current.light,
		strength,
	)
}
