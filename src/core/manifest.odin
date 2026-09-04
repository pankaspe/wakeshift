/*
* Manifest
* Everything needed to reproduce a run, as plain data.
*
* This is the payload a leaderboard submission will eventually carry
* (Design Doc, section 10). The client does not get to be believed about
* its score: it sends the seed it was given and the exact ticks it pressed
* the key on, the server replays those against the same deterministic
* simulation, and computes the score itself. claimed_depth is recorded
* only so the two can be compared — it is a claim, never evidence.
*
* Three properties make that replay possible, and all three are already
* in place: generation seeded explicitly (game/pattern.odin), input as
* recorded data rather than live polling (core/input.odin), and a fixed
* timestep so a tick means the same thing everywhere (core/time.odin).
*
* Since 1.0.0 a run's whole input is a list of ticks the key went down on.
* There is nothing else to record because there is nothing else to press:
* one key, one gesture, and no state that depends on how long it was held.
*
* Locally the same manifest is worth keeping for its own sake: it is a
* recording of the best run, which is all a ghost or a replay needs.
*/
package core

// Identifies the build a run was played on. A manifest is only
// reproducible against the simulation it was recorded from, so a replay
// or a server check has to know which one that was.
// 0.1.0: two lanes, tap-only flip
// 0.2.0: the Limen — a flip is a longer journey and holding stops it
//        halfway, so the same input log played against 0.1.0 produces a
//        different run
// 0.3.0: patterns chain on sets of bands rather than single lanes
// 0.4.0: the ground became geometry — lanes sampled off the terrain
//        profile instead of pinned to the screen edges
// 0.5.0: the Step, the ground itself lifting into a wall
// 0.6.0: the Corruption as a passive drain on Lucidity
// 1.0.0: the design rewrite (doc v2.0). Two states instead of three, no
//        Lucidity, a shorter flip, and four obstacle types gone. Nothing
//        recorded before this replays into anything meaningful, which is
//        why the numbering leaves 0.x behind rather than continuing it.
GAME_VERSION :: "1.0.0-alpha"

RunManifest :: struct {
	game_version:  string,
	seed:          u64, // decides every random choice the level generator makes
	tick_rate:     u32, // simulation steps per second this run was played at
	tick_count:    u64, // how many steps the run lasted
	flip_ticks:    []u64, // every tick the player pressed flip on, in order
	claimed_depth: f32, // what the client says it scored — to be verified, not trusted
}

// Collects flip presses as a run happens. Kept separate from RunManifest
// because a manifest is a finished, immutable record while this grows.
RunRecorder :: struct {
	seed:       u64,
	flip_ticks: [dynamic]u64,
}

new_run_recorder :: proc(seed: u64) -> RunRecorder {
	return RunRecorder{seed = seed}
}

// Frees a recorder's storage. Call before overwriting one for a new run.
destroy_run_recorder :: proc(recorder: ^RunRecorder) {
	delete(recorder.flip_ticks)
	recorder.flip_ticks = nil
}

// Notes that flip was pressed on the given tick. Called once per
// simulation step that consumed a press, so the log lines up exactly with
// the steps a replay would run.
record_flip :: proc(recorder: ^RunRecorder, tick: u64) {
	append(&recorder.flip_ticks, tick)
}

// Freezes the recording into a manifest describing the finished run.
//
// The returned manifest *borrows* the recorder's tick log rather than
// copying it: it stays valid only while the recorder does, which is
// enough for the one thing this is for — handing it straight to a save.
build_manifest :: proc(recorder: RunRecorder, tick_count: u64, claimed_depth: f32) -> RunManifest {
	return RunManifest {
		game_version = GAME_VERSION,
		seed = recorder.seed,
		tick_rate = u32(TICK_RATE),
		tick_count = tick_count,
		flip_ticks = recorder.flip_ticks[:],
		claimed_depth = claimed_depth,
	}
}
