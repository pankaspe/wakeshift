/*
* Obstacle
* Obstacles are described as events in time (when they should reach the
* player), not as absolute pixel positions. Their on-screen x position is
* derived every frame from the world's elapsed time and scroll speed.
* This means changing scroll_speed later never breaks perceived timing
* (Design Doc, section 6-7).
*/
package main

import "core:math"
import rl "vendor:raylib/v55"

// Obstacle reference size in pixels — same footprint as the player for now.
OBSTACLE_SIZE :: 45

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
expected_lane_for_type :: proc(obstacle_type: ObstacleType) -> Lane {
	switch obstacle_type {
	case .Block, .Chasm:
		return .Real
	case .PulsingShape, .DreamHole:
		return .Dream
	}
	return .Real
}

Obstacle :: struct {
	arrival_time:  f32, // world.elapsed_time value at which this obstacle reaches PLAYER_X
	lane:          Lane,
	size:          rl.Vector2,
	obstacle_type: ObstacleType,
}

// Creates an obstacle that will arrive at the player's x position at the given time.
new_obstacle :: proc(arrival_time: f32, lane: Lane, obstacle_type: ObstacleType) -> Obstacle {
	return Obstacle {
		arrival_time = arrival_time,
		lane = lane,
		size = rl.Vector2{OBSTACLE_SIZE, OBSTACLE_SIZE},
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
	x := PLAYER_X + time_until_arrival * world.scroll_speed
	size := get_obstacle_size(obstacle, world)
	y := get_lane_y(obstacle.lane, size)
	return rl.Vector2{x, y}
}

// Draws the obstacle, distinguishing "full" obstacles (something appears,
// solid) from "void" obstacles (something is missing, drawn as an outline
// only) — the pieno/vuoto principle from Design Doc, section 5.
draw_obstacle :: proc(obstacle: Obstacle, world: World) {
	position := get_obstacle_position(obstacle, world)
	size := get_obstacle_size(obstacle, world)

	switch obstacle.obstacle_type {
	case .Block, .PulsingShape:
		rl.DrawRectangleV(position, size, rl.RED)
	case .Chasm, .DreamHole:
		rl.DrawRectangleLinesEx(rl.Rectangle{position.x, position.y, size.x, size.y}, 2, rl.RED)
	}
}
