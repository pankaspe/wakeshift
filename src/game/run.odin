/*
* Run
* Application screen state, plus the single place that defines what a
* fresh run looks like. Everything per-run is rebuilt in reset_run;
* everything meant to survive across runs (the personal best) deliberately
* is not touched here.
*/
package game

GameState :: enum {
	MainMenu,
	Playing,
	Paused,
	GameOver,
	Options,
}

// Starts a fresh run. The seed arrives from the caller rather than being
// drawn here: it is an *input* to the run, the thing that decides which
// maze the player gets, and it has to be recorded alongside the input log
// for the run to be reproducible later. A replay passes the recorded seed;
// a live run passes a fresh one.
reset_run :: proc(player: ^Player, world: ^World, maze: ^Maze, score: ^Score, corruption: ^Corruption, seed: u64) {
	player^ = new_player()
	world^ = new_world()
	maze^ = new_maze(seed)
	score^ = new_score()
	corruption^ = new_corruption()
}
