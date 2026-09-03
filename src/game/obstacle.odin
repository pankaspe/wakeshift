/*
* Obstacle
* Obstacles are described as events in time (when they should reach the
* player), not as absolute pixel positions. Their on-screen x position is
* derived every frame from the world's elapsed time and scroll speed.
* This means changing scroll_speed later never breaks perceived timing
* (Design Doc, section 6-7).
*
* Six types, and — since phase 6 — genuinely six behaviours rather than
* one behaviour with six skins. They split along two axes the design doc
* draws (section 5):
*
*   full vs void      A Block is something that appears; a Chasm is the
*                     floor failing to be there. The two are opposite
*                     readings, and after phase 6 they are opposite
*                     *rules*: a Block kills whoever touches it, a Chasm
*                     kills only whoever is still standing on the floor
*                     when it passes underneath (see collision.odin).
*                     The Step (T7.5.5) is the third case and belongs to
*                     neither end: not a thing standing on the floor and
*                     not the floor missing, but the floor itself rising
*                     into the lane. It asks a Block's question — be
*                     elsewhere — in a Chasm's voice, since it is the
*                     ground doing it and so only reaches whoever is on
*                     the ground.
*   honest vs         The Real world's obstacles are static and mean what
*   anticipatory      they show. The Feint and the Patroller do not: they
*                     anticipate the obvious answer rather than react to
*                     the player, which is the distinction the design doc
*                     is careful about (section 5, "what makes an obstacle
*                     intelligent"). Nothing here ever reads the player's
*                     position — an obstacle that adapts feels stolen even
*                     when it is survivable, and breaks pillar 3.
*
* Everything an obstacle does over time is a function of *its own*
* arrival_time, never of global clock time. That is not tidiness: an
* obstacle whose animation runs off the world clock presents a different
* face every time the same pattern is generated, so the pattern author
* cannot say what the player will face and the player cannot learn it.
* phase_offset is authored in the pattern for the same reason — randomness
* would put fairness back in the hands of the seed.
*/
package game

import "../core"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib/v55"

// Obstacle reference size in pixels — same footprint as the player.
OBSTACLE_SIZE :: 54

ObstacleType :: enum {
	Block, // Real, full: sticks up from the floor, kills on contact
	Chasm, // Real, void: a gap in the floor, kills only the grounded
	PulsingShape, // Dream, full: hangs from the ceiling, grows and retracts
	DreamHole, // Dream, void: the ceiling dissolves, kills only whoever hangs from it
	Feint, // either lane: looks like a threat, retracts before it arrives, never lethal
	Patroller, // either lane: sweeps the whole column on a readable cycle
	Step, // Real, neither: the floor itself rises into a wall
}

// Which lane a type belongs to, per the thematic pairing in Design Doc
// section 5 (Real = full/static, Dream = void/dynamic), and whether it is
// bound to a lane at all. The Feint and the Patroller are not: a bluff
// works in either world, and a Patroller crosses the whole column by
// definition. Used to catch pattern-authoring mistakes early (see
// validate_pattern_pool).
expected_lane_for_type :: proc(obstacle_type: ObstacleType) -> (lane: core.Lane, bound: bool) {
	switch obstacle_type {
	case .Block, .Chasm, .Step:
		return .Real, true
	case .PulsingShape, .DreamHole:
		return .Dream, true
	case .Feint, .Patroller:
		return .Real, false
	}
	return .Real, false
}

// True for the two types that are an *absence* rather than a thing.
is_void_obstacle :: proc(obstacle_type: ObstacleType) -> bool {
	return obstacle_type == .Chasm || obstacle_type == .DreamHole
}

// True for everything the *terrain* draws rather than draw_obstacle: the
// two voids and the Step. They have one thing in common that decides
// both their drawing and their rule — they are the ground itself doing
// something, so only the code that knows where the surface is can draw
// them, and only whoever is standing on that surface is touched by them.
is_terrain_obstacle :: proc(obstacle_type: ObstacleType) -> bool {
	return is_void_obstacle(obstacle_type) || obstacle_type == .Step
}

// --- Step (Real, the floor as a wall) ---
//
// How far the floor lifts. Taller than the player is, so that a raised
// stretch reads as something to be elsewhere for rather than as a bump
// (the character is PLAYER_SIZE tall standing on the floor).
STEP_HEIGHT :: 52

// How long a raised stretch runs, in pixels of world. Wider than a
// chasm on average: a hole is a moment to not be down for, and a step is
// a stretch. At the opening speed these are 0.32 s, 0.44 s and 0.60 s of
// floor that is not there to stand on.
STEP_WIDTH_SHORT :: OBSTACLE_SIZE * 1.6
STEP_WIDTH_MEDIUM :: OBSTACLE_SIZE * 2.2
STEP_WIDTH_LONG :: OBSTACLE_SIZE * 3.0

Obstacle :: struct {
	arrival_time:      f32, // world.elapsed_time value at which this obstacle reaches PLAYER_X
	lane:              core.Lane,
	size:              rl.Vector2,
	obstacle_type:     ObstacleType,

	// Where in its own cycle an animated obstacle is at the moment it
	// arrives, in turns (0..1). Authored by the pattern, never drawn at
	// random: it is the difference between "a pulsing shape" and "a
	// pulsing shape that will be a wall when it reaches you", and the
	// player can only learn the second one.
	phase_offset:      f32,
	lucidity_resolved: bool, // true once this obstacle has been checked for a near-miss
}

// Chasm and Dream Hole width variants. Picked randomly at creation —
// purely flavour, and the one random choice left in an obstacle, so a
// pattern still knows exactly what it is asking of the player.
GAP_WIDTH_SHORT :: OBSTACLE_SIZE * 1.2
GAP_WIDTH_MEDIUM :: OBSTACLE_SIZE * 1.9
GAP_WIDTH_LONG :: OBSTACLE_SIZE * 2.6

// Creates an obstacle that will arrive at the player's x position at the given time.
//
// Takes the caller's random generator rather than reaching for the global
// one: every random choice a run makes has to come from the run's own
// seed to stay reproducible (see PatternGenerator in pattern.odin).
new_obstacle :: proc(
	arrival_time: f32,
	lane: core.Lane,
	obstacle_type: ObstacleType,
	phase_offset: f32,
	rng: rand.Generator,
) -> Obstacle {
	width: f32 = OBSTACLE_SIZE
	if is_void_obstacle(obstacle_type) {
		roll := rand.float32(rng)
		switch {
		case roll < 0.4:
			width = GAP_WIDTH_SHORT
		case roll < 0.75:
			width = GAP_WIDTH_MEDIUM
		case:
			width = GAP_WIDTH_LONG
		}
	}
	if obstacle_type == .Patroller {
		width = PATROLLER_SIZE
	}

	height: f32 = OBSTACLE_SIZE
	if obstacle_type == .Step {
		// Same treatment as a gap's width, and for the same reason: it is
		// flavour, and it is the one random choice left in an obstacle, so
		// a pattern still knows exactly what it is asking of the player.
		roll := rand.float32(rng)
		switch {
		case roll < 0.4:
			width = STEP_WIDTH_SHORT
		case roll < 0.75:
			width = STEP_WIDTH_MEDIUM
		case:
			width = STEP_WIDTH_LONG
		}
		height = STEP_HEIGHT
	}

	return Obstacle {
		arrival_time = arrival_time,
		lane = lane,
		size = rl.Vector2{width, height},
		obstacle_type = obstacle_type,
		phase_offset = phase_offset,
	}
}

// Seconds since this obstacle arrived at the player (negative before).
// Every animation below is a function of this and nothing else.
get_obstacle_age :: proc(obstacle: Obstacle, world: World) -> f32 {
	return world.elapsed_time - obstacle.arrival_time
}

// --- Pulsing Shape (Dream, full) ---

PULSING_SHAPE_MIN_HEIGHT :: 8
PULSING_SHAPE_MAX_HEIGHT :: 55
PULSING_SHAPE_PERIOD :: 0.7 // seconds per full grow-retract cycle

// Anchored to arrival, so what the player sees coming is what they get.
// Driven by global time, as it was until phase 6, the same pattern could
// present a 55px wall on one run and an 8px stub on the next: the level
// was different every time for reasons neither the author nor the player
// could see.
get_pulsing_height :: proc(obstacle: Obstacle, world: World) -> f32 {
	phase := get_obstacle_age(obstacle, world) / PULSING_SHAPE_PERIOD + obstacle.phase_offset
	pulse := (math.sin(phase * 2 * math.PI) + 1) / 2 // remapped from [-1,1] to [0,1]
	return PULSING_SHAPE_MIN_HEIGHT + pulse * (PULSING_SHAPE_MAX_HEIGHT - PULSING_SHAPE_MIN_HEIGHT)
}

// --- Feint (either lane, never lethal) ---
//
// It grows exactly like the full obstacle of its lane, holds long enough
// to be believed, then retracts to nothing before it arrives. Whoever
// answers it with the obvious flip lands in whatever the pattern put in
// the other lane; whoever waits sees it go.
//
// The retraction has to *finish* far enough ahead of arrival that the
// player still has time to read the real threat and commit a flip — a
// bluff that resolves after the last useful moment is not a bluff, it is
// a trick, and pillar 3 says the information is always available before
// the commitment.

FEINT_APPEAR :: 2.2 // seconds before arrival it starts growing
FEINT_PEAK :: 1.3 // fully grown from here...
FEINT_GONE :: 0.6 // ...back to nothing by here

get_feint_height :: proc(obstacle: Obstacle, world: World) -> f32 {
	time_left := -get_obstacle_age(obstacle, world)

	switch {
	case time_left > FEINT_APPEAR, time_left <= FEINT_GONE:
		return 0
	case time_left > FEINT_PEAK:
		t := (FEINT_APPEAR - time_left) / (FEINT_APPEAR - FEINT_PEAK)
		return OBSTACLE_SIZE * core.ease_out_quad(t)
	case:
		t := (FEINT_PEAK - time_left) / (FEINT_PEAK - FEINT_GONE)
		return OBSTACLE_SIZE * (1 - core.ease_in_out_quad(t))
	}
}

// --- Patroller (either lane, sweeps the column) ---
//
// The one real presence in the set, and the one thing that threatens the
// middle — which is what closes the imbalance phase 5 left behind, where
// holding in the Limen risked nothing but fuel.
//
// It sweeps floor to ceiling on a cosine anchored to its arrival, so a
// pattern says where it will be at the moment it reaches the player by
// choosing phase_offset: 0 puts it at the ceiling, 0.25 in the middle,
// 0.5 on the floor. Nothing about it reads the player.

PATROLLER_SIZE :: 46
PATROLLER_PERIOD :: 1.7 // seconds per full round trip

// 0 at the ceiling, 1 on the floor.
get_patroller_sweep :: proc(obstacle: Obstacle, world: World) -> f32 {
	phase := get_obstacle_age(obstacle, world) / PATROLLER_PERIOD + obstacle.phase_offset
	return (1 - math.cos(phase * 2 * math.PI)) * 0.5
}

// --- Geometry ---

// Returns the obstacle's current size. Fixed for everything whose shape
// does not move; the two that do are the ones whose *timing* is the
// threat rather than their position.
get_obstacle_size :: proc(obstacle: Obstacle, world: World) -> rl.Vector2 {
	#partial switch obstacle.obstacle_type {
	case .PulsingShape:
		return rl.Vector2{obstacle.size.x, get_pulsing_height(obstacle, world)}
	case .Feint:
		return rl.Vector2{obstacle.size.x, get_feint_height(obstacle, world)}
	case .Patroller:
		return rl.Vector2{PATROLLER_SIZE, PATROLLER_SIZE}
	}
	return obstacle.size
}

// Computes the obstacle's current on-screen position, derived from how
// much time remains until (or has passed since) its arrival_time.
//
// x is the same for everything: the world scrolls, obstacles do not move
// through it. y is where the types part company — most hang off the wall
// of their own lane, the Patroller is somewhere on its sweep.
get_obstacle_position :: proc(obstacle: Obstacle, world: World) -> rl.Vector2 {
	time_until_arrival := obstacle.arrival_time - world.elapsed_time
	x := core.PLAYER_X + time_until_arrival * world.scroll_speed
	size := get_obstacle_size(obstacle, world)

	ground := get_ground(world)

	if obstacle.obstacle_type == .Patroller {
		// It crosses the column between the two walls, not between the two
		// screen edges: over raised ground the second would put it inside
		// the terrain. The phase still means what it always meant — 0 at
		// the ceiling, 0.5 on the floor — because the ends of the sweep
		// are the walls themselves.
		sweep := get_patroller_sweep(obstacle, world)
		ceiling := core.get_lane_y(ground, .Dream, x, size)
		floor := core.get_lane_y(ground, .Real, x, size)
		return rl.Vector2{x, ceiling + (floor - ceiling) * sweep}
	}

	return rl.Vector2{x, core.get_lane_y(ground, obstacle.lane, x, size)}
}

get_obstacle_rect :: proc(obstacle: Obstacle, world: World) -> rl.Rectangle {
	position := get_obstacle_position(obstacle, world)
	size := get_obstacle_size(obstacle, world)
	return rl.Rectangle{position.x, position.y, size.x, size.y}
}

// Extra distance past the left edge an obstacle must travel before it is
// discarded. Nothing needs the margin — it is slack, so that a future
// change to how far left something is drawn (a trailing particle, a
// shadow) cannot silently start culling things that are still visible.
OBSTACLE_CULL_MARGIN :: 200

// True once an obstacle can no longer affect anything: it is well past
// the left edge of the screen, and its near-miss has already been counted.
//
// Both conditions matter. Position alone would be enough for collision and
// drawing, but the Lucidity streak is registered the moment an obstacle
// passes the player (see register_obstacle_passed), and dropping one before
// that happened would silently lose a point of streak.
is_obstacle_finished :: proc(obstacle: Obstacle, world: World) -> bool {
	if !obstacle.lucidity_resolved {
		return false
	}
	position := get_obstacle_position(obstacle, world)
	size := get_obstacle_size(obstacle, world)
	return position.x + size.x < -OBSTACLE_CULL_MARGIN
}

// Drops obstacles that are finished with, keeping the list from growing
// for the whole length of a run — without it a five-minute run leaves a
// few hundred dead entries to be walked on every single step.
//
// Compacts the whole list rather than dropping a finished prefix, because
// finished obstacles do not arrive in order: gaps range from 65 to 140 px
// wide, so a newer but narrow obstacle can leave the screen before an
// older but wide one. A prefix scan would stop at the first survivor and
// leak everything behind it.
//
// Survivors keep their original order. Nothing downstream depends on that
// today, but obstacles are generated in ascending arrival_time and quietly
// scrambling it would be an unpleasant surprise for anything that later
// assumes it.
remove_finished_obstacles :: proc(obstacles: ^[dynamic]Obstacle, world: World) {
	kept := 0
	for index in 0 ..< len(obstacles) {
		if !is_obstacle_finished(obstacles[index], world) {
			obstacles[kept] = obstacles[index]
			kept += 1
		}
	}
	resize(obstacles, kept)
}
