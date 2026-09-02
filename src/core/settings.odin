/*
* Settings
* The player's presentation preferences, as plain data (roadmap phase 2.5).
*
* These live in core rather than platform for the same reason Input does:
* platform is what *applies* them to a real window, but ui has to render
* them and save has to persist them, and neither of those is allowed to
* depend on the platform layer. A Settings value is vocabulary, like Lane
* — it describes an intent, and knows nothing about how it is carried out.
*
* Every field is a plain value with a valid default, because it arrives
* from disk: a save that has been edited, or written by a build that
* spelled an enum differently, decodes into whatever bytes it holds. CBOR
* will happily hand back an enum value outside the declared range without
* reporting an error (verified), so validate_settings runs over anything
* that came off disk before it reaches a window call.
*/
package core

// Whether the game occupies the whole monitor or lives in a window.
//
// Fullscreen means real fullscreen — the state a compositor recognizes —
// but always at the desktop's *existing* video mode, so no resolution
// change happens and none of the usual costs of exclusive fullscreen
// apply: no mode-change flicker, no slow alt-tab, no desktop left at the
// wrong resolution if the game crashes.
//
// This started out as borderless windowed instead, and measurement is
// what changed it: on KDE a screen-sized undecorated window is still a
// normal window, so the compositor maximizes it into the work area and
// keeps the panel drawn on top of it, whatever "always on top" hints are
// set. platform/window.odin records the numbers.
DisplayMode :: enum u8 {
	Fullscreen,
	Windowed,
}

// How often frames are drawn when vsync is off. The simulation is
// unaffected either way: it always advances at TICK_RATE in fixed steps
// (core/time.odin), and this only changes how often that state is
// painted.
FpsLimit :: enum u8 {
	Fixed60,
	Monitor,
	Unlimited,
}

// A window size in pixels. Not a video mode: the game never changes the
// monitor's mode, so this is only ever how large the window is.
Resolution :: struct {
	width:  i32,
	height: i32,
}

Settings :: struct {
	display_mode:  DisplayMode,
	// Size of the window in Windowed mode. Kept while in Fullscreen too,
	// so leaving fullscreen returns to the window the player had.
	window_width:  i32,
	window_height: i32,
	vsync:         bool,
	fps_limit:     FpsLimit,
}

// Smallest window the game may be resized to. Below this the letterboxed
// canvas gets small enough that the HUD stops being readable, and there
// is nothing to gain from allowing it.
MIN_WINDOW_WIDTH :: 960
MIN_WINDOW_HEIGHT :: 540

// Fallback window size, used until the player picks one. Matches the
// canvas resolution exactly, so in a fresh window there is no scaling at
// all.
DEFAULT_WINDOW_WIDTH :: SCREEN_WIDTH
DEFAULT_WINDOW_HEIGHT :: SCREEN_HEIGHT

// The 16:9 ladder offered in the options screen, filtered at runtime to
// the entries that actually fit the current monitor (platform/window.odin).
// Ordered ascending — the options list reads as a ramp, and the filter is
// a prefix of it.
WINDOW_RESOLUTIONS :: [5]Resolution {
	{1280, 720},
	{1600, 900},
	{1920, 1080},
	{2560, 1440},
	{3840, 2160},
}

// Upper bound on how many entries the options screen can offer: every
// rung of the ladder, plus the computed "fit to monitor" one. Callers
// size their buffer with this, so a rung added above needs no change
// anywhere else.
MAX_WINDOW_RESOLUTIONS :: len(WINDOW_RESOLUTIONS) + 1

// What a first launch gets: fullscreen on the monitor the window opens
// on, with vsync on (roadmap T2.5.5). Fullscreen is the
// zero value of DisplayMode deliberately — a save that loses this field
// still starts the way a new install does.
new_settings :: proc() -> Settings {
	return Settings {
		display_mode = .Fullscreen,
		window_width = DEFAULT_WINDOW_WIDTH,
		window_height = DEFAULT_WINDOW_HEIGHT,
		vsync = true,
		fps_limit = .Monitor,
	}
}

// Forces a Settings value that came from outside the program into a state
// the window code can act on without checking anything itself.
//
// Enums are range-checked by hand: CBOR round-trips an out-of-range enum
// silently rather than rejecting it, so a hand-edited save could otherwise
// reach a switch that has no matching case.
validate_settings :: proc(settings: ^Settings) {
	if settings.display_mode != .Fullscreen && settings.display_mode != .Windowed {
		settings.display_mode = .Fullscreen
	}
	switch settings.fps_limit {
	case .Fixed60, .Monitor, .Unlimited:
	// recognized
	case:
		settings.fps_limit = .Monitor
	}

	// An upper bound as well as a lower one: the size is applied to a real
	// window, and an absurd value from a corrupted save must not become an
	// off-screen or unclosable window.
	settings.window_width = clamp(settings.window_width, MIN_WINDOW_WIDTH, 16384)
	settings.window_height = clamp(settings.window_height, MIN_WINDOW_HEIGHT, 16384)
}
