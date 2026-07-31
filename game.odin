/*
* This is Game file, game.odin
* holds game-level state (playing / game over) and collision checks
*/
package main

import rl "vendor:raylib/v55"

GameState :: enum {
	Playing,
	GameOver,
}

// Converts a position/size pair into a raylib Rectangle, for collision checks.
to_rect :: proc(position, size: rl.Vector2) -> rl.Rectangle {
	return rl.Rectangle{position.x, position.y, size.x, size.y}
}

// Checks whether the player collides with an obstacle.
// Invulnerability (Section 4, during flip transitions) blocks collisions entirely.
// Note: Chasm and DreamHole use the exact same check as Block/PulsingShape —
// the "inverted reading" from the design doc is visual only (see draw_obstacle),
// the underlying rule is always "don't be in this lane when it arrives".
check_player_obstacle_collision :: proc(player: Player, obstacle: Obstacle, world: World) -> bool {
	if player.is_invulnerable {
		return false
	}

	obstacle_position := get_obstacle_position(obstacle, world)
	obstacle_size := get_obstacle_size(obstacle, world)

	player_rect := to_rect(player.position, player.size)
	obstacle_rect := to_rect(obstacle_position, obstacle_size)

	return rl.CheckCollisionRecs(player_rect, obstacle_rect)
}
