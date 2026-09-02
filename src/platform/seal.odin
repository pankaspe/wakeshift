/*
* Seal
* Wraps a plaintext payload in an authenticated, encrypted container
* (XChaCha20-Poly1305) and unwraps it again, rejecting anything that has
* been altered (Design Doc, section 10).
*
* What this actually buys, stated plainly: the key below is compiled into
* the binary, so anyone willing to open the executable can extract it.
* This stops a save file being edited in a text editor. It is NOT
* protection for an online leaderboard and must never be presented as
* such — that requires the server replaying a run from its seed and input
* log and computing the score itself (Design Doc, section 10).
*
* Container layout, all offsets fixed:
*
*   0   4   magic "WSSV"
*   4   1   container version
*   5   24  nonce (XChaCha20 extended IV, fresh random bytes per save)
*   29  16  Poly1305 authentication tag
*   45  N   ciphertext
*
* The 5-byte header is passed as additional authenticated data, so magic
* and version are covered by the tag too: a valid header cannot be spliced
* onto a ciphertext from a different save.
*/
package platform

import "core:crypto"
import "core:crypto/chacha20poly1305"

// Sealing a save needs fresh entropy per write. Every desktop target we
// build for provides it; fail at compile time rather than at the first
// attempted save if that ever stops being true.
#assert(crypto.HAS_RAND_BYTES)

SAVE_MAGIC :: "WSSV"

// Version of the *container*, distinct from SaveData.format_version
// (save_data.odin), which versions the payload shape inside it. Changing
// the sealing scheme — nonce size, cipher, field order — bumps this one;
// changing what SaveData holds bumps the other.
SEAL_CONTAINER_VERSION :: 1

@(private)
SEAL_MAGIC_SIZE :: len(SAVE_MAGIC)
@(private)
SEAL_VERSION_OFFSET :: SEAL_MAGIC_SIZE
@(private)
SEAL_HEADER_SIZE :: SEAL_VERSION_OFFSET + 1
@(private)
SEAL_NONCE_OFFSET :: SEAL_HEADER_SIZE
@(private)
SEAL_TAG_OFFSET :: SEAL_NONCE_OFFSET + chacha20poly1305.XIV_SIZE
@(private)
SEAL_CIPHERTEXT_OFFSET :: SEAL_TAG_OFFSET + chacha20poly1305.TAG_SIZE

// Embedded key. See the honest note at the top of this file: this is a
// deterrent against casual editing, not a secret that can be kept.
@(private, rodata)
SEAL_KEY := [chacha20poly1305.KEY_SIZE]byte {
	0xdd, 0xc0, 0x8f, 0x2e, 0x76, 0xaf, 0xa0, 0x62,
	0x63, 0x06, 0x75, 0x93, 0x78, 0x9f, 0xfc, 0xdf,
	0x10, 0x27, 0xa1, 0xaa, 0xee, 0xe4, 0xf9, 0x44,
	0x7a, 0x85, 0x3c, 0xdc, 0x46, 0x5f, 0xd0, 0x1e,
}

// Wraps plaintext into a sealed container ready to be written to disk.
// A fresh random nonce is drawn for every call, so sealing identical
// data twice produces different bytes — expected, not a bug.
//
// The returned bytes are heap-allocated with the given allocator: the
// caller owns them and must delete() them once done.
seal_bytes :: proc(plaintext: []byte, allocator := context.allocator) -> (sealed: []byte, ok: bool) {
	buffer, alloc_err := make([]byte, SEAL_CIPHERTEXT_OFFSET + len(plaintext), allocator)
	if alloc_err != nil {
		return nil, false
	}

	copy(buffer[:SEAL_MAGIC_SIZE], SAVE_MAGIC)
	buffer[SEAL_VERSION_OFFSET] = SEAL_CONTAINER_VERSION

	aad := buffer[:SEAL_HEADER_SIZE]
	nonce := buffer[SEAL_NONCE_OFFSET:SEAL_TAG_OFFSET]
	tag := buffer[SEAL_TAG_OFFSET:SEAL_CIPHERTEXT_OFFSET]
	ciphertext := buffer[SEAL_CIPHERTEXT_OFFSET:]

	crypto.rand_bytes(nonce)

	ctx: chacha20poly1305.Context = ---
	chacha20poly1305.init_xchacha(&ctx, SEAL_KEY[:])
	defer chacha20poly1305.reset(&ctx)

	chacha20poly1305.seal(&ctx, ciphertext, tag, nonce, aad, plaintext)

	return buffer, true
}

// Unwraps a sealed container, returning ok = false for anything that
// isn't intact and authentic: wrong magic, unknown container version,
// truncated bytes, or a payload altered by so much as a single bit.
//
// Every length check happens *before* any crypto call on purpose. The
// AEAD routines validate their slice sizes with ensure(), which aborts
// the process — so handing them a truncated file directly would crash
// the game instead of rejecting the save.
//
// The returned bytes are heap-allocated with the given allocator: the
// caller owns them and must delete() them once done.
open_bytes :: proc(sealed: []byte, allocator := context.allocator) -> (plaintext: []byte, ok: bool) {
	if len(sealed) < SEAL_CIPHERTEXT_OFFSET {
		return nil, false
	}
	if string(sealed[:SEAL_MAGIC_SIZE]) != SAVE_MAGIC {
		return nil, false
	}
	if sealed[SEAL_VERSION_OFFSET] != SEAL_CONTAINER_VERSION {
		return nil, false
	}

	aad := sealed[:SEAL_HEADER_SIZE]
	nonce := sealed[SEAL_NONCE_OFFSET:SEAL_TAG_OFFSET]
	tag := sealed[SEAL_TAG_OFFSET:SEAL_CIPHERTEXT_OFFSET]
	ciphertext := sealed[SEAL_CIPHERTEXT_OFFSET:]

	buffer, alloc_err := make([]byte, len(ciphertext), allocator)
	if alloc_err != nil {
		return nil, false
	}

	ctx: chacha20poly1305.Context = ---
	chacha20poly1305.init_xchacha(&ctx, SEAL_KEY[:])
	defer chacha20poly1305.reset(&ctx)

	if !chacha20poly1305.open(&ctx, buffer, nonce, aad, ciphertext, tag) {
		delete(buffer, allocator)
		return nil, false
	}

	return buffer, true
}
