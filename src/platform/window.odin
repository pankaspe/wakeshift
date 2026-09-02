/*
* Window
* Creates the OS window, turns a core.Settings value into its actual
* state, and answers what the current monitor can offer (roadmap T2.5.2,
* T2.5.3, T2.5.8).
*
* Everything raylib is told about the window goes through here, so there
* is exactly one place that knows the difference between "the player
* chose fullscreen" and the sequence of calls that produces it — the same
* split that keeps input polling in one procedure.
*
* Fullscreen means real fullscreen — the state a compositor recognizes —
* but always at the desktop's own video mode, so no resolution change
* happens. Three measured facts got it there, all found by reading the
* live window's EWMH state under KWin 6 on Wayland (so, XWayland):
*
*   1. Borderless windowed is not fullscreen on KDE. A screen-sized
*      undecorated window is still a *normal* window: the compositor
*      maximizes it into the work area (2560x1440 monitor -> 2560x1398
*      window) and keeps the panel drawn on top, even though raylib does
*      set _NET_WM_STATE_ABOVE and _STAYS_ON_TOP. Only
*      _NET_WM_STATE_FULLSCREEN puts a window above panels.
*
*   2. raylib's ToggleFullscreen asks GLFW for a video mode the size of
*      the *current window*. Called on a 1280x720 window it does not
*      enlarge the window to the monitor — it shrinks the monitor to
*      1280x720. Everything below exists to make sure that call can only
*      ever happen when the window is already the monitor's size.
*
*   3. raylib's SetWindowState acts on FLAG_FULLSCREEN_MODE whenever the
*      requested flag set *differs* from the current one, unlike every
*      other flag it handles. Changing vsync therefore used to drop the
*      window out of fullscreen as a side effect.
*/
package platform

import "../core"
import rl "vendor:raylib/v55"

// Creates the game window in the mode the settings ask for.
//
// Created hidden and shown by show_window once it is set up: entering
// fullscreen restyles a window that already exists, and doing that in
// front of the player is the startup flash this phase exists to remove
// (roadmap T2.5.5).
//
// The size passed to raylib is the crux. For fullscreen it is 0, 0, which
// raylib reads as "the monitor's own size" and applies while creating the
// window — so the size is already right, synchronously, before anything
// toggles. Asking for a smaller window and resizing it afterwards would
// work only if the window manager acknowledged the resize in time, and
// when it does not, fact 2 above changes the player's desktop resolution.
// Measured: it did, to 1024x768.
//
// raylib's own FLAG_FULLSCREEN_MODE is deliberately not used. It was
// tried: raylib reports IsWindowFullscreen() = true, but the window that
// reaches the compositor carries no _NET_WM_STATE_FULLSCREEN and is
// maximized into the work area instead, panel still on top.
open_window :: proc(settings: core.Settings, title: cstring) {
	flags := rl.ConfigFlags{.WINDOW_RESIZABLE, .WINDOW_HIDDEN}
	if settings.vsync {
		flags += {.VSYNC_HINT}
	}
	rl.SetConfigFlags(flags)

	if settings.display_mode == .Fullscreen {
		rl.InitWindow(0, 0, title)
	} else {
		rl.InitWindow(settings.window_width, settings.window_height, title)
	}

	rl.SetWindowMinSize(core.MIN_WINDOW_WIDTH, core.MIN_WINDOW_HEIGHT)
	apply_settings(settings)
}

show_window :: proc() {
	rl.ClearWindowState({.WINDOW_HIDDEN})
}

// True while the window is in real fullscreen. Asked of raylib rather
// than tracked, because F11, the options screen and startup can all
// change it.
is_fullscreen :: proc() -> bool {
	return bool(rl.IsWindowFullscreen())
}

// How many frames after a mode change the window is worth nudging toward
// the mode it was asked for. A change takes more than one frame because
// the window manager answers a resize when it feels like it, and this is
// what lets apply_display_mode wait for that answer instead of assuming
// it. Bounded on purpose: a window manager that insists must be allowed
// to win rather than be fought once per frame forever.
WINDOW_SETTLE_FRAMES :: 30

// Moves the window one step closer to the requested mode, and does
// nothing at all once it is there. Cheap and safe to call every frame,
// which is how it is used: main calls it for WINDOW_SETTLE_FRAMES frames
// after any change.
//
// It is a step rather than a single act because both directions need the
// window manager to answer first — going in, the window must be the
// monitor's size before the toggle is allowed to happen; coming out, the
// restored window has to stop being maximized before it can be resized.
apply_display_mode :: proc(settings: core.Settings) {
	switch settings.display_mode {
	case .Fullscreen:
		if is_fullscreen() {
			return
		}

		monitor := rl.GetCurrentMonitor()
		monitor_width := rl.GetMonitorWidth(monitor)
		monitor_height := rl.GetMonitorHeight(monitor)

		// The guard that makes fact 2 harmless: the toggle is reached
		// only when the size raylib will hand GLFW is the monitor's own,
		// which is the mode already in use, which GLFW then skips. Until
		// the resize lands, ask again and come back next frame.
		if rl.GetScreenWidth() != monitor_width || rl.GetScreenHeight() != monitor_height {
			rl.SetWindowSize(monitor_width, monitor_height)
			return
		}
		rl.ToggleFullscreen()

	case .Windowed:
		if is_fullscreen() {
			rl.ToggleFullscreen()
			return
		}

		// Leaving fullscreen restores the geometry the window had on the
		// way in — the monitor's own size. KDE maximizes a window that
		// size, and a maximized window ignores a resize, so it has to be
		// un-maximized first. Measured without this: a request for a
		// 1600x900 window settled at 2560x1370, maximized.
		if rl.IsWindowMaximized() {
			rl.RestoreWindow()
			return
		}
		if rl.GetScreenWidth() != settings.window_width ||
		   rl.GetScreenHeight() != settings.window_height {
			rl.SetWindowSize(settings.window_width, settings.window_height)
			center_window()
		}
	}
}

// Centers the window on the monitor it is currently on. Monitor position
// is included because on a multi-monitor desktop the origin of a
// secondary monitor is not (0, 0).
center_window :: proc() {
	monitor := rl.GetCurrentMonitor()
	origin := rl.GetMonitorPosition(monitor)
	monitor_width := rl.GetMonitorWidth(monitor)
	monitor_height := rl.GetMonitorHeight(monitor)

	rl.SetWindowPosition(
		i32(origin.x) + (monitor_width - rl.GetScreenWidth()) / 2,
		i32(origin.y) + (monitor_height - rl.GetScreenHeight()) / 2,
	)
}

// Sets how often frames are drawn.
//
// The one trap here is stacking two limiters: with vsync on, the driver
// already blocks until the next refresh, and a target frame rate on top
// of it makes the loop wait twice and land at an uneven fraction of the
// refresh rate. So a target is only ever set when vsync is off.
//
// None of this reaches the simulation, which advances at core.TICK_RATE
// in fixed steps whatever the drawing rate turns out to be — main.odin
// already draws from a world extrapolated across the leftover fraction
// of a step, so a refresh rate that is not a multiple of 60 stays smooth.
apply_frame_pacing :: proc(settings: core.Settings) {
	// Fact 3 from the file header: SetWindowState toggles fullscreen
	// whenever the requested flag set differs from the current one.
	// Mirroring the mode the window is already in keeps that comparison
	// equal, so the call changes only what it was asked to change.
	mode_bits := rl.ConfigFlags{}
	if is_fullscreen() {
		mode_bits += {.FULLSCREEN_MODE}
	}

	if settings.vsync {
		rl.SetWindowState(mode_bits + {.VSYNC_HINT})
		rl.SetTargetFPS(0)
		return
	}

	// ClearWindowState is safe to pass a bare flag to: its fullscreen
	// branch only fires when fullscreen is in the requested set too.
	rl.ClearWindowState({.VSYNC_HINT})
	switch settings.fps_limit {
	case .Fixed60:
		rl.SetTargetFPS(core.TICK_RATE)
	case .Monitor:
		refresh_rate := rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())
		// A monitor that will not say what it refreshes at would otherwise
		// become "unlimited", which is not what the player asked for.
		rl.SetTargetFPS(refresh_rate > 0 ? refresh_rate : core.TICK_RATE)
	case .Unlimited:
		rl.SetTargetFPS(0)
	}
}

// Applies every part of a Settings value to the live window.
apply_settings :: proc(settings: core.Settings) {
	apply_display_mode(settings)
	apply_frame_pacing(settings)
}

// Size of the monitor the window is currently on.
current_monitor_size :: proc() -> core.Resolution {
	monitor := rl.GetCurrentMonitor()
	return core.Resolution {
		width = rl.GetMonitorWidth(monitor),
		height = rl.GetMonitorHeight(monitor),
	}
}

// Vertical room a window manager typically takes for a title bar and a
// panel. Only an estimate — no portable API reports the usable work area
// — but the point is to keep the offered sizes ones the player can
// actually see all of, not to be exact.
WINDOW_CHROME_ALLOWANCE :: 80

// Fills buffer with the window sizes worth offering on the current
// monitor, and returns the filled prefix.
//
// That is the fixed 16:9 ladder from core/settings.odin restricted to
// entries that fit, followed by one "fit to monitor" entry: the largest
// 16:9 window that fits the monitor once room is left for the window
// chrome. The last entry is computed rather than taken from the ladder,
// so on an ultrawide or a 16:10 panel it is a genuine best fit instead of
// the nearest rung below.
//
// Always returns at least one entry: if nothing fits — a monitor smaller
// than the minimum window — the minimum is offered anyway, because the
// options screen has to show something and the window manager will
// resolve the overflow its own way.
list_window_resolutions :: proc(buffer: []core.Resolution) -> []core.Resolution {
	monitor := current_monitor_size()
	usable_height := monitor.height - WINDOW_CHROME_ALLOWANCE

	count := 0
	for resolution in core.WINDOW_RESOLUTIONS {
		if count >= len(buffer) {
			break
		}
		if resolution.width <= monitor.width && resolution.height <= usable_height {
			buffer[count] = resolution
			count += 1
		}
	}

	if count < len(buffer) {
		fit := fit_to_monitor(monitor)
		// Only worth a row of its own if it is not one of the rungs above.
		if count == 0 || buffer[count - 1] != fit {
			buffer[count] = fit
			count += 1
		}
	}

	if count == 0 {
		buffer[0] = core.Resolution{core.MIN_WINDOW_WIDTH, core.MIN_WINDOW_HEIGHT}
		count = 1
	}
	return buffer[:count]
}

// The largest 16:9 window that fits the given monitor with room for the
// window chrome, floored at the minimum window size.
//
// The width is snapped down to a multiple of 32 so the height comes out
// whole as well — the exact fit on a 2560x1440 panel is 2417x1359, and a
// menu row reading "2400 x 1350" is worth the 17 pixels it costs.
@(private)
fit_to_monitor :: proc(monitor: core.Resolution) -> core.Resolution {
	usable_height := monitor.height - WINDOW_CHROME_ALLOWANCE

	width := min(monitor.width, usable_height * core.SCREEN_WIDTH / core.SCREEN_HEIGHT)
	width = (width / 32) * 32
	height := width * core.SCREEN_HEIGHT / core.SCREEN_WIDTH

	return core.Resolution {
		width = max(width, core.MIN_WINDOW_WIDTH),
		height = max(height, core.MIN_WINDOW_HEIGHT),
	}
}
