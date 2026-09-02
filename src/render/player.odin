/*
* Player Render
* Draws the player as a Hollow Knight-inspired silhouette. Real lane:
* light body, dark rim, dark eyes. Dream lane: a negative of that — dark
* body, light rim, light eyes — with eyes mirrored top-to-bottom to read
* as "upside down", since the player hangs from the ceiling there
* (Design Doc, section 12: Silhouette + Light).
*
* Also applies squash & stretch (traditional animation principle): a
* gentle stretch while mid-flip, settling into a squash bounce on
* landing that decays back to normal shape (section 15.2).
*/
package render

import "../core"
import "../game"
import "core:math"
import rl "vendor:raylib/v55"

PLAYER_REAL_BODY_COLOR :: rl.Color{240, 240, 245, 255}
PLAYER_REAL_RIM_COLOR :: rl.BLACK
PLAYER_REAL_EYE_COLOR :: rl.BLACK

PLAYER_DREAM_BODY_COLOR :: rl.BLACK
PLAYER_DREAM_RIM_COLOR :: rl.Color{240, 240, 245, 255}
PLAYER_DREAM_EYE_COLOR :: rl.Color{210, 240, 255, 255}

PLAYER_ROUNDNESS :: 0.5 // 0 = sharp rectangle, 1 = fully rounded (pill shape)

// How much the shape stretches vertically at the peak of a flip.
STRETCH_AMOUNT :: 0.16

// How long the post-landing squash bounce lasts, and how strong it starts.
SETTLE_DURATION :: 0.22
SETTLE_SQUASH_AMOUNT :: 0.28

// Which lane the shape should currently be anchored to, for scaling purposes:
// mid-flip we anchor to where we're headed, not where we came from.
get_player_anchor_lane :: proc(player: game.Player) -> core.Lane {
	if player.state == .Transitioning {
		return player.target_lane
	}
	return player.lane
}

// Returns a per-axis scale multiplier (1.0 = normal shape).
// Values > 1 on Y stretch tall/thin; values < 1 on Y squash short/wide.
// X is always adjusted opposite to Y, for a (rough) sense of volume
// preservation — a classic animation trick, not physically exact.
get_player_scale :: proc(player: game.Player) -> rl.Vector2 {
	if player.state == .Transitioning {
		// Bell curve peaking mid-flip, back to 1 at both ends.
		t := player.transition_timer / game.TRANSITION_DURATION
		stretch := STRETCH_AMOUNT * math.sin(t * math.PI)
		return rl.Vector2{1 - stretch * 0.6, 1 + stretch}
	}

	if player.settle_timer < SETTLE_DURATION {
		// Decaying oscillation: starts squashed, overshoots into a slight
		// stretch, settles back to 1 by the end of the window.
		t := player.settle_timer / SETTLE_DURATION
		decay := 1 - t
		offset := SETTLE_SQUASH_AMOUNT * decay * math.cos(t * math.PI * 2.5)
		return rl.Vector2{1 + offset * 0.6, 1 - offset}
	}

	return rl.Vector2{1, 1}
}

draw_player :: proc(player: game.Player) {
	scale := get_player_scale(player)
	scaled_size := rl.Vector2{player.size.x * scale.x, player.size.y * scale.y}

	// Keep the shape anchored to the surface it's touching (floor or
	// ceiling) while it grows/shrinks, instead of scaling from the center —
	// otherwise it would look like it's floating away from the ground.
	anchor_lane := get_player_anchor_lane(player)
	draw_x := player.position.x + (player.size.x - scaled_size.x) * 0.5
	draw_y := player.position.y
	if anchor_lane == .Real {
		draw_y = player.position.y + player.size.y - scaled_size.y
	}

	body_rect := rl.Rectangle{draw_x, draw_y, scaled_size.x, scaled_size.y}
	is_dream := player.lane == .Dream

	body_color := is_dream ? PLAYER_DREAM_BODY_COLOR : PLAYER_REAL_BODY_COLOR
	rim_color := is_dream ? PLAYER_DREAM_RIM_COLOR : PLAYER_REAL_RIM_COLOR
	eye_color := is_dream ? PLAYER_DREAM_EYE_COLOR : PLAYER_REAL_EYE_COLOR

	// Rim light: a slightly larger silhouette drawn first, behind the body,
	// so only its edges peek out — a cheap but effective "outer glow"
	// without needing a real lighting/shader pass.
	rim_rect := rl.Rectangle {
		body_rect.x - core.RIM_THICKNESS,
		body_rect.y - core.RIM_THICKNESS,
		body_rect.width + core.RIM_THICKNESS * 2,
		body_rect.height + core.RIM_THICKNESS * 2,
	}
	rl.DrawRectangleRounded(rim_rect, PLAYER_ROUNDNESS, 12, rim_color)

	// Main body, on top of the rim
	rl.DrawRectangleRounded(body_rect, PLAYER_ROUNDNESS, 12, body_color)

	draw_player_eyes(body_rect, eye_color, is_dream)
}

// Eyes shifted toward the front (direction of travel) horizontally always.
// Vertically, mirrored between Real (near-top) and Dream (near-bottom) to
// read as upside down when hanging from the ceiling.
// Takes the already-scaled body_rect, so eyes move together with the squash/stretch.
draw_player_eyes :: proc(body_rect: rl.Rectangle, eye_color: rl.Color, is_dream: bool) {
	eye_radius := body_rect.width * 0.06
	eye_y_factor: f32 = is_dream ? 0.55 : 0.45
	eye_y := body_rect.y + body_rect.height * eye_y_factor
	eye_spacing := body_rect.width * 0.16
	front_center_x := body_rect.x + body_rect.width * 0.62

	rl.DrawCircleV(rl.Vector2{front_center_x - eye_spacing * 0.5, eye_y}, eye_radius, eye_color)
	rl.DrawCircleV(rl.Vector2{front_center_x + eye_spacing * 0.5, eye_y}, eye_radius, eye_color)
}
