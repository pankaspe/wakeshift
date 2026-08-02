/*
* This is Player file, player.odin
* holds the player character state and draws it
*/
package main

import rl "vendor:raylib/v55"

// Vertical split of the play area (Design Doc, section 6):
// Dream lane 30% / transition zone 40% / Real lane 30%
DREAM_LANE_RATIO :: 0.30
TRANSITION_ZONE_RATIO :: 0.40
REAL_LANE_RATIO :: 0.30

// Player reference size in pixels (Design Doc, section 6: ~40-50px)
PLAYER_SIZE :: 45

// Fixed horizontal position of the player on screen.
// The player stays put; the world will scroll past it (Section 5).
PLAYER_X :: 200

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
	lane:                  Lane, // current lane (used once not transitioning)
	state:                 PlayerState,
	target_lane:           Lane, // lane we're flipping into, while transitioning
	transition_timer:      f32, // seconds elapsed since transition started
	transition_start_y:    f32, // y position when the transition began
	is_invulnerable:       bool,
	invulnerability_timer: f32, // seconds elapsed since invulnerability started
	settle_timer:          f32, // seconds since landing, drivers the post flip squash bounce
}

// Creates a player anchored to the floor, in the Real lane.
new_player :: proc() -> Player {
	player_size := rl.Vector2{PLAYER_SIZE, PLAYER_SIZE}

	return Player {
		position = rl.Vector2 {
			PLAYER_X,
			SCREEN_HEIGHT - player_size.y, // bottom edge touches the floor
		},
		size     = player_size,
		lane     = .Real,
		state    = .Real,
	}
}

// Ease-out quadratic: starts fast, slows down towards the end.
// t goes from 0 (start) to 1 (end) and so does the returned value.
ease_out_quad :: proc(t: f32) -> f32 {
	return 1 - (1 - t) * (1 - t)
}

// Reads input and updates the player state machine.
update_player :: proc(player: ^Player) {
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
		eased_t := ease_out_quad(t)

		target_y := get_lane_y(player.target_lane, player.size)
		player.position.y =
			player.transition_start_y + (target_y - player.transition_start_y) * eased_t

		if player.transition_timer >= TRANSITION_DURATION {
			// Transition complete: settle into the target lane.
			player.lane = player.target_lane
			player.state = .Real if player.lane == .Real else .Dream
			player.position.y = target_y

			// landing moment: start the squash bounce from zero
			player.settle_timer = 0
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
