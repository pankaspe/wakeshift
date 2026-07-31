/*
* Obstacle
* Obstacles are described as events in time (when they should reach the
* player), not as absolute pixel positions. Their on-screen x position is
* derived every frame from the world's elapsed time and scroll speed.
* This means changing scroll_speed later never breaks perceived timing
* (Design Doc, section 6-7).
*/
package main

import rl "vendor:raylib/v55"

// Obstacle reference size in pixels — same footprint as the player for now.
OBSTACLE_SIZE :: 45

Obstacle :: struct {
	arrival_time: f32, // world.elapsed_time value at which this obstacle reaches PLAYER_X
	lane:         Lane,
	size:         rl.Vector2,
}

// Creates an obstacle that will arrive at the player's x position at the given time.
new_obstacle :: proc(arrival_time: f32, lane: Lane) -> Obstacle {
	return Obstacle {
		arrival_time = arrival_time,
		lane = lane,
		size = rl.Vector2{OBSTACLE_SIZE, OBSTACLE_SIZE},
	}
}

// Computes the obstacle's current on-screen position, derived from
// how much time remains until (or has passed since) its arrival_time.
get_obstacle_position :: proc(obstacle: Obstacle, world: World) -> rl.Vector2 {
	time_until_arrival := obstacle.arrival_time - world.elapsed_time
	x := PLAYER_X + time_until_arrival * world.scroll_speed
	y := get_lane_y(obstacle.lane, obstacle.size)
	return rl.Vector2{x, y}
}

// Draws the obstacle as a placeholder rectangle at its current derived position.
draw_obstacle :: proc(obstacle: Obstacle, world: World) {
	position := get_obstacle_position(obstacle, world)
	rl.DrawRectangleV(position, obstacle.size, rl.RED)
}
