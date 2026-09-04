/*
* Dither
* One level of noise over the finished frame, to break the banding in the
* background's gradients (ROADMAP.md, note 2 of the R2.6 playtest).
*
* WHY THE BANDS ARE THERE
*
* They are not a colour mistake and they do not go away by retuning the
* palette. The palette deliberately keeps every filled surface under the
* lowest bloom threshold there is, which leaves a background gradient
* only a few dozen 8-bit levels to spend across most of the screen — a
* flat step every several pixels, and every one of those steps is a
* straight horizontal line hundreds of pixels long. The eye finds long
* coherent edges; that is all a Mach band is.
*
* Raising the contrast of the field would fix the banding and break the
* bloom margin: they are one decision seen from two sides. Noise is the
* third option, and it costs neither.
*
* WHAT THIS DOES AND WHAT IT DOES NOT
*
* Be exact about it, because the word "dithering" promises more than this
* delivers. Proper dithering perturbs a value *before* it is quantised,
* and by the time a pass can read the frame the quantisation has already
* happened — the information the bands are missing is gone. What this
* does is add one level to a scattered half of the pixels, which leaves
* the step between two bands exactly where it was and buries the straight
* line it makes under noise of the same amplitude. The contour stops
* being coherent, which is the part the eye was reading.
*
* Measured on a real frame: 49.5% of pixels lifted by exactly one level
* and none by anything else, the widest flat run down the field's ramp
* falling from 16 px to 8, and a mean shift of +0.495 of a level.
*
* WHERE IT RUNS, AND WHY THERE
*
* At the *output* resolution, on the render target, after the bloom and
* before the Corruption:
*
*   - Native, because a dither pattern has to land on the pixel grid it
*     is dithering. Drawn inside the game canvas it would be scaled by
*     the camera and each noise pixel would become a block.
*   - After the bloom, and this one is not a preference. The palette
*     holds every filled surface at 76/255 = 0.298, a bare half-level
*     under the lowest bloom threshold in the game. Lifting a field pixel
*     by one puts it at 0.302 — over. Run before the bloom, this pass
*     would hand the bright pass half of the background; run after it,
*     the bright pass never sees a pixel this touched.
*   - Before the Corruption, so the void behind the front stays pure
*     black. One level of speckle in a dead zone is one level too many,
*     and the front's own edge was measured bit-identical against a
*     black it can multiply all the way down.
*
* No shader: it is one tiled texture drawn additively, so there is
* nothing here that can fail to compile.
*/
package fx

import rl "vendor:raylib/v55"

// Size of the noise tile, repeated across the frame. Big enough that the
// repeat is not a pattern the eye can lock onto at one level of
// amplitude, small enough to be free.
DITHER_TILE :: 64

Dither :: struct {
	enabled: bool,
	tile:    rl.Texture2D,
}

new_dither :: proc() -> Dither {
	pixels: [DITHER_TILE * DITHER_TILE]rl.Color

	// A fixed xorshift rather than the run's generator or a global one:
	// this is a texture built once at startup, it must be the same every
	// launch, and fx is not allowed to know that a seeded run exists.
	state: u32 = 0x9E3779B9
	for i in 0 ..< len(pixels) {
		state ~= state << 13
		state ~= state >> 17
		state ~= state << 5

		// Value 1, not 255. Under BLEND_ADDITIVE with full alpha the
		// source colour is added as it stands, so this adds exactly one
		// 8-bit level and nothing else — the smallest mark the frame can
		// hold.
		lit: u8 = state & 1 == 0 ? 0 : 1
		pixels[i] = rl.Color{lit, lit, lit, 255}
	}

	image := rl.Image {
		data    = raw_data(pixels[:]),
		width   = DITHER_TILE,
		height  = DITHER_TILE,
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}

	texture := rl.LoadTextureFromImage(image)

	// Repeat is what makes one tile cover the frame; point sampling is
	// what keeps a noise pixel a pixel instead of a smudge.
	rl.SetTextureWrap(texture, .REPEAT)
	rl.SetTextureFilter(texture, .POINT)

	return Dither{enabled = true, tile = texture}
}

destroy_dither :: proc(dither: Dither) {
	rl.UnloadTexture(dither.tile)
}

// Adds the noise to the frame, in place, at one texel per output pixel.
apply_dither :: proc(dither: Dither, target: rl.RenderTexture2D) {
	if !dither.enabled {
		return
	}

	width := f32(target.texture.width)
	height := f32(target.texture.height)

	rl.BeginTextureMode(target)
	defer rl.EndTextureMode()

	rl.BeginBlendMode(.ADDITIVE)
	defer rl.EndBlendMode()

	// A source rectangle larger than the tile is what turns the wrap mode
	// into tiling. Positive height, like every other pass in this package:
	// the frame is flipped exactly once, in present_display.
	rl.DrawTexturePro(
		dither.tile,
		rl.Rectangle{0, 0, width, height},
		rl.Rectangle{0, 0, width, height},
		rl.Vector2{0, 0},
		0,
		rl.WHITE,
	)
}
