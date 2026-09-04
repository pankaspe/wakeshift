/*
* Player
* Holds the player character state and drives the flip state machine
* (Design Doc, section 4). Drawing lives separately in the render package:
* nothing under game/ ever draws.
*
* The whole control scheme is one sentence, and the code is arranged so
* that sentence is literally what runs:
*
*     A flip is one journey from wall to wall, and there is nothing else.
*
* One key, one gesture (Design Doc, pillar 1). The v1.x version of this
* file had a second: holding the key stopped the journey at its midpoint,
* in a third state. That state is gone, and with it the only reason the
* journey had to be long — the midpoint was the tap/hold decision point,
* so the journey had to take long enough to reach it *after* an ordinary
* tap had ended. Without that constraint the flip can be what it should
* have been all along: fast enough to be a reflex.
*
* Since R2.1 the character also moves **horizontally**, and that axis is
* the whole of the rewrite. A cube does not kill: it stops you against its
* face, the face scrolls away with the world, and you are dragged
* backwards toward the Corruption. Running free you claw the ground back,
* at two thirds of the speed you lose it. How far the character sits from
* the front is the only health bar the game has.
*
* The two axes are independent and resolved in one place, in this order:
* the press, then the journey, then the ground, then where the body
* actually is. The order matters exactly once — a tap frees you from a
* cube on the same step it is pressed, because the journey has already
* started by the time the ground is resolved.
*
* A press that arrives mid-journey is **buffered**, not dropped and not
* blended into the journey in progress: it takes off the instant that
* journey lands, carrying the overshoot with it so the rhythm stays
* exact. Two flips back to back therefore work at the full FLIP_DURATION
* cadence with no dead frame between them.
*
* The buffer is **one deep, deliberately**. Measured: five presses on five
* consecutive steps produce two flips, not five. A deeper queue would let
* mashing bank flips the player can no longer see coming, and the
* character would keep turning over after they stopped asking — which is
* a worse bug than the one the buffer exists to fix. One press ahead is
* forgiveness; five is the game playing itself.
*
* It first shipped with a curve that lingered at the threshold, on the
* theory that a flip which visibly slows through the middle teaches the
* third state before anyone tries to use it. Playtest killed it: the
* character came off the wall at three times average speed, stopped dead
* mid-air, then shot away again, and what that reads as is a hitch in the
* one gesture the whole game is made of. The lesson is worth keeping
* around, because it will come up again in phases 9 and 11 — a flourish
* placed *on the player's own motion* is not decoration, it is friction.
* Teach with the background, the light, the particles; never by making
* the character do something it didn't ask to do.
*/
package game

import "../core"
import rl "vendor:raylib/v55"

// Player reference size in pixels (Design Doc, section 6: ~40-50px)
PLAYER_SIZE :: 45

// Player state machine (Design Doc, sections 3-4).
PlayerState :: enum {
	Real, // settled on the floor
	Dream, // settled on the ceiling
	Transitioning, // mid-journey between the two
}

// How long the whole journey takes, wall to wall.
//
// Constant in *time*, never in space: the corridor changes width along
// the track and the gesture must not change with it. A flip the player
// has to recalibrate at every curve stops being a reflex, which is the
// one thing this game asks of them.
FLIP_DURATION :: 0.16

// How fast the character claws back ground once nothing is blocking them,
// as a fraction of the world's scroll speed.
//
// A fraction rather than a number of pixels, so that buying Slancio
// (roadmap R6.3) makes a mistake cost more *and* take proportionally as
// long to repay — the trade stays honest at every speed.
//
// Deliberately under 1: ground is lost at the full scroll speed and won
// back at two thirds of it, so a brief mistake is repaid in about half
// again the time it took to make, and three close together are a real
// problem. This is the first number the playtest should argue with.
PLAYER_RECOVERY_RATIO :: 0.66

// Duration of the invulnerability grace period, in seconds.
//
// Deliberately shorter than the journey. It exists to forgive the flip
// started at the last possible instant, and the player is clear of the
// lane they were in long before it expires. Covering the *whole* journey
// instead would hand out a much worse deal than it sounds: presses queue,
// so a player mashing the key would be permanently untouchable.
INVULNERABILITY_DURATION :: 0.10

Player :: struct {
	position:              rl.Vector2,
	size:                  rl.Vector2,
	lane:                  core.Lane, // the wall we are on, or the one we left
	state:                 PlayerState,
	target_lane:           core.Lane, // the wall this journey ends at
	transition_timer:      f32, // seconds travelled along the journey; frozen while suspended
	is_invulnerable:       bool,
	invulnerability_timer: f32, // seconds elapsed since invulnerability started
	settle_timer:          f32, // seconds since landing, drives the post flip squash bounce

	// A press that arrived while a journey was already running. Consumed
	// the instant that journey lands, with the overshoot carried into the
	// next one, so a burst of taps keeps its rhythm instead of being
	// quantised to whenever the code happened to notice.
	flip_queued:           bool,

	// True on any step a cube is holding the character back. Presentation
	// reads it, and so does anything that wants to know why the ground is
	// going the wrong way.
	is_blocked:            bool,

	// How fast the character is moving across the screen, px/s. Derived
	// rather than integrated: the pin sets a position directly, so the
	// velocity is measured after the fact from where the body ended up.
	//
	// It is what turns scroll into *distance travelled*: pinned, it is
	// exactly minus the scroll speed, and the two cancel to zero (see
	// score.odin). Blocking costs depth without a single line that says
	// so.
	velocity_x:            f32,
}

// Creates a player anchored to the floor, in the Real lane.
new_player :: proc() -> Player {
	player_size := rl.Vector2{PLAYER_SIZE, PLAYER_SIZE}

	// The opening ground: the run has not started, so it is the profile at
	// time zero, at the speed a run opens at.
	ground := core.Ground{time = 0, speed = INITIAL_SCROLL_SPEED}

	return Player {
		position = rl.Vector2 {
			core.PLAYER_HOME_X,
			core.get_lane_y(ground, .Real, core.PLAYER_HOME_X, player_size),
		},
		size     = player_size,
		lane     = .Real,
		state    = .Real,
	}
}

// Where the player's box sits for a given world state.
//
// The journey is between the two walls, and since phase 7.5 the walls
// are the terrain, so both of its endpoints are sampled fresh every step
// rather than captured when the flip began. A flip that starts before a
// change in the ground and ends after it therefore always lands on the
// ground that is actually there — at the cost of a path that curves a
// little while the terrain slides underneath, which is the trade the
// alternative (aiming at where the ground will be on arrival) makes in
// reverse, with a target the player cannot see yet.
//
// It is a pure function of the player and the world on purpose: the
// simulation calls it with the stepped world, and render calls it with
// the world nudged forward by the leftover fraction of a step, so the
// character rides the same interpolated ground the terrain is drawn on
// instead of stepping down it at the tick rate.
get_player_y :: proc(player: Player, world: World) -> f32 {
	ground := get_ground(world)

	switch player.state {
	case .Real, .Dream:
		return core.get_lane_y(ground, player.lane, player.position.x, player.size)

	case .Transitioning:
		// player.lane is still the wall we left; target_lane is the one we
		// are going to.
		from := core.get_lane_y(ground, player.lane, player.position.x, player.size)
		to := core.get_lane_y(ground, player.target_lane, player.position.x, player.size)
		return from + (to - from) * flip_progress(player.transition_timer / FLIP_DURATION)
	}
	return player.position.y
}

// Where along the journey we are (0 at the wall we left, 1 at the wall we
// are heading to) after a fraction t of its duration.
//
// One constant speed, and it is deliberate rather than lazy. Anything
// that leaves the wall faster than average has to give the time back
// before the midpoint — that is arithmetic, not a tuning choice — and
// giving it back means decelerating in mid-air, which is the hitch that
// playtest threw out. A straight line is the only shape with no hitch to
// give back.
//
// The two ends are also the two places a discontinuity in speed is
// *right*: leaving is a push, and arriving is a landing, which the
// squash-and-stretch bounce already absorbs (render/player.odin).
//
// It stays a named procedure rather than being inlined because a future
// game feel pass will be tempted to shape it, and the comment above is
// the argument it has to beat.
flip_progress :: proc(t: f32) -> f32 {
	return clamp(t, 0, 1)
}

// Advances the player state machine for one simulation step.
//
// Both input and delta_time arrive as arguments rather than being polled
// from raylib in here: the same input and the same timestep must always
// produce the same run, which is what makes a run recordable and
// replayable (see core/input.odin).
//
update_player :: proc(
	player: ^Player,
	world: World,
	obstacles: []Obstacle,
	input: core.Input,
	delta_time: f32,
) {
	was_at := player.position.x

	// A press either starts a journey or is remembered until the current
	// one lands. Only one is remembered at a time — see the file header
	// for why a deeper buffer is worse rather than better.
	if input.flip {
		if player.state == .Transitioning {
			player.flip_queued = true
		} else {
			start_flip(player)
		}
	}

	switch player.state {
	case .Transitioning:
		advance_flip(player, delta_time)
	case .Real, .Dream:
	// settled on a wall: nothing to advance
	}

	// Invulnerability runs on its own timer, independent from the journey,
	// since the two durations are deliberately different.
	if player.is_invulnerable {
		player.invulnerability_timer += delta_time
		if player.invulnerability_timer >= INVULNERABILITY_DURATION {
			player.is_invulnerable = false
		}
	}

	player.settle_timer += delta_time

	// Horizontal, after the journey: a tap frees the character from a cube
	// on the same step it is pressed, because by now they are already
	// travelling and nothing on a lane can hold them.
	advance_ground(player, world, obstacles, delta_time)
	player.velocity_x = (player.position.x - was_at) / delta_time

	// One place decides where the body is, for every state: the walls
	// moved under it this step even if the player did nothing, and the
	// ground under them changes with x as well as with time.
	player.position.y = get_player_y(player^, world)
}

// Runs the character back toward where they belong, then pushes them out
// of anything solid they ran into. **Move first, resolve second** — the
// order is not cosmetic.
//
// The obvious arrangement is the other way round: look for a cube, and if
// there is one, pin against its face. It self-destructs. Pinning places
// the character exactly at the face, which is *not* an overlap, so the
// next step finds nothing blocking, lets them creep forward, and the step
// after that pins them again. Measured, is_blocked flickered every other
// step while the character was plainly stuck — a lie to anything that
// reads it, and a wrong answer to the one question the whole design turns
// on.
//
// Moving first makes the contact real: they try to advance, they overlap,
// they are pushed back, and is_blocked means what it says. It also gets
// the dragging for free — the face is scrolling left, so being pushed
// behind it every step *is* losing ground at exactly the world's speed,
// with nobody having to say the word.
@(private)
advance_ground :: proc(
	player: ^Player,
	world: World,
	obstacles: []Obstacle,
	delta_time: f32,
) {
	recovery := world.scroll_speed * PLAYER_RECOVERY_RATIO * delta_time
	player.position.x = min(player.position.x + recovery, core.PLAYER_HOME_X)

	player.is_blocked = false
	for obstacle in obstacles {
		if !blocks_player(player^, obstacle, world) {
			continue
		}
		player.is_blocked = true
		player.position.x = min(player.position.x, get_obstacle_rect(obstacle, world).x - player.size.x)
	}
}

// How much ground the character has left, in pixels: the distance from
// the Corruption front to their trailing edge. This is the health bar,
// and there is no other.
get_player_runway :: proc(player: Player, front_x: f32) -> f32 {
	return player.position.x - front_x
}

@(private)
start_flip :: proc(player: ^Player) {
	player.target_lane = core.opposite_lane(player.lane)
	player.state = .Transitioning
	player.transition_timer = 0
	player.flip_queued = false

	player.is_invulnerable = true
	player.invulnerability_timer = 0
}

@(private)
advance_flip :: proc(player: ^Player, delta_time: f32) {
	player.transition_timer += delta_time
	if player.transition_timer < FLIP_DURATION {
		return
	}

	// Journey complete: settle onto the wall it was always headed for.
	// The position is not written here — get_player_y answers with the
	// settled wall from this step on, and it is the same value the
	// journey was approaching, so the landing has nothing to snap to.
	overshoot := player.transition_timer - FLIP_DURATION
	player.lane = player.target_lane
	player.state = .Real if player.lane == .Real else .Dream
	player.settle_timer = 0 // landing moment: start the squash bounce from zero

	// A press that arrived mid-journey takes off again immediately, from
	// the wall just landed on, carrying the overshoot with it. Carrying it
	// is what keeps a burst of taps rhythmic: without it every queued flip
	// would start on a step boundary and the second of two fast taps would
	// land up to a whole step late.
	if player.flip_queued {
		start_flip(player)
		player.transition_timer = overshoot
	}
}

// How far through the body's turn-over the player is, 0..1. The body
// turns faster than it travels — the whip is over well before the journey
// ends — so nothing about the body is still moving on its own at the
// moment it lands. Two animations resolving at once read as one stutter.
FLIP_WHIP_DURATION :: 0.10

get_whip_progress :: proc(player: Player) -> f32 {
	if player.state != .Transitioning {
		return 1
	}
	return clamp(player.transition_timer / FLIP_WHIP_DURATION, 0, 1)
}
