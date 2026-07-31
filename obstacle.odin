/*
* This is Obstacle file, obstacle.odin
* holds obstacle state and draws it. For now: a single hardcoded block,
* no collision logic yet (that's section 7).
*/
package main

import rl "vendor:raylib/v55"

// Obstacle reference size in pixels — same footprint as the player for now.
OBSTACLE_SIZE :: 45

Obstacle :: struct {
	position: rl.Vector2,
	size:     rl.Vector2,
	lane:     Lane,
}

// Creates a single obstacle at a fixed starting x, anchored to the given lane.
new_obstacle :: proc(start_x: f32, lane: Lane) -> Obstacle {
	size := rl.Vector2{OBSTACLE_SIZE, OBSTACLE_SIZE}

	return Obstacle {
		position = rl.Vector2{start_x, get_lane_y(lane, size)},
		size = size,
		lane = lane,
	}
}

// Moves the obstacle left according to the world's scroll speed.
update_obstacle :: proc(obstacle: ^Obstacle, world: World, delta_time: f32) {
	obstacle.position.x -= world.scroll_speed * delta_time
}

// Draws the obstacle as a placeholder rectangle.
draw_obstacle :: proc(obstacle: Obstacle) {
	rl.DrawRectangleV(obstacle.position, obstacle.size, rl.RED)
}
