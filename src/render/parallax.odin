/*
* Parallax
* The last rung of the weight hierarchy: the thinnest and slowest mark on
* screen (Design Doc, section 10 — the character, then the live lane,
* then the dormant one, then this).
*
* Two things, both of them the same idea at the same weight: distant
* horizons in the two bands the world can never reach, and a **grid**
* receding to a vanishing point behind everything. Anticipated from phase
* R7, and with this art direction it costs a tenth of what it would have:
* there is no silhouette to fill and no texture to author, only the same
* stroke at a weight nothing else uses.
*
* The grid is the one part of the background that *does* cross the
* corridor, which the horizons are forbidden to do. It is allowed because
* it is not a horizon: it has no edge to be mistaken for a lane, it moves
* on a different axis from everything else (outward from the middle, not
* right to left), and it is drawn at the faintest alpha on screen. If it
* ever competes with the play line, it is the first thing to turn down —
* pillar 2 says readability wins.
*
* THREE RULES, AND ALL THREE ARE ABOUT NOT COMPETING
*
* Decision 3 of the art direction says the field sits under the line in
* value, contrast and detail, and that the vignette exists to push the
* eye to the middle where the game is played. So:
*
*   - **It never enters the corridor.** The track keeps TRACK_SKY_MARGIN
*     of screen outside both lanes at every legal spine and span, so the
*     bands above y = 70 and below y = 650 are the only two places on
*     screen the world can never reach. Every layer lives inside them,
*     amplitude included, which is checked by arithmetic rather than by
*     eye — see PARALLAX_LAYERS.
*   - **It is drawn under the vignette**, not over it. A mark at the top
*     of the screen that ignored the lens would pull the eye exactly where
*     the lens is trying to stop it going, so the background pass draws
*     the field, then this, then the vignette over both
*     (render/background.odin).
*   - **It does not take the glow gain.** Everything else on screen burns
*     brighter toward the Dream (render/palette.odin); the background is
*     the one thing that must not, or it would compete hardest exactly
*     where everything else is already brightest.
*
* AND IT CURVES, BECAUSE THE DANGER CORNERS
*
* Two sines of different wavelengths rather than one, so it reads as a
* landscape and not as a signal — but never a straight run and never a
* right angle, because a right angle is the one thing in this picture
* that means "this costs you".
*
* It is a pure function of the scroll it is handed. No state, nothing to
* reset, and a menu can drive it with the wall clock to get the same
* horizon drifting behind it.
*/
package render

import "../core"
import "core:math"
import rl "vendor:raylib/v55"

// How many points each curve is sampled at across the screen. The
// wavelengths are hundreds of pixels, so this is smooth several times
// over; the cost is one stroke per layer per band.
PARALLAX_SAMPLES :: 40

// The band the world can never reach, measured from each screen edge:
// TRACK_SKY_MARGIN, which core/track.odin clamps every keyframe against.
PARALLAX_BAND :: core.TRACK_SKY_MARGIN

ParallaxLayer :: struct {
	base:       f32, // distance from the nearest screen edge, at rest
	amplitude:  f32,
	wavelength: f32,
	speed:      f32, // fraction of the world's own scroll
	weight:     f32, // fraction of the live lane's stroke
	alpha:      f32,
}

// Nearest first. Each one further back is thinner, fainter and slower,
// which is the whole of what parallax is here.
//
// base + amplitude stays under PARALLAX_BAND for every entry, which is
// what keeps the curves out of the corridor at every legal corridor.
PARALLAX_LAYERS :: [3]ParallaxLayer {
	{base = 51, amplitude = 10, wavelength = 620, speed = 0.30, weight = 0.42, alpha = 0.30},
	{base = 36, amplitude = 8, wavelength = 940, speed = 0.18, weight = 0.34, alpha = 0.22},
	{base = 19, amplitude = 6, wavelength = 1420, speed = 0.10, weight = 0.28, alpha = 0.15},
}

// How much of the shape the second, shorter wave carries. Enough that the
// curve stops looking like a sine, little enough that it stays a horizon.
PARALLAX_HARMONIC :: 0.30
PARALLAX_HARMONIC_RATIO :: 2.3

// The two bands are the same three layers mirrored, so this offsets the
// lower one along its own travel: mirrored *and* identical would make the
// screen read as folded in half.
PARALLAX_MIRROR_OFFSET :: 703

// A hair of halo, so the thinnest mark on screen is still a neon one
// rather than a hairline.
PARALLAX_GLOW :: 0.16
PARALLAX_SPREAD :: 3.0

// --- The grid ---
//
// A tunnel receding to a vanishing point at the middle of the screen:
// spokes running out to the edges, and rings expanding along them. The
// rings are spaced so that each one is a fixed multiple of the last, which
// is what perspective does — a constant spacing reads as a target, not as
// distance.
GRID_SPOKES :: 26
GRID_RINGS :: 7
GRID_RING_RATIO :: 1.62 // how much bigger each ring is than the one inside it
GRID_INNER :: 0.055 // the innermost ring, as a fraction of the screen's half-height
GRID_PERIOD :: 5.4 // seconds for a ring to travel from the inside to the outside

// The vanishing point, in fractions of the screen. Level with the
// corridor's neutral spine and a little behind the player, so the tunnel
// is receding away from where they are looking.
GRID_VANISH :: rl.Vector2{0.44, 0.5}

// Faintest on screen, and the spokes fainter still than the rings: a
// radial line crossing the corridor is the most competing shape the
// background has.
GRID_RING_ALPHA :: 0.13
GRID_SPOKE_ALPHA :: 0.07
GRID_WEIGHT :: 0.30 // fraction of the live lane's stroke


@(private)
parallax_y :: proc(layer: ParallaxLayer, x, travel, sign: f32) -> f32 {
	phase := (x + travel) / layer.wavelength * 2 * math.PI
	wave :=
		(1 - PARALLAX_HARMONIC) * math.sin(phase) +
		PARALLAX_HARMONIC * math.sin(phase * PARALLAX_HARMONIC_RATIO + 1.7)

	edge := sign > 0 ? layer.base : f32(core.SCREEN_HEIGHT) - layer.base
	return edge + layer.amplitude * wave * sign
}

// Draws one layer in one band. sign is +1 for the band at the top of the
// screen and -1 for the one at the bottom.

@(private)
draw_parallax_layer :: proc(layer: ParallaxLayer, palette: core.Palette, travel, sign: f32) {
	points: [PARALLAX_SAMPLES + 1]rl.Vector2
	for i in 0 ..= PARALLAX_SAMPLES {
		x := f32(core.SCREEN_WIDTH) * f32(i) / f32(PARALLAX_SAMPLES)
		points[i] = rl.Vector2{x, parallax_y(layer, x, travel, sign)}
	}

	line := new_stroke(
		core.with_alpha(palette.light, layer.alpha),
		TERRAIN_STROKE_THICKNESS * layer.weight,
	)
	line.glow = PARALLAX_GLOW
	line.spread = PARALLAX_SPREAD
	line.core_light = 0
	draw_stroke(points[:], line)
}

// The whole background's worth of distance.
//
// `scroll` is however far the world has travelled — the run's own
// scroll_offset in a game, and the wall clock times the opening speed
// behind a menu, which is why nothing here knows which of the two it is
// looking at. `palette` is the field's, sampled at the *lagged*
// background_t, so the horizons wash between the worlds on the same slow
// clock the field does instead of snapping with the player.
draw_parallax :: proc(palette: core.Palette, scroll: f32) {
	layers := PARALLAX_LAYERS
	for layer in layers {
		travel := -scroll * layer.speed
		draw_parallax_layer(layer, palette, travel, 1)
		draw_parallax_layer(layer, palette, travel + PARALLAX_MIRROR_OFFSET, -1)
	}
}

// One ring of the tunnel, as a rectangle around the vanishing point —
// rectangles rather than circles because a rectangle's corners run out to
// the screen's own, which is what makes it read as a room rather than as
// a target.
@(private)
draw_grid_ring :: proc(palette: core.Palette, scale: f32, alpha: f32) {
	if alpha <= 0.004 {
		return
	}
	centre := rl.Vector2 {
		GRID_VANISH.x * core.SCREEN_WIDTH,
		GRID_VANISH.y * core.SCREEN_HEIGHT,
	}
	half := rl.Vector2 {
		scale * core.SCREEN_HEIGHT * 0.5 * (f32(core.SCREEN_WIDTH) / core.SCREEN_HEIGHT),
		scale * core.SCREEN_HEIGHT * 0.5,
	}

	ring := [4]rl.Vector2 {
		{centre.x - half.x, centre.y - half.y},
		{centre.x + half.x, centre.y - half.y},
		{centre.x + half.x, centre.y + half.y},
		{centre.x - half.x, centre.y + half.y},
	}
	line := new_stroke(
		core.with_alpha(palette.light, alpha),
		TERRAIN_STROKE_THICKNESS * GRID_WEIGHT,
	)
	line.glow = 0
	line.core_light = 0
	line.closed = true
	draw_stroke(ring[:], line)
}

// The tunnel behind everything: rings travelling outward from a vanishing
// point, and the spokes they travel along.
//
// A pure function of the clock, like the horizons are of the scroll. The
// rings fade in at the vanishing point and out past the screen's corner,
// so nothing ever pops.
draw_grid :: proc(palette: core.Palette, time: f32) {
	centre := rl.Vector2 {
		GRID_VANISH.x * core.SCREEN_WIDTH,
		GRID_VANISH.y * core.SCREEN_HEIGHT,
	}

	// The spokes, out to well past the corner so none of them stops short.
	reach := f32(core.SCREEN_WIDTH + core.SCREEN_HEIGHT)
	spoke := new_stroke(
		core.with_alpha(palette.light, GRID_SPOKE_ALPHA),
		TERRAIN_STROKE_THICKNESS * GRID_WEIGHT,
	)
	spoke.glow = 0
	spoke.core_light = 0
	for i in 0 ..< GRID_SPOKES {
		angle := f32(i) / f32(GRID_SPOKES) * 2 * math.PI
		line := [2]rl.Vector2 {
			centre,
			{centre.x + math.cos(angle) * reach, centre.y + math.sin(angle) * reach},
		}
		draw_stroke(line[:], spoke)
	}

	// The rings. Their travel is exponential, so a ring is always the same
	// multiple of the one inside it however far along the cycle they are.
	phase := time / GRID_PERIOD
	phase -= math.floor(phase)
	for i in 0 ..< GRID_RINGS {
		step := f32(i) + phase
		scale := GRID_INNER * math.pow(f32(GRID_RING_RATIO), step)

		// In at the vanishing point, out past the corner.
		near := clamp(step / 1.2, 0, 1)
		far := 1 - clamp((scale - 1.0) / 0.8, 0, 1)
		draw_grid_ring(palette, scale, GRID_RING_ALPHA * near * far)
	}
}
