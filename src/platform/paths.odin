/*
* Paths
* Locates (and creates, if missing) the OS-specific directory Wake Shift
* stores its persistent data in — never the process's working directory,
* which changes depending on where the game happens to be launched from
* (Design Doc, section 10).
*
*   Linux:   $XDG_DATA_HOME/wake-shift/   (usually ~/.local/share/wake-shift/)
*   macOS:   ~/Library/Application Support/wake-shift/
*   Windows: %LOCALAPPDATA%\wake-shift\
*
* core:os already resolves the right per-platform base directory
* (os.user_data_dir); this file only appends the app name and makes sure
* the resulting directory exists before anything tries to read or write
* inside it, so callers never have to check for that themselves.
*/
package platform

import "core:os"

APP_DIR_NAME :: "wake-shift"

// Resolves Wake Shift's save directory and creates it (and any missing
// parent directories) if it doesn't exist yet. Returns ok = false if the
// OS couldn't tell us where user data belongs, or the directory couldn't
// be created — callers should fall back to defaults rather than crash,
// same as a corrupted save file (see save.odin).
//
// The returned string is heap-allocated with the given allocator: the
// caller owns it and must delete() it once done, same as any other
// core:os path-returning call.
get_save_dir :: proc(allocator := context.allocator) -> (dir: string, ok: bool) {
	base, base_err := os.user_data_dir(allocator)
	if base_err != nil {
		return "", false
	}
	defer delete(base, allocator)

	joined, join_err := os.join_path({base, APP_DIR_NAME}, allocator)
	if join_err != nil {
		return "", false
	}

	// make_directory_all is *not* idempotent the way its name suggests:
	// on every backend it returns .Exist rather than nil when the
	// directory was already there (verified against both the Linux and
	// POSIX-generic implementations) — that's the expected case on every
	// launch after the first, not a failure.
	if mkdir_err := os.make_directory_all(joined); mkdir_err != nil && mkdir_err != .Exist {
		delete(joined, allocator)
		return "", false
	}

	return joined, true
}
