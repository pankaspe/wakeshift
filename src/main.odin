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
*      player left it in (platform/settings, roadmap T2.5.5)
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
import "fx"
import "game"
import "platform"
import "render"
import "ui"
import "core:math/rand"
import rl "vendor:raylib/v55"

// Draws terrain, every obstacle, then the player on top — the gameplay
// scene itself, on top of a background already drawn, with no HUD or
// overlay. Playing draws this live; Paused
// and GameOver draw the same frozen scene underneath their own overlay,
// so without this helper the three calls would repeat identically in
// every case of the DRAW switch below.
draw_gameplay :: proc(
	world: game.World,
	obstacles: []game.Obstacle,
	player: game.Player,
	palettes: core.PaletteSet,
) {
	render.draw_terrain(world, palettes)
	for obstacle in obstacles {
		render.draw_obstacle(obstacle, world, palettes)
	}
	render.draw_player(player, world, palettes)
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

	// Read first, before there is a window to read them for: nothing on
	// this path touches raylib (platform/save.odin), which is what lets the
	// window be born in the right mode instead of flashing through a
	// default one (roadmap T2.5.5).
	settings := platform.load_settings()

	// Born in the mode the settings ask for, and hidden until it is set up
	// (platform/window.odin). Resizable so the window can be dragged to any
	// size; combined with Display's letterboxed scaling, the game always
	// fills whatever size it ends up at.
	platform.open_window(settings, "Wake Shift")
	defer rl.CloseWindow()
	// disable raylib's default ESC-closes-window behavior: we use ESC to pause instead
	rl.SetExitKey(.KEY_NULL)

	platform.show_window()

	// Frames left in which to re-assert the window's bounds after a mode
	// change. A window manager applies its own constraints a frame or two
	// late, so the mode set above has to be insisted on for a moment
	// (platform/window.odin).
	window_settle := platform.WINDOW_SETTLE_FRAMES

	// canvas the whole game draws to. Game code keeps working in 1280x720
	// coordinates; the target itself is allocated at the real output
	// resolution and rebuilt whenever that changes (platform/display.odin).
	disp := platform.new_display()
	defer platform.destroy_display(disp)

	// Bloom runs on the finished frame, between the canvas closing and
	// the blit to the window (fx/bloom.odin). It allocates its own
	// buffers on the first frame and re-allocates them whenever the
	// frame's size changes, so nothing here has to tell it about resizes.
	bloom := fx.new_bloom()
	defer fx.destroy_bloom(bloom)

	// build the cumulative per-tier pattern pools, then catch any
	// pattern-authoring mistakes immediately at startup — for every tier,
	// not just the base one
	game.build_tier_pools()
	game.validate_tier_pools()

	// --- Persistent state (survives across runs, not reset by reset_run) ---

	// personal best, loaded once at startup, saved on every new record (section 14)
	high_score := platform.load_high_score()

	// navigable menus, shared widget (section 13). The item arrays live
	// here because a Menu borrows its rows rather than owning them (see
	// ui/menu.odin) — they have to outlive the menu, and main's scope is
	// the whole program.
	main_menu_items := [?]ui.MenuItem {
		{label = "Start Run"},
		{label = "Options"},
		{label = "Quit"},
	}
	pause_menu_items := [?]ui.MenuItem {
		{label = "Resume"},
		{label = "Options"},
		{label = "Main Menu"},
	}
	main_menu := ui.new_menu(main_menu_items[:])
	pause_menu := ui.new_menu(pause_menu_items[:])

	// options screen, plus the state it returns to — it is reachable from
	// both the main menu and the pause menu, and going "back" has to mean
	// whichever one opened it (roadmap T2.5.7)
	options_screen: ui.OptionsScreen
	ui.init_options_screen(&options_screen)
	options_return := game.GameState.MainMenu

	// window sizes worth offering on the monitor the window is on. Rebuilt
	// on entering the options screen and after a mode change, because a
	// window moved to another monitor gets a different list.
	resolution_storage: [core.MAX_WINDOW_RESOLUTIONS]core.Resolution
	resolutions := platform.list_window_resolutions(resolution_storage[:])

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

	// Wall time since launch. Drives presentation that has no run behind
	// it and must never be confused with world.elapsed_time, which is the
	// simulation's own clock and advances in fixed steps.
	display_time: f32 = 0

	// Simulation input waiting for a step to consume it. Needed because a
	// frame and a step are no longer the same thing: a frame that runs no
	// step would otherwise drop the press, and one that runs two would
	// apply it twice.
	pending_input := core.Input{}

	// The simulation's own view of whether the flip key is down
	// (core/input.odin). It goes up on the step that consumed a press and
	// comes down on the first step that sees the key released, and it
	// starts every run false — a key already held when a run begins does
	// nothing until it is released and pressed again.
	//
	// Kept here rather than read straight off the keyboard because it is
	// simulation state: the Limen depends on it, so a run is only
	// reproducible if every change to it is recorded (core/manifest.odin).
	flip_down := false

	// --- Main loop ---
	for !rl.WindowShouldClose() && !should_quit {

		// Anything formatted for this frame's HUD and menus is allocated
		// from the temporary arena; released here so a long session does
		// not accumulate a frame's worth of strings sixty times a second.
		defer free_all(context.temp_allocator)

		// A mode change is not one call but a short negotiation with the
		// window manager (platform/window.odin), so for a moment afterwards
		// the window is nudged toward the mode it was asked for. A no-op
		// once it is there.
		if window_settle > 0 {
			window_settle -= 1
			platform.apply_display_mode(settings)
		}

		// Rebuild the render target if the window changed size since the
		// last frame — a drag, a monitor change, or the fullscreen switch
		// below (platform/display.odin).
		platform.update_display(&disp)

		// The one clock read in the whole project, and the one keyboard
		// poll, both here (core/input.odin). Clamped once, at the source:
		// everything downstream is measuring the same frame.
		frame_time := min(rl.GetFrameTime(), core.MAX_FRAME_TIME)

		// Wall time since launch, for things that are drawn but not
		// simulated: the menu's slow drift between the two worlds, the
		// horizon's breathing on a screen with no run behind it. Never
		// reaches the simulation — that advances only in whole steps of
		// core.FIXED_TIMESTEP, out of the accumulator below.
		display_time += frame_time

		// Sample the keyboard exactly once per frame, here. Nothing
		// downstream polls raylib for itself — see core/input.odin.
		input := platform.read_input()

		// F11 is the same switch the options screen offers, so it changes
		// the setting rather than the window directly: however the mode was
		// changed, it is what the next launch starts in.
		if input.toggle_fullscreen {
			settings.display_mode = settings.display_mode == .Fullscreen ? .Windowed : .Fullscreen
			platform.apply_settings(settings)
			window_settle = platform.WINDOW_SETTLE_FRAMES
			resolutions = platform.list_window_resolutions(resolution_storage[:])
			platform.save_settings(settings)
		}

		// ============================================================
		// UPDATE — one switch, reads input and advances game logic.
		// Runs once per frame, BEFORE anything is drawn.
		// Add new per-frame gameplay logic inside the .Playing case.
		// ============================================================
		switch game_state {
		case .MainMenu:
			if confirmed, _ := ui.update_menu(&main_menu, input); confirmed {
				switch main_menu.selected {
				case 0:
					run_seed = rand.uint64()
					game.reset_run(&player, &world, &score, &obstacles, &generator, &lucidity, run_seed)
					accumulator = 0
					pending_input = core.Input{}
					flip_down = false
					core.destroy_run_recorder(&recorder)
					recorder = core.new_run_recorder(run_seed)
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

			// Hold this frame's flip until a step takes it (see pending_input).
			pending_input.flip = pending_input.flip || input.flip

			accumulator += frame_time

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
				//
				// Press first, then release: a key tapped and let go
				// inside a single frame records both on the same tick,
				// which describes a hold no step ever saw. That is what a
				// tap that short is.
				if step_input.flip {
					flip_down = true
					core.record_flip(&recorder, world.tick)
				}
				if flip_down && !input.flip_held {
					flip_down = false
					core.record_release(&recorder, world.tick)
				}
				step_input.flip_held = flip_down

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

				// update the player (input, the journey, the Limen).
				// Lucidity goes in by pointer because suspension spends
				// it, and it has to be spent before the score is paid at
				// the multiplier it leaves behind.
				game.update_player(&player, world, &lucidity, step_input, core.FIXED_TIMESTEP)

				// run down the HUD's payout flash
				game.update_lucidity(&lucidity, core.FIXED_TIMESTEP)

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
					flip_down = false
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
		// deliberately nothing else runs here: world, player, obstacles
		// all stay frozen exactly as they were when ESC was pressed

		case .Options:
			// A setting is applied the moment it changes, so the player sees
			// what they picked, and written to disk on the way out — one save
			// per visit instead of one per keypress.
			//
			// Safe to do mid-run: nothing here reaches the simulation, and the
			// long frame a mode change costs is capped by core.MAX_FRAME_TIME
			// before it can become catch-up steps.
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
				game.reset_run(&player, &world, &score, &obstacles, &generator, &lucidity, run_seed)
				accumulator = 0
				pending_input = core.Input{}
				flip_down = false
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

		// The palette of this frame (core/palette.odin). With a run on
		// screen it is read off the player's height and the run's depth;
		// with only a menu on screen there is no player to read, so it
		// drifts slowly between the two worlds instead — the first thing
		// anyone sees already states the premise.
		showing_run :=
			game_state == .Playing ||
			game_state == .Paused ||
			game_state == .GameOver ||
			(game_state == .Options && options_return == .Paused)

		palettes :=
			showing_run \
			? render.new_scene_palette(player, world) \
			: render.new_menu_palette(display_time)

		rl.ClearBackground(palettes.limen.deep)
		render.draw_background(palettes, showing_run ? world.elapsed_time : display_time)

		switch game_state {
		case .MainMenu:
			ui.draw_main_menu(main_menu, high_score, palettes)

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
			draw_gameplay(interpolated_world(world, accumulator), obstacles[:], player, palettes)
			ui.draw_hud(
				score,
				lucidity,
				game.tiers[game.get_current_tier_index(world.elapsed_time)].name,
				palettes,
			)

		case .Paused:
			// draw the frozen gameplay frame underneath, then the overlay on top
			draw_gameplay(world, obstacles[:], player, palettes)
			ui.draw_hud(
				score,
				lucidity,
				game.tiers[game.get_current_tier_index(world.elapsed_time)].name,
				palettes,
			)
			ui.draw_pause_overlay(pause_menu, palettes)

		case .GameOver:
			draw_gameplay(world, obstacles[:], player, palettes)
			ui.draw_game_over(score, high_score, palettes)

		case .Options:
			// Opened from the pause menu, the frozen run stays visible behind
			// it — the same overlay relationship the pause screen has, so
			// changing a setting mid-run does not look like leaving it.
			if options_return == .Paused {
				draw_gameplay(world, obstacles[:], player, palettes)
			}
			ui.draw_options_screen(options_screen, palettes)
		}

		platform.end_game_canvas()

		// The light, added after everything that emits it has been drawn.
		// It reads the same two variables the palette does, so the bloom
		// and the colors describe one world rather than two.
		fx.apply_bloom(&bloom, disp.render_target, fx.bloom_for_world(palettes.world_t, palettes.depth_t))

		platform.present_display(disp)
	}
}
