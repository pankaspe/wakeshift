/*
* Wake Shift
* main.odin
* game built with Odin and Raylib
*
* Structure of this file:
*   1. Window + one-time setup
*   2. State declarations (one variable per subsystem, roughly in the
*      order each subsystem was introduced across the roadmap sections)
*   3. Main loop, split into two switches over game_state:
*      - UPDATE: reads input, advances logic, may change game_state
*      - DRAW:   renders whatever state UPDATE just settled on, onto the
*        virtual canvas (display.odin), which is then scaled and
*        presented to the real window/fullscreen once per frame
*/
package main

import rl "vendor:raylib/v55"

main :: proc() {
	// --- Window + one-time setup ---
	// resizable so the window can be dragged to any size; combined with
	// Display's letterboxed scaling, the game always fills it correctly
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1280, 720, "Wake Shift")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	// disable raylib's default ESC-closes-window behavior: we use ESC to pause instead
	rl.SetExitKey(.KEY_NULL)

	// virtual canvas the whole game draws to, scaled to fill the real
	// window/fullscreen at the end of each frame (see display.odin)
	display := new_display()
	defer destroy_display(display)

	// build the cumulative per-tier pattern pools, then catch any
	// pattern-authoring mistakes immediately at startup — for every tier,
	// not just the base one
	build_tier_pools()
	validate_tier_pools()

	// --- Persistent state (survives across runs, not reset by reset_run) ---

	// personal best, loaded once at startup, saved on every new record (section 14)
	high_score := load_high_score()

	// navigable menus, shared widget (section 13)
	main_menu := new_menu([]string{"Start Run", "Quit"})
	pause_menu := new_menu([]string{"Resume", "Main Menu"})

	should_quit := false

	// overall application screen state — starts at the main menu (section 13)
	game_state := GameState.MainMenu

	// --- Per-run state (all reset together by reset_run, section 13/17) ---

	// player: position, lane, flip/transition state (sections 1-4, 15)
	player := new_player()

	// world: scroll speed and elapsed time (section 5, 8)
	world := new_world()

	// obstacle list, filled in continuously by the pattern generator (section 9-10)
	obstacles: [dynamic]Obstacle

	// pattern generator: starts 2 safe seconds in, requiring the player
	// to be in the Dream lane first (matches pattern_steady_real's entry_lane)
	generator := new_pattern_generator(all_patterns, 2.0, .Dream)

	// run score, Dream Depth (section 12)
	score := new_score()

	// near-miss streak, drives the score multiplier (section 17)
	lucidity := new_lucidity()

	// --- Main loop ---
	for !rl.WindowShouldClose() && !should_quit {

		if rl.IsKeyPressed(.F11) {
			rl.ToggleFullscreen()
		}

		// ============================================================
		// UPDATE — one switch, reads input and advances game logic.
		// Runs once per frame, BEFORE anything is drawn.
		// Add new per-frame gameplay logic inside the .Playing case.
		// ============================================================
		switch game_state {
		case .MainMenu:
			if update_menu(&main_menu) {
				if main_menu.selected == 0 {
					reset_run(&player, &world, &score, &obstacles, &generator, &lucidity)
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

			// figure out the current difficulty tier (based on last frame's
			// elapsed_time — one frame of lag here is irrelevant in practice)
			tier_index := get_current_tier_index(world.elapsed_time)

			// keep the generator drawing from the pool unlocked so far
			generator.pool = get_pool_for_tier(tier_index)

			// update the world (scroll, easing toward this tier's target
			// speed) — must run before update_player, since update_player
			// now reads world.elapsed_time (section 17)
			update_world(&world, rl.GetFrameTime(), tiers[tier_index].scroll_speed)

			// update the player (input, flip/transition state)
			update_player(&player, world)

			// update the score, scaled by the current Lucidity multiplier
			update_score(&score, player, rl.GetFrameTime(), get_score_multiplier(lucidity))

			// keep generating obstacles ahead of the player
			generate_ahead(&generator, &obstacles, world.elapsed_time)

			// check collision against every obstacle
			for obstacle in obstacles {
				if check_player_obstacle_collision(player, obstacle, world) {
					game_state = .GameOver
					reset_lucidity(&lucidity)

					// the run just ended: this is the one moment we check
					// and persist a new personal best
					if score.value > high_score {
						high_score = score.value
						save_high_score(high_score)
					}
				}
			}

			// mark obstacles that just passed the player as resolved,
			// registering a near-miss into the Lucidity streak when
			// deserved (only if the run didn't just end above)
			if game_state == .Playing {
				for i in 0 ..< len(obstacles) {
					obstacle := &obstacles[i]
					if !obstacle.lucidity_resolved && world.elapsed_time >= obstacle.arrival_time {
						obstacle.lucidity_resolved = true
						register_obstacle_passed(&lucidity, player, obstacle^)
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
				reset_run(&player, &world, &score, &obstacles, &generator, &lucidity)
				game_state = .Playing
			}
		}

		// ============================================================
		// DRAW — separate switch, only draws what's already been decided
		// above. Never changes game state or game logic, only pixels.
		// Runs once per frame, AFTER update, onto the fixed-resolution
		// virtual canvas (begin/end_game_canvas), which present_display
		// then scales and letterboxes into the real window/fullscreen.
		// Add new visual elements inside the relevant case(s) below.
		// ============================================================
		begin_game_canvas(display)
		rl.ClearBackground(rl.BEIGE)

		switch game_state {
		case .MainMenu:
			draw_main_menu(main_menu, high_score)

		case .Playing:
			draw_terrain(world)
			for obstacle in obstacles {
				draw_obstacle(obstacle, world)
			}
			draw_player(player)
			draw_hud(score, lucidity, tiers[get_current_tier_index(world.elapsed_time)].name)

		case .Paused:
			// draw the frozen gameplay frame underneath, then the overlay on top
			draw_terrain(world)
			for obstacle in obstacles {
				draw_obstacle(obstacle, world)
			}
			draw_player(player)
			draw_hud(score, lucidity, tiers[get_current_tier_index(world.elapsed_time)].name)
			draw_pause_overlay(pause_menu)

		case .GameOver:
			draw_terrain(world)
			for obstacle in obstacles {
				draw_obstacle(obstacle, world)
			}
			draw_player(player)
			draw_game_over(score, high_score)
		}

		end_game_canvas()
		present_display(display)
	}
}
