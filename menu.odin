/*
* Menu
* A small reusable navigable menu widget: a list of string options,
* navigated with UP/DOWN, confirmed with ENTER. Used for both the main
* menu and the pause overlay (Design Doc, section 9).
*/
package main

import "core:fmt"
import rl "vendor:raylib/v55"

Menu :: struct {
	options:  []string,
	selected: int,
}

new_menu :: proc(options: []string) -> Menu {
	return Menu{options = options, selected = 0}
}

// Handles UP/DOWN navigation, wrapping around at the ends.
// Returns true on the frame ENTER is pressed to confirm the current selection.
update_menu :: proc(menu: ^Menu) -> bool {
	if rl.IsKeyPressed(.DOWN) {
		menu.selected = (menu.selected + 1) % len(menu.options)
	}
	if rl.IsKeyPressed(.UP) {
		menu.selected = (menu.selected - 1 + len(menu.options)) % len(menu.options)
	}
	return rl.IsKeyPressed(.ENTER)
}

// Draws text horizontally centered on screen at the given y.
draw_centered_text :: proc(text: cstring, y: i32, font_size: i32, color: rl.Color) {
	width := rl.MeasureText(text, font_size)
	x := (SCREEN_WIDTH - width) / 2
	rl.DrawText(text, x, y, font_size, color)
}

// Draws every option, centered, marking the currently selected one with
// "> label <" and a darker color.
draw_menu :: proc(menu: Menu, start_y: i32, spacing: i32, font_size: i32) {
	for option, index in menu.options {
		prefix := index == menu.selected ? "> " : "  "
		suffix := index == menu.selected ? " <" : "  "
		color := index == menu.selected ? rl.BLACK : rl.DARKGRAY

		text := fmt.ctprintf("%s%s%s", prefix, option, suffix)
		draw_centered_text(text, start_y + i32(index) * spacing, font_size, color)
	}
}
