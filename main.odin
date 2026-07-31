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

	// catch any pattern-authoring mistakes immediately at startup
	validate_pattern_pool(all_patterns)

	// create the player, anchored to the floor in the real lane
	player := new_player()

	// create the world (scroll, state)
	world := new_world()

	// obstacle list, filled in continuously by the pattern generator
	obstacles: [dynamic]Obstacle

	// pattern generator: starts 2 safe seconds in, requiring the player
	// to be in the Dream lane first (matches pattern_steady_real's entry_lane)
	generator := new_pattern_generator(all_patterns, 2.0, .Dream)

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

			// keep generating obstacles ahead of the player
			generate_ahead(&generator, &obstacles, world.elapsed_time)

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
				obstacles = nil
				generator = new_pattern_generator(all_patterns, 2.0, .Dream)

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
