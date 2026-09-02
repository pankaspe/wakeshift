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
SAVE_FORMAT_VERSION :: 2

SaveData :: struct {
	format_version: int,

	// Personal best "Dream Depth" (Design Doc, section 8).
	high_score:     f32,

	// Recording of the run that set that score: seed plus the ticks its
	// flips landed on (core/manifest.odin). Enough to replay it exactly,
	// which is what a ghost — or a server checking the score — needs.
	best_run:       core.RunManifest,

	// Options and recent-run history land here in roadmap T12.4, not
	// guessed at ahead of time.
}

// A freshly initialized SaveData: what a brand new install starts with,
// and what callers should fall back to whenever loading fails for any
// reason (missing file, corrupted bytes, unrecognized format_version).
new_save_data :: proc() -> SaveData {
	return SaveData{format_version = SAVE_FORMAT_VERSION}
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
	return data, true
}
