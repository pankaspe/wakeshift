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
	corruption: game.Corruption,
	palettes: core.PaletteSet,
) {
	render.draw_terrain(world, obstacles, palettes)
	for obstacle in obstacles {
		render.draw_obstacle(obstacle, world, palettes)
	}
	render.draw_player(player, world, palettes)

	// Last, over everything: the front is in front of the world it is
	// eating. The colour behind it dies in a post-process on the finished
	// frame (fx/corruption.odin) — this is only the edge.
	render.draw_corruption(corruption, player, palettes)
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

	// The colour dying from the left, applied to the finished frame after
	// the bloom (fx/corruption.odin). The *edge* of the front is drawn in
	// the world instead, so the player can still see it if this shader
	// fails to compile.
	corruption_fx := fx.new_corruption()
	defer fx.destroy_corruption(corruption_fx)

	// One level of noise over the finished frame, between the bloom and
	// the Corruption (fx/dither.odin). The background is the whole screen
	// now, so the banding in its gradients stopped being a detail.
	dither := fx.new_dither()
	defer fx.destroy_dither(dither)

	// The vignette mask the background is drawn through, baked once
	// (render/background.odin). render/ owns no globals, so main holds it
	// the same way it holds the bloom's buffers.
	background := render.new_background()
	defer render.destroy_background(background)

	// build the cumulative per-tier pattern pools, then catch any
	// pattern-authoring mistakes immediately at startup — for every tier,
	// not just the base one
	game.build_tier_pools()
	game.validate_tier_pools()
	game.validate_tier_balance()

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

	// pattern generator: starts 2 safe seconds in
	generator := game.new_pattern_generator(game.all_patterns, 2.0, run_seed)

	// records which ticks the player flipped on, so a run that sets a
	// record can be stored as something replayable rather than a bare
	// number (core/manifest.odin)
	recorder := core.new_run_recorder(run_seed)
	defer core.destroy_run_recorder(&recorder)

	// run score, Dream Depth: the distance travelled, and the only score
	score := game.new_score()

	// the dream going out behind the player: a front advancing from the
	// left, and the distance to it is the whole health bar (section 5)
	corruption := game.new_corruption()

	// --- Fixed timestep bookkeeping (core/time.odin) ---

	// Real time seen but not yet simulated. Always drained below one full
	// step by the end of a frame.
	accumulator: f32 = 0

	// Wall time since launch. Drives presentation that has no run behind
	// it and must never be confused with world.elapsed_time, which is the
	// simulation's own clock and advances in fixed steps.
	display_time: f32 = 0

	// Where the *background* thinks the player is, which is not quite
	// where they are: it chases world_t on a lag of its own so a burst of
	// flips washes the screen instead of strobing it
	// (render/background.odin). Presentation only, like display_time —
	// it is advanced from the frame clock and never enters a step. Starts
	// between the two worlds, which is where the menu's drift lives.
	background_t: f32 = 0.5

	// Simulation input waiting for a step to consume it. Needed because a
	// frame and a step are no longer the same thing: a frame that runs no
	// step would otherwise drop the press, and one that runs two would
	// apply it twice.
	pending_input := core.Input{}

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
					game.reset_run(&player, &world, &score, &obstacles, &generator, &corruption, run_seed)
					accumulator = 0
					pending_input = core.Input{}
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
				if step_input.flip {
					core.record_flip(&recorder, world.tick)
				}

				// figure out the current difficulty tier (based on the previous
				// step's elapsed_time — one step of lag here is irrelevant)
				tier_index := game.get_current_tier_index(world.elapsed_time)

				// point the generator at everything this tier changes:
				// the unlocked pool, the gap between patterns, and how
				// the draw is weighted by demand (difficulty.odin)
				game.set_generator_tier(&generator, tier_index)

				// update the world (scroll, easing toward this tier's target
				// speed) — must run before update_player, since update_player
				// now reads world.elapsed_time (section 17)
				game.update_world(
					&world,
					core.FIXED_TIMESTEP,
					game.tiers[tier_index].scroll_speed,
				)

				// update the player: the press, the journey it starts, and
				// the ground held or lost against the cubes already on
				// screen — which is why the obstacle list goes in
				game.update_player(
					&player,
					world,
					obstacles[:],
					step_input,
					core.FIXED_TIMESTEP,
				)

				// the front advances with distance, not with time
				game.update_corruption(&corruption, world)

				// depth is how far the *character* travelled, so a step
				// spent pinned against a cube scores nothing
				game.update_score(&score, world, player, core.FIXED_TIMESTEP)

				// keep generating obstacles ahead of the player
				game.generate_ahead(&generator, &obstacles, &world.track, world.elapsed_time)

				// out of room: the front caught up. Checked before the
				// obstacles because it is the ending the whole design is
				// built around, and it should not be masked by a gap the
				// player fell into on the same step.
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

				// check collision against every obstacle
				for obstacle in obstacles {
					if game_state != .Playing {
						break
					}
					if game.check_player_obstacle_collision(player, obstacle, world) {
						game_state = .GameOver

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

				// drop obstacles that are off-screen,
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
				game.reset_run(&player, &world, &score, &obstacles, &generator, &corruption, run_seed)
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

		rl.ClearBackground(palettes.neutral.deep)

		// The field is the world (Design Doc, section 10), and it arrives
		// about a second after the player does. Chased here rather than
		// inside the draw because it is state that has to survive the
		// frame, and it is advanced from the frame clock — the same wall
		// time display_time is made of, never a simulation step.
		background_t = render.chase_background_t(background_t, palettes.world_t, frame_time)
		render.draw_background(background, palettes, background_t, display_time)

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
			draw_gameplay(
				interpolated_world(world, accumulator),
				obstacles[:],
				player,
				corruption,
				palettes,
			)
			ui.draw_hud(score, palettes)

		case .Paused:
			// draw the frozen gameplay frame underneath, then the overlay on top
			draw_gameplay(world, obstacles[:], player, corruption, palettes)
			ui.draw_hud(score, palettes)
			ui.draw_pause_overlay(pause_menu, palettes)

		case .GameOver:
			draw_gameplay(world, obstacles[:], player, corruption, palettes)
			ui.draw_game_over(score, high_score, palettes)

		case .Options:
			// Opened from the pause menu, the frozen run stays visible behind
			// it — the same overlay relationship the pause screen has, so
			// changing a setting mid-run does not look like leaving it.
			if options_return == .Paused {
				draw_gameplay(world, obstacles[:], player, corruption, palettes)
			}
			ui.draw_options_screen(options_screen, palettes)
		}

		platform.end_game_canvas()

		// The light, added after everything that emits it has been drawn.
		// It reads the same two variables the palette does, so the bloom
		// and the colors describe one world rather than two.
		fx.apply_bloom(&bloom, disp.render_target, fx.bloom_for_world(palettes.world_t, palettes.depth_t))

		// After the bloom, because a lifted field pixel lands just *over*
		// the lowest bloom threshold and the bright pass must never see
		// one; and before the Corruption, so the void behind the front
		// stays a black with nothing scattered in it (fx/dither.odin).
		fx.apply_dither(dither, disp.render_target)

		// After the bloom, so a lit edge's halo greys along with the edge
		// that threw it. The front is given as a fraction of the frame,
		// which is what keeps fx from needing to know the canvas is
		// 1280 wide or that a game is what filled it.
		if showing_run {
			fx.apply_corruption(
				&corruption_fx,
				disp.render_target,
				corruption.front_x / core.SCREEN_WIDTH,
			)
		}

		platform.present_display(disp)
	}
}
