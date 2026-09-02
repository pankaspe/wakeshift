/*
* Save
* Saves and loads the player's personal best "Dream Depth" so it survives
* closing and reopening the game (Design Doc, section 10).
*
* Deliberately still the original plain-text, working-directory-relative
* implementation: roadmap phase 2 replaces it wholesale with a CBOR payload
* sealed with ChaCha20-Poly1305, living in the OS user data directory.
* Moving it here first keeps that replacement a single-package change.
*/
package platform

import "core:fmt"
import "core:os"
import "core:strconv"

HIGH_SCORE_FILE :: "highscore.txt"

// Reads the saved high score from disk. Returns 0 if the file doesn't
// exist yet (first run ever) or its contents can't be parsed.
load_high_score :: proc() -> f32 {
	data, err := os.read_entire_file(HIGH_SCORE_FILE, context.allocator)
	if err != nil {
		return 0
	}
	defer delete(data)

	value, parse_ok := strconv.parse_f32(string(data))
	if !parse_ok {
		return 0
	}
	return value
}

// Writes the given value to disk, overwriting whatever was there before.
save_high_score :: proc(value: f32) {
	text := fmt.tprintf("%.0f", value)
	err := os.write_entire_file(HIGH_SCORE_FILE, transmute([]byte)text)
	if err != nil {
		fmt.println("WARNING: failed to save high score to disk:", err)
	}
}
