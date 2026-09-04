/*
* Stroke
* The neon line: the single mark the whole art direction is made of.
*
* Both governing sketches are built from one thing — a luminous line of
* varying weight with round ends. raylib has no such primitive.
* DrawLineEx is a bare quad: consecutive segments leave a wedge of
* background showing at every turn, and the ends stop square. Building it
* once is the highest-leverage graphics code in the project, because the
* terrain's lit edge, the plants, the trees, the mushrooms and every menu
* screen are the same mark at different weights (roadmap T7.5.2).
*
* Three passes over one piece of geometry:
*
*   the ribbon, built once. The polyline becomes a list of ribs — a
*      point, the direction to push its two edges apart, and a width
*      factor — which every pass then reuses at a different weight.
*   the halo, outward. GLOW_LAYERS passes under BLEND_ADDITIVE, each
*      wider and fainter, sharing glow.odin's falloff so that a stroke
*      and a plain halo drawn next to each other agree.
*   the core, last. One pass at the stroke's own alpha, lifted toward
*      white: a neon line is not its own colour at the centre, the colour
*      is what the light does to the air around it.
*
* Two details are there to keep the additive pass honest, and both are
* about the same failure. Overlapping geometry drawn additively adds
* twice, so anywhere the ribbon covers itself becomes a bright bead. The
* joins are therefore mitred rather than stamped with a circle, and the
* round ends are tessellated *into* the ribbon rather than drawn over it.
* A circle is only used where a mitre genuinely cannot exist — a turn so
* sharp the spike would run away — and there the bead is hidden by the
* fold anyway. (The terrain's rim has been double-adding at every vertex
* since phase 3, which is what this replaces.)
*
* It knows nothing about the game, deliberately: only points, a colour
* and a weight go in. If phase 13 wants it in the menus, ui may not
* import render — so either ui gains that import, or this file and
* glow.odin move down into a package of their own. It is written to make
* that a file move rather than a rewrite.
*/
package render

import "../core"
import "core:math"
import rl "vendor:raylib/v55"

// Longest polyline the primitive will draw. The geometry lives in fixed
// storage rather than being allocated per call: a frame draws dozens of
// strokes, and most of them are short.
//
// One of them is not, since phase RL.2: a lane is a single mark running
// the width of the screen, carrying a keyframe every few dozen pixels
// and four more points for every cube welded into it. A polyline longer
// than this is silently truncated, which would be a line that stops in
// mid air, so the headroom is deliberate — a measured worst case is
// around fifty.
STROKE_MAX_POINTS :: 256

// How many ribs a round end is tessellated into. Five is smooth at any
// weight this game uses; the cost is five extra pairs of vertices.
STROKE_CAP_STEPS :: 5

// How far a mitre may stretch, in half-widths, before the join is
// rounded instead. Beyond roughly this the spike is longer than the
// stroke is wide, which reads as a thorn rather than a corner.
STROKE_MITER_LIMIT :: 2.2

// Where the halo begins, as a multiple of the core's width.
//
// Not 1, and the difference is the whole quality of the mark. The layers
// nearest the core are the bright ones, so starting them at the core's
// own width spends them *under* it, where the opaque pass paints over
// them: measured on a 6 px stroke, the profile fell from 642 to 36 in a
// single pixel, which is a line with an outline rather than a line with
// a glow. Starting outside the core puts every layer where it can be
// seen, and the shoulder becomes a slope instead of a step.
STROKE_HALO_INNER :: 1.6

// Defaults for a stroke that is a light source in its own right.
STROKE_GLOW :: 0.45
STROKE_SPREAD :: 4.5
STROKE_CORE_LIGHT :: 0.5

// One mark. Everything is a plain number so a caller can push any of it
// around per frame — the taper of a plant, the glow of a rim as its
// world wakes up — without a second procedure.
Stroke :: struct {
	color:      rl.Color, // sampled from the palette; its alpha is the core's
	thickness:  f32, // width of the core at the first point, in px
	taper:      f32, // width at the last point, as a fraction of the first
	glow:       f32, // halo strength, 0..1; 0 draws the core alone
	spread:     f32, // how far the halo reaches, in multiples of the core
	core_light: f32, // how far the core is lifted toward white, 0..1
	closed:     bool, // weld the last point back to the first
	round_caps: bool, // round the two ends of an open stroke
}

// A stroke that behaves like the sketches: soft halo, near-white core,
// round ends, no taper. Adjust the fields afterwards rather than growing
// the parameter list.
new_stroke :: proc(color: rl.Color, thickness: f32) -> Stroke {
	return Stroke {
		color = color,
		thickness = thickness,
		taper = 1,
		glow = STROKE_GLOW,
		spread = STROKE_SPREAD,
		core_light = STROKE_CORE_LIGHT,
		round_caps = true,
	}
}

// One cross-section of the ribbon.
//
// Everything here is in *half-widths*, not pixels, so the same rib
// serves every pass: a vertex is point + half*along ± half*width*normal.
// `along` is what rounds the ends — it walks the rib forward past the
// last point while `width` shrinks it to nothing.
@(private)
StrokeRib :: struct {
	point:  rl.Vector2,
	normal: rl.Vector2, // unit mitre: longer than 1 where the line turns
	along:  rl.Vector2, // displacement down the line, in half-widths
	width:  f32, // half-width factor at this rib
	round:  bool, // the mitre was refused here; fill the fold with a disc
}

@(private)
stroke_ribs: [STROKE_MAX_POINTS + 2 * STROKE_CAP_STEPS]StrokeRib

@(private)
stroke_strip: [2 * (STROKE_MAX_POINTS + 2 * STROKE_CAP_STEPS) + 2]rl.Vector2

@(private)
normalized :: proc(v: rl.Vector2) -> rl.Vector2 {
	length := math.sqrt(v.x * v.x + v.y * v.y)
	if length < 1e-6 {
		return rl.Vector2{0, 0}
	}
	return v / length
}

// Rotated a quarter turn, to the side the ribbon's first edge goes.
//
// Which of the two perpendiculars this is is *not* free. A triangle strip
// is wound by the order its pairs come out in, and backface culling drops
// the whole ribbon if that order is the wrong way round — silently, with
// no error and nothing on screen. This picks the same side terrain.odin's
// strip does: for a line running left to right, the first vertex of each
// pair is the upper one.
@(private)
perpendicular :: proc(v: rl.Vector2) -> rl.Vector2 {
	return rl.Vector2{v.y, -v.x}
}

// Turns a polyline into ribs, and returns how many there are.
@(private)
build_stroke_ribs :: proc(points: []rl.Vector2, stroke: Stroke) -> int {
	count := min(len(points), STROKE_MAX_POINTS)
	if count < 2 {
		return 0
	}

	// The taper runs along the *length* of the stroke, not along its
	// vertex list: a stem drawn with three points, two of them close
	// together, has to thin out over the distance it covers.
	total: f32 = 0
	for i in 1 ..< count {
		total += math.sqrt(
			(points[i].x - points[i - 1].x) * (points[i].x - points[i - 1].x) +
			(points[i].y - points[i - 1].y) * (points[i].y - points[i - 1].y),
		)
	}
	if total < 1e-6 {
		return 0
	}

	capped := stroke.round_caps && !stroke.closed
	base := capped ? STROKE_CAP_STEPS : 0

	travelled: f32 = 0
	for i in 0 ..< count {
		if i > 0 {
			travelled += math.sqrt(
				(points[i].x - points[i - 1].x) * (points[i].x - points[i - 1].x) +
				(points[i].y - points[i - 1].y) * (points[i].y - points[i - 1].y),
			)
		}

		// The two directions meeting at this point. An open stroke's ends
		// have only one, and use it twice.
		previous, next: rl.Vector2
		if i > 0 {
			previous = normalized(points[i] - points[i - 1])
		} else if stroke.closed {
			previous = normalized(points[0] - points[count - 1])
		}
		if i < count - 1 {
			next = normalized(points[i + 1] - points[i])
		} else if stroke.closed {
			next = normalized(points[0] - points[count - 1])
		}
		if previous == {0, 0} {previous = next}
		if next == {0, 0} {next = previous}

		normal_next := perpendicular(next)
		mitre := perpendicular(previous) + normal_next
		length := math.sqrt(mitre.x * mitre.x + mitre.y * mitre.y)

		normal := normal_next
		round := false
		if length < 1e-4 {
			// The line doubles back on itself: no mitre exists at all.
			round = true
		} else {
			mitre = mitre / length
			// How far the mitre has to stretch to keep the edge parallel
			// to both segments. Grows without bound as the turn sharpens.
			projection := mitre.x * normal_next.x + mitre.y * normal_next.y
			stretch := projection > 1e-4 ? 1 / projection : f32(STROKE_MITER_LIMIT + 1)
			if stretch > STROKE_MITER_LIMIT {
				normal = mitre // bevel it, and fill the fold with a disc
				round = true
			} else {
				normal = mitre * stretch
			}
		}

		// A closed stroke has no first or last point to taper between.
		width: f32 = stroke.closed ? 1 : 1 + (stroke.taper - 1) * (travelled / total)

		stroke_ribs[base + i] = StrokeRib {
			point  = points[i],
			normal = normal,
			width  = width,
			round  = round && i > 0 && i < count - 1,
		}
	}

	if !capped {
		return count
	}

	// The round ends, tessellated into the ribbon: each step walks half a
	// width further out while narrowing by the same cosine, which traces
	// a half disc without ever covering the ribbon it grows from.
	start_direction := normalized(points[1] - points[0])
	end_direction := normalized(points[count - 1] - points[count - 2])
	start_width := stroke_ribs[base].width
	end_width := stroke_ribs[base + count - 1].width

	for step in 0 ..< STROKE_CAP_STEPS {
		angle := math.PI * 0.5 * (1 - f32(step) / f32(STROKE_CAP_STEPS))
		reach := math.sin(angle)
		shrink := math.cos(angle)

		stroke_ribs[step] = StrokeRib {
			point  = points[0],
			normal = perpendicular(start_direction),
			along  = start_direction * -reach * start_width,
			width  = shrink * start_width,
		}
		stroke_ribs[base + count + STROKE_CAP_STEPS - 1 - step] = StrokeRib {
			point  = points[count - 1],
			normal = perpendicular(end_direction),
			along  = end_direction * reach * end_width,
			width  = shrink * end_width,
		}
	}

	return count + 2 * STROKE_CAP_STEPS
}

// One pass of the ribbon at a given half-width.
@(private)
draw_stroke_pass :: proc(rib_count: int, half: f32, color: rl.Color, closed: bool) {
	vertices := 0
	for i in 0 ..< rib_count {
		rib := stroke_ribs[i]
		center := rib.point + rib.along * half
		offset := rib.normal * (half * rib.width)

		stroke_strip[vertices] = center + offset
		stroke_strip[vertices + 1] = center - offset
		vertices += 2
	}
	if closed {
		stroke_strip[vertices] = stroke_strip[0]
		stroke_strip[vertices + 1] = stroke_strip[1]
		vertices += 2
	}
	rl.DrawTriangleStrip(raw_data(stroke_strip[:vertices]), i32(vertices), color)

	// Only where the mitre was refused. Everywhere else this disc would
	// be the bead the mitre exists to avoid.
	for i in 0 ..< rib_count {
		rib := stroke_ribs[i]
		if rib.round {
			rl.DrawCircleV(rib.point, half * rib.width, color)
		}
	}
}

// Draws a polyline as one neon mark.
draw_stroke :: proc(points: []rl.Vector2, stroke: Stroke) {
	if stroke.thickness <= 0 {
		return
	}
	rib_count := build_stroke_ribs(points, stroke)
	if rib_count == 0 {
		return
	}

	if stroke.glow > 0 && stroke.spread > STROKE_HALO_INNER {
		rl.BeginBlendMode(.ADDITIVE)
		for i in 0 ..< GLOW_LAYERS {
			t := f32(i) / f32(GLOW_LAYERS - 1)
			alpha := glow_layer_alpha(t, stroke.glow)
			// The shared falloff reaches zero at the outermost layer, so
			// that pass would build its geometry to draw nothing at all.
			if u8(alpha * 255) == 0 {
				continue
			}
			thickness :=
				stroke.thickness *
				(STROKE_HALO_INNER + (stroke.spread - STROKE_HALO_INNER) * t)
			draw_stroke_pass(
				rib_count,
				thickness * 0.5,
				core.with_alpha(stroke.color, alpha),
				stroke.closed,
			)
		}
		rl.EndBlendMode()
	}

	draw_stroke_pass(
		rib_count,
		stroke.thickness * 0.5,
		core.lighten_color(stroke.color, stroke.core_light),
		stroke.closed,
	)
}

// The two-point case, so a caller with a single segment does not have to
// build a slice for it.
draw_stroke_line :: proc(start, end: rl.Vector2, stroke: Stroke) {
	points := [2]rl.Vector2{start, end}
	draw_stroke(points[:], stroke)
}

// A stroke with no length: one round mark of the same weight and the
// same halo. The dotted horizon of the menus is a row of these.
draw_stroke_dot :: proc(center: rl.Vector2, stroke: Stroke) {
	radius := stroke.thickness * 0.5
	if radius <= 0 {
		return
	}
	if stroke.glow > 0 && stroke.spread > 1 {
		draw_glow_circle(center, radius * stroke.spread, stroke.color, stroke.glow)
	}
	rl.DrawCircleV(center, radius, core.lighten_color(stroke.color, stroke.core_light))
}
