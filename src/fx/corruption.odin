/*
* Corruption
* The colour dying from the left, as a post-process on the finished frame.
*
* It has to be a post-process rather than a palette value, and the reason
* is worth stating because the palette *does* have a corruption axis. That
* axis takes a scalar: one number for the whole picture. The Corruption is
* not a level, it is a **place** — the colour is dead to the left of a
* boundary and alive to its right — and the only stage that knows what x a
* pixel is at is the one that has the finished pixels.
*
* What the scalar axis in core/palette.odin buys, then, is not the effect
* but the *rule*: collapse a colour to its own luma, so the colour dies
* and the light does not. The shader below is the same arithmetic with the
* same Rec. 709 weights, and the two must stay in step — an equal-weight
* average here would make the corrupted side change exposure as well as
* hue, which is the one thing the two-axis split exists to prevent.
*
* Runs **after** the bloom, deliberately. The halo of a lit edge is part
* of the picture, so the boundary has to grey it along with everything
* else; running before would leave a coloured bloom hanging over a grey
* world at exactly the seam the player is meant to be reading. Bloom
* itself is untouched by any of this, which is the promise: what the
* Corruption takes is the colour, never the light.
*
* Two blits, because a shader cannot read and write the same texture: the
* frame is desaturated into a scratch buffer and copied straight back.
*/
package fx

import rl "vendor:raylib/v55"

// How wide the ramp back to full colour is, as a fraction of the frame's
// width. The boundary is soft on purpose — a hard edge reads as a wall,
// which is the mechanic the design explicitly rejected, while a gradient
// reads as something spreading.
CORRUPTION_SOFTNESS :: 0.11

@(private)
DESATURATE_SOURCE :: `#version 330
in vec2 fragTexCoord;
uniform sampler2D texture0;

// Where the boundary sits, 0..1 across the frame, and how far to its
// right the colour takes to come fully back.
uniform float front;
uniform float softness;

out vec4 finalColor;

void main() {
	vec4 texel = texture(texture0, fragTexCoord);

	// 1 everywhere left of the front, easing to 0 over the ramp.
	float amount = 1.0 - smoothstep(front, front + softness, fragTexCoord.x);

	// Rec. 709 luma, matching core.desaturate_color exactly. An
	// equal-weight average would collapse a saturated blue to a grey far
	// brighter than it looked: only the colour is meant to die here.
	float luma = dot(texel.rgb, vec3(0.2126, 0.7152, 0.0722));

	finalColor = vec4(mix(texel.rgb, vec3(luma), amount), texel.a);
}
`

Corruption :: struct {
	scratch:       rl.RenderTexture2D,
	shader:        rl.Shader,
	front_loc:     i32,
	softness_loc:  i32,
	source_width:  i32,
	source_height: i32,

	// False when the shader failed to compile. The frame then keeps its
	// colour and the game still runs — but see the note in main.odin: the
	// front is also *drawn*, so it stays visible either way. A killer the
	// player cannot see would break pillar 3, and a shader is not
	// something to stake that on.
	enabled:       bool,
}

new_corruption :: proc() -> Corruption {
	corruption := Corruption{}
	corruption.shader = rl.LoadShaderFromMemory(nil, DESATURATE_SOURCE)
	if !rl.IsShaderValid(corruption.shader) {
		return corruption // enabled stays false
	}
	corruption.front_loc = rl.GetShaderLocation(corruption.shader, "front")
	corruption.softness_loc = rl.GetShaderLocation(corruption.shader, "softness")
	corruption.enabled = true
	return corruption
}

destroy_corruption :: proc(corruption: Corruption) {
	if corruption.scratch.id != 0 {
		rl.UnloadRenderTexture(corruption.scratch)
	}
	rl.UnloadShader(corruption.shader)
}

@(private)
rebuild_scratch :: proc(corruption: ^Corruption, width, height: i32) {
	if corruption.scratch.id != 0 {
		rl.UnloadRenderTexture(corruption.scratch)
	}
	corruption.scratch = rl.LoadRenderTexture(width, height)
	rl.SetTextureFilter(corruption.scratch.texture, .BILINEAR)
	rl.SetTextureWrap(corruption.scratch.texture, .CLAMP)
	corruption.source_width = width
	corruption.source_height = height
}

// Drains the colour out of everything left of `front`, in place.
//
// `front` is 0..1 across the frame, so this knows nothing about the
// game's coordinate space, its canvas size, or what is doing the
// corrupting. Call after apply_bloom and before the frame is presented.
apply_corruption :: proc(corruption: ^Corruption, target: rl.RenderTexture2D, front: f32) {
	if !corruption.enabled || front <= 0 {
		return
	}

	if target.texture.width != corruption.source_width ||
	   target.texture.height != corruption.source_height {
		rebuild_scratch(corruption, target.texture.width, target.texture.height)
	}

	width := target.texture.width
	height := target.texture.height

	boundary := clamp(front, 0, 1)
	softness := f32(CORRUPTION_SOFTNESS)
	rl.SetShaderValue(corruption.shader, corruption.front_loc, &boundary, .FLOAT)
	rl.SetShaderValue(corruption.shader, corruption.softness_loc, &softness, .FLOAT)

	rl.BeginTextureMode(corruption.scratch)
	rl.BeginShaderMode(corruption.shader)
	draw_fullscreen(target.texture, width, height, rl.WHITE)
	rl.EndShaderMode()
	rl.EndTextureMode()

	rl.BeginTextureMode(target)
	draw_fullscreen(corruption.scratch.texture, width, height, rl.WHITE)
	rl.EndTextureMode()
}
