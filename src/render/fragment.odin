/*
* Fragment Render
* The things lying in the maze: a small diamond, hollow, standing in the
* middle of its cell.
*
* WHY A FILLED DIAMOND, AND WHAT THAT CHANGED
*
* It was hollow, and the rule it was obeying was the oldest one in
* CLAUDE.md: two things are filled, the field and the character. The rule
* has moved rather than been broken. **Fill now means actor** — you and
* the things worth having — and line means world. That works because the
* three families are told apart by *hue* now (core/palette.odin), so fill
* is free to say something else.
*
* The fill is deliberately dimmer than the outline, and that is not
* taste. A small bright filled shape under a frame-wide bloom stops being
* a shape and becomes a blob — the same lesson the 45 px figure taught,
* that you have to inspect a shape at the size it is drawn. So the fill
* carries "this is solid, it is an actor" at low luminance and the bright
* outline carries the silhouette.
*
* It is a diamond and not a square for the cheapest reason there is:
* every wall in the game is axis-aligned, so forty-five degrees is a
* shape nothing else on screen has, and the eye finds it without the
* colour having to help (pillar 6).
*
* WHY IT PULSES ON SCALE AND ALPHA AND NEVER ON BRIGHTNESS
*
* Bloom is a threshold. A mark that pulses in brightness crosses it and
* comes back, so the halo pops in and out and the whole thing reads as
* flicker rather than as breathing. Scale and alpha move nothing across
* the threshold.
*
* The phase comes from the cell the pickup is in, so a screen of them
* breathes out of step without anything having to remember anything.
*
* A Lucid is the same mark with a dot in it. The two never share a screen
* — a fragment is collectable only in the Real and a Lucid only in the
* Dream (game/fragment.odin) — so the dot is not there to tell them
* apart, it is there to say *this is the rare one* in a phase that lasts
* six seconds.
*
* IT TRUNCATES AT BOTH FRONTS LIKE EVERYTHING ELSE
*
* The world exists between the pen on the right and the Corruption on the
* left, and a shape straddling either one is cut rather than faded. A
* diamond fully inside the window is one closed stroke with welded joins;
* one that straddles is drawn edge by edge with each edge clipped, which
* is the same picture minus the joins nobody can see anyway.
*/
package render

import "../core"
import "../fx"
import "../game"
import "core:math"
import rl "vendor:raylib/v55"

// Half the diamond's width, in px. Against a 60 px cell and a 38 px body:
// small enough to sit inside the corridor with air around it, large
// enough to be read three or four moves ahead, which is the whole point
// of putting it there.
PICKUP_RADIUS :: 12

PICKUP_WEIGHT :: 1.0 // multiples of the world's stroke
PICKUP_GLOW :: 0.55
PICKUP_SPREAD :: 5.0

// The fill: dimmed well away from the outline so the bloom cannot eat the
// silhouette, and opaque enough to read as solid over the field.
PICKUP_FILL_DIM :: 0.55 // how far the accent is pulled toward black
PICKUP_FILL_ALPHA :: 0.80

// The breath. Slow, and small: a pickup is an offer sitting still in a
// maze, not something arriving.
PICKUP_PULSE_PERIOD :: 1.7 // seconds for a full breath
PICKUP_PULSE_SCALE :: 0.09 // how much of the radius it swings
PICKUP_PULSE_ALPHA :: 0.16 // and of the fill's opacity

// The Lucid's centre mark.
LUCID_DOT_WEIGHT :: 1.6

// The most that can be on screen at once. Five chunk slots at
// MAX_PICKUPS_PER_CHUNK is the true ceiling; the window is never more
// than three of them wide.
@(private = "file")
PICKUP_STORAGE :: 64

@(private = "file")
clip_segment :: proc(a, b: rl.Vector2, low, high: f32) -> (rl.Vector2, rl.Vector2, bool) {
	start, end := a, b
	if start.x > end.x {
		start, end = end, start
	}
	span := end.x - start.x
	if span <= 0 {
		if start.x < low || start.x > high {
			return {}, {}, false
		}
		return a, b, true
	}
	t0 := clamp((low - start.x) / span, 0, 1)
	t1 := clamp((high - start.x) / span, 0, 1)
	if t1 <= t0 {
		return {}, {}, false
	}
	return start + (end - start) * t0, start + (end - start) * t1, true
}

@(private = "file")
diamond_points :: proc(centre: rl.Vector2, radius: f32) -> [4]rl.Vector2 {
	return {
		{centre.x + radius, centre.y},
		{centre.x, centre.y + radius},
		{centre.x - radius, centre.y},
		{centre.x, centre.y - radius},
	}
}

// Cuts a convex polygon to the strip between two x values, Sutherland
// and Hodgman, one plane at a time. A quad against two planes comes out
// as at most six points.
//
// The fill has to be clipped and not merely hidden. The world exists
// between the two fronts and a shape that straddles one is *cut*, never
// faded and never popped in: a fill that appeared whole the moment its
// centre cleared the pen would be the appearance animation the whole
// two-fronts idea exists to not need.
@(private = "file")
clip_convex_x :: proc(points: []rl.Vector2, low, high: f32, out: []rl.Vector2) -> int {
	scratch: [8]rl.Vector2
	count := 0
	for point in points {
		scratch[count] = point
		count += 1
	}

	// keep = true means "inside is x >= edge", false means "x <= edge".
	clip :: proc(
		source: []rl.Vector2,
		count: int,
		edge: f32,
		keep_right: bool,
		out: []rl.Vector2,
	) -> int {
		inside :: proc(x, edge: f32, keep_right: bool) -> bool {
			return keep_right ? x >= edge : x <= edge
		}
		written := 0
		for i in 0 ..< count {
			a := source[i]
			b := source[(i + 1) % count]
			a_in := inside(a.x, edge, keep_right)
			b_in := inside(b.x, edge, keep_right)
			if a_in {
				out[written] = a
				written += 1
			}
			if a_in != b_in {
				span := b.x - a.x
				t: f32 = span != 0 ? (edge - a.x) / span : 0
				out[written] = a + (b - a) * clamp(t, 0, 1)
				written += 1
			}
		}
		return written
	}

	staging: [8]rl.Vector2
	count = clip(scratch[:], count, low, true, staging[:])
	if count < 3 {
		return 0
	}
	count = clip(staging[:], count, high, false, out)
	return count < 3 ? 0 : count
}

// Fills a convex polygon given in the *outline's* order.
//
// **A triangle fan's winding is not free either**, and it wants the
// opposite order to the one the stroke wants. Measured by reading the
// frame back: the diamond as the outline builds it fills 0 pixels — the
// whole shape culled, silently, with nothing on screen to say so — and
// reversed it fills 7200, which is the 2r² the area works out to on
// paper. One point order for the shape, reversed here and nowhere else,
// so the two passes can never disagree about what the diamond is.
@(private = "file")
fill_convex :: proc(points: []rl.Vector2, colour: rl.Color) {
	if len(points) < 3 {
		return
	}
	reversed: [8]rl.Vector2
	count := min(len(points), len(reversed))
	for i in 0 ..< count {
		reversed[i] = points[count - 1 - i]
	}
	rl.DrawTriangleFan(raw_data(reversed[:count]), i32(count), colour)
}

// The pickups the camera can see, clipped to the world's two fronts.
draw_pickups :: proc(
	maze: ^game.Maze,
	world: game.World,
	palettes: core.PaletteSet,
	front_x: f32,
	dream: game.Dream,
	display_time: f32,
) {
	first, last := game.get_visible_columns(world)

	storage: [PICKUP_STORAGE]game.VisiblePickup
	count := game.gather_pickups(maze, first, last, storage[:])
	if count == 0 {
		return
	}

	left := front_x
	right := f32(DRAW_FRONT_X)

	// The actors' accent, not the world's: a fragment must not wash out
	// with depth along with the maze it is hiding in (core/palette.odin).
	mark := new_stroke(palettes.actor_accent, WORLD_STROKE_THICKNESS * PICKUP_WEIGHT)
	mark.glow = PICKUP_GLOW
	mark.spread = PICKUP_SPREAD
	apply_glow_gain(&mark, glow_gain(palettes.world_t))

	dot := mark
	dot.thickness = WORLD_STROKE_THICKNESS * LUCID_DOT_WEIGHT

	for i in 0 ..< count {
		pickup := storage[i]

		// A pickup belonging to the other phase is not there. That is the
		// third channel pillar 6 asks for: with the colour off, what the
		// maze is offering still says which world is running.
		if game.pickup_phase(pickup.kind) != dream.phase {
			continue
		}

		centre := rl.Vector2 {
			game.maze_screen_x(pickup.position.x, world.camera_x),
			pickup.position.y,
		}
		if centre.x + PICKUP_RADIUS * 2 < left || centre.x - PICKUP_RADIUS * 2 > right {
			continue
		}

		// Out of step with its neighbours, and reproducibly so: the phase
		// is the cell, so nothing has to be remembered between frames and
		// two runs of the same seed breathe identically.
		phase := f32((pickup.col * 7 + pickup.row * 13) % 16) / 16
		wave := math.sin_f32((display_time / PICKUP_PULSE_PERIOD + phase) * 2 * math.PI)

		radius := PICKUP_RADIUS * (1 + PICKUP_PULSE_SCALE * wave)
		points := diamond_points(centre, radius)

		// The fill first, the outline over it.
		fill_alpha := PICKUP_FILL_ALPHA + PICKUP_PULSE_ALPHA * wave
		clipped: [8]rl.Vector2
		if written := clip_convex_x(points[:], left, right, clipped[:]); written >= 3 {
			fill_convex(
				clipped[:written],
				core.with_alpha(
					core.dim_color(palettes.actor_accent, PICKUP_FILL_DIM),
					fill_alpha,
				),
			)
		}

		if centre.x - radius >= left && centre.x + radius <= right {
			whole := mark
			whole.closed = true
			draw_stroke(points[:], whole)
		} else {
			// Straddling a front: every edge cut at it, and the ends left
			// square so the cut reads as a cut rather than as a stroke
			// that chose to stop there.
			edge := mark
			edge.round_caps = false
			for index in 0 ..< 4 {
				a := points[index]
				b := points[(index + 1) % 4]
				if start, end, ok := clip_segment(a, b, left, right); ok {
					draw_stroke_line(start, end, edge)
				}
			}
		}

		if pickup.kind == .Lucid && centre.x >= left && centre.x <= right {
			draw_stroke_dot(centre, dot)
		}
	}
}

// --- Taking one ---

// The mark a pickup leaves when it is taken: a short outward puff at the
// body, in the pickup's own colour.
//
// A burst rather than a stream, and that is not a detail: collecting is
// an *instant*, and a rate handed a single frame rounds against the
// stream's fractional debt and can emit nothing at all (fx/particles.odin).
//
// It is emitted from main next to the fray, on the frame clock, because
// the pool is presentation and the simulation may not know it exists.
// What main passes in is how many were taken since the last frame — a
// difference read off the run's own tally, which is a presentation value
// derived from the simulation and never the other way round.
PICKUP_BURST_COUNT :: 14
PICKUP_BURST_SPEED :: 90
PICKUP_BURST_DRAG :: 4.5
PICKUP_BURST_LIFE :: 0.45
PICKUP_BURST_SIZE :: 2.3

emit_pickup_burst :: proc(
	particles: ^fx.Particles,
	player: game.Player,
	world: game.World,
	palettes: core.PaletteSet,
	taken: int,
) {
	if taken <= 0 {
		return
	}
	position := game.get_player_world(player)
	emitter := fx.Emitter {
		origin      = rl.Vector2 {
			game.maze_screen_x(position.x, world.camera_x),
			position.y,
		},
		spread      = rl.Vector2{4, 4},
		scatter     = rl.Vector2{PICKUP_BURST_SPEED, PICKUP_BURST_SPEED},
		drag        = PICKUP_BURST_DRAG,
		life        = PICKUP_BURST_LIFE,
		life_jitter = 0.18,
		size        = PICKUP_BURST_SIZE,
		size_jitter = 0.8,
		color       = core.with_alpha(palettes.actor_accent, 0.9),
	}
	fx.burst(particles, emitter, PICKUP_BURST_COUNT * taken)
}
