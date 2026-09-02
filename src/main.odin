/*
* Wake Shift
* main.odin
* game built with Odin and Raylib
*
* Structure of this file:
*   1. draw_gameplay and interpolated_world — the two helpers that live
*      here rather than in a package: pure orchestration of game/render
*      calls, neither a game nor a render concern in its own right
*   2. Window + one-time setup
*   3. State declarations (one variable per subsystem, roughly in the
*      order each subsystem was introduced across the roadmap sections)
*   4. Main loop:
*      - UPDATE: reads input, then advances the simulation in fixed steps
*        (core/time.odin) — a frame may run zero, one, or several
*      - DRAW:   renders whatever state UPDATE settled on, onto the
*        virtual canvas (platform/display.odin), which is then scaled and
*        presented to the real window/fullscreen once per frame
*/
package main

import "core"
import "game"
import "platform"
import "render"
import "ui"
import "core:math/rand"
import rl "vendor:raylib/v55"

// Draws terrain, every obstacle, then the player on top — the gameplay
// scene itself, with no HUD or overlay. Playing draws this live; Paused
// and GameOver draw the same frozen scene underneath their own overlay,
// so without this helper the three calls would repeat identically in
// every case of the DRAW switch below.
draw_gameplay :: proc(world: game.World, obstacles: []game.Obstacle, player: game.Player) {
	render.draw_terrain(world)
	for obstacle in obstacles {
		render.draw_obstacle(obstacle, world)
	}
	render.draw_player(player)
}

// Returns a copy of the world advanced by the leftover fraction of a
// simulation step, for drawing only. Terrain scroll and every obstacle
// position derive from world time, so nudging that one value forward
// smooths the whole scene without any of them needing to know that a
// fixed timestep exists.
//
// Never feed the result back into the simulation: it is a display-only
// extrapolation, and the real world state is the one that was stepped.
interpolated_world :: proc(world: game.World, accumulator: f32) -> game.World {
	ahead := world
	ahead.elapsed_time += accumulator
	ahead.scroll_offset += ahead.scroll_speed * accumulator
	return ahead
}

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
	// window/fullscreen at the end of each frame (see platform/display.odin)
	disp := platform.new_display()
	defer platform.destroy_display(disp)

	// build the cumulative per-tier pattern pools, then catch any
	// pattern-authoring mistakes immediately at startup — for every tier,
	// not just the base one
	game.build_tier_pools()
	game.validate_tier_pools()

	// --- Persistent state (survives across runs, not reset by reset_run) ---

	// personal best, loaded once at startup, saved on every new record (section 14)
	high_score := platform.load_high_score()

	// navigable menus, shared widget (section 13)
	main_menu := ui.new_menu([]string{"Start Run", "Quit"})
	pause_menu := ui.new_menu([]string{"Resume", "Main Menu"})

	should_quit := false

	// overall application screen state — starts at the main menu (section 13)
	game_state := game.GameState.MainMenu

	// --- Per-run state (all reset together by reset_run, section 13/17) ---

	// player: position, lane, flip/transition state (sections 1-4, 15)
	player := game.new_player()

	// world: scroll speed and elapsed time (section 5, 8)
	world := game.new_world()

	// obstacle list, filled in continuously by the pattern generator (section 9-10)
	obstacles: [dynamic]game.Obstacle

	// seed for the current run: decides every random choice the level
	// generator makes. Drawn fresh here, at the composition root, because
	// it is an input to the run — a replay would set it from a recorded
	// RunManifest instead (roadmap T2.8) and change nothing else.
	run_seed := rand.uint64()

	// pattern generator: starts 2 safe seconds in, requiring the player
	// to be in the Dream lane first (matches pattern_steady_real's entry_lane)
	generator := game.new_pattern_generator(game.all_patterns, 2.0, .Dream, run_seed)

	// records which ticks the player flipped on, so a run that sets a
	// record can be stored as something replayable rather than a bare
	// number (core/manifest.odin)
	recorder := core.new_run_recorder(run_seed)
	defer core.destroy_run_recorder(&recorder)

	// run score, Dream Depth (section 12)
	score := game.new_score()

	// near-miss streak, drives the score multiplier (section 17)
	lucidity := game.new_lucidity()

	// --- Fixed timestep bookkeeping (core/time.odin) ---

	// Real time seen but not yet simulated. Always drained below one full
	// step by the end of a frame.
	accumulator: f32 = 0

	// Simulation input waiting for a step to consume it. Needed because a
	// frame and a step are no longer the same thing: a frame that runs no
	// step would otherwise drop the press, and one that runs two would
	// apply it twice.
	pending_input := core.Input{}

	// --- Main loop ---
	for !rl.WindowShouldClose() && !should_quit {

		// Sample the keyboard exactly once per frame, here. Nothing
		// downstream polls raylib for itself — see core/input.odin.
		input := platform.read_input()

		if input.toggle_fullscreen {
			rl.ToggleFullscreen()
		}

		// ============================================================
		// UPDATE — one switch, reads input and advances game logic.
		// Runs once per frame, BEFORE anything is drawn.
		// Add new per-frame gameplay logic inside the .Playing case.
		// ============================================================
		switch game_state {
		case .MainMenu:
			if ui.update_menu(&main_menu, input) {
				if main_menu.selected == 0 {
					run_seed = rand.uint64()
					game.reset_run(&player, &world, &score, &obstacles, &generator, &lucidity, run_seed)
					accumulator = 0
					pending_input = core.Input{}
					core.destroy_run_recorder(&recorder)
					recorder = core.new_run_recorder(run_seed)
					game_state = .Playing
				} else {
					should_quit = true
				}
				main_menu.selected = 0
			}

		case .Playing:
			if input.pause {
				pause_menu.selected = 0
				game_state = .Paused
			}

			// Hold this frame's flip until a step takes it (see pending_input).
			pending_input.flip = pending_input.flip || input.flip

			accumulator += min(rl.GetFrameTime(), core.MAX_FRAME_TIME)

			// Run as many whole simulation steps as the elapsed real time
			// has earned — usually one, occasionally none or two.
			for accumulator >= core.FIXED_TIMESTEP {
				accumulator -= core.FIXED_TIMESTEP

				// This step consumes the latched input; any further step
				// this frame sees no press, exactly as if the key had been
				// released, because it has.
				step_input := pending_input
				pending_input = core.Input{}

				// world.tick is still the count of completed steps here,
				// so it names the step this input is about to drive —
				// exactly the index a replay would feed it back on.
				if step_input.flip {
					core.record_flip(&recorder, world.tick)
				}

				// figure out the current difficulty tier (based on the previous
				// step's elapsed_time — one step of lag here is irrelevant)
				tier_index := game.get_current_tier_index(world.elapsed_time)

				// keep the generator drawing from the pool unlocked so far
				generator.pool = game.get_pool_for_tier(tier_index)

				// update the world (scroll, easing toward this tier's target
				// speed) — must run before update_player, since update_player
				// now reads world.elapsed_time (section 17)
				game.update_world(
					&world,
					core.FIXED_TIMESTEP,
					game.tiers[tier_index].scroll_speed,
				)

				// update the player (input, flip/transition state)
				game.update_player(&player, world, step_input, core.FIXED_TIMESTEP)

				// update the score, scaled by the current Lucidity multiplier
				game.update_score(
					&score,
					player,
					core.FIXED_TIMESTEP,
					game.get_score_multiplier(lucidity),
				)

				// keep generating obstacles ahead of the player
				game.generate_ahead(&generator, &obstacles, world.elapsed_time)

				// check collision against every obstacle
				for obstacle in obstacles {
					if game.check_player_obstacle_collision(player, obstacle, world) {
						game_state = .GameOver
						game.reset_lucidity(&lucidity)

						// the run just ended: this is the one moment we check
						// and persist a new personal best
						if score.value > high_score {
							high_score = score.value
							platform.save_best_run(
								high_score,
								core.build_manifest(recorder, world.tick, score.value),
							)
						}
					}
				}

				// mark obstacles that just passed the player as resolved,
				// registering a near-miss into the Lucidity streak when
				// deserved (only if the run didn't just end above)
				if game_state == .Playing {
					for i in 0 ..< len(obstacles) {
						obstacle := &obstacles[i]
						if !obstacle.lucidity_resolved &&
						   world.elapsed_time >= obstacle.arrival_time {
							obstacle.lucidity_resolved = true
							game.register_obstacle_passed(&lucidity, player, obstacle^)
						}
					}
				}

				// drop obstacles that are off-screen and already counted,
				// so the list stays short instead of growing all run
				game.remove_finished_obstacles(&obstacles, world)

				// The run ended inside this step: stop simulating, whatever
				// time is left in the accumulator belongs to the next run.
				if game_state != .Playing {
					accumulator = 0
					pending_input = core.Input{}
					break
				}
			}

		case .Paused:
			if ui.update_menu(&pause_menu, input) {
				if pause_menu.selected == 0 {
					game_state = .Playing
				} else {
					game_state = .MainMenu
				}
			}
		// deliberately nothing else runs here: world, player, obstacles
		// all stay frozen exactly as they were when ESC was pressed

		case .GameOver:
			if input.confirm {
				run_seed = rand.uint64()
				game.reset_run(&player, &world, &score, &obstacles, &generator, &lucidity, run_seed)
				accumulator = 0
				pending_input = core.Input{}
				core.destroy_run_recorder(&recorder)
				recorder = core.new_run_recorder(run_seed)
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
		platform.begin_game_canvas(disp)
		rl.ClearBackground(rl.BEIGE)

		switch game_state {
		case .MainMenu:
			ui.draw_main_menu(main_menu, high_score)

		case .Playing:
			// The simulation moves in whole steps; the display refreshes
			// on its own schedule. Drawing the last stepped state directly
			// would visibly stutter on frames that ran no step, so the
			// scene is drawn from a *copy* of the world nudged forward by
			// whatever fraction of a step is still in the accumulator.
			//
			// Scrolling is perfectly linear, so this is exact rather than a
			// guess. It does mean the picture leads the collision state by
			// up to one step (~17ms) — the forgiving direction: something
			// can look like it grazed you a frame before the game agrees.
			draw_gameplay(interpolated_world(world, accumulator), obstacles[:], player)
			ui.draw_hud(score, lucidity, game.tiers[game.get_current_tier_index(world.elapsed_time)].name)

		case .Paused:
			// draw the frozen gameplay frame underneath, then the overlay on top
			draw_gameplay(world, obstacles[:], player)
			ui.draw_hud(score, lucidity, game.tiers[game.get_current_tier_index(world.elapsed_time)].name)
			ui.draw_pause_overlay(pause_menu)

		case .GameOver:
			draw_gameplay(world, obstacles[:], player)
			ui.draw_game_over(score, high_score)
		}

		platform.end_game_canvas()
		platform.present_display(disp)
	}
}
