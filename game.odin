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
check_player_obstacle_collision :: proc(player: Player, obstacle: Obstacle, world: World) -> bool {
	if player.is_invulnerable {
		return false
	}

	obstacle_position := get_obstacle_position(obstacle, world)

	player_rect := to_rect(player.position, player.size)
	obstacle_rect := to_rect(obstacle_position, obstacle.size)

	return rl.CheckCollisionRecs(player_rect, obstacle_rect)
}
