/*
* Palette
* The three-world color system and the two continuous variables that
* drive it (Design Doc, section 12).
*
*   world_t  where the player is vertically: 0 = floor (Real), 0.5 =
*            middle (Limen), 1 = ceiling (Dream). Continuous, never
*            stepped — this is what makes a flip look like a crossing
*            instead of a state change.
*   depth_t  how far into the run we are: as it grows, the Real and
*            Dream palettes both converge toward the Limen's washed-out
*            one, until the two worlds stop being told apart by color
*            (the "convergence", Design Doc section 12). Position and
*            type of motion are what carry the player from there on.
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

// Design Doc, section 12. Starting values, to be refined on screen.
REAL_PALETTE :: Palette {
	deep       = rl.Color{0x0B, 0x0F, 0x17, 255},
	near       = rl.Color{0x18, 0x22, 0x31, 255},
	silhouette = rl.Color{0x05, 0x07, 0x0B, 255},
	light      = rl.Color{0x8F, 0xB8, 0xE8, 255},
	accent     = rl.Color{0xD8, 0xE8, 0xFF, 255},
}

LIMEN_PALETTE :: Palette {
	deep       = rl.Color{0x1A, 0x1B, 0x26, 255},
	near       = rl.Color{0x3A, 0x35, 0x50, 255},
	silhouette = rl.Color{0x0A, 0x09, 0x10, 255},
	light      = rl.Color{0xF0, 0xE6, 0xD2, 255},
	accent     = rl.Color{0xFF, 0xF6, 0xE0, 255},
}

DREAM_PALETTE :: Palette {
	deep       = rl.Color{0x2A, 0x0D, 0x33, 255},
	near       = rl.Color{0x4E, 0x1B, 0x5C, 255},
	silhouette = rl.Color{0x0B, 0x04, 0x10, 255},
	light      = rl.Color{0xFF, 0xAE, 0x5C, 255},
	accent     = rl.Color{0xFF, 0x6F, 0xBE, 255},
}

// Shared line weights for the whole project — one "pen" for every
// silhouette, rather than a per-element decision. Moved here from
// screen.odin now that there is a palette file to hold it: a border
// weight and a border color are the same decision.
RIM_THICKNESS :: 1.8 // dark separation line, used sparingly now
LIGHT_RIM_THICKNESS :: 2.6 // the lit edge that reads as the light source

// How far the two worlds travel toward the Limen at maximum depth.
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
	limen:       Palette,
	dream:       Palette,

	// Sampled at world_t: the palette of "wherever the player is right
	// now", which is what the player's own body and light sample from.
	current:     Palette,
	world_t:     f32,
	depth_t:     f32,

	// How alive each world is, 0..1 (they do not sum to 1 by accident:
	// at the Limen both are half alive, which is the point).
	real_alive:  f32,
	dream_alive: f32,
}

// Interpolates Real -> Limen over the lower half of world_t and
// Limen -> Dream over the upper half. Two segments rather than one
// straight Real -> Dream blend, because the Limen has a palette of its
// own and is not the average of the other two (Design Doc, section 12).
sample_palette :: proc(set: PaletteSet, world_t: f32) -> Palette {
	t := clamp(world_t, 0, 1)
	if t <= 0.5 {
		return lerp_palette(set.real, set.limen, t * 2)
	}
	return lerp_palette(set.limen, set.dream, (t - 0.5) * 2)
}

new_palette_set :: proc(world_t: f32, depth_t: f32) -> PaletteSet {
	convergence := clamp(depth_t, 0, 1) * CONVERGENCE_MAX

	set := PaletteSet {
		real        = lerp_palette(REAL_PALETTE, LIMEN_PALETTE, convergence),
		limen       = LIMEN_PALETTE,
		dream       = lerp_palette(DREAM_PALETTE, LIMEN_PALETTE, convergence),
		world_t     = clamp(world_t, 0, 1),
		depth_t     = clamp(depth_t, 0, 1),
		real_alive  = 1 - clamp(world_t, 0, 1),
		dream_alive = clamp(world_t, 0, 1),
	}
	set.current = sample_palette(set, set.world_t)
	return set
}

// The palette of a world that is currently the *other* one: its
// background and its light fade toward the Limen, its silhouette does
// not. Silhouettes stay solid black-ish in every world on purpose — they
// are how the player reads shapes, and readability outranks mood
// (pillar 2).
dormant_palette :: proc(palette: Palette, limen: Palette, alive: f32) -> Palette {
	fade := (1 - clamp(alive, 0, 1)) * DORMANT_FADE
	faded := palette
	faded.deep = lerp_color(palette.deep, limen.deep, fade)
	faded.near = lerp_color(palette.near, limen.deep, fade)
	faded.light = lerp_color(palette.light, limen.deep, fade)
	faded.accent = lerp_color(palette.accent, limen.light, fade)
	return faded
}
