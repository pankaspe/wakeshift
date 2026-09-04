/*
* Palette
* The three-world color system and the two continuous variables that
* drive it (Design Doc, section 12).
*
*   world_t  where the player is vertically: 0 = floor (Real), 1 =
*            ceiling (Dream), and everything in between while a flip is
*            crossing. Continuous, never stepped — this is what makes a
*            flip look like a crossing instead of a state change.
*   depth_t  how far into the run we are: as it grows, the Real and
*            Dream palettes both converge toward the neutral palette's washed-out
*            one, until the two worlds stop being told apart by color
*            (the "convergence", Design Doc section 12). Position and
*            type of motion are what carry the player from there on.
*
* There is no third variable here, and there deliberately is not. The
* Corruption also changes the colour of everything, but it is a **place**
* rather than a level — the world is gone to the left of a front and whole
* to its right — so it cannot be a number a whole-screen palette carries.
* It is applied to the finished frame instead (fx/corruption.odin). This
* file briefly had a scalar corruption axis with the colour rule in it;
* the rule went with it when the front started eating to black.
*
* Why this lives in core and not in render, against what CLAUDE.md said:
* ui draws menus, the HUD and the options screen out of the same palette
* the game world uses, and ui may not import render. Same reasoning that
* already put Input and Settings here — it is shared vocabulary, not a
* rendering technique. render/palette.odin keeps the half that does need
* game state: turning a Player and a World into world_t and depth_t.
*
* The rule "no hardcoded colors anywhere else" is unchanged. This file is
* now the one place that names a color.
*/
package core

import rl "vendor:raylib/v55"

// The five roles every element samples from. Each of the three worlds
// fills all five, so any drawing code can ask for "the light color"
// without knowing which world is currently alive.
Palette :: struct {
	deep:       rl.Color, // far background, at the horizon
	near:       rl.Color, // near background, at the floor/ceiling edge
	silhouette: rl.Color, // every solid body: player, obstacles, terrain
	light:      rl.Color, // rim light and glow
	accent:     rl.Color, // the one thing allowed to shout
}

// The three palettes, sampled from the art direction (`docs/sketch/
// sketch_3.jpeg`) rather than invented: teal and cyan below, violet and
// lavender above, and a blazing white-cyan threshold between them.
//
// **They are darker than the sketch on purpose, and only in value.** The
// hue and the saturation are the sketch's; the brightness is not. The
// sketch is a flat illustration whose glow is painted in, while this
// frame gets a real bloom pass afterwards — and that pass takes
// max(r,g,b) against a threshold of 0.30 to 0.50 (fx/bloom.odin). The
// sketch's sky peaks at 0.68, so adopting it literally would put the
// whole background through the bright pass and turn the screen into
// haze. The brightness the sketch has in its sky is therefore spent
// where it belongs here: in `light` and `accent`, which are what the
// bloom is supposed to find.
//
// Every background value below is kept under the *lowest* threshold it
// can ever meet, not merely under its own world's. That distinction was
// found by measuring rather than by reading: the bloom settings are
// interpolated on world_t, so a player halfway through a flip is lit by
// the neutral palette's threshold of 0.30 while the floor at the bottom
// of the screen is still drawn in the Real palette. The first version of
// this table put real.near at 0.369, which is comfortably under Real's
// own 0.50 and blooms at 20% every time the character crosses the middle.
// The margins are arithmetic, not opinion — see ROADMAP.md, "La palette".
//
// The other reason the sketch reads lighter than this will is that its
// brightness is mostly *drawn*: clouds, aurora, plants, all of it hollow
// lit outline. That is scenery, and scenery is phase R7. Closing the
// remaining gap is that job, not this table's.

// The world below: cold teal, cyan light, green accent.
REAL_PALETTE :: Palette {
	deep       = rl.Color{0x16, 0x32, 0x3F, 255}, // max channel 0.247
	near       = rl.Color{0x1A, 0x3E, 0x4C, 255}, // 0.298: under the *neutral* 0.30, not just Real's 0.50
	silhouette = rl.Color{0x05, 0x0C, 0x11, 255},
	light      = rl.Color{0x5F, 0xE0, 0xF0, 255},
	accent     = rl.Color{0x8C, 0xF5, 0xB8, 255},
}

// The threshold between them, and the colour both worlds converge toward
// as a run gets deeper. In the sketch this is the horizon: the brightest
// thing on screen by a wide margin.
//
// Its background values are the tightest in the table, because its bloom
// threshold is the lowest (0.30) *and* deep convergence pulls both other
// palettes onto these numbers — so a value that blooms here blooms across
// the entire late game.
NEUTRAL_PALETTE :: Palette {
	deep       = rl.Color{0x23, 0x2B, 0x3E, 255}, // 0.243
	near       = rl.Color{0x33, 0x3D, 0x54, 255}, // 0.329: a whisper over 0.30, deliberately
	silhouette = rl.Color{0x07, 0x08, 0x10, 255},
	light      = rl.Color{0xE4, 0xFA, 0xFF, 255},
	accent     = rl.Color{0xF2, 0xFD, 0xFF, 255},
}

// The world above: violet, lavender light, pink accent.
//
// Its light used to be orange and its accent hot pink — a warm world
// against a cold one, which was a reasonable idea and is not what the art
// direction says. The sketch's upper half is lavender and rose over
// violet, and warm orange was the single loudest thing on screen that the
// sketches never contained.
DREAM_PALETTE :: Palette {
	deep       = rl.Color{0x2C, 0x1F, 0x42, 255}, // 0.259
	near       = rl.Color{0x3A, 0x24, 0x50, 255}, // 0.314, under Dream's 0.38
	silhouette = rl.Color{0x0A, 0x06, 0x14, 255},
	light      = rl.Color{0xB7, 0x9B, 0xF7, 255},
	accent     = rl.Color{0xFF, 0x9F, 0xE2, 255},
}

// Shared line weights for the whole project — one "pen" for every
// silhouette, rather than a per-element decision. Moved here from
// screen.odin now that there is a palette file to hold it: a border
// weight and a border color are the same decision.
RIM_THICKNESS :: 1.8 // dark separation line, used sparingly now
LIGHT_RIM_THICKNESS :: 2.6 // the lit edge that reads as the light source

// How far the two worlds travel toward the neutral palette at maximum depth.
// Deliberately short of 1: at full convergence the palettes are nearly
// indistinguishable, but the horizon must not vanish outright or the
// screen stops having a top and a bottom at all.
CONVERGENCE_MAX :: 0.72

// How far a world's background dims while the player is in the other
// one. Also short of 1: the dormant world stays visible, it just stops
// being the one that is alive (Design Doc, section 12 — both worlds are
// always on screen).
DORMANT_FADE :: 0.55

// --- Color math ---

lerp_color :: proc(a, b: rl.Color, t: f32) -> rl.Color {
	k := clamp(t, 0, 1)
	return rl.Color {
		u8(f32(a.r) + (f32(b.r) - f32(a.r)) * k),
		u8(f32(a.g) + (f32(b.g) - f32(a.g)) * k),
		u8(f32(a.b) + (f32(b.b) - f32(a.b)) * k),
		u8(f32(a.a) + (f32(b.a) - f32(a.a)) * k),
	}
}

// Same color at a different opacity. Takes 0..1 rather than 0..255 so
// call sites read as "a third of the way" instead of "85".
with_alpha :: proc(color: rl.Color, alpha: f32) -> rl.Color {
	result := color
	result.a = u8(clamp(alpha, 0, 1) * 255)
	return result
}

// Darkens toward black without touching alpha. Used for text and HUD
// tiers, where a second, dimmer weight of the same color says "secondary"
// more clearly than a different hue would.
dim_color :: proc(color: rl.Color, amount: f32) -> rl.Color {
	k := 1 - clamp(amount, 0, 1)
	return rl.Color{u8(f32(color.r) * k), u8(f32(color.g) * k), u8(f32(color.b) * k), color.a}
}

// Lifts a color toward white without touching alpha — the opposite of
// dim_color, and the reason both live here rather than at their call
// sites: white and black are colors too, and the rule is that no file
// outside this one writes one down.
//
// What it is for is the core of a light source. A neon line is not its
// own color at the centre: the color is what the light does to the air
// around it, and the middle of it is closer to white the brighter it is.
lighten_color :: proc(color: rl.Color, amount: f32) -> rl.Color {
	white := rl.Color{255, 255, 255, color.a}
	result := lerp_color(color, white, amount)
	result.a = color.a
	return result
}

lerp_palette :: proc(a, b: Palette, t: f32) -> Palette {
	return Palette {
		deep = lerp_color(a.deep, b.deep, t),
		near = lerp_color(a.near, b.near, t),
		silhouette = lerp_color(a.silhouette, b.silhouette, t),
		light = lerp_color(a.light, b.light, t),
		accent = lerp_color(a.accent, b.accent, t),
	}
}

// --- The per-frame palette state ---

// The three palettes as they stand at the current depth, plus the single
// blend the player's position selects out of them. Built once per frame
// and passed down; nothing recomputes it per element.
PaletteSet :: struct {
	real:        Palette,
	neutral:       Palette,
	dream:       Palette,

	// Sampled at world_t: the palette of "wherever the player is right
	// now", which is what the player's own body and light sample from.
	current:     Palette,
	world_t:     f32,
	depth_t:     f32,

	// How alive each world is, 0..1 (they do not sum to 1 by accident:
	// at the neutral palette both are half alive, which is the point).
	real_alive:  f32,
	dream_alive: f32,
}

// Interpolates Real -> neutral over the lower half of world_t and
// neutral -> Dream over the upper half. Two segments rather than one
// straight Real -> Dream blend, because the neutral palette is not the
// average of the other two: it is what both worlds converge toward with
// depth, so the blend has to actually pass through it (Design Doc,
// section 10).
sample_palette :: proc(set: PaletteSet, world_t: f32) -> Palette {
	t := clamp(world_t, 0, 1)
	if t <= 0.5 {
		return lerp_palette(set.real, set.neutral, t * 2)
	}
	return lerp_palette(set.neutral, set.dream, (t - 0.5) * 2)
}

new_palette_set :: proc(world_t: f32, depth_t: f32) -> PaletteSet {
	convergence := clamp(depth_t, 0, 1) * CONVERGENCE_MAX

	set := PaletteSet {
		real        = lerp_palette(REAL_PALETTE, NEUTRAL_PALETTE, convergence),
		neutral     = NEUTRAL_PALETTE,
		dream       = lerp_palette(DREAM_PALETTE, NEUTRAL_PALETTE, convergence),
		world_t     = clamp(world_t, 0, 1),
		depth_t     = clamp(depth_t, 0, 1),
		real_alive  = 1 - clamp(world_t, 0, 1),
		dream_alive = clamp(world_t, 0, 1),
	}
	set.current = sample_palette(set, set.world_t)
	return set
}

// The palette of a world that is currently the *other* one: its
// background and its light fade toward the neutral palette, its silhouette does
// not. Silhouettes stay solid black-ish in every world on purpose — they
// are how the player reads shapes, and readability outranks mood
// (pillar 2).
dormant_palette :: proc(palette: Palette, neutral: Palette, alive: f32) -> Palette {
	fade := (1 - clamp(alive, 0, 1)) * DORMANT_FADE
	faded := palette
	faded.deep = lerp_color(palette.deep, neutral.deep, fade)
	faded.near = lerp_color(palette.near, neutral.deep, fade)
	faded.light = lerp_color(palette.light, neutral.deep, fade)
	faded.accent = lerp_color(palette.accent, neutral.light, fade)
	return faded
}
