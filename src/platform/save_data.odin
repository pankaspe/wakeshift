/*
* Save Data
* The versioned data model persisted to disk, and its CBOR codec. Kept
* deliberately separate from *how* the bytes reach disk: sealing them
* against tampering (ChaCha20-Poly1305, roadmap T2.3) and the actual
* read/write wiring through the save directory (T2.4, see save.odin and
* paths.odin) both build on top of encode_save_data/decode_save_data
* rather than reaching into this file.
*/
package platform

import "../core"
import "core:encoding/cbor"

// Bump this whenever SaveData's shape changes. decode_save_data refuses
// to trust a payload from a version it doesn't recognize rather than
// guessing field-by-field compatibility — a save from an older or newer
// build is treated exactly like a corrupted one (Design Doc, section 10).
//
// 1: high score only
// 2: + the best run's RunManifest (roadmap T2.8)
// 3: + display settings (roadmap T2.5.4)
// 4: + the manifest's release ticks, needed to replay the Limen's holds
//    (roadmap T5.1)
// 5: - those release ticks again. The design rewrite (doc v2.0) removed
//    the third state, so there is no hold to replay and a manifest is
//    once more just the ticks the key went down on. Discards every
//    existing save, which is right for a second reason: a depth set in
//    the three-state game was set in a different game (roadmap R1.2).
SAVE_FORMAT_VERSION :: 5

SaveData :: struct {
	format_version: int,

	// Personal best "Dream Depth" (Design Doc, section 8).
	high_score:     f32,

	// Recording of the run that set that score: seed plus the ticks its
	// flips landed on (core/manifest.odin). Enough to replay it exactly,
	// which is what a ghost — or a server checking the score — needs.
	best_run:       core.RunManifest,

	// Display mode, window size, vsync and frame limit (roadmap T2.5.4).
	// Read before the window exists at startup, which is what lets the
	// window be created the right size instead of being corrected into it
	// a frame later.
	settings:       core.Settings,

	// Recent-run history lands here in roadmap T13.4, not guessed at ahead
	// of time.
}

// A freshly initialized SaveData: what a brand new install starts with,
// and what callers should fall back to whenever loading fails for any
// reason (missing file, corrupted bytes, unrecognized format_version).
new_save_data :: proc() -> SaveData {
	return SaveData{format_version = SAVE_FORMAT_VERSION, settings = core.new_settings()}
}

// Frees the heap allocations inside a SaveData.
//
// Only ever call this on a value that came back from load_save: decoding
// allocates the manifest's string and tick log, while a SaveData built in
// memory points at a static version string and a borrowed tick log, and
// freeing those would be a bug.
destroy_save_data :: proc(data: ^SaveData, allocator := context.allocator) {
	delete(data.best_run.game_version, allocator)
	delete(data.best_run.flip_ticks, allocator)
	data.best_run = core.RunManifest{}
}

// Encodes data as CBOR bytes, ready to be sealed and written to disk by
// the caller. ENCODE_SMALL keeps the payload compact without paying for
// deterministic map-key sorting, which a single flat struct has no use
// for (there are no maps in it).
//
// The returned bytes are heap-allocated with the given allocator: the
// caller owns them and must delete() them once done.
encode_save_data :: proc(data: SaveData, allocator := context.allocator) -> (bytes: []byte, ok: bool) {
	encoded, err := cbor.marshal(data, cbor.ENCODE_SMALL, allocator)
	if err != nil {
		return nil, false
	}
	return encoded, true
}

// Decodes CBOR bytes back into SaveData. Returns ok = false — never a
// partially-filled or best-guess result — if the bytes don't decode at
// all, or decode into a format_version this build doesn't recognize.
decode_save_data :: proc(bytes: []byte, allocator := context.allocator) -> (data: SaveData, ok: bool) {
	err := cbor.unmarshal(bytes, &data, allocator = allocator)
	if err != nil || data.format_version != SAVE_FORMAT_VERSION {
		return SaveData{}, false
	}

	// Settings are the one part of a save handed straight to OS calls, and
	// CBOR reports no error for an enum value outside the declared range
	// (verified) — so a payload that decoded cleanly still has to be forced
	// into a state the window code can act on.
	core.validate_settings(&data.settings)
	return data, true
}
