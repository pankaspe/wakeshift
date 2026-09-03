/*
* Player
* Holds the player character state and drives the flip state machine
* (Design Doc, section 4). Drawing lives separately in the render package:
* nothing under game/ ever draws.
*
* The whole control scheme is one sentence, and the code is arranged so
* that sentence is literally what runs:
*
*     A flip is a journey from wall to wall, and holding stops it halfway.
*
* So a flip is a single journey with a single clock. Holding does not
* start a different move, it *pauses* that clock at the halfway mark;
* releasing resumes it, and the journey finishes where it was always
* going. That is why the Limen never needs a rule about where you came
* from: there is only one direction of travel, and it never changes.
*
* Why the journey is longer than it used to be (0.12s -> FLIP_DURATION):
* the halfway mark is also the tap/hold decision point, so the time it
* takes to reach it *is* the threshold between the two gestures. At the
* old duration the middle arrived after 60ms, and a perfectly ordinary
* tap would have suspended by accident.
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
import "core:math"
import rl "vendor:raylib/v55"

// Player reference size in pixels (Design Doc, section 6: ~40-50px)
PLAYER_SIZE :: 45

// A time far enough outside any run that comparing against it is always
// false. Used to say "this has not happened yet" without a second flag.
NEVER :: 1000

// Player state machine (Design Doc, sections 3-4).
PlayerState :: enum {
	Real, // settled on the floor
	Dream, // settled on the ceiling
	Transitioning, // mid-journey between the two
	Suspended, // stopped at the halfway mark: the Limen
}

// How long the whole journey takes, wall to wall, when nothing stops it.
// The halfway mark — and so the tap/hold decision — lands at half of it,
// so this constant is really two decisions in one: how fast the flip
// feels, and how long a press has to be before it counts as a hold.
// Shortening it sharpens the first and narrows the second.
FLIP_DURATION :: 0.24

// Duration of the invulnerability grace period, in seconds.
//
// Deliberately shorter than the journey now. It exists to forgive the
// flip started at the last possible instant (Design Doc, section 4), and
// the player is clear of the lane they were in long before it expires.
// Covering the *whole* journey instead would hand out a much worse deal
// than it sounds: with no cooldown on the flip, a player mashing the key
// would be permanently untouchable.
INVULNERABILITY_DURATION :: 0.15

Player :: struct {
	position:              rl.Vector2,
	size:                  rl.Vector2,
	lane:                  core.Lane, // the wall we are on, or the one we left
	state:                 PlayerState,
	target_lane:           core.Lane, // the wall this journey ends at
	transition_timer:      f32, // seconds travelled along the journey; frozen while suspended
	transition_start_y:    f32, // y position when the journey began
	is_invulnerable:       bool,
	invulnerability_timer: f32, // seconds elapsed since invulnerability started
	settle_timer:          f32, // seconds since landing, drives the post flip squash bounce

	// Seconds spent in the current suspension, 0 when not suspended.
	// Gameplay uses it for nothing yet; the Limen's audio filter will open
	// over it (roadmap T12.2).
	suspended_time:        f32,

	// How open the body is, 0..1, eased toward 1 while suspended and back
	// to 0 otherwise. Pure presentation, but it lives here for the same
	// reason settle_timer does: it is a value that has to *ease*, and
	// render draws from state it is handed rather than keeping its own.
	opening:               f32,

	// The lane most recently departed, and when the departure began. This
	// is what a near-miss is actually about (see lucidity.odin): getting
	// out of the way of something that was coming for the place you were
	// standing in.
	left_lane:             core.Lane,
	left_lane_at:          f32,
}

// Creates a player anchored to the floor, in the Real lane.
new_player :: proc() -> Player {
	player_size := rl.Vector2{PLAYER_SIZE, PLAYER_SIZE}

	return Player {
		position   = rl.Vector2 {
			core.PLAYER_X,
			core.SCREEN_HEIGHT - player_size.y, // bottom edge touches the floor
		},
		size         = player_size,
		lane         = .Real,
		state        = .Real,

		// Far enough in the past that the first obstacles of a run cannot
		// be mistaken for something this player dodged.
		left_lane_at = -NEVER,
	}
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
// It stays a named procedure rather than being inlined because the
// midpoint is load-bearing — the Limen sits at flip_progress = 0.5, and
// anything that changes this shape moves the third state.
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
// Lucidity arrives by pointer because the Limen spends it. The two are
// one system on purpose (Design Doc, section 8) — the resource that
// multiplies the score is the same one that pays for the place where the
// score is highest — and splitting the rule across two procedures would
// only hide that.
update_player :: proc(
	player: ^Player,
	world: World,
	lucidity: ^Lucidity,
	input: core.Input,
	delta_time: f32,
) {
	// A flip can only be started from a wall: mid-journey the key means
	// "stop at the middle" instead, which is the whole of the second
	// gesture.
	if input.flip && (player.state == .Real || player.state == .Dream) {
		start_flip(player, world)
	}

	switch player.state {
	case .Transitioning:
		advance_flip(player, lucidity, input, delta_time)
	case .Suspended:
		advance_suspension(player, lucidity, input, delta_time)
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
	advance_opening(player, delta_time)
}

// How long the body takes to open into the float, or to close back out of
// it, in seconds.
OPENING_DURATION :: 0.18

@(private)
advance_opening :: proc(player: ^Player, delta_time: f32) {
	target: f32 = is_suspended(player^) ? 1 : 0
	step := delta_time / OPENING_DURATION
	player.opening += clamp(target - player.opening, -step, step)
}

@(private)
start_flip :: proc(player: ^Player, world: World) {
	// Remember what we are getting out of the way of, and when. Recorded
	// at the departure rather than at the landing because that is the
	// moment the risk was actually taken.
	player.left_lane = player.lane
	player.left_lane_at = world.elapsed_time

	player.target_lane = .Dream if player.lane == .Real else .Real
	player.state = .Transitioning
	player.transition_timer = 0
	player.transition_start_y = player.position.y

	player.is_invulnerable = true
	player.invulnerability_timer = 0
}

@(private)
advance_flip :: proc(player: ^Player, lucidity: ^Lucidity, input: core.Input, delta_time: f32) {
	half := f32(FLIP_DURATION) * 0.5

	// The one moment the tap/hold question is asked: the step on which the
	// journey crosses its own midpoint. Testing the crossing rather than
	// the position means it fires exactly once per journey — a resumed
	// journey is already past the middle and can never suspend twice.
	before_middle := player.transition_timer < half
	player.transition_timer += delta_time
	crossing_middle := before_middle && player.transition_timer >= half

	if crossing_middle && input.flip_held && can_suspend(lucidity^) {
		enter_suspension(player, half)
		return
	}

	target_y := core.get_lane_y(player.target_lane, player.size)
	progress := flip_progress(player.transition_timer / FLIP_DURATION)
	player.position.y = player.transition_start_y + (target_y - player.transition_start_y) * progress

	if player.transition_timer >= FLIP_DURATION {
		// Journey complete: settle onto the wall it was always headed for.
		player.lane = player.target_lane
		player.state = .Real if player.lane == .Real else .Dream
		player.position.y = target_y

		// landing moment: start the squash bounce from zero
		player.settle_timer = 0
	}
}

// Freezing the clock at the midpoint is all it takes to stop there: the
// position is whatever the journey's own curve says at that instant, so
// suspension cannot drift away from the path and resuming cannot jump.
// flip_progress(0.5) is exactly 0.5, which for a player of uniform size
// puts its centre on the centre of the screen.
@(private)
enter_suspension :: proc(player: ^Player, half_duration: f32) {
	player.state = .Suspended
	player.transition_timer = half_duration
	player.suspended_time = 0

	target_y := core.get_lane_y(player.target_lane, player.size)
	player.position.y = player.transition_start_y + (target_y - player.transition_start_y) * 0.5

	// No invulnerability in the Limen (Design Doc, section 4): the
	// suspension is a state, not a prolonged grace period. Whatever is
	// left of the flip's grace is spent here.
	player.is_invulnerable = false
}

// The Limen is a bet on a clock, not a shelter. It ends when the player
// lets go, and it ends on its own when the fuel runs out — and both exits
// do the same thing, because there is only ever one direction of travel.
@(private)
advance_suspension :: proc(
	player: ^Player,
	lucidity: ^Lucidity,
	input: core.Input,
	delta_time: f32,
) {
	player.suspended_time += delta_time
	spend_lucidity(lucidity, LUCIDITY_DRAIN_RATE * delta_time)

	if !input.flip_held || lucidity.value <= 0 {
		player.state = .Transitioning
		player.suspended_time = 0
	}
}

// True while the player is in the Limen — the third state, worth its own
// question because "which lane are you in" has no answer here.
is_suspended :: proc(player: Player) -> bool {
	return player.state == .Suspended
}

// How far through the body's turn-over the player is, 0..1. The body
// turns faster than it travels: the whip is over *before the midpoint*,
// not merely before the journey ends, so nothing about the body is still
// moving on its own at the instant the tap/hold question is asked. Two
// animations resolving at the same moment read as one stutter.
FLIP_WHIP_DURATION :: 0.10

get_whip_progress :: proc(player: Player) -> f32 {
	if player.state == .Real || player.state == .Dream {
		return 1
	}
	return clamp(player.transition_timer / FLIP_WHIP_DURATION, 0, 1)
}

// Unused for now, but the Limen's own oscillation is a sine of this and
// nothing else, so it belongs next to the state it describes.
get_suspension_sway :: proc(player: Player, period: f32) -> f32 {
	return math.sin(player.suspended_time / period * 2 * math.PI)
}

// Which band the player counts as being in, for anything that speaks the
// pattern contract's vocabulary (core/lane.odin).
//
// A player mid-journey is reported as the band they are heading for, not
// the one they left. That is not an approximation: the journey has one
// direction and it never changes, so a transitioning player is already
// committed — the only thing still in doubt is whether they will stop in
// the middle on the way.
get_player_band :: proc(player: Player) -> core.Band {
	switch player.state {
	case .Real:
		return .Real
	case .Dream:
		return .Dream
	case .Suspended:
		return .Limen
	case .Transitioning:
		return core.band_of_lane(player.target_lane)
	}
	return .Real
}
