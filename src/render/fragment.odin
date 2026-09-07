/*
* Fragment Render
* The things lying in the maze: a small diamond, hollow, standing in the
* middle of its cell.
*
* WHY A HOLLOW DIAMOND
*
* The picture already has exactly two vocabularies and the whole art
* direction rests on them: **the walls are line, the body is fill**. A
* pickup has to be an object rather than a piece of the maze, and it has
* to be told apart from the body in the same glance — so it takes the
* body's colour and the maze's hollowness. Filled would make it a second
* character; the walls' colour would make it furniture.
*
* It is a diamond and not a square for the cheapest reason there is:
* every wall in the game is axis-aligned, so forty-five degrees is a
* shape nothing else on screen has, and the eye finds it without the
* colour having to help (pillar 6).
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
import rl "vendor:raylib/v55"

// Half the diamond's width, in px. Against a 60 px cell and a 38 px body:
// small enough to sit inside the corridor with air around it, large
// enough to be read three or four moves ahead, which is the whole point
// of putting it there.
PICKUP_RADIUS :: 12

PICKUP_WEIGHT :: 1.0 // multiples of the world's stroke
PICKUP_GLOW :: 0.55
PICKUP_SPREAD :: 5.0

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

// The pickups the camera can see, clipped to the world's two fronts.
draw_pickups :: proc(
	maze: ^game.Maze,
	world: game.World,
	palettes: core.PaletteSet,
	front_x: f32,
	dream: game.Dream,
) {
	first, last := game.get_visible_columns(world)

	storage: [PICKUP_STORAGE]game.VisiblePickup
	count := game.gather_pickups(maze, first, last, storage[:])
	if count == 0 {
		return
	}

	left := front_x
	right := f32(DRAW_FRONT_X)

	mark := new_stroke(palettes.current.accent, WORLD_STROKE_THICKNESS * PICKUP_WEIGHT)
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
		if centre.x + PICKUP_RADIUS < left || centre.x - PICKUP_RADIUS > right {
			continue
		}

		points := diamond_points(centre, PICKUP_RADIUS)

		if centre.x - PICKUP_RADIUS >= left && centre.x + PICKUP_RADIUS <= right {
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
		color       = core.with_alpha(palettes.current.accent, 0.9),
	}
	fx.burst(particles, emitter, PICKUP_BURST_COUNT * taken)
}
