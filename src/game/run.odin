/*
* Run
* Application screen state, plus the single place that defines what a fresh
* run looks like. Everything per-run is rebuilt in reset_run; everything
* meant to survive across runs (the personal best) deliberately is not
* touched here (Design Doc, section 9-10).
*/
package game

// Application-level screen state — separate from the player's own state
// machine (Section 3). This one governs which screen is shown and which
// input is being listened for (Design Doc, section 9).
GameState :: enum {
	MainMenu,
	Playing,
	Paused,
	GameOver,

	// Presentation settings (roadmap T2.5.7). Reachable from both the main
	// menu and the pause menu, so the state it returns to is remembered by
	// the caller rather than fixed here.
	Options,
}

// Starts a fresh run. The seed arrives from the caller rather than being
// drawn in here: it is an *input* to the run, the thing that decides which
// level the player gets, and it has to be recorded alongside the input log
// for the run to be reproducible later (Design Doc, section 10). A replay
// passes the recorded seed; a live run passes a fresh one.
reset_run :: proc(
	player: ^Player,
	world: ^World,
	score: ^Score,
	obstacles: ^[dynamic]Obstacle,
	generator: ^PatternGenerator,
	lucidity: ^Lucidity,
	seed: u64,
) {
	player^ = new_player()
	world^ = new_world()
	score^ = new_score()
	lucidity^ = new_lucidity()

	delete(obstacles^)
	obstacles^ = nil
	// {.Real} because that is where new_player actually puts the player.
	// It used to say .Dream, which meant the very first pattern of every
	// run demanded a lane the player was not in — survivable only because
	// of the two-second lead-in, and a contract violation at the one seam
	// nobody thinks to check.
	generator^ = new_pattern_generator(all_patterns, 2.0, {.Real}, seed)
}
