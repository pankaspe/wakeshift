/*
* Background
* The field: the one filled surface in the whole game (Design Doc,
* section 10 — "il quadro"). Every other mark on screen is a stroke drawn
* on top of it.
*
* Three passes, and the order is the argument. The field, then the
* parallax (render/parallax.odin), then the vignette over both — so the
* lens dims the distant horizons along with everything else. Drawn the
* other way round, the thinnest mark on screen would be the one thing the
* vignette could not reach, and it would pull the eye exactly where the
* vignette is trying to stop it going.
*
* THE FIELD IS THE WORLD
*
* Phase RL replaced the old sky — Dream above, Real below, a lit horizon
* between them — with a single field whose colour *is* the world the
* player is in. That is decision 1 of the art direction: the two worlds
* are told apart by the colour behind the line, never by the line itself,
* so the stroke reads as "the world" rather than as "a thing that
* changes", and a flip becomes an event across the whole screen instead
* of a bright band in the middle of it.
*
* The horizon went with the split, and so did its glow: with the field
* changing colour wholesale there is nothing left for a band of light in
* the middle of the screen to say that the field is not already saying
* louder.
*
* THE FIELD LAGS, AND THAT IS THE POINT
*
* A flip lasts 0.16 s and a burst is three of them back to back. A field
* that followed world_t literally would strobe, so it chases instead, on
* a time constant of its own (BACKGROUND_LAG). During a burst it sits
* somewhere in the middle rather than slamming between the two worlds,
* and a single deliberate flip reads as a slow wash across the frame.
*
* The chased value is **presentation only**: it is advanced from the
* frame clock in main, next to display_time, and never reaches the
* simulation. Two consequences worth knowing:
*
*   - The background can be Dream-coloured while the player is lit by the
*     Real world's bloom, and vice versa. That is why every `near` in
*     core/palette.odin is now under the *lowest* bloom threshold there
*     is rather than under its own world's — see the comment there.
*   - It is not a state and does not need to be reset between runs. It
*     simply arrives, a second late, wherever the player already is.
*
* THE VIGNETTE IS A SCREEN FIXTURE
*
* It does not ride the corridor's spine the way the old sky did. That
* rule existed because a horizon nailed to the screen while the world
* slid up and down underneath it read as two pictures; a vignette is not
* part of the world's geometry but of the lens looking at it, so it stays
* where the lens is. Its job (decision 3) is to push the eye to the
* middle, where the game is played, and to keep the field under the
* stroke in value, contrast and detail everywhere else.
*
* It is baked once into a small mask texture rather than assembled from
* gradient rectangles every frame. Two half-screen linear gradients meet
* at a slope discontinuity, and a kink in a ramp this shallow is a Mach
* band; a mask lets the falloff be a real smoothstep with no kink
* anywhere, and costs one 256x144 texture.
*
* The edges go *darker than* the palette's own `deep`, which is legal in
* the direction the bloom does not care about, and buys the gradient
* three times the levels it used to have to spend — see fx/dither.odin
* for the other half of that fight.
*/
package render

import "../core"
import "core:math"
import rl "vendor:raylib/v55"

// How long the field takes to catch up with the player, as the time
// constant of an exponential chase: it covers 63% of the remaining
// distance in this many seconds, 95% in three times it.
//
// At 0.45 a single flip (0.16 s) moves the field about a quarter of the
// way while the character is still crossing, and the wash finishes about
// a second after they land. Three flips in a burst leave it near the
// middle, which is the whole reason it exists.
BACKGROUND_LAG :: 0.45

// The vignette mask. Small on purpose: it is stretched over the canvas
// with bilinear filtering, and at 5x the interpolation error is well
// under one 8-bit level of the field it is fading.
VIGNETTE_MASK_WIDTH :: 256
VIGNETTE_MASK_HEIGHT :: 144

// The falloff, in units where 1.0 is half the screen's height.
//
// The horizontal axis is squashed so the bright region is a wide band
// rather than a circle: the corridor runs the full width of the screen
// and the whole of it has to stay readable, while there is nothing above
// or below it that needs to be looked at.
VIGNETTE_X_SCALE :: 0.72
VIGNETTE_INNER :: 0.20 // flat and bright inside this radius
VIGNETTE_OUTER :: 1.25 // fully dark by here, which the corners reach

// How far past `deep` the edges go, as a fraction darkened toward black.
// The bloom only constrains how *bright* a filled surface may be, so this
// direction is free — and spending it buys levels: 48 of them across the
// vertical falloff against the 13 the old sky had.
VIGNETTE_DEPTH :: 0.55

// The field is never quite still, so a paused frame does not look like a
// static image. It breathes the vignette's strength and not its colour:
// a couple of levels at the edges, nothing at all in the middle.
BACKGROUND_BREATH_PERIOD :: 7.0
BACKGROUND_BREATH_RANGE :: 0.05

// The mask, built once at startup. Held by main and passed in, the same
// way fx holds its buffers: render/ owns no globals.
Background :: struct {
	vignette: rl.Texture2D,
}

new_background :: proc() -> Background {
	pixels: [VIGNETTE_MASK_WIDTH * VIGNETTE_MASK_HEIGHT]rl.Color

	for y in 0 ..< VIGNETTE_MASK_HEIGHT {
		dy := (f32(y) + 0.5) / VIGNETTE_MASK_HEIGHT * 2 - 1
		for x in 0 ..< VIGNETTE_MASK_WIDTH {
			dx := ((f32(x) + 0.5) / VIGNETTE_MASK_WIDTH * 2 - 1) * VIGNETTE_X_SCALE
			radius := math.sqrt(dx * dx + dy * dy)
			amount := math.smoothstep(f32(VIGNETTE_INNER), f32(VIGNETTE_OUTER), radius)

			// White with the falloff in alpha: drawn over the field it
			// tints to the edge colour, so one texture serves whatever
			// pair of colours the current world happens to be.
			pixels[y * VIGNETTE_MASK_WIDTH + x] = rl.Color{255, 255, 255, u8(amount * 255 + 0.5)}
		}
	}

	image := rl.Image {
		data    = raw_data(pixels[:]),
		width   = VIGNETTE_MASK_WIDTH,
		height  = VIGNETTE_MASK_HEIGHT,
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}

	texture := rl.LoadTextureFromImage(image)
	rl.SetTextureFilter(texture, .BILINEAR)
	return Background{vignette = texture}
}

destroy_background :: proc(background: Background) {
	rl.UnloadTexture(background.vignette)
}

// One step of the field's chase toward where the player actually is.
// Framerate independent: the same wall time produces the same result
// whatever the frame rate, which a plain lerp per frame would not.
chase_background_t :: proc(current: f32, target: f32, dt: f32) -> f32 {
	if dt <= 0 {
		return current
	}
	k := 1 - math.exp(-dt / BACKGROUND_LAG)
	return current + (target - current) * k
}

// Fills the frame with the world the player is arriving in.
//
// background_t is the *chased* position, not the player's own — see the
// file header. time is wall time and drives nothing but the breathing.
// scroll is how far the world has travelled, for the parallax alone:
// the run's own scroll_offset in a game, the wall clock behind a menu.
draw_background :: proc(
	background: Background,
	palettes: core.PaletteSet,
	background_t: f32,
	time: f32,
	scroll: f32,
) {
	// The same two-segment blend the palette itself uses, so the field
	// passes through the neutral world instead of averaging past it.
	field := core.sample_palette(palettes, background_t)

	breath := (math.sin(time / BACKGROUND_BREATH_PERIOD * 2 * math.PI) + 1) * 0.5
	strength := 1 - BACKGROUND_BREATH_RANGE + BACKGROUND_BREATH_RANGE * breath

	rl.DrawRectangle(0, 0, core.SCREEN_WIDTH, core.SCREEN_HEIGHT, field.near)

	// Under the vignette, and out of the same lagged palette the field
	// itself is drawn from: the horizons belong to the background, not to
	// the world standing in front of it.
	draw_parallax(field, scroll)

	edge := core.dim_color(field.deep, VIGNETTE_DEPTH)
	rl.DrawTexturePro(
		background.vignette,
		rl.Rectangle{0, 0, VIGNETTE_MASK_WIDTH, VIGNETTE_MASK_HEIGHT},
		rl.Rectangle{0, 0, core.SCREEN_WIDTH, core.SCREEN_HEIGHT},
		rl.Vector2{0, 0},
		0,
		core.with_alpha(edge, strength),
	)
}
