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
}

reset_run :: proc(
	player: ^Player,
	world: ^World,
	score: ^Score,
	obstacles: ^[dynamic]Obstacle,
	generator: ^PatternGenerator,
	lucidity: ^Lucidity,
) {
	player^ = new_player()
	world^ = new_world()
	score^ = new_score()
	lucidity^ = new_lucidity()

	delete(obstacles^)
	obstacles^ = nil
	generator^ = new_pattern_generator(all_patterns, 2.0, .Dream)
}
