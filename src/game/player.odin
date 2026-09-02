/*
* Player
* Holds the player character state and drives the flip state machine
* (Design Doc, section 4). Drawing lives separately in the render package:
* nothing under game/ ever draws.
*/
package game

import "../core"
import rl "vendor:raylib/v55"

// Player reference size in pixels (Design Doc, section 6: ~40-50px)
PLAYER_SIZE :: 45

// Player state machine (Design Doc, section 4).
// Transitioning is a short in-between state while flipping lanes.
PlayerState :: enum {
	Real,
	Dream,
	Transitioning,
}

// Duration of the flip transition, in seconds (Design Doc, section 4: ~0.1-0.15s)
TRANSITION_DURATION :: 0.12

// Duration of the invulnerability grace period, in seconds.
// Kept as a separate constant from TRANSITION_DURATION: the design doc notes
// these may need to differ once we playtest against real obstacles (Roadmap, section 19).
INVULNERABILITY_DURATION :: 0.15

Player :: struct {
	position:              rl.Vector2,
	size:                  rl.Vector2,
	lane:                  core.Lane, // current lane (used once not transitioning)
	state:                 PlayerState,
	target_lane:           core.Lane, // lane we're flipping into, while transitioning
	transition_timer:      f32, // seconds elapsed since transition started
	transition_start_y:    f32, // y position when the transition began
	is_invulnerable:       bool,
	invulnerability_timer: f32, // seconds elapsed since invulnerability started
	settle_timer:          f32, // seconds since landing, drivers the post flip squash bounce
	lane_since:            f32,
}

// Creates a player anchored to the floor, in the Real lane.
new_player :: proc() -> Player {
	player_size := rl.Vector2{PLAYER_SIZE, PLAYER_SIZE}

	return Player {
		position   = rl.Vector2 {
			core.PLAYER_X,
			core.SCREEN_HEIGHT - player_size.y, // bottom edge touches the floor
		},
		size       = player_size,
		lane       = .Real,
		state      = .Real,
		lane_since = 0,
	}
}

// Reads input and updates the player state machine.
update_player :: proc(player: ^Player, world: World) {
	// Start a flip only if we're not already mid-transition.
	if rl.IsKeyPressed(.SPACE) && player.state != .Transitioning {
		player.target_lane = .Dream if player.lane == .Real else .Real
		player.state = .Transitioning
		player.transition_timer = 0
		player.transition_start_y = player.position.y

		player.is_invulnerable = true
		player.invulnerability_timer = 0
	}

	if player.state == .Transitioning {
		player.transition_timer += rl.GetFrameTime()

		// Compute normalized progress (0 to 1), clamped so it never overshoots.
		t := player.transition_timer / TRANSITION_DURATION
		if t > 1 {
			t = 1
		}
		eased_t := core.ease_out_quad(t)

		target_y := core.get_lane_y(player.target_lane, player.size)
		player.position.y =
			player.transition_start_y + (target_y - player.transition_start_y) * eased_t

		if player.transition_timer >= TRANSITION_DURATION {
			// Transition complete: settle into the target lane.
			player.lane = player.target_lane
			player.state = .Real if player.lane == .Real else .Dream
			player.position.y = target_y

			// landing moment: start the squash bounce from zero, and mark
			// when this lane was settled into (drives near-miss detection)
			player.settle_timer = 0
			player.lane_since = world.elapsed_time
		}
	}

	// Invulnerability runs on its own timer, independent from the transition state,
	// since the two durations may end up different after playtesting.
	if player.is_invulnerable {
		player.invulnerability_timer += rl.GetFrameTime()
		if player.invulnerability_timer >= INVULNERABILITY_DURATION {
			player.is_invulnerable = false
		}
	}

	player.settle_timer += rl.GetFrameTime()
}
