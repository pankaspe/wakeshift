/*
* Corruption
* The world being eaten from the left, as a post-process on the finished
* frame.
*
* It has to be a post-process, because the Corruption is not a level, it
* is a **place**: the world is gone to the left of a boundary and whole to
* its right, and the only stage that knows what x a pixel is at is the one
* holding the finished pixels.
*
* IT GOES TO BLACK, NOT TO GREY (playtest R2.6)
*
* The first version drained each pixel to its own luma, on the design's
* original rule that the Corruption owns saturation while depth owns hue,
* and that form and brightness survive. Built and looked at, the dead
* zone was too faint to read — precisely because the one axis that would
* have made it legible had been forbidden.
*
* So it takes everything. Behind the front there is not a washed-out
* version of what was there, there is nothing: the Corruption eats the
* world rather than draining it (Design Doc, section 5, revised).
*
* It does not put the two colour systems back into collision, which is
* what the original rule was protecting. Convergence with depth is
* **global** and moves the hue; this is **spatial**. They never contend
* for the same pixel — to the right of the front depth is in charge, to
* the left there is nothing left to be in charge of.
*
* And it makes the art rule and the mechanic the same rule, which the
* halfway version never quite did: *scenery is line, danger is mass*, and
* a front that goes to full black is literally line becoming mass.
*
* THE RAMP SITS BEHIND THE FRONT, NOT ACROSS IT
*
* This mattered the moment grey became black. The boundary's lit edge is
* drawn in the world (render/corruption.odin) at exactly front_x, and a
* ramp centred on the front would eat the one mark that says where the
* front *is* — the picture would go dark with nothing to read the edge of.
* So the fade runs from front - softness up to the front itself: the lip
* is untouched, and the void deepens behind it.
*
* Runs **after** the bloom, deliberately: a lit edge's halo is part of the
* picture and has to be eaten along with the edge that threw it. Bloom
* itself is untouched by any of this.
*
* Two blits, because a shader cannot read and write the same texture: the
* frame is consumed into a scratch buffer and copied straight back.
*/
package fx

import rl "vendor:raylib/v55"

// How far behind the front the world takes to go fully dark, as a
// fraction of the frame's width. Soft on purpose: a hard edge reads as a
// wall, which is the mechanic the design explicitly rejected, while a
// gradient reads as something spreading.
CORRUPTION_SOFTNESS :: 0.11

@(private)
VOID_PASS_SOURCE :: `#version 330
in vec2 fragTexCoord;
uniform sampler2D texture0;

// Where the boundary sits, 0..1 across the frame, and how far *behind*
// it the world takes to go fully dark.
uniform float front;
uniform float softness;

out vec4 finalColor;

void main() {
	vec4 texel = texture(texture0, fragTexCoord);

	// 0 at the front itself, rising to 1 a softness behind it. Anchored on
	// the front rather than straddling it, so the lit edge drawn at
	// exactly front_x survives to say where the boundary is.
	float amount = 1.0 - smoothstep(front - softness, front, fragTexCoord.x);

	finalColor = vec4(texel.rgb * (1.0 - amount), texel.a);
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
	corruption.shader = rl.LoadShaderFromMemory(nil, VOID_PASS_SOURCE)
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

// Eats everything behind `front`, in place.
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
