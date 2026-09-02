/*
* Bloom
* Real bloom: a bright-pass, a separable gaussian blur, and an additive
* composite back onto the frame (roadmap T4.1-T4.2). This is what makes
* "silhouette and light" actually read as *light* — until now the palette
* named colors and nothing on screen glowed.
*
* fx knows nothing about the game, and nothing here breaks that: it takes
* a render texture and a handful of numbers. The one concession is
* bloom_for_world, which maps the three-world variables to those numbers —
* those variables live in core, which fx is allowed to see, and putting
* the mapping anywhere else would mean a package that owns the look of
* the light without being allowed to name it.
*
* The pipeline, per frame:
*
*   target ──bright-pass──> bright ──blur H──> blur_a ──blur V──> blur_b
*                                         (twice, at widening offsets)
*     └────────────────── additive composite <───────────────────┘
*
* Three things worth knowing before touching it:
*
* - **The buffers are half the frame's size.** Halving is not only for
*   speed: a blur of a given tap count covers twice as much of the picture
*   when the picture is half as big, so the downscale is buying width as
*   well. The upscale on the way back is bilinear, which is free
*   smoothing.
* - **Everything is LDR.** The frame is an RGBA8 texture, so "bright"
*   means "close to white", not "above 1.0" — the threshold is tuned
*   against a palette whose backgrounds sit around 0.1 and whose rim light
*   sits around 0.6-1.0. An intensity above 1 cannot be a brighter tint
*   (a tint only scales down), so it is drawn as more than one additive
*   pass.
* - **Orientation is handled once, at the end.** Render textures are
*   stored bottom-up, and every pass here draws with a positive source
*   rect, which preserves that convention through the chain; the single
*   flip in platform/present_display still puts the frame the right way
*   up. Introducing a flip in the middle would double it.
*
* A shader that fails to compile disables bloom rather than killing the
* game: the same rule the save file follows, for the same reason.
*/
package fx

import "../core"
import rl "vendor:raylib/v55"

// How much smaller the bright/blur buffers are than the frame.
BLOOM_DOWNSCALE :: 2

// How many horizontal+vertical blur pairs to run, and how much wider the
// taps spread on each one. Two is the point where a third stops being
// visible on this palette.
BLOOM_BLUR_ITERATIONS :: 2
BLOOM_SPREAD_STEP :: 2.0

BloomSettings :: struct {
	// Brightness a pixel needs before it contributes anything, 0..1.
	threshold: f32,

	// Width of the soft ramp above the threshold. Without it, a rim
	// crossing the threshold pops on rather than lighting up.
	knee:      f32,

	// How much of the blurred layer is added back, 0..2.
	intensity: f32,
}

Bloom :: struct {
	bright:        rl.RenderTexture2D,
	blur_a:        rl.RenderTexture2D,
	blur_b:        rl.RenderTexture2D,
	bright_shader: rl.Shader,
	blur_shader:   rl.Shader,
	threshold_loc: i32,
	knee_loc:      i32,
	direction_loc: i32,

	// The frame size the buffers were built for. Compared every frame, so
	// a window resize rebuilds them the same way it rebuilds the frame
	// itself (platform/display.odin).
	source_width:  i32,
	source_height: i32,

	// False when a shader failed to compile. Bloom then does nothing at
	// all and the game runs unlit rather than not running.
	enabled:       bool,
}

// --- Shaders ---
//
// Embedded rather than loaded from disk: the game ships as one binary
// with no asset directory, and a missing .fs file at a player's machine
// would be a crash on startup for no benefit.

@(private)
BRIGHT_PASS_SOURCE :: `#version 330
in vec2 fragTexCoord;
uniform sampler2D texture0;
uniform float threshold;
uniform float knee;
out vec4 finalColor;

void main() {
	vec3 color = texture(texture0, fragTexCoord).rgb;

	// Brightness as the strongest channel, not luminance: this palette
	// glows in saturated golds and pinks, and a luminance weighting would
	// quietly decide that blue light is dimmer than it looks.
	float brightness = max(color.r, max(color.g, color.b));

	// Soft knee, so a rim brightening into the threshold fades in.
	float contribution = clamp((brightness - threshold) / max(knee, 0.0001), 0.0, 1.0);

	finalColor = vec4(color * contribution, 1.0);
}
`

@(private)
BLUR_SOURCE :: `#version 330
in vec2 fragTexCoord;
uniform sampler2D texture0;

// One texel step along the axis being blurred, already scaled by this
// iteration's spread. The pass is separable: the same shader runs once
// horizontally and once vertically.
uniform vec2 direction;
out vec4 finalColor;

const float weights[5] = float[](0.227027, 0.194595, 0.121622, 0.054054, 0.016216);

void main() {
	vec3 result = texture(texture0, fragTexCoord).rgb * weights[0];
	for (int i = 1; i < 5; i++) {
		vec2 offset = direction * float(i);
		result += texture(texture0, fragTexCoord + offset).rgb * weights[i];
		result += texture(texture0, fragTexCoord - offset).rgb * weights[i];
	}
	finalColor = vec4(result, 1.0);
}
`

// Builds the shaders. Buffers are allocated lazily on the first frame,
// because the frame's size is not known until there is a frame.
new_bloom :: proc() -> Bloom {
	bloom := Bloom{}

	bloom.bright_shader = rl.LoadShaderFromMemory(nil, BRIGHT_PASS_SOURCE)
	bloom.blur_shader = rl.LoadShaderFromMemory(nil, BLUR_SOURCE)

	if !rl.IsShaderValid(bloom.bright_shader) || !rl.IsShaderValid(bloom.blur_shader) {
		return bloom // enabled stays false
	}

	bloom.threshold_loc = rl.GetShaderLocation(bloom.bright_shader, "threshold")
	bloom.knee_loc = rl.GetShaderLocation(bloom.bright_shader, "knee")
	bloom.direction_loc = rl.GetShaderLocation(bloom.blur_shader, "direction")
	bloom.enabled = true
	return bloom
}

destroy_bloom :: proc(bloom: Bloom) {
	unload_buffers(bloom)
	rl.UnloadShader(bloom.bright_shader)
	rl.UnloadShader(bloom.blur_shader)
}

@(private)
unload_buffers :: proc(bloom: Bloom) {
	if bloom.bright.id != 0 {
		rl.UnloadRenderTexture(bloom.bright)
		rl.UnloadRenderTexture(bloom.blur_a)
		rl.UnloadRenderTexture(bloom.blur_b)
	}
}

@(private)
rebuild_buffers :: proc(bloom: ^Bloom, source_width, source_height: i32) {
	unload_buffers(bloom^)

	width := max(source_width / BLOOM_DOWNSCALE, 1)
	height := max(source_height / BLOOM_DOWNSCALE, 1)

	bloom.bright = rl.LoadRenderTexture(width, height)
	bloom.blur_a = rl.LoadRenderTexture(width, height)
	bloom.blur_b = rl.LoadRenderTexture(width, height)

	for texture in ([]rl.Texture2D{bloom.bright.texture, bloom.blur_a.texture, bloom.blur_b.texture}) {
		rl.SetTextureFilter(texture, .BILINEAR)

		// Clamp, or the blur wraps light from one edge of the screen onto
		// the other — most visible exactly where the terrain's lit edge
		// runs off the side.
		rl.SetTextureWrap(texture, .CLAMP)
	}

	bloom.source_width = source_width
	bloom.source_height = source_height
}

// Draws a whole texture onto whatever surface is currently bound, scaled
// to fill it. Source rect stays positive on purpose — see the note about
// orientation in the file header.
@(private)
draw_fullscreen :: proc(texture: rl.Texture2D, width, height: i32, tint: rl.Color) {
	source := rl.Rectangle{0, 0, f32(texture.width), f32(texture.height)}
	destination := rl.Rectangle{0, 0, f32(width), f32(height)}
	rl.DrawTexturePro(texture, source, destination, rl.Vector2{0, 0}, 0, tint)
}

// Adds bloom to the frame, in place. Call after the frame is finished and
// before it is presented.
apply_bloom :: proc(bloom: ^Bloom, target: rl.RenderTexture2D, settings: BloomSettings) {
	if !bloom.enabled || settings.intensity <= 0 {
		return
	}

	if target.texture.width != bloom.source_width ||
	   target.texture.height != bloom.source_height {
		rebuild_buffers(bloom, target.texture.width, target.texture.height)
	}

	width := bloom.bright.texture.width
	height := bloom.bright.texture.height

	// 1. Bright pass, downscaling into the smaller buffer as it goes.
	threshold := settings.threshold
	knee := settings.knee
	rl.SetShaderValue(bloom.bright_shader, bloom.threshold_loc, &threshold, .FLOAT)
	rl.SetShaderValue(bloom.bright_shader, bloom.knee_loc, &knee, .FLOAT)

	rl.BeginTextureMode(bloom.bright)
	rl.ClearBackground(rl.BLANK)
	rl.BeginShaderMode(bloom.bright_shader)
	draw_fullscreen(target.texture, width, height, rl.WHITE)
	rl.EndShaderMode()
	rl.EndTextureMode()

	// 2. Separable blur, ping-ponging between the two buffers. Each
	// iteration reaches further than the last, which is a wide gaussian
	// for the price of a narrow one run twice.
	texel_x := 1.0 / f32(width)
	texel_y := 1.0 / f32(height)
	source := bloom.bright

	rl.BeginShaderMode(bloom.blur_shader)
	for iteration in 0 ..< BLOOM_BLUR_ITERATIONS {
		spread := f32(1) + f32(iteration) * (BLOOM_SPREAD_STEP - 1)

		horizontal := rl.Vector2{texel_x * spread, 0}
		rl.SetShaderValue(bloom.blur_shader, bloom.direction_loc, &horizontal, .VEC2)
		rl.BeginTextureMode(bloom.blur_a)
		rl.ClearBackground(rl.BLANK)
		draw_fullscreen(source.texture, width, height, rl.WHITE)
		rl.EndTextureMode()

		vertical := rl.Vector2{0, texel_y * spread}
		rl.SetShaderValue(bloom.blur_shader, bloom.direction_loc, &vertical, .VEC2)
		rl.BeginTextureMode(bloom.blur_b)
		rl.ClearBackground(rl.BLANK)
		draw_fullscreen(bloom.blur_a.texture, width, height, rl.WHITE)
		rl.EndTextureMode()

		source = bloom.blur_b
	}
	rl.EndShaderMode()

	// 3. Composite. A tint can only scale a color down, so an intensity
	// above 1 is drawn as a full pass plus a partial one rather than as a
	// brighter white that RGBA8 could not hold anyway.
	rl.BeginTextureMode(target)
	rl.BeginBlendMode(.ADDITIVE)
	remaining := clamp(settings.intensity, 0, 2)
	for remaining > 0 {
		pass := min(remaining, 1)
		tint := rl.Color{255, 255, 255, u8(pass * 255)}
		draw_fullscreen(source.texture, target.texture.width, target.texture.height, tint)
		remaining -= pass
	}
	rl.EndBlendMode()
	rl.EndTextureMode()
}

// --- How much the world glows ---
//
// Design Doc, section 12, read as three settings rather than three
// adjectives: hard in the Real world, invasive in the Dream, overexposed
// in the Limen.

// Hard light: a high threshold, so only the lit edges themselves bloom
// and everything else stays sharp. This is the world where shapes have
// weight and outlines mean something.
// The thresholds are set against what actually reaches the frame, not
// against the palette's own values: a rim is drawn at partial alpha over
// a dark background, so a light of 0.91 lands at about 0.66. Tuned from
// the palette instead, the Real world's bloom measured as a 1% gain on
// the brightest row — technically present, invisible in practice.
REAL_BLOOM :: BloomSettings {
	threshold = 0.50,
	knee      = 0.25,
	intensity = 0.70,
}

// Overexposed: almost everything clears the threshold, and it is added
// back at more than full strength. The threshold between waking and
// sleeping is meant to be the hardest place on screen to look at
// steadily — but it is also where the player is *choosing* to be, which
// is why the intensity stops where it does instead of whiting out.
LIMEN_BLOOM :: BloomSettings {
	threshold = 0.30,
	knee      = 0.34,
	intensity = 1.30,
}

// Invasive: a low threshold and a strong return, so the warm light in the
// Dream world spills past the shapes that emit it.
DREAM_BLOOM :: BloomSettings {
	threshold = 0.38,
	knee      = 0.30,
	intensity = 1.05,
}

@(private)
lerp_bloom :: proc(a, b: BloomSettings, t: f32) -> BloomSettings {
	k := clamp(t, 0, 1)
	return BloomSettings {
		threshold = a.threshold + (b.threshold - a.threshold) * k,
		knee = a.knee + (b.knee - a.knee) * k,
		intensity = a.intensity + (b.intensity - a.intensity) * k,
	}
}

// The bloom the player's height and the run's depth ask for.
//
// Interpolated in exactly the same two segments as the palette
// (core/palette.odin) and converged toward the Limen by the same amount,
// because the light and the colors have to be describing one world. If
// these two ever drift apart, the picture stops agreeing with itself.
bloom_for_world :: proc(world_t, depth_t: f32) -> BloomSettings {
	t := clamp(world_t, 0, 1)

	settings: BloomSettings
	if t <= 0.5 {
		settings = lerp_bloom(REAL_BLOOM, LIMEN_BLOOM, t * 2)
	} else {
		settings = lerp_bloom(LIMEN_BLOOM, DREAM_BLOOM, (t - 0.5) * 2)
	}

	convergence := clamp(depth_t, 0, 1) * core.CONVERGENCE_MAX
	return lerp_bloom(settings, LIMEN_BLOOM, convergence)
}
