/*
* Obstacle
* Obstacles are described as events in time (when they should reach the
* player), not as absolute pixel positions. Their on-screen x position is
* derived every frame from the world's elapsed time and scroll speed.
* This means changing scroll_speed later never breaks perceived timing
* (Design Doc, section 6-7).
*/
package game

import "../core"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib/v55"

// Obstacle reference size in pixels — same footprint as the player for now.
OBSTACLE_SIZE :: 54

// The four obstacle types for the MVP (Design Doc, section 5).
// Block/Chasm belong to the Real lane ("full" theme), PulsingShape/DreamHole
// belong to the Dream lane ("void" theme) — see the thematic pairing in the doc.
ObstacleType :: enum {
	Block, // static, sticks up from the floor
	Chasm, // static, a gap in the floor — same collision rule as Block, read inverted
	PulsingShape, // dynamic height, oscillates — sometimes blocks, sometimes doesn't
	DreamHole, // static, a gap in the ceiling — same collision rule as Block, read inverted
}

// Declares which lane each obstacle type belongs to, per the thematic
// pairing in Design Doc section 5 (Real = full/static, Dream = void/dynamic).
// Used to catch pattern-authoring mistakes early (see validate_pattern_pool).
expected_lane_for_type :: proc(obstacle_type: ObstacleType) -> core.Lane {
	switch obstacle_type {
	case .Block, .Chasm:
		return .Real
	case .PulsingShape, .DreamHole:
		return .Dream
	}
	return .Real
}

Obstacle :: struct {
	arrival_time:      f32, // world.elapsed_time value at which this obstacle reaches PLAYER_X
	lane:              core.Lane,
	size:              rl.Vector2,
	obstacle_type:     ObstacleType,
	lucidity_resolved: bool, // true once this obstacle has been checked for a near-miss (section 17)
}


// Chasm width variants (Design Doc concept: cracks can be short, medium, or
// long). Picked randomly at creation time — purely cosmetic/difficulty
// flavor, not something we need to hand-author per pattern.
CHASM_WIDTH_SHORT :: OBSTACLE_SIZE * 1.0
CHASM_WIDTH_MEDIUM :: OBSTACLE_SIZE * 1.6
CHASM_WIDTH_LONG :: OBSTACLE_SIZE * 2.2

// Creates an obstacle that will arrive at the player's x position at the given time.
//
// Takes the caller's random generator rather than reaching for the global
// one: chasm width is a random choice, and every random choice a run makes
// has to come from the run's own seed to stay reproducible (see
// PatternGenerator in pattern.odin).
new_obstacle :: proc(
	arrival_time: f32,
	lane: core.Lane,
	obstacle_type: ObstacleType,
	rng: rand.Generator,
) -> Obstacle {
	width: f32 = OBSTACLE_SIZE
	if obstacle_type == .Chasm {
		roll := rand.float32(rng)
		switch {
		case roll < 0.4:
			width = CHASM_WIDTH_SHORT
		case roll < 0.75:
			width = CHASM_WIDTH_MEDIUM
		case:
			width = CHASM_WIDTH_LONG
		}
	}

	return Obstacle {
		arrival_time = arrival_time,
		lane = lane,
		size = rl.Vector2{width, OBSTACLE_SIZE},
		obstacle_type = obstacle_type,
	}
}

// Pulsing Shape oscillation range and speed (Design Doc, section 5: grows and
// retracts periodically — sometimes blocks the lane, sometimes doesn't,
// depending on the exact moment the player crosses it).
PULSING_SHAPE_MIN_HEIGHT :: 8
PULSING_SHAPE_MAX_HEIGHT :: 55
PULSING_SHAPE_PERIOD :: 0.7 // seconds per full grow-retract cycle

// Returns the obstacle's current size. Fixed for every type except
// Pulsing Shape, whose height oscillates over world time.
get_obstacle_size :: proc(obstacle: Obstacle, world: World) -> rl.Vector2 {
	if obstacle.obstacle_type != .PulsingShape {
		return obstacle.size
	}

	phase := world.elapsed_time / PULSING_SHAPE_PERIOD
	pulse := (math.sin(phase * 2 * math.PI) + 1) / 2 // remapped from [-1,1] to [0,1]
	height :=
		PULSING_SHAPE_MIN_HEIGHT + pulse * (PULSING_SHAPE_MAX_HEIGHT - PULSING_SHAPE_MIN_HEIGHT)

	return rl.Vector2{obstacle.size.x, height}
}

// Computes the obstacle's current on-screen position, derived from
// how much time remains until (or has passed since) its arrival_time.
get_obstacle_position :: proc(obstacle: Obstacle, world: World) -> rl.Vector2 {
	time_until_arrival := obstacle.arrival_time - world.elapsed_time
	x := core.PLAYER_X + time_until_arrival * world.scroll_speed
	size := get_obstacle_size(obstacle, world)
	y := core.get_lane_y(obstacle.lane, size)
	return rl.Vector2{x, y}
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
// finished obstacles do not arrive in order: chasm widths range from 54 to
// 118 px, so a newer but narrow obstacle can leave the screen before an
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
