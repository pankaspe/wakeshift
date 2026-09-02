/*
* Display
* Manages a fixed-resolution virtual canvas (SCREEN_WIDTH x SCREEN_HEIGHT)
* that all game code draws to, independent of the real window/monitor
* size. At the end of each frame, that canvas is scaled (with letterbox
* bars if the aspect ratio doesn't match) to fill whatever window size
* or fullscreen resolution the player actually has — this is what lets
* the game go fullscreen cleanly, on any monitor, without any gameplay
* or asset code needing to know about real screen dimensions at all.
*/
package platform

import "../core"
import rl "vendor:raylib/v55"

Display :: struct {
	render_target: rl.RenderTexture2D,
}

new_display :: proc() -> Display {
	return Display{render_target = rl.LoadRenderTexture(core.SCREEN_WIDTH, core.SCREEN_HEIGHT)}
}

destroy_display :: proc(display: Display) {
	rl.UnloadRenderTexture(display.render_target)
}

// Call before drawing any game content this frame — everything drawn
// between this and end_game_canvas lands on the virtual canvas, not
// directly on the real window.
begin_game_canvas :: proc(display: Display) {
	rl.BeginTextureMode(display.render_target)
}

end_game_canvas :: proc() {
	rl.EndTextureMode()
}

// Draws the virtual canvas, scaled and centered (letterboxed) to fill
// the real window/screen, then presents the frame. Called once per
// frame, after end_game_canvas.
present_display :: proc(display: Display) {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(rl.BLACK) // letterbox bar color

	screen_width := f32(rl.GetScreenWidth())
	screen_height := f32(rl.GetScreenHeight())
	scale := min(screen_width / core.SCREEN_WIDTH, screen_height / core.SCREEN_HEIGHT)

	dest_width := core.SCREEN_WIDTH * scale
	dest_height := core.SCREEN_HEIGHT * scale
	dest_x := (screen_width - dest_width) * 0.5
	dest_y := (screen_height - dest_height) * 0.5

	// Render textures are stored upside-down in memory (an OpenGL quirk),
	// so the source height is negative here to flip it back the right way.
	source_rect := rl.Rectangle {
		0,
		0,
		f32(display.render_target.texture.width),
		-f32(display.render_target.texture.height),
	}
	dest_rect := rl.Rectangle{dest_x, dest_y, dest_width, dest_height}

	rl.DrawTexturePro(
		display.render_target.texture,
		source_rect,
		dest_rect,
		rl.Vector2{0, 0},
		0,
		rl.WHITE,
	)
}
