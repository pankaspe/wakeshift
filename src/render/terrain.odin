/*
* Terrain
* Draws the two lanes — and, since phase RL, that is the whole of the
* world. There is no fill any more: the floor and the ceiling are two
* continuous strokes, and everything that stands on them is drawn *in*
* them (Design Doc, section 10 — La Linea).
*
* It does not decide where they are. Since phase 7.5 the profile lives in
* core/track.odin, because the player and the obstacles stand on it: this
* file draws the surface the simulation is already using, and the two
* cannot drift apart because there is only one of them.
*
* THE LINE IS THE WORLD, SO THE LINE CARRIES THE OBSTACLES
*
* Phase RL.2 moved the cube out of render/obstacle.odin and into this
* polyline. A cube on a lane is no longer a box drawn over the ground: it
* is the ground itself lifting away and coming back, one mark with two
* right angles in it. That is the new readability rule doing its work —
*
*     the world curves, the danger corners
*
* — which is geometric rather than about fill, and is therefore the one
* half of the old "scenery is line, danger is mass" that survived the
* change of direction. The stack and the pyramid are the same step at a
* different height and a different top profile; the pyramid's staircase
* falls out of the polyline for free, exactly the way the track's own
* relief does.
*
* The only cube this file does not draw is the floating one, because it
* is the one cube that is not on the surface (render/obstacle.odin).
*
* A GAP IS THE LINE STOPPING
*
* It is the only discontinuity in the game, and that is now literally
* true: the outline is cut at the hole's edges and drawn as separate
* strokes. It was once a dark box sitting *on top of* the floor line,
* which is why the design's "full vs void" pairing never landed.
*
* **Both sides break the same way, mirrored.** The stroke turns out of
* the corridor at the lip — down off the floor, up off the ceiling —
* which puts two more right angles in it: a cut, and a lethal one either
* way up.
*
* It was asymmetric until 5 September: the ceiling ran on past the lip,
* tapered to nothing and lit the opening with a halo, on the reading that
* overhead an absence is a way through rather than a fall (Design Doc,
* section 5). That went out when the obstacle set came down to two. With
* only a hole and a cube left, each has to be one mark that means one
* thing wherever it appears, and a soft lit disc in the middle of the
* corridor was read as *something standing there* — the failure mode a
* hole cannot afford, because a hole is the absence of anything.
*
* How the cutting works: the surface is a function of x, not a fixed list
* of points, so the outline is built once across the whole screen and
* then clipped to whatever the holes leave of it. Vertices land exactly
* on the cut, so a hole is never snapped to a keyframe.
*/
package render

import "../core"
import "../game"
import "core:slice"
import rl "vendor:raylib/v55"

// The mark the world is drawn with, at the weight the *live* lane gets.
// It used to be a rim light running along the top of a filled mass; with
// the fill gone it *is* the mass, so it carries more weight, more light
// and more halo than the rim did.
//
// It is also the rung of the weight hierarchy everything else is measured
// against (Design Doc, section 10): the character is a multiple of it
// above, the dormant lane a fraction of it below.
TERRAIN_STROKE_THICKNESS :: 2.8
TERRAIN_CORE_LIGHT :: 0.30
TERRAIN_GLOW_STRENGTH :: 0.45
TERRAIN_GLOW_SPREAD :: 5.5

// What the sleeping lane keeps of that weight, and of that opacity.
//
// RL.4's decision, and it is the one the phase was named for: the two
// lanes are **not** both drawn full. La Linea has one line; we have two,
// and two identical parallel strokes read as a tube rather than as a
// world with a floor and something above it. The asymmetry is not "the
// ceiling is secondary" — it follows the player, so what thins is always
// the lane they are not in.
//
// Thinner *and* fainter, as the doc asks, but neither taken far: the line
// is no longer backed by a silhouette, so this is the whole of the
// dormant lane's presence, and it is still the boundary between ground
// and air. Losing it would cost readability (pillar 2) to buy mood.
TERRAIN_DORMANT_WEIGHT :: 0.70
TERRAIN_RIM_DORMANT :: 0.55
TERRAIN_RIM_ALIVE :: 0.85

// How far past each screen edge the terrain is built, so a hole whose
// edge is just off screen still cuts correctly. Comfortably more than one
// profile entry at the fastest tier, which is 74 px wide.
TERRAIN_MARGIN :: 100

// How far a broken lane turns out of the corridor at the lip, in pixels.
// Down off the floor, up off the ceiling — the same mark mirrored, which
// is what makes a hole one obstacle instead of two.
CHASM_WALL_DEPTH :: 22


// Two points closer together than this are the same point. A clipped
// outline can produce one when a cut lands exactly on a vertex, and a
// zero-length segment gives the stroke a rib with no direction.
TERRAIN_EPSILON :: 0.01

// The surface height at any screen x, from the shared profile.
//
// A thin wrapper on core rather than a copy of it: a hole can begin
// anywhere, so the spans on either side of it need a vertex exactly at
// its edge, and asking for the surface as a function of x is what makes
// that possible.
terrain_surface_y :: proc(world: game.World, is_floor: bool, x: f32) -> f32 {
	return game.get_surface_y(world, is_floor ? core.Lane.Real : core.Lane.Dream, x)
}

// A range of screen x.
Span :: struct {
	start: f32,
	end:   f32,
}

// One cube, as the piece of surface it replaces. The rect is the box the
// collision uses, so the mark and the hitbox are the same thing by
// construction rather than by agreement.
@(private)
Step :: struct {
	start: f32,
	end:   f32,
	rect:  rl.Rectangle,
	form:  game.CubeForm,
}

// Every cube standing on one lane, left to right and never overlapping.
//
// The floating cube is excluded: it is the one form that is not on the
// surface, so it cannot be a step in it, and render/obstacle.odin keeps
// it. An overlapping cube is dropped rather than merged, because the
// outline walks x forward and cannot go back — authored patterns do not
// produce one, and swallowing it is better than tearing the line.
@(private)
collect_steps :: proc(
	world: game.World,
	obstacles: []game.Obstacle,
	lane: core.Lane,
	allocator := context.temp_allocator,
) -> [dynamic]Step {
	found := make([dynamic]Step, 0, 8, allocator)

	for obstacle in obstacles {
		if obstacle.obstacle_type != .Cube || obstacle.lane != lane {
			continue
		}
		if obstacle.cube == .Float {
			continue
		}
		rect := game.get_obstacle_rect(obstacle, world)
		if rect.width <= 0 {
			continue
		}
		if rect.x + rect.width < -TERRAIN_MARGIN || rect.x > core.SCREEN_WIDTH + TERRAIN_MARGIN {
			continue
		}
		append(
			&found,
			Step{start = rect.x, end = rect.x + rect.width, rect = rect, form = obstacle.cube},
		)
	}

	slice.sort_by(found[:], proc(a, b: Step) -> bool {return a.start < b.start})

	kept := make([dynamic]Step, 0, len(found), allocator)
	cursor := f32(-1e9)
	for step in found {
		if step.start < cursor {
			continue
		}
		append(&kept, step)
		cursor = step.end
	}
	return kept
}

// Every stretch of one lane's surface that a hole has taken out of it, in
// screen x, sorted and merged.
//
// Merging matters: two gaps that touch have no ground between them, and
// drawing the zero-width piece that separates them would put a stroke
// down the middle of a hole.
collect_gap_spans :: proc(
	world: game.World,
	obstacles: []game.Obstacle,
	lane: core.Lane,
	allocator := context.temp_allocator,
) -> [dynamic]Span {
	found := make([dynamic]Span, 0, 8, allocator)

	for obstacle in obstacles {
		if !game.is_gap(obstacle.obstacle_type) || obstacle.lane != lane {
			continue
		}
		rect := game.get_obstacle_rect(obstacle, world)
		start := max(rect.x, -TERRAIN_MARGIN)
		end := min(rect.x + rect.width, core.SCREEN_WIDTH + TERRAIN_MARGIN)
		if end > start {
			append(&found, Span{start = start, end = end})
		}
	}

	slice.sort_by(found[:], proc(a, b: Span) -> bool {return a.start < b.start})

	merged := make([dynamic]Span, 0, len(found), allocator)
	for span in found {
		if len(merged) > 0 && span.start <= merged[len(merged) - 1].end {
			last := &merged[len(merged) - 1]
			last.end = max(last.end, span.end)
			continue
		}
		append(&merged, span)
	}
	return merged
}

// What is left of one side once the gaps are taken out of it.
//
// `right` is the draw front since RL.5, not the edge of the world, so a
// gap that has not been reached yet has to be clamped rather than
// subtracted: cutting at a hole the pen has not drawn would put the
// hole's own end-of-line mark where the pen is.
solid_spans :: proc(
	gaps: []Span,
	left, right: f32,
	allocator := context.temp_allocator,
) -> [dynamic]Span {
	spans := make([dynamic]Span, 0, len(gaps) + 1, allocator)

	cursor := left
	for gap in gaps {
		if gap.start >= right {
			break
		}
		if gap.start > cursor {
			append(&spans, Span{start = cursor, end = min(gap.start, right)})
		}
		cursor = max(cursor, gap.end)
		if cursor >= right {
			return spans
		}
	}
	if cursor < right {
		append(&spans, Span{start = cursor, end = right})
	}
	return spans
}

// Appends a point unless it is the one already there. A cut landing
// exactly on a vertex would otherwise hand the stroke a rib with no
// direction to build its ribbon from.
@(private)
push_point :: proc(points: ^[dynamic]rl.Vector2, point: rl.Vector2) {
	if len(points) > 0 {
		last := points[len(points) - 1]
		if abs(last.x - point.x) < TERRAIN_EPSILON && abs(last.y - point.y) < TERRAIN_EPSILON {
			return
		}
	}
	append(points, point)
}

// The surface between two x values, sampled at the track's own keyframes.
//
// The vertices are keyframes, spaced in time rather than in pixels, so
// how far apart they land on screen is the scroll speed — the undulation
// stretches as a run gets faster (core/track.odin). Nothing else is
// needed, because the profile is linear between them.
@(private)
append_surface :: proc(
	points: ^[dynamic]rl.Vector2,
	world: game.World,
	is_floor: bool,
	from, to: f32,
) {
	if to <= from {
		return
	}
	ground := game.get_ground(world)
	start_time := core.ground_time_at_x(ground, from)
	end_time := core.ground_time_at_x(ground, to)

	for i in 0 ..< world.track.count {
		point := world.track.points[i]
		if point.time <= start_time {
			continue
		}
		if point.time >= end_time {
			break
		}
		x := from + (point.time - start_time) * max(ground.speed, 1)
		if x > from && x < to {
			push_point(points, rl.Vector2{x, terrain_surface_y(world, is_floor, x)})
		}
	}
}

// The far side of a step: two right angles for every form but the
// pyramid, which is a staircase of them.
//
// Read off the obstacle's own rectangle rather than off the surface, so
// the top of the mark is exactly the top of the hitbox. The two vertical
// faces are implied — this appends the far edge at the same x the caller
// already put the surface at, and the polyline goes straight up.
@(private)
append_step :: proc(points: ^[dynamic]rl.Vector2, step: Step, is_floor: bool) {
	// The edge of the box furthest from the lane it stands on. Hanging
	// from the ceiling is the same picture with the mirror applied.
	far_y := is_floor ? step.rect.y : step.rect.y + step.rect.height

	if step.form != .Pyramid {
		push_point(points, rl.Vector2{step.start, far_y})
		push_point(points, rl.Vector2{step.end, far_y})
		return
	}

	// Cubes in a staircase, rising away from the player: the low step is
	// met first, which is what says in advance which side to be on.
	base_y := is_floor ? step.rect.y + step.rect.height : step.rect.y
	grow := is_floor ? f32(-1) : f32(1)
	columns := max(int(step.rect.width / game.CUBE_UNIT), 1)
	width := step.rect.width / f32(columns)

	for column in 0 ..< columns {
		top := base_y + grow * f32(column + 1) * game.CUBE_UNIT
		left := step.start + f32(column) * width
		push_point(points, rl.Vector2{left, top})
		push_point(points, rl.Vector2{left + width, top})
	}
}

// One lane, as a single polyline running the width of the screen with
// every cube welded into it. The holes are not cut here — they are taken
// out afterwards, so that a cube straddling a hole's edge is clipped
// rather than mis-authored into a broken shape.
@(private)
build_lane_outline :: proc(
	world: game.World,
	obstacles: []game.Obstacle,
	lane: core.Lane,
	allocator := context.temp_allocator,
) -> [dynamic]rl.Vector2 {
	steps := collect_steps(world, obstacles, lane, allocator)
	is_floor := lane == core.Lane.Real

	// A cube may reach past the margin; the line has to start before it
	// and end after it, or its vertical face would be drawn at the wrong
	// x. Both ends are off screen either way.
	left := f32(-TERRAIN_MARGIN)
	right := f32(core.SCREEN_WIDTH + TERRAIN_MARGIN)
	if len(steps) > 0 {
		left = min(left, steps[0].start)
		right = max(right, steps[len(steps) - 1].end)
	}

	points := make([dynamic]rl.Vector2, 0, 96, allocator)
	push_point(&points, rl.Vector2{left, terrain_surface_y(world, is_floor, left)})

	cursor := left
	for step in steps {
		append_surface(&points, world, is_floor, cursor, step.start)
		push_point(&points, rl.Vector2{step.start, terrain_surface_y(world, is_floor, step.start)})
		append_step(&points, step, is_floor)
		push_point(&points, rl.Vector2{step.end, terrain_surface_y(world, is_floor, step.end)})
		cursor = step.end
	}

	append_surface(&points, world, is_floor, cursor, right)
	push_point(&points, rl.Vector2{right, terrain_surface_y(world, is_floor, right)})
	return points
}

// The part of an outline between two x values, with vertices interpolated
// onto the two cuts.
//
// The outline walks x forward and never back, so a segment either lies
// inside the window, outside it, or crosses one of its edges — which is
// what makes this a walk rather than a general polygon clip. A vertical
// face is two points at the same x and is kept or dropped whole.
@(private)
clip_outline :: proc(
	outline: []rl.Vector2,
	from, to: f32,
	allocator := context.temp_allocator,
) -> [dynamic]rl.Vector2 {
	piece := make([dynamic]rl.Vector2, 0, len(outline), allocator)
	if to <= from || len(outline) < 2 {
		return piece
	}

	for i in 0 ..< len(outline) - 1 {
		a := outline[i]
		b := outline[i + 1]
		if b.x < from || a.x > to {
			continue
		}
		if a.x < from && b.x > a.x {
			t := (from - a.x) / (b.x - a.x)
			push_point(&piece, rl.Vector2{from, a.y + (b.y - a.y) * t})
		} else if a.x >= from && a.x <= to {
			push_point(&piece, a)
		}
		if b.x > to && b.x > a.x {
			t := (to - a.x) / (b.x - a.x)
			push_point(&piece, rl.Vector2{to, a.y + (b.y - a.y) * t})
		}
	}

	last := outline[len(outline) - 1]
	if last.x >= from && last.x <= to {
		push_point(&piece, last)
	}
	return piece
}

// Everything one lane needs to know about how it is lit: its own colours,
// how awake its world is, and the scene-wide gain toward the Dream.
//
// One value rather than three loose floats, because every drawing
// procedure below needs all three and none of them needs anything else.
@(private)
LaneLight :: struct {
	palette: core.Palette,
	alive:   f32,
	gain:    GlowGain,
}

@(private)
lane_light :: proc(palettes: core.PaletteSet, is_floor: bool) -> LaneLight {
	return LaneLight {
		palette = is_floor ? palettes.real : palettes.dream,
		alive = is_floor ? palettes.real_alive : palettes.dream_alive,
		gain = glow_gain(palettes.world_t),
	}
}

// The mark one lane's line is drawn with. Weight, opacity and halo all
// grow with how awake that world is; the colour does not, because the two
// worlds are told apart by the field behind them (art direction, decision
// 1). On top of that the whole scene burns brighter toward the Dream,
// which is decision 4 and is the same number everywhere on screen.
@(private)
terrain_stroke :: proc(light: LaneLight) -> Stroke {
	alpha := TERRAIN_RIM_DORMANT + (TERRAIN_RIM_ALIVE - TERRAIN_RIM_DORMANT) * light.alive
	weight := TERRAIN_DORMANT_WEIGHT + (1 - TERRAIN_DORMANT_WEIGHT) * light.alive

	line := new_stroke(
		core.with_alpha(light.palette.light, alpha),
		TERRAIN_STROKE_THICKNESS * weight,
	)
	line.glow = TERRAIN_GLOW_STRENGTH * (0.45 + 0.55 * light.alive)
	line.spread = TERRAIN_GLOW_SPREAD
	line.core_light = TERRAIN_CORE_LIGHT
	apply_glow_gain(&line, light.gain)
	return line
}

// One unbroken stretch of one lane, as a single mark.
//
// broken_start / broken_end say whether that end of the piece is a hole
// rather than the edge of the screen, which is the only thing that
// decides what happens there.
@(private)
draw_terrain_piece :: proc(
	piece: ^[dynamic]rl.Vector2,
	light: LaneLight,
	is_floor: bool,
	broken_start, broken_end: bool,
) {
	if len(piece) < 2 {
		return
	}

	// The lane ends: the line turns out of the corridor at the lip. Two
	// more right angles, and the mark says "cut" rather than "fade" —
	// which is the truth, because this is the danger that kills outright.
	//
	// **Both lanes, mirrored, and that is deliberate.** Until 5 September
	// the ceiling did something else entirely: it ran on past the lip,
	// tapered to nothing, and lit the opening with a halo, on the theory
	// that overhead an absence is a way out rather than a fall. It was
	// dropped because the game now has exactly two obstacles and they have
	// to be legible as two: a big soft disc in the middle of the corridor
	// reads as a *thing that is there* — it was mistaken for an emitter by
	// the person who designed it — and the whole point of a hole is that
	// nothing is there. One hole, one mark, whichever way up you are.
	wall := is_floor ? f32(CHASM_WALL_DEPTH) : f32(-CHASM_WALL_DEPTH)
	if broken_start {
		lip := piece[0]
		inject_at(piece, 0, rl.Vector2{lip.x, lip.y + wall})
	}
	if broken_end {
		lip := piece[len(piece) - 1]
		append(piece, rl.Vector2{lip.x, lip.y + wall})
	}

	draw_stroke(piece[:], terrain_stroke(light))
}

@(private)
draw_terrain_side :: proc(
	world: game.World,
	obstacles: []game.Obstacle,
	palettes: core.PaletteSet,
	front_x: f32,
	is_floor: bool,
) {
	lane := is_floor ? core.Lane.Real : core.Lane.Dream
	light := lane_light(palettes, is_floor)

	outline := build_lane_outline(world, obstacles, lane)
	if len(outline) < 2 {
		return
	}
	// The world exists between the two fronts and nowhere else: written by
	// the pen on the right (RL.5), eaten by the Corruption on the left
	// (RL.6). Two lines of arithmetic, and between them they are the whole
	// of both ideas — which is what RL.2 bought by putting the obstacles
	// inside this polyline (render/draw_front.odin, render/corruption.odin).
	left := max(outline[0].x, front_x)
	right := min(outline[len(outline) - 1].x, DRAW_FRONT_X)
	if right <= left {
		return
	}

	gaps := collect_gap_spans(world, obstacles, lane)

	// Where this lane's line currently ends under the pen, if it ends
	// there at all: a hole straddling the front means there is nothing to
	// put a nib on, because what is being drawn right now is an absence.
	pen: rl.Vector2
	drawing := false

	for span in solid_spans(gaps[:], left, right) {
		piece := clip_outline(outline[:], span.start, span.end)
		broken_end := span.end < right - TERRAIN_EPSILON
		if !broken_end && len(piece) >= 2 {
			pen = piece[len(piece) - 1]
			drawing = true
		}
		draw_terrain_piece(
			&piece,
			light,
			is_floor,
			span.start > left + TERRAIN_EPSILON,
			broken_end,
		)
	}

	if drawing {
		draw_nib(pen, palettes)
	}
}

// front_x is the Corruption's boundary: nothing left of it is drawn,
// because there is nothing there any more.
draw_terrain :: proc(
	world: game.World,
	obstacles: []game.Obstacle,
	palettes: core.PaletteSet,
	front_x: f32,
) {
	draw_terrain_side(world, obstacles, palettes, front_x, true) // floor
	draw_terrain_side(world, obstacles, palettes, front_x, false) // ceiling
}
