/*
* Wake Shift
* main.odin
* game built with Odin and Raylib
*
* Structure of this file:
*   1. draw_gameplay and interpolated_world — the two helpers that live
*      here rather than in a package: pure orchestration of game/render
*      calls, neither a game nor a render concern in its own right
*   2. Window + one-time setup — settings are read from disk *before*
*      the window exists, so it is created in the mode and size the
*      player left it in (platform/settings)
*   3. State declarations, one variable per subsystem
*   4. Main loop:
*      - UPDATE: reads input, then advances the simulation in fixed steps
*        (core/time.odin) — a frame may run zero, one, or several
*      - DRAW:   renders whatever state UPDATE settled on, onto the
*        virtual canvas (platform/display.odin), which is then scaled and
*        presented to the real window/fullscreen once per frame
*/
package main

import "core"
import "fx"
import "game"
import "platform"
import "render"
import "ui"
import "core:math/rand"
import rl "vendor:raylib/v55"

// Whether the Corruption still drains the finished frame to black behind
// its front (fx/corruption.odin).
//
// Off since RL.6, because the world is a line and the Corruption is the
// line ceasing to be there: the maze is clipped at the front, so behind it
// there is nothing left to drain — only the field, and a field with no
// drawing on it is what "the world is not here" looks like on paper.
CORRUPTION_FILTER_ENABLED :: false

// Draws the maze, then the block on top — the gameplay scene itself, on a
// background already drawn, with no HUD or overlay. Playing draws this
// live; Paused and GameOver draw the same frozen scene under their own
// overlay, so without this helper the three calls would repeat in every
// case of the DRAW switch below.
draw_gameplay :: proc(
	maze: ^game.Maze,
	world: game.World,
	player: game.Player,
	corruption: game.Corruption,
	dream: game.Dream,
	palettes: core.PaletteSet,
	particles: fx.Particles,
) {
	// The world exists between the two fronts: written by the pen on the
	// right, eaten by the Corruption on the left. Both are a clip, and
	// both of them are this one number and DRAW_FRONT_X. The left one is
	// usually off the picture, and clipping to it then costs nothing.
	front_x := game.get_corruption_screen_x(corruption, world)
	render.draw_maze(maze, world, palettes, front_x)

	// Between the walls and the body: a pickup is an object in the maze,
	// and the block passing over one has to cover it.
	render.draw_pickups(maze, world, palettes, front_x, dream)

	// The dust the world's line throws off as it reaches the front. Drawn
	// with the world because it *is* the world, a moment later.
	fx.draw_particles(particles)

	render.draw_player(player, world, palettes)

	// The bar, around the body it belongs to (render/charge.odin).
	render.draw_charge(player, dream, world, palettes)

	// Last, over everything: the front is in front of the world it is
	// eating. This is the edge; the fraying is the dust above.
	render.draw_corruption(corruption, player, world, palettes)
}

// Returns a copy of the world advanced by the leftover fraction of a
// simulation step, for drawing only. Every wall's screen x derives from
// the camera, so running the camera's own chase over the leftover time
// smooths the whole scene without any of it needing to know a fixed
// timestep exists.
//
// It is handed the *interpolated* body, not the stepped one, or the camera
// would be chasing where the player was rather than where they are drawn.
//
// Never feed the result back into the simulation: it is a display-only
// extrapolation, and the real world state is the one that was stepped.
interpolated_world :: proc(
	world: game.World,
	ahead_player: game.Player,
	accumulator: f32,
) -> game.World {
	ahead := world
	ahead.elapsed_time += accumulator
	game.advance_camera(&ahead, accumulator, game.get_player_world(ahead_player).x)
	return ahead
}

// Returns a copy of the player advanced by the same fraction the world is,
// for drawing only.
//
// Without it the picture is **asymmetric**, and that is a bug you can see:
// the maze is drawn where it will be a fraction of a step from now and the
// block where it was at the last whole one, so a body sliding along a wall
// is drawn up to one step's scroll out of place. Exact rather than a
// guess: a slide is perfectly linear in distance.
interpolated_player :: proc(player: game.Player, accumulator: f32) -> game.Player {
	if player.dir == .None {
		return player
	}
	ahead := player
	ahead.travelled = min(ahead.travelled + game.RUNNER_SPEED * accumulator, ahead.length)
	return ahead
}

main :: proc() {
	// --- Window + one-time setup ---

	settings := platform.load_settings()
	platform.open_window(settings, "Wake Shift")
	defer rl.CloseWindow()
	// ESC pauses instead of closing the window
	rl.SetExitKey(.KEY_NULL)
	platform.show_window()

	window_settle := platform.WINDOW_SETTLE_FRAMES

	disp := platform.new_display()
	defer platform.destroy_display(disp)

	bloom := fx.new_bloom()
	defer fx.destroy_bloom(bloom)

	corruption_fx := fx.new_corruption()
	defer fx.destroy_corruption(corruption_fx)

	particles := fx.new_particles()

	dither := fx.new_dither()
	defer fx.destroy_dither(dither)

	background := render.new_background()
	defer render.destroy_background(background)

	// --- Persistent state (survives across runs) ---

	high_score := platform.load_high_score()

	main_menu_items := [?]ui.MenuItem{{label = "Start Run"}, {label = "Options"}, {label = "Quit"}}
	pause_menu_items := [?]ui.MenuItem {
		{label = "Resume"},
		{label = "Options"},
		{label = "Main Menu"},
	}
	main_menu := ui.new_menu(main_menu_items[:])
	pause_menu := ui.new_menu(pause_menu_items[:])

	options_screen: ui.OptionsScreen
	ui.init_options_screen(&options_screen)
	options_return := game.GameState.MainMenu

	resolution_storage: [core.MAX_WINDOW_RESOLUTIONS]core.Resolution
	resolutions := platform.list_window_resolutions(resolution_storage[:])

	should_quit := false
	game_state := game.GameState.MainMenu

	// --- Per-run state (all reset together by reset_run) ---

	player := game.new_player()
	world := game.new_world()

	// The seed for the current run: it decides every wall the generator
	// draws. Taken fresh here, at the composition root, because it is an
	// *input* to the run — a replay would set it from a recorded manifest
	// and change nothing else.
	run_seed := rand.uint64()
	maze := game.new_maze(run_seed)

	score := game.new_score()
	corruption := game.new_corruption()
	dream := game.new_dream()

	// The run's input log. It records flip ticks and a four-direction
	// control scheme has no flips, so **a manifest saved today does not
	// reproduce a run**. Kept live rather than deleted because everything
	// around it — the seed, the tick count, the save path — is what a
	// replay needs, and only the event type is wrong (see TIMELINE.md).
	recorder := core.new_run_recorder(run_seed)
	defer core.destroy_run_recorder(&recorder)

	// --- Fixed timestep bookkeeping (core/time.odin) ---

	accumulator: f32 = 0
	display_time: f32 = 0
	background_t: f32 = 0.5

	intro_timer: f32 = 0
	intro_dismissed_at: f32 = -1

	// How many pickups this frame's steps took, so the dust can be thrown
	// for something that *happened*. A difference read off the run's own
	// tally: presentation derived from the simulation, never the reverse.
	pickups_taken := 0

	// Simulation input waiting for a step to consume it. A frame and a step
	// are not the same thing: a frame that runs no step would otherwise
	// drop the press, and one that runs two would apply it twice.
	pending_input := core.Input{}

	start_run :: proc(
		player: ^game.Player,
		world: ^game.World,
		maze: ^game.Maze,
		score: ^game.Score,
		corruption: ^game.Corruption,
		dream: ^game.Dream,
		particles: ^fx.Particles,
		recorder: ^core.RunRecorder,
		accumulator: ^f32,
		pending_input: ^core.Input,
		intro_timer: ^f32,
		intro_dismissed_at: ^f32,
		seed: u64,
	) {
		game.reset_run(player, world, maze, score, corruption, dream, seed)
		fx.clear_particles(particles)
		accumulator^ = 0
		pending_input^ = core.Input{}
		intro_timer^ = 0
		intro_dismissed_at^ = -1
		core.destroy_run_recorder(recorder)
		recorder^ = core.new_run_recorder(seed)
	}

	// --- Main loop ---
	for !rl.WindowShouldClose() && !should_quit {
		defer free_all(context.temp_allocator)

		if window_settle > 0 {
			window_settle -= 1
			platform.apply_display_mode(settings)
		}
		platform.update_display(&disp)

		// The one clock read in the whole project, and the one keyboard
		// poll, both here. Clamped once, at the source.
		frame_time := min(rl.GetFrameTime(), core.MAX_FRAME_TIME)
		display_time += frame_time
		input := platform.read_input()

		if input.toggle_fullscreen {
			settings.display_mode = settings.display_mode == .Fullscreen ? .Windowed : .Fullscreen
			platform.apply_settings(settings)
			window_settle = platform.WINDOW_SETTLE_FRAMES
			resolutions = platform.list_window_resolutions(resolution_storage[:])
			platform.save_settings(settings)
		}

		// ============================================================
		// UPDATE
		// ============================================================
		switch game_state {
		case .MainMenu:
			if confirmed, _ := ui.update_menu(&main_menu, input); confirmed {
				switch main_menu.selected {
				case 0:
					run_seed = rand.uint64()
					start_run(
						&player,
						&world,
						&maze,
						&score,
						&corruption,
						&dream,
						&particles,
						&recorder,
						&accumulator,
						&pending_input,
						&intro_timer,
						&intro_dismissed_at,
						run_seed,
					)
					game_state = .Playing
				case 1:
					options_return = .MainMenu
					resolutions = platform.list_window_resolutions(resolution_storage[:])
					ui.sync_options_screen(&options_screen, settings, resolutions)
					game_state = .Options
				case:
					should_quit = true
				}
				main_menu.selected = 0
			}

		case .Playing:
			if input.pause {
				pause_menu.selected = 0
				game_state = .Paused
			}

			// The intro prompt lives on the frame clock, not on a step, so
			// it is advanced here and frozen whenever a step does not run.
			intro_timer += frame_time
			if game.input_direction(input) != .None && intro_dismissed_at < 0 {
				intro_dismissed_at = intro_timer
			}

			// Hold this frame's press until a step takes it. The held
			// state is level-triggered and is simply the latest reading,
			// so it is copied rather than accumulated.
			pending_input.move_up ||= input.move_up
			pending_input.move_down ||= input.move_down
			pending_input.move_left ||= input.move_left
			pending_input.move_right ||= input.move_right
			pending_input.hold_up = input.hold_up
			pending_input.hold_down = input.hold_down
			pending_input.hold_left = input.hold_left
			pending_input.hold_right = input.hold_right

			accumulator += frame_time

			for accumulator >= core.FIXED_TIMESTEP {
				accumulator -= core.FIXED_TIMESTEP

				// This step consumes the latched press; any further step
				// this frame sees none, exactly as if the key had been
				// released, because it has. A key still *held* keeps
				// meaning the same thing, so it survives the reset.
				step_input := pending_input
				pending_input.move_up = false
				pending_input.move_down = false
				pending_input.move_left = false
				pending_input.move_right = false

				// A key held down repeats the move it already means, once
				// the body is free to take another. It is not a second
				// gesture — see core/input.odin.
				if player.dir == .None && game.input_direction(step_input) == .None {
					step_input.move_up = step_input.hold_up
					step_input.move_down = step_input.hold_down
					step_input.move_left = step_input.hold_left
					step_input.move_right = step_input.hold_right
				}

				// Every chunk the pen will reach, built here rather than
				// from inside a draw (game/maze.odin).
				game.ensure_maze_ahead(&maze, world)

				// The body moves first now, and then the camera follows it.
				// The order used to be the other way round because the
				// camera was the thing setting the pace; it is a camera
				// again (game/world.odin), so it goes second.
				// The Dream's rules are in force from the instant the bar
				// fills, not from the end of the crossing: a pierce that
				// half worked would be unreadable.
				game.update_player(
					&player,
					&maze,
					step_input,
					core.FIXED_TIMESTEP,
					game.dream_is_active(dream),
				)

				// Before the bar is stepped, so a fragment that fills it
				// turns the world on the step it was taken.
				taken_before := dream.fragments + dream.lucids
				game.collect_pickups(&maze, player, &dream)
				pickups_taken += dream.fragments + dream.lucids - taken_before
				game.update_dream(&dream, core.FIXED_TIMESTEP)

				game.update_world(&world, core.FIXED_TIMESTEP, game.get_player_world(player).x)

				// The front comes on through the world, on its own clock
				// and never on the camera's.
				game.update_corruption(&corruption, player, dream, core.FIXED_TIMESTEP)

				game.update_score(&score, player)

				// Out of room: the front caught up. The only ending there
				// is, which is the design working rather than a
				// simplification (pillar 7).
				if game.corruption_has_reached(corruption, player) {
					game_state = .GameOver
					if score.value > high_score {
						high_score = score.value
						platform.save_best_run(
							high_score,
							core.build_manifest(recorder, world.tick, score.value),
						)
					}
				}

				if game_state != .Playing {
					accumulator = 0
					pending_input = core.Input{}
					break
				}
			}

		case .Paused:
			if confirmed, _ := ui.update_menu(&pause_menu, input); confirmed {
				switch pause_menu.selected {
				case 0:
					game_state = .Playing
				case 1:
					options_return = .Paused
					resolutions = platform.list_window_resolutions(resolution_storage[:])
					ui.sync_options_screen(&options_screen, settings, resolutions)
					game_state = .Options
				case:
					game_state = .MainMenu
				}
			}
		// deliberately nothing else runs here: the world and the body stay
		// frozen exactly as they were when ESC was pressed

		case .Options:
			leave, changed := ui.update_options_screen(
				&options_screen,
				&settings,
				resolutions,
				input,
			)
			if changed {
				platform.apply_settings(settings)
				window_settle = platform.WINDOW_SETTLE_FRAMES
				resolutions = platform.list_window_resolutions(resolution_storage[:])
			}
			if leave {
				platform.save_settings(settings)
				pause_menu.selected = 0
				main_menu.selected = 0
				game_state = options_return
			}

		case .GameOver:
			if input.confirm {
				run_seed = rand.uint64()
				start_run(
					&player,
					&world,
					&maze,
					&score,
					&corruption,
					&dream,
					&particles,
					&recorder,
					&accumulator,
					&pending_input,
					&intro_timer,
					&intro_dismissed_at,
					run_seed,
				)
				game_state = .Playing
			}
		}

		// ============================================================
		// DRAW
		// ============================================================
		platform.begin_game_canvas(disp)

		showing_run :=
			game_state == .Playing ||
			game_state == .Paused ||
			game_state == .GameOver ||
			(game_state == .Options && options_return == .Paused)

		palettes :=
			showing_run \
			? render.new_scene_palette(dream, world) \
			: render.new_menu_palette(display_time)

		rl.ClearBackground(palettes.neutral.deep)

		background_t = render.chase_background_t(background_t, palettes.world_t, frame_time)
		render.draw_background(background, palettes, background_t, display_time)

		// Only while actually playing, not for every state that *shows* a
		// run: a paused frame is a still, and dust drifting across one
		// would be the only thing on screen that had not stopped.
		if game_state == .Playing {
			render.emit_fray(&particles, world, corruption, player, palettes, frame_time)
			render.emit_pickup_burst(&particles, player, world, palettes, pickups_taken)
			fx.update_particles(&particles, frame_time)
		}
		pickups_taken = 0

		switch game_state {
		case .MainMenu:
			ui.draw_main_menu(main_menu, high_score, palettes)

		case .Playing:
			ahead_player := interpolated_player(player, accumulator)
			draw_gameplay(
				&maze,
				interpolated_world(world, ahead_player, accumulator),
				ahead_player,
				corruption,
				dream,
				palettes,
				particles,
			)
			ui.draw_hud(score, palettes)
			ui.draw_intro_prompt(intro_timer, intro_dismissed_at, palettes)

		case .Paused:
			draw_gameplay(&maze, world, player, corruption, dream, palettes, particles)
			ui.draw_hud(score, palettes)
			ui.draw_pause_overlay(pause_menu, palettes)

		case .GameOver:
			draw_gameplay(&maze, world, player, corruption, dream, palettes, particles)
			ui.draw_game_over(score, high_score, dream, palettes)

		case .Options:
			if options_return == .Paused {
				draw_gameplay(&maze, world, player, corruption, dream, palettes, particles)
			}
			ui.draw_options_screen(options_screen, palettes)
		}

		platform.end_game_canvas()

		fx.apply_bloom(
			&bloom,
			disp.render_target,
			fx.bloom_for_world(palettes.world_t, palettes.depth_t),
		)
		fx.apply_dither(dither, disp.render_target)

		if CORRUPTION_FILTER_ENABLED && showing_run {
			fx.apply_corruption(
				&corruption_fx,
				disp.render_target,
				game.get_corruption_screen_x(corruption, world) / core.SCREEN_WIDTH,
			)
		}

		platform.present_display(disp)
	}
}
