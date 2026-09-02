/*
* Save
* Reads and writes the player's persistent data (Design Doc, section 10).
*
* The path a save takes, and the exact reverse on load:
*
*   SaveData -> encode_save_data  (CBOR, save_data.odin)
*            -> seal_bytes        (XChaCha20-Poly1305, seal.odin)
*            -> <user data dir>/save.dat  (paths.odin)
*
* Loading never fails in a way the caller has to handle. A missing,
* unreadable, corrupted, tampered, or unrecognized save all yield
* defaults: losing a personal best is annoying, but it must never stop
* someone from playing.
*/
package platform

import "../core"
import "core:fmt"
import "core:os"

SAVE_FILE_NAME :: "save.dat"

@(private)
get_save_file_path :: proc(allocator := context.allocator) -> (path: string, ok: bool) {
	dir, dir_ok := get_save_dir(allocator)
	if !dir_ok {
		return "", false
	}
	defer delete(dir, allocator)

	joined, join_err := os.join_path({dir, SAVE_FILE_NAME}, allocator)
	if join_err != nil {
		return "", false
	}
	return joined, true
}

// Loads persistent data, always successfully: anything that goes wrong
// falls back to a fresh SaveData rather than reporting an error upward.
load_save :: proc() -> SaveData {
	path, path_ok := get_save_file_path()
	if !path_ok {
		return new_save_data()
	}
	defer delete(path)

	// No save yet: first launch.
	if !os.exists(path) {
		return new_save_data()
	}

	sealed, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		return new_save_data()
	}
	defer delete(sealed)

	plaintext, open_ok := open_bytes(sealed)
	if !open_ok {
		return new_save_data()
	}
	defer delete(plaintext)

	data, decode_ok := decode_save_data(plaintext)
	if !decode_ok {
		return new_save_data()
	}
	return data
}

// Writes data to disk, sealed. Returns false if it couldn't be written;
// callers may warn, but must carry on — a failed save is not a reason to
// interrupt a run.
store_save :: proc(data: SaveData) -> bool {
	path, path_ok := get_save_file_path()
	if !path_ok {
		return false
	}
	defer delete(path)

	encoded, encode_ok := encode_save_data(data)
	if !encode_ok {
		return false
	}
	defer delete(encoded)

	sealed, seal_ok := seal_bytes(encoded)
	if !seal_ok {
		return false
	}
	defer delete(sealed)

	return os.write_entire_file(path, sealed) == nil
}

// Reads just the personal best, for the menus that only show a number.
load_high_score :: proc() -> f32 {
	data := load_save()
	defer destroy_save_data(&data)
	return data.high_score
}

// Reads just the display settings.
//
// Deliberately usable before InitWindow: nothing on this path touches
// raylib, so the window can be created at the size and mode the player
// left it in instead of being born wrong and corrected a frame later
// (roadmap T2.5.5). Already range-checked by decode_save_data.
load_settings :: proc() -> core.Settings {
	data := load_save()
	defer destroy_save_data(&data)
	return data.settings
}

// Records the display settings, preserving whatever else the save holds.
//
// Same read-modify-write shape as save_best_run below, for the same
// reason: the save is one sealed blob, so writing one field must never
// be allowed to drop the others. Here the destroy can wait until after
// the write, because everything in `data` was allocated by the load —
// unlike save_best_run, which is handed a borrowed tick log.
save_settings :: proc(settings: core.Settings) {
	data := load_save()
	defer destroy_save_data(&data)

	data.settings = settings
	if !store_save(data) {
		fmt.println("WARNING: failed to save settings to disk")
	}
}

// Records a new personal best together with the recording of the run that
// set it (core/manifest.odin), preserving whatever else the save holds.
//
// manifest borrows its tick log from the live recorder, so it is stored
// immediately and never freed here — note the destroy below happens
// *before* it is assigned in, releasing what loading allocated rather
// than what the caller lent us.
save_best_run :: proc(value: f32, manifest: core.RunManifest) {
	data := load_save()
	destroy_save_data(&data)

	data.high_score = value
	data.best_run = manifest
	if !store_save(data) {
		fmt.println("WARNING: failed to save high score to disk")
	}
}
