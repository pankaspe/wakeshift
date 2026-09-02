/*
* Display
* Presents the game at the real resolution of whatever output it is
* running on, while every line of game code keeps drawing in the fixed
* 1280x720 coordinate space of core/screen.odin.
*
* How that works, and why it changed (roadmap T2.5.1):
*
* The canvas used to be a 1280x720 render texture blown up to fill the
* window. That is a *raster* upscale — on a 1080p monitor every drawn
* pixel becomes 1.5 pixels, on a 4K one it becomes 3 — and Wake Shift's
* whole visual identity is silhouettes and rim light, the two things a
* soft upscale ruins first. But the game draws vector primitives, not
* pixel art, so there is nothing to preserve by rasterizing at 720p.
*
* So the render target is allocated at the *output* size instead, and a
* Camera2D zoom of `scale` is pushed around all game drawing. Game code
* passes the same 1280x720 coordinates it always has; they land on
* native pixels. The target is then blitted 1:1, which is why it is sized
* to the scaled canvas rather than to the whole window: the letterbox
* bars are simply the part of the window the blit does not cover, and
* stay outside the target where a later bloom pass (roadmap phase 4)
* would otherwise have to mask them out.
*
* The one thing that does not get sharper is text drawn with raylib's
* default bitmap font, which has no resolution to gain — a real font
* arrives with the visual identity in roadmap phase 3.
*/
package platform

import "../core"
import rl "vendor:raylib/v55"

Display :: struct {
	render_target:  rl.RenderTexture2D,

	// Output size the target was last built for. update_display compares
	// against the live window every frame and rebuilds when they diverge,
	// which covers dragging the window edge, a monitor change, and the
	// fullscreen/windowed switch alike (roadmap T2.5.2) — none of them
	// announce themselves, and all three change the size.
	output_width:   i32,
	output_height:  i32,

	// Canvas pixels per game unit, and where the canvas sits inside the
	// window. Derived from the two sizes above; kept here so present_display
	// does not recompute what update_display already worked out.
	scale:          f32,
	offset_x:       f32,
	offset_y:       f32,
}

new_display :: proc() -> Display {
	display := Display{}
	rebuild_render_target(&display, output_size())
	return display
}

destroy_display :: proc(display: Display) {
	rl.UnloadRenderTexture(display.render_target)
}

// Live size of the drawable area, floored at one pixel.
//
// A minimized window reports zero on some platforms, and a zero-sized
// render texture is an invalid GL object rather than an empty one — the
// clamp keeps a minimize from destroying the target the game draws into.
@(private)
output_size :: proc() -> core.Resolution {
	return core.Resolution {
		width = max(rl.GetScreenWidth(), 1),
		height = max(rl.GetScreenHeight(), 1),
	}
}

@(private)
rebuild_render_target :: proc(display: ^Display, output: core.Resolution) {
	scale := min(
		f32(output.width) / f32(core.SCREEN_WIDTH),
		f32(output.height) / f32(core.SCREEN_HEIGHT),
	)

	// Round rather than truncate, then floor at one pixel: on a window
	// narrower than the canvas the scale is below 1, and truncation would
	// eventually reach a zero-sized target.
	target_width := max(i32(f32(core.SCREEN_WIDTH) * scale + 0.5), 1)
	target_height := max(i32(f32(core.SCREEN_HEIGHT) * scale + 0.5), 1)

	if display.render_target.id != 0 {
		rl.UnloadRenderTexture(display.render_target)
	}
	display.render_target = rl.LoadRenderTexture(target_width, target_height)

	// Bilinear only matters on the rounding remainder — the blit is 1:1
	// by construction — but it costs nothing and keeps the edge clean.
	rl.SetTextureFilter(display.render_target.texture, .BILINEAR)

	display.output_width = output.width
	display.output_height = output.height
	display.scale = scale
	display.offset_x = f32(output.width - target_width) * 0.5
	display.offset_y = f32(output.height - target_height) * 0.5
}

// Call once per frame, before begin_game_canvas: reallocates the render
// target if the output changed size since the last frame.
//
// Rebuilding costs a texture allocation, so it happens only on the frames
// where the size actually moved. That frame is a long one, but the
// simulation is protected from long frames already (core.MAX_FRAME_TIME),
// so a resize cannot push extra steps into a run.
update_display :: proc(display: ^Display) {
	output := output_size()
	if output.width != display.output_width || output.height != display.output_height {
		rebuild_render_target(display, output)
	}
}

// Call before drawing any game content this frame. Everything drawn
// between this and end_game_canvas lands on the render target, in game
// coordinates: the camera below is what turns a 1280x720 coordinate into
// a native pixel.
begin_game_canvas :: proc(display: Display) {
	rl.BeginTextureMode(display.render_target)
	rl.BeginMode2D(rl.Camera2D{zoom = display.scale})
}

end_game_canvas :: proc() {
	rl.EndMode2D()
	rl.EndTextureMode()
}

// Blits the canvas into the window, centered, and presents the frame.
// Called once per frame, after end_game_canvas.
present_display :: proc(display: Display) {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(rl.BLACK) // letterbox bar color

	texture := display.render_target.texture

	// Render textures are stored upside-down in memory (an OpenGL quirk),
	// so the source height is negative here to flip it back the right way.
	source_rect := rl.Rectangle{0, 0, f32(texture.width), -f32(texture.height)}
	dest_rect := rl.Rectangle {
		display.offset_x,
		display.offset_y,
		f32(texture.width),
		f32(texture.height),
	}

	rl.DrawTexturePro(texture, source_rect, dest_rect, rl.Vector2{0, 0}, 0, rl.WHITE)
}
