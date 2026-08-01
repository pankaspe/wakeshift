/*
* Wake Shift
* main.odin
* game built with Odin and Raylib
*/
package main

import rl "vendor:raylib/v55"

main :: proc() {
	// set window size but need to do dynamic for full screen and adapt resolution
	rl.InitWindow(1280, 720, "Wake Shift")
	defer rl.CloseWindow()
	// set fps
	rl.SetTargetFPS(60)
	// disable raylib's default ESC-closes-window behavior: we use ESC to pause instead
	rl.SetExitKey(.KEY_NULL)

	// catch any pattern-authoring mistakes immediately at startup
	validate_pattern_pool(all_patterns)

	// run score (Dream Depth)
	score := new_score()

	// personal best, loaded once at startup
	high_score := load_high_score()

	// navigable menus, shared widget (Design Doc, section 9)
	main_menu := new_menu([]string{"Start Run", "Quit"})
	pause_menu := new_menu([]string{"Resume", "Main Menu"})

	should_quit := false

	// create the player, anchored to the floor in the Real lane
	player := new_player()

	// create the world (scroll state)
	world := new_world()

	// obstacle list, filled in continuously by the pattern generator
	obstacles: [dynamic]Obstacle

	// pattern generator: starts 2 safe seconds in, requiring the player
	// to be in the Dream lane first (matches pattern_steady_real's entry_lane)
	generator := new_pattern_generator(all_patterns, 2.0, .Dream)

	// overall game state — starts at the main menu
	game_state := GameState.MainMenu

	// start main loop until close
	for !rl.WindowShouldClose() && !should_quit {

		// ============================================================
		// UPDATE — one switch, reads input and advances game logic.
		// Runs once per frame, BEFORE anything is drawn.
		// ============================================================
		switch game_state {
		case .MainMenu:
			if update_menu(&main_menu) {
				if main_menu.selected == 0 {
					reset_run(&player, &world, &score, &obstacles, &generator)
					game_state = .Playing
				} else {
					should_quit = true
				}
				main_menu.selected = 0
			}

		case .Playing:
			if rl.IsKeyPressed(.ESCAPE) {
				pause_menu.selected = 0
				game_state = .Paused
			}

			// update the world (scroll)
			update_world(&world, rl.GetFrameTime())

			// update the player (input, state)
			update_player(&player)

			// update the score
			update_score(&score, player, rl.GetFrameTime())

			// keep generating obstacles ahead of the player
			generate_ahead(&generator, &obstacles, world.elapsed_time)

			// check collision against every obstacle
			for obstacle in obstacles {
				if check_player_obstacle_collision(player, obstacle, world) {
					game_state = .GameOver

					// the run just ended: this is the one moment we check
					// and persist a new personal best
					if score.value > high_score {
						high_score = score.value
						save_high_score(high_score)
					}
				}
			}

		case .Paused:
			if update_menu(&pause_menu) {
				if pause_menu.selected == 0 {
					game_state = .Playing
				} else {
					game_state = .MainMenu
				}
			}
		// deliberately nothing else runs here: world, player, obstacles
		// all stay frozen exactly as they were when ESC was pressed

		case .GameOver:
			if rl.IsKeyPressed(.ENTER) {
				reset_run(&player, &world, &score, &obstacles, &generator)
				game_state = .Playing
			}
		}

		// ============================================================
		// DRAW — separate switch, only draws what's already been decided
		// above. Never changes game state or game logic, only pixels.
		// Runs once per frame, AFTER update, between BeginDrawing/EndDrawing.
		// ============================================================
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BEIGE)

		switch game_state {
		case .MainMenu:
			draw_main_menu(main_menu, high_score)

		case .Playing:
			draw_world(world)
			for obstacle in obstacles {
				draw_obstacle(obstacle, world)
			}
			draw_player(player)
			draw_hud(score)

		case .Paused:
			// draw the frozen gameplay frame underneath, then the overlay on top
			draw_world(world)
			for obstacle in obstacles {
				draw_obstacle(obstacle, world)
			}
			draw_player(player)
			draw_hud(score)
			draw_pause_overlay(pause_menu)

		case .GameOver:
			draw_world(world)
			for obstacle in obstacles {
				draw_obstacle(obstacle, world)
			}
			draw_player(player)
			draw_game_over(score, high_score)
		}
	}
}
