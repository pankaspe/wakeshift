/*
* Wake Shift
* main.odin
* game built with Odin and Raylib
*/

package main
import "core:fmt"
import rl "vendor:raylib/v55"

main :: proc() {

	// set window size but need to do dynamic for full screen and adapt resolution
	rl.InitWindow(1280, 720, "Wake Shift")
	defer rl.CloseWindow()

	// set fps
	rl.SetTargetFPS(60)

	// create the player, anchored to the floor in the real lane
	player := new_player()

	// create the world (scroll, state)
	world := new_world()

	// build the obstacle list by chaining the hand-authored pattern pool,
	// giving the player 2 safe seconds before the first obstacle arrives
	obstacles := build_obstacles_from_patterns(real_world_patterns, 2.0)

	// overall game state
	game_state := GameState.Playing

	// start main loop until close
	for !rl.WindowShouldClose() {

		// start drawing frames
		rl.BeginDrawing()
		defer rl.EndDrawing()

		// clear background color for each frame
		rl.ClearBackground(rl.BEIGE)

		if game_state == .Playing {
			// update the world (scroll)
			update_world(&world, rl.GetFrameTime())

			// update the player (input, state)
			update_player(&player)

			// check collision against every obstacle
			for obstacle in obstacles {
				if check_player_obstacle_collision(player, obstacle, world) {
					game_state = .GameOver
				}
			}
		} else if game_state == .GameOver {
			// restart the run
			if rl.IsKeyPressed(.ENTER) {
				player = new_player()
				world = new_world()

				delete(obstacles)
				obstacles = build_obstacles_from_patterns(real_world_patterns, 2.0)

				game_state = .Playing
			}
		}

		// draw the world (floor/ceiling marks)
		draw_world(world)

		// draw every obstacle
		for obstacle in obstacles {
			draw_obstacle(obstacle, world)
		}

		// draw the player
		draw_player(player)

		if game_state == .GameOver {
			rl.DrawText("AWAKENED", 480, 300, 40, rl.RED)
			rl.DrawText("Press ENTER to try again", 440, 350, 20, rl.DARKGRAY)
		}
	}
}
