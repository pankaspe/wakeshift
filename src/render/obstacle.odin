/*
* Obstacle Render
* Draws each obstacle type with a shape that reads as what it represents,
* not a generic rectangle (Design Doc, section 12). Real lane obstacles
* are natural/solid (stone, cracked earth); Dream lane obstacles are
* organic/unnatural (pulsing membrane, torn rift).
*
* Every obstacle is a silhouette in the palette of its own world, lit
* along its edge by that world's light (roadmap T3.5). Nothing here picks
* a color of its own: an obstacle in the Dream lane goes violet or washes
* out with the convergence without this file knowing that happened.
*
* The two void types are **not drawn here**. A Chasm and a Dream Hole are
* the ground failing to exist, and the only code that knows where the
* ground is, is the terrain — so it cuts its own holes and this file
* returns early for them (render/terrain.odin). Drawing them here is what
* made them read as boxes standing on the floor for the whole of the
* prototype.
*/
package render

import "../core"
import "../game"
import rl "vendor:raylib/v55"

// How strongly an obstacle's lit edge glows. Lower than the terrain's:
// obstacles are small and numerous, and a halo on each one would eat the
// contrast that makes them readable at 400 px/s (pillar 2).
OBSTACLE_GLOW_STRENGTH :: 0.22
OBSTACLE_GLOW_SPREAD :: 4

draw_obstacle :: proc(obstacle: game.Obstacle, world: game.World, palettes: core.PaletteSet) {
	position := game.get_obstacle_position(obstacle, world)
	size := game.get_obstacle_size(obstacle, world)

	is_real := obstacle.lane == .Real
	palette := is_real ? palettes.real : palettes.dream
	alive := is_real ? palettes.real_alive : palettes.dream_alive

	switch obstacle.obstacle_type {
	case .Block:
		draw_block(position, size, palette, alive)

	case .PulsingShape:
		draw_pulsing_shape(position, size, palette, alive)

	case .Feint:
		// It has to be indistinguishable from the thing it is pretending
		// to be, or it is not a bluff — the tell is that it retracts, in
		// full view, with time to spare (game/obstacle.odin).
		if size.y <= 0 {
			return
		}
		if is_real {
			draw_block(position, size, palette, alive)
		} else {
			draw_pulsing_shape(position, size, palette, alive)
		}

	case .Patroller:
		draw_patroller(position, size, palettes)

	case .Chasm, .DreamHole, .Step:
	// drawn by the terrain, which owns where its own surface is
	}
}

// --- Patroller: the one presence that crosses the whole column ---

// It samples the palette at its *own* height rather than its lane's, so
// it takes on the colour of wherever it currently is — cold near the
// floor, washed out through the middle, warm against the ceiling. That
// is the accessibility rule paying for itself: the thing that tells you
// where it is, is also the thing that tells you which world it is in.
PATROLLER_GLOW :: 0.40
PATROLLER_CORE_RATIO :: 0.42

draw_patroller :: proc(position, size: rl.Vector2, palettes: core.PaletteSet) {
	center := rl.Vector2{position.x + size.x * 0.5, position.y + size.y * 0.5}
	radius := size.x * 0.5

	local_t := 1 - center.y / core.SCREEN_HEIGHT
	palette := core.sample_palette(palettes, local_t)

	draw_glow_circle(center, radius * 2.6, palette.accent, PATROLLER_GLOW)
	rl.DrawCircleV(center, radius, palette.silhouette)
	rl.DrawCircleLinesV(center, radius, core.with_alpha(palette.light, 0.75))

	// A bright core, so the silhouette does not disappear against a dark
	// background at the exact moment it matters — this is the only
	// obstacle that can be anywhere vertically, including in front of the
	// darkest part of the picture.
	rl.DrawCircleV(center, radius * PATROLLER_CORE_RATIO, palette.accent)
}

// --- Block: an irregular stone ---

// Normalized (0..1) outline of an irregular rock, hand-authored once.
// Scaled and positioned to each obstacle's actual size/position at draw time.
block_shape_points := [8]rl.Vector2 {
	{0.65, 1.00},
	{0.95, 0.75},
	{1.00, 0.35},
	{0.75, 0.05},
	{0.45, 0.00},
	{0.20, 0.15},
	{0.00, 0.55},
	{0.10, 1.00},
}

draw_block :: proc(position, size: rl.Vector2, palette: core.Palette, alive: f32) {
	points: [8]rl.Vector2
	for point, i in block_shape_points {
		points[i] = rl.Vector2{position.x + point.x * size.x, position.y + point.y * size.y}
	}

	rl.DrawTriangleFan(raw_data(points[:]), i32(len(points)), palette.silhouette)
	draw_lit_outline(points[:], palette, alive)
}

// Draws a closed outline (last point connects back to the first) in the
// world's light: a hard line always, plus an additive halo that grows
// with how alive that world is. This is what replaces the flat black
// border every shape used to carry.
draw_lit_outline :: proc(points: []rl.Vector2, palette: core.Palette, alive: f32) {
	rim_color := core.with_alpha(palette.light, 0.35 + 0.45 * alive)

	for i in 0 ..< len(points) {
		next := (i + 1) % len(points)
		draw_glow_line(
			points[i],
			points[next],
			core.RIM_THICKNESS,
			OBSTACLE_GLOW_SPREAD,
			palette.light,
			OBSTACLE_GLOW_STRENGTH * alive,
		)
	}
	for i in 0 ..< len(points) {
		next := (i + 1) % len(points)
		rl.DrawLineEx(points[i], points[next], core.RIM_THICKNESS, rim_color)
	}
}

// --- Pulsing Shape: an organic membrane hanging from the ceiling ---

// Drawn as a stack of overlapping circles, tapering toward the tip —
// reads as a soft, organic blob rather than a rigid mechanical shape.
// Size (especially size.y) is already animated by get_obstacle_size, so
// this just needs to render whatever height it's given.
PULSING_LAYER_COUNT :: 5
PULSING_TIP_GLOW :: 0.35

draw_pulsing_shape :: proc(position, size: rl.Vector2, palette: core.Palette, alive: f32) {
	center_x := position.x + size.x * 0.5

	for i in 0 ..< PULSING_LAYER_COUNT {
		t := f32(i) / f32(PULSING_LAYER_COUNT - 1) // 0 at ceiling, 1 at tip
		radius := size.x * 0.5 * (1 - t * 0.3) // tapers slightly toward the tip
		center_y := position.y + size.y * t

		// Dark where it grows out of the ceiling, lit at the tip: the tip
		// is the part that reaches into the lane, so it is the part that
		// has to announce itself.
		rl.DrawCircleV(
			rl.Vector2{center_x, center_y},
			radius,
			core.lerp_color(palette.silhouette, palette.accent, t * 0.85),
		)
	}

	tip := rl.Vector2{center_x, position.y + size.y}
	draw_glow_circle(
		tip,
		size.x * 0.9,
		palette.accent,
		PULSING_TIP_GLOW * (0.4 + 0.6 * alive),
	)

	// A faint lit rim where it meets the ceiling, so it doesn't look like
	// it's floating in front of it.
	rl.DrawCircleLinesV(
		rl.Vector2{center_x, position.y},
		size.x * 0.5,
		core.with_alpha(palette.light, 0.25 + 0.35 * alive),
	)
}
