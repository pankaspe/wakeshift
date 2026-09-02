/*
* Glow
* A cheap additive bloom, drawn with primitives instead of a shader
* (roadmap T3.7). Real bloom — bright-pass plus a separable blur over the
* whole frame — is roadmap phase 4; this is what carries the "light"
* half of "silhouette and light" until then, and it stays useful
* afterwards for the few places that want a glow the whole-frame pass
* would not give them.
*
* The technique: draw the same shape several times, each larger and
* fainter than the last, under BLEND_ADDITIVE so overlapping layers
* accumulate into brightness instead of painting over each other. Cost is
* a handful of extra primitives, and it composes with anything already on
* screen.
*
* Two things to know before using it. Additive light *adds*, so a glow on
* a bright background washes it out rather than lighting it — keep the
* backgrounds dark, which the palette already does. And a glow is never
* the only cue for anything: pillar 6 (never color alone) applies to
* light just as much as to hue.
*/
package render

import rl "vendor:raylib/v55"

// More layers is a smoother falloff and more draw calls. Five reads as a
// soft halo; below three the bands are visible.
GLOW_LAYERS :: 5

// Innermost layer's size, as a fraction of the requested radius. The
// layers spread from here out to the full radius.
GLOW_INNER_RATIO :: 0.30

// Alpha of a glow layer at normalized distance t from the center, for a
// glow of the given strength. Quadratic falloff: bright core, long faint
// skirt — closer to how a real bloom looks than a linear ramp.
@(private)
glow_layer_alpha :: proc(t: f32, strength: f32) -> f32 {
	falloff := (1 - t) * (1 - t)
	return strength * falloff / f32(GLOW_LAYERS)
}

// A round halo. strength is 0..1: roughly "how much of the color the
// center of the glow contributes".
draw_glow_circle :: proc(center: rl.Vector2, radius: f32, color: rl.Color, strength: f32) {
	if strength <= 0 || radius <= 0 {
		return
	}

	rl.BeginBlendMode(.ADDITIVE)
	defer rl.EndBlendMode()

	for i in 0 ..< GLOW_LAYERS {
		t := f32(i) / f32(GLOW_LAYERS - 1)
		layer_radius := radius * (GLOW_INNER_RATIO + (1 - GLOW_INNER_RATIO) * t)
		alpha := glow_layer_alpha(t, strength)
		rl.DrawCircleV(center, layer_radius, rl.Color{color.r, color.g, color.b, u8(alpha * 255)})
	}
}

// A glowing line: the lit edge of a silhouette, or the horizon.
// thickness is the innermost layer's weight; the halo grows out to
// thickness * spread.
draw_glow_line :: proc(
	start, end: rl.Vector2,
	thickness: f32,
	spread: f32,
	color: rl.Color,
	strength: f32,
) {
	if strength <= 0 {
		return
	}

	rl.BeginBlendMode(.ADDITIVE)
	defer rl.EndBlendMode()

	for i in 0 ..< GLOW_LAYERS {
		t := f32(i) / f32(GLOW_LAYERS - 1)
		layer_thickness := thickness * (1 + (spread - 1) * t)
		alpha := glow_layer_alpha(t, strength)
		rl.DrawLineEx(
			start,
			end,
			layer_thickness,
			rl.Color{color.r, color.g, color.b, u8(alpha * 255)},
		)
	}
}

// A horizontal band of light fading out above and below a line — the
// horizon's own glow, and later any wide soft light source. Drawn as
// stacked gradient rectangles rather than circles, so it costs the same
// whatever the screen width is.
draw_glow_band :: proc(y: f32, half_height: f32, x, width: f32, color: rl.Color, strength: f32) {
	if strength <= 0 || half_height <= 0 {
		return
	}

	rl.BeginBlendMode(.ADDITIVE)
	defer rl.EndBlendMode()

	core_color := rl.Color{color.r, color.g, color.b, u8(clamp(strength, 0, 1) * 255)}
	edge_color := rl.Color{color.r, color.g, color.b, 0}

	rl.DrawRectangleGradientV(
		i32(x),
		i32(y - half_height),
		i32(width),
		i32(half_height),
		edge_color,
		core_color,
	)
	rl.DrawRectangleGradientV(
		i32(x),
		i32(y),
		i32(width),
		i32(half_height),
		core_color,
		edge_color,
	)
}
