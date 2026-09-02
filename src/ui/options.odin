/*
* Options
* The settings screen: display mode, window size, vsync and frame limit
* (roadmap T2.5.7). Reachable from the main menu and from the pause menu,
* left with ESC or the Back row.
*
* This file owns the translation in both directions — a core.Settings
* value into rows of text, and the row the player is on back into a
* setting — and nothing else. Applying a setting to a real window belongs
* to platform/window.odin, which this package is not allowed to reach and
* has no reason to: the caller takes the changed Settings and hands it
* over.
*
* Value text is formatted into fixed buffers held by the screen rather
* than allocated per frame. A settings screen is redrawn every frame it
* is open, so anything allocated to draw it is allocated every frame, and
* the rows are short enough that a buffer settles the question.
*/
package ui

import "../core"
import "core:fmt"
import rl "vendor:raylib/v55"

// Row order, also the order they are drawn in.
OPTION_DISPLAY_MODE :: 0
OPTION_WINDOW_SIZE :: 1
OPTION_VSYNC :: 2
OPTION_FRAME_LIMIT :: 3
OPTION_BACK :: 4
OPTION_ROW_COUNT :: 5

// Longest value string is a window size ("3840 x 2160"), comfortably
// inside this.
@(private)
VALUE_BUFFER_SIZE :: 32

OptionsScreen :: struct {
	items:         [OPTION_ROW_COUNT]MenuItem,
	value_storage: [OPTION_ROW_COUNT][VALUE_BUFFER_SIZE]u8,
	menu:          Menu,
}

// The menu borrows the item array, so the screen must be built in place
// through a pointer: a copy would leave the menu pointing at the
// original's rows.
init_options_screen :: proc(screen: ^OptionsScreen) {
	screen.items = [OPTION_ROW_COUNT]MenuItem {
		{label = "Display", value_count = 2},
		{label = "Window Size", value_count = 1},
		{label = "V-Sync", value_count = 2},
		{label = "Frame Limit", value_count = 3},
		{label = "Back"},
	}
	screen.menu = Menu {
		items    = screen.items[:],
		selected = 0,
	}
}

@(private)
set_value :: proc(screen: ^OptionsScreen, row: int, text: string) {
	screen.items[row].value = fmt.bprintf(screen.value_storage[row][:], "%s", text)
}

// Index of the entry in resolutions closest to the current window size.
//
// "Closest" rather than "equal" because the window is also resizable by
// dragging, and the monitor decides which entries exist at all: a size
// the player set on another monitor, or by hand, still has to land the
// cursor somewhere sensible instead of silently on the first row.
@(private)
nearest_resolution :: proc(resolutions: []core.Resolution, width, height: i32) -> int {
	best_index := 0
	best_distance := max(int)

	for resolution, index in resolutions {
		distance := abs(int(resolution.width - width)) + abs(int(resolution.height - height))
		if distance < best_distance {
			best_distance = distance
			best_index = index
		}
	}
	return best_index
}

// Rewrites every row from the current settings. Called once per frame
// before update, so the screen always shows what is actually in effect —
// including a value that changed from outside it, like F11 or a window
// dragged to a new size.
sync_options_screen :: proc(
	screen: ^OptionsScreen,
	settings: core.Settings,
	resolutions: []core.Resolution,
) {
	windowed := settings.display_mode == .Windowed

	screen.items[OPTION_DISPLAY_MODE].value_index = settings.display_mode == .Fullscreen ? 0 : 1
	set_value(screen, OPTION_DISPLAY_MODE, windowed ? "Windowed" : "Fullscreen")

	// Window size is a window size, not a video mode: in fullscreen the
	// size is the monitor's and there is nothing to choose, so the row is
	// shown dimmed rather than hidden.
	screen.items[OPTION_WINDOW_SIZE].value_count = max(len(resolutions), 1)
	screen.items[OPTION_WINDOW_SIZE].disabled = !windowed
	resolution_index := nearest_resolution(
		resolutions,
		settings.window_width,
		settings.window_height,
	)
	screen.items[OPTION_WINDOW_SIZE].value_index = resolution_index
	if windowed && len(resolutions) > 0 {
		resolution := resolutions[resolution_index]
		screen.items[OPTION_WINDOW_SIZE].value = fmt.bprintf(
			screen.value_storage[OPTION_WINDOW_SIZE][:],
			"%d x %d",
			resolution.width,
			resolution.height,
		)
	} else {
		set_value(screen, OPTION_WINDOW_SIZE, "Monitor")
	}

	screen.items[OPTION_VSYNC].value_index = settings.vsync ? 0 : 1
	set_value(screen, OPTION_VSYNC, settings.vsync ? "On" : "Off")

	// With vsync on the driver already paces the loop; a second limiter on
	// top of it makes the two fight (platform/window.odin), so the row has
	// no meaning until vsync is off.
	screen.items[OPTION_FRAME_LIMIT].disabled = settings.vsync
	switch settings.fps_limit {
	case .Fixed60:
		screen.items[OPTION_FRAME_LIMIT].value_index = 0
		set_value(screen, OPTION_FRAME_LIMIT, "60 FPS")
	case .Monitor:
		screen.items[OPTION_FRAME_LIMIT].value_index = 1
		set_value(screen, OPTION_FRAME_LIMIT, "Monitor")
	case .Unlimited:
		screen.items[OPTION_FRAME_LIMIT].value_index = 2
		set_value(screen, OPTION_FRAME_LIMIT, "Unlimited")
	}

	// Navigation skips disabled rows, but a row can become disabled while
	// the cursor is already on it — switching to fullscreen from the row
	// above the window size, for instance.
	if screen.menu.items[screen.menu.selected].disabled {
		move_selection(&screen.menu, 1)
	}
}

// Runs one frame of the options screen. Returns leave = true when the
// player is done with it, and changed = true on the frame a setting
// actually moved — the caller applies it to the window on that edge and
// persists it when leaving.
//
// settings is written in place rather than returned, so a caller holding
// the game's one Settings value never has to remember to assign the
// result back.
update_options_screen :: proc(
	screen: ^OptionsScreen,
	settings: ^core.Settings,
	resolutions: []core.Resolution,
	input: core.Input,
) -> (
	leave: bool,
	changed: bool,
) {
	sync_options_screen(screen, settings^, resolutions)

	confirmed, value_changed := update_menu(&screen.menu, input)

	// ESC is the same "go back" as the Back row, so the screen behaves
	// like the pause menu it can be opened from.
	if input.pause {
		return true, false
	}
	if confirmed && screen.menu.selected == OPTION_BACK {
		return true, false
	}
	if !value_changed {
		return false, false
	}

	switch screen.menu.selected {
	case OPTION_DISPLAY_MODE:
		settings.display_mode =
			screen.items[OPTION_DISPLAY_MODE].value_index == 0 ? .Fullscreen : .Windowed

	case OPTION_WINDOW_SIZE:
		if len(resolutions) > 0 {
			resolution := resolutions[screen.items[OPTION_WINDOW_SIZE].value_index]
			settings.window_width = resolution.width
			settings.window_height = resolution.height
		}

	case OPTION_VSYNC:
		settings.vsync = screen.items[OPTION_VSYNC].value_index == 0

	case OPTION_FRAME_LIMIT:
		switch screen.items[OPTION_FRAME_LIMIT].value_index {
		case 0:
			settings.fps_limit = .Fixed60
		case 1:
			settings.fps_limit = .Monitor
		case:
			settings.fps_limit = .Unlimited
		}
	}

	return false, true
}

draw_options_screen :: proc(screen: OptionsScreen) {
	draw_centered_text("OPTIONS", 180, 40, rl.BLACK)
	draw_menu(screen.menu, 280, 46, 24)
	draw_centered_text("LEFT / RIGHT to change  -  ESC to go back", 540, 18, rl.DARKGRAY)
}
