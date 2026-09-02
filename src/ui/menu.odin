/*
* Menu
* A small reusable navigable menu widget: a list of rows, navigated with
* UP/DOWN, confirmed with ENTER (Design Doc, section 9).
*
* A row is either an *action* — "Start Run", "Quit" — or a *setting*: a
* label with a value cycled in place with LEFT/RIGHT, never confirmed
* (roadmap T2.5.6). One widget covers both because they are the same list
* to navigate, and the options screen would otherwise duplicate every
* piece of it.
*
* The value text is a plain string the owner writes into the row rather
* than a list the widget holds. That keeps the widget ignorant of what is
* being configured: the options screen knows that index 2 of the
* resolution list means 1920x1080, and the menu only knows there are N of
* something and the player is on the third.
*/
package ui

import "../core"
import "core:fmt"
import rl "vendor:raylib/v55"

MenuItem :: struct {
	label:       string,

	// A setting row: `value_count` choices, currently showing `value`
	// (which the owner refreshes from `value_index`). value_count == 0
	// marks a plain action row, where LEFT/RIGHT do nothing.
	value:       string,
	value_index: int,
	value_count: int,

	// Shown dimmed, skipped by navigation, and immune to LEFT/RIGHT and
	// ENTER — for a row that exists but does not apply right now, like
	// window size while the game is fullscreen. Greying it out says more
	// than hiding it would: the row is still there, it just has no effect
	// in the current mode.
	disabled:    bool,
}

Menu :: struct {
	items:    []MenuItem,
	selected: int,
}

// The items slice is borrowed, not copied: the caller owns the storage
// and stays free to rewrite labels and values in it between frames, which
// is how a settings row's displayed value keeps up with the setting.
new_menu :: proc(items: []MenuItem) -> Menu {
	menu := Menu {
		items    = items,
		selected = 0,
	}
	// A menu whose first row is disabled must not open with the cursor
	// parked on it.
	if len(items) > 0 && items[0].disabled {
		move_selection(&menu, 1)
	}
	return menu
}

// Moves the selection by step rows, wrapping, skipping disabled rows.
//
// Bounded by the row count so a menu with nothing selectable in it stops
// instead of spinning forever.
@(private)
move_selection :: proc(menu: ^Menu, step: int) {
	count := len(menu.items)
	if count == 0 {
		return
	}

	index := menu.selected
	for _ in 0 ..< count {
		index = (index + step + count) % count
		if !menu.items[index].disabled {
			menu.selected = index
			return
		}
	}
}

// Handles UP/DOWN navigation and LEFT/RIGHT value cycling.
//
// Returns confirmed = true on the frame ENTER is pressed on an action
// row, and value_changed = true on the frame a setting row's value moved
// — the caller applies the new setting on that edge rather than diffing
// state every frame.
//
// Takes input as an argument for the same reason gameplay does (see
// core/input.odin): exactly one place in the project reads the keyboard.
update_menu :: proc(menu: ^Menu, input: core.Input) -> (confirmed: bool, value_changed: bool) {
	if len(menu.items) == 0 {
		return false, false
	}

	if input.menu_down {
		move_selection(menu, 1)
	}
	if input.menu_up {
		move_selection(menu, -1)
	}

	item := &menu.items[menu.selected]
	if item.disabled {
		return false, false
	}

	if item.value_count > 0 {
		step := 0
		if input.menu_right {
			step = 1
		}
		if input.menu_left {
			step = -1
		}
		if step != 0 {
			item.value_index = (item.value_index + step + item.value_count) % item.value_count
			value_changed = true
		}
		// A setting row has nothing to confirm — ENTER on it would
		// otherwise fall through to whatever the caller does on confirm.
		return false, value_changed
	}

	return input.confirm, false
}

// Draws text horizontally centered on screen at the given y.
draw_centered_text :: proc(text: cstring, y: i32, font_size: i32, color: rl.Color) {
	width := rl.MeasureText(text, font_size)
	x := (core.SCREEN_WIDTH - width) / 2
	rl.DrawText(text, x, y, font_size, color)
}

// Horizontal gap either side of the screen centre for a setting row:
// the label ends before it, the value starts after it. A two-column
// layout rather than one centered string, so a row does not shift
// sideways every time its value changes length.
@(private)
SETTING_COLUMN_GAP :: 30

// Draws every row, marking the selected one — "> label <" for an action,
// "< value >" for a setting.
draw_menu :: proc(menu: Menu, start_y: i32, spacing: i32, font_size: i32) {
	for item, index in menu.items {
		selected := index == menu.selected
		y := start_y + i32(index) * spacing

		color := rl.DARKGRAY
		if item.disabled {
			color = rl.GRAY
		} else if selected {
			color = rl.BLACK
		}

		if item.value_count == 0 {
			prefix := selected ? "> " : "  "
			suffix := selected ? " <" : "  "
			draw_centered_text(
				fmt.ctprintf("%s%s%s", prefix, item.label, suffix),
				y,
				font_size,
				color,
			)
			continue
		}

		label := fmt.ctprintf("%s", item.label)
		value := fmt.ctprintf("%s", item.value)

		center := i32(core.SCREEN_WIDTH) / 2
		label_x := center - SETTING_COLUMN_GAP - rl.MeasureText(label, font_size)
		value_x := center + SETTING_COLUMN_GAP

		rl.DrawText(label, label_x, y, font_size, color)
		rl.DrawText(value, value_x, y, font_size, color)

		// Arrows only on the selected row: they are the affordance saying
		// this row is cycled rather than confirmed, and drawing them on
		// every row would bury that.
		if selected && !item.disabled {
			arrow_gap := font_size / 2
			rl.DrawText("<", value_x - arrow_gap - rl.MeasureText("<", font_size), y, font_size, color)
			rl.DrawText(">", value_x + rl.MeasureText(value, font_size) + arrow_gap, y, font_size, color)
		}
	}
}
