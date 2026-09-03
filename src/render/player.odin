/*
* Player Render
* The character: a dark silhouette with a head, a torso and four limbs,
* built entirely from thick lines and circles (Design Doc, section 12 —
* "a body, two poses"). No sprite, no texture; the sense of quality is
* meant to come from the math of the movement, not from the detail of
* the shapes.
*
* Three things are happening at once here, and they are deliberately
* kept separate:
*
*   the skeleton  a fixed set of joints in a local unit box, authored
*                 once below and never touched by animation
*   the pose      how that box lands on screen: rotation, squash &
*                 stretch, and the mirror that keeps the character facing
*                 forward while upside down
*   the animation the joint angles for this instant: the run cycle, and
*                 the drift that replaces it as the Dream takes over
*
* The silhouette rule (Design Doc, section 12): the body is the same dark
* shape in all three states, and only the *light* changes world. The old
* code inverted body and rim between worlds — a light body in the Real
* world, a dark one in the Dream — which read as two different
* characters. That is fixed here.
*
* The third pose (Design Doc, section 12 — "a body, two poses", plus the
* Limen's own): while suspended the body opens into it — arms wide, knees
* loosely tucked, everything drifting on one slow sine — and closes back
* out of it when the journey resumes. It is a single 0..1 quantity that
* the running pose is lerped toward, not a second animation with its own
* state, so there is exactly one figure builder and one place a limb
* angle comes from.
*
* Accessibility (pillar 6): the two worlds are never told apart by color
* alone. The character bounces on a hard, regular run cycle in the Real
* world and drifts on a slow float in the Dream one, and the two blend
* continuously through world_t, so the type of motion says which world is
* live even with the color removed entirely.
*/
package render

import "../core"
import "../game"
import "core:math"
import rl "vendor:raylib/v55"

// --- The skeleton, in fractions of the player's box ---
//
// Origin at the box center, +x forward (the direction of travel), +y
// down. Everything is authored here once; a pose is only ever a
// transform of these numbers, which is what keeps the run cycle and the
// flip from having to know about each other.

PLAYER_HEAD_CENTER :: rl.Vector2{0.09, -0.31}
PLAYER_HEAD_RADIUS :: 0.150
PLAYER_NECK :: rl.Vector2{0.06, -0.19}
PLAYER_SHOULDER :: rl.Vector2{0.03, -0.13}
PLAYER_HIP :: rl.Vector2{-0.02, 0.08}

PLAYER_THIGH_LENGTH :: 0.21
PLAYER_SHIN_LENGTH :: 0.21
PLAYER_UPPER_ARM_LENGTH :: 0.15
PLAYER_FOREARM_LENGTH :: 0.15

PLAYER_TORSO_THICKNESS :: 0.20
PLAYER_LIMB_THICKNESS :: 0.085

// --- The run cycle ---

// Pixels of world scroll per full two-step stride. Tying the cycle to
// distance rather than to time means the legs speed up with the world on
// their own, through every tier change, with nothing to keep in sync.
PLAYER_STRIDE_LENGTH :: 74

PLAYER_LEG_SWING :: 0.62 // radians the thigh swings either side of vertical
PLAYER_KNEE_BASE :: 0.18 // knees are never locked straight
PLAYER_KNEE_SWING :: 0.95 // extra bend while the leg recovers
PLAYER_ARM_SWING :: 0.42
PLAYER_ELBOW_BEND :: 0.65
PLAYER_LEAN :: 0.12 // radians of forward lean, a runner's posture
PLAYER_BOUNCE :: 0.045 // vertical bob per step, in box fractions

// --- The Dream drift, which replaces the run cycle as world_t rises ---

PLAYER_FLOAT_PERIOD :: 2.6 // seconds per full rise and fall
PLAYER_FLOAT_AMOUNT :: 0.055 // box fractions
PLAYER_WOBBLE_PERIOD :: 1.7
PLAYER_WOBBLE_AMOUNT :: 0.22 // radians added to the limbs, out of phase

// --- The float: how the body opens at the threshold ---

// The body opens only when the journey actually stops at the threshold —
// never on the way past it. An earlier version had every flip bloom
// halfway open as it crossed the middle, to teach the third state; what
// it taught instead was that the character does something unasked-for in
// the middle of the one gesture the game is made of. The easing lives in
// game/player.odin (Player.opening) so it survives the frame.

PLAYER_FLOAT_ARM :: 2.05 // radians from straight down: arms wide, slightly raised
PLAYER_FLOAT_ELBOW_OPEN :: 0.18 // nearly straight, unlike the running bend
PLAYER_FLOAT_LEG_SPREAD :: 0.34
PLAYER_FLOAT_KNEE :: 0.42 // loosely tucked, not locked

// The slow oscillation of the suspended body: a whole-figure lean, and a
// drift in the limbs, both on long periods so they read as weightless
// rather than as an idle animation.
PLAYER_SWAY_PERIOD :: 3.1
PLAYER_SWAY_ROTATION :: 0.10 // radians
PLAYER_SWAY_LIMB :: 0.16 // radians

// --- Squash & stretch ---

STRETCH_AMOUNT :: 0.16 // vertical stretch at the peak of a flip
SETTLE_DURATION :: 0.22 // length of the post-landing squash bounce
SETTLE_SQUASH_AMOUNT :: 0.28

// --- Light ---

PLAYER_RIM_THICKNESS :: 2.4 // how far the lit edge sticks out past the body
PLAYER_GLOW_RADIUS :: 1.35 // multiples of the box size
PLAYER_GLOW_STRENGTH :: 0.20
PLAYER_FLIP_GLOW_BOOST :: 0.35 // extra glow at the peak of a flip
PLAYER_SUSPENDED_GLOW :: 0.28 // extra glow while the body is open at the threshold
PLAYER_EYE_RADIUS :: 0.035
PLAYER_EYE_SPACING :: 0.085

// How the figure's local box lands on screen.
PlayerPose :: struct {
	origin:   rl.Vector2, // where local (0,0) sits
	rotation: f32, // radians, clockwise on screen
	scale:    rl.Vector2, // squash & stretch; scale.x is negative when mirrored
	unit:     f32, // pixels per local unit
}

// Every joint of the figure, in local coordinates, for this instant.
PlayerFigure :: struct {
	head:     rl.Vector2,
	neck:     rl.Vector2,
	shoulder: rl.Vector2,
	hip:      rl.Vector2,
	knees:    [2]rl.Vector2,
	feet:     [2]rl.Vector2,
	elbows:   [2]rl.Vector2,
	hands:    [2]rl.Vector2,
}

// Which lane the shape should currently be anchored to, for scaling
// purposes: mid-flip we anchor to where we're headed, not where we came
// from.
get_player_anchor_lane :: proc(player: game.Player) -> core.Lane {
	if player.state == .Transitioning || player.state == .Suspended {
		return player.target_lane
	}
	return player.lane
}

// Returns a per-axis scale multiplier (1.0 = normal shape).
// Values > 1 on Y stretch tall/thin; values < 1 on Y squash short/wide.
// X is always adjusted opposite to Y, for a (rough) sense of volume
// preservation — a classic animation trick, not physically exact.
get_player_scale :: proc(player: game.Player) -> rl.Vector2 {
	whip := game.get_whip_progress(player)
	if whip < 1 {
		// Bell curve peaking mid-turn, back to 1 at both ends. On the
		// whip's clock, not the journey's: the stretch belongs to the
		// impulse, and a suspended character has long since settled out
		// of it.
		stretch := STRETCH_AMOUNT * math.sin(whip * math.PI)
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

// The whip (Design Doc, section 12): half a turn, in the direction of
// travel, over the ~7 frames the flip lasts, with a small overshoot so
// it lands as an impulse rather than as a swing. Every flip turns the
// same way, so repeated flips read as one continuous forward somersault.
get_player_rotation :: proc(player: game.Player) -> f32 {
	if player.state == .Real || player.state == .Dream {
		return player.lane == .Dream ? math.PI : 0
	}

	// The lane being left is whichever one we are not heading into.
	from: f32 = player.target_lane == .Dream ? 0 : math.PI
	return from + math.PI * core.ease_out_back(game.get_whip_progress(player))
}

// Half a turn leaves the character upside down *and* facing backwards,
// so hanging from the ceiling also mirrors the figure horizontally: the
// two together are exactly the vertical mirror the pose wants, with the
// rotation carrying the motion.
//
// A mirror cannot be interpolated — it is a change of handedness — so it
// snaps, and it snaps halfway through the *turn*, where the figure is
// side-on and turning at full speed. The turn takes 120 ms whatever the
// journey does, so that is one frame around frame 4. If it ever reads as a pop on screen,
// the fix is to squash the figure thin at the same instant, not to
// slow the rotation down.
get_player_mirror :: proc(player: game.Player) -> f32 {
	facing_dream := player.lane == .Dream

	if player.state == .Transitioning || player.state == .Suspended {
		past_midpoint := game.get_whip_progress(player) >= 0.5
		facing_dream = past_midpoint ? player.target_lane == .Dream : player.target_lane == .Real
	}

	return facing_dream ? -1 : 1
}

new_player_pose :: proc(player: game.Player) -> PlayerPose {
	scale := get_player_scale(player)

	// Keep the figure planted on the surface it is touching while it
	// squashes and stretches, instead of scaling about its center —
	// otherwise a landing looks like it happens above the ground.
	anchor_shift := (1 - scale.y) * player.size.y * 0.5
	if get_player_anchor_lane(player) == .Dream {
		anchor_shift = -anchor_shift
	}

	return PlayerPose {
		origin = rl.Vector2 {
			player.position.x + player.size.x * 0.5,
			player.position.y + player.size.y * 0.5 + anchor_shift,
		},
		rotation = get_player_rotation(player),
		scale = rl.Vector2{scale.x * get_player_mirror(player), scale.y},
		unit = player.size.y,
	}
}

// Local point -> screen point. Mirror and squash first, rotation second:
// the figure is mirrored in its own frame, then the whole thing is
// turned.
pose_point :: proc(pose: PlayerPose, local: rl.Vector2) -> rl.Vector2 {
	x := local.x * pose.scale.x * pose.unit
	y := local.y * pose.scale.y * pose.unit

	c := math.cos(pose.rotation)
	s := math.sin(pose.rotation)
	return rl.Vector2{pose.origin.x + x * c - y * s, pose.origin.y + x * s + y * c}
}

// A limb segment's far end, given an angle measured from straight down
// and turning toward the front.
@(private)
limb_end :: proc(from: rl.Vector2, angle, length: f32) -> rl.Vector2 {
	return rl.Vector2{from.x + math.sin(angle) * length, from.y + math.cos(angle) * length}
}

// Builds the figure for this instant.
//
// stride comes from distance travelled and drives the run; time drives
// the Dream's drift and the Limen's sway. world_t crossfades between the
// first two, so there is no moment where the character switches
// animation — it stops running and starts floating the same way the
// palette stops being blue and starts being violet. opening then lerps
// the whole body toward the spread, weightless pose of the threshold.
new_player_figure :: proc(stride, time, world_t, opening: f32) -> PlayerFigure {
	dream := clamp(world_t, 0, 1)
	grounded := 1 - dream
	open := clamp(opening, 0, 1)

	sway := math.sin(time / PLAYER_SWAY_PERIOD * 2 * math.PI)

	// The body rises twice per stride while running, breathes slowly while
	// floating, and hangs a little lower the more it is suspended.
	bounce := -PLAYER_BOUNCE * abs(math.sin(stride)) * grounded * (1 - open)
	float := PLAYER_FLOAT_AMOUNT * math.sin(time / PLAYER_FLOAT_PERIOD * 2 * math.PI) * dream
	float += PLAYER_FLOAT_AMOUNT * sway * open
	body_offset := rl.Vector2{0, bounce + float}

	figure := PlayerFigure {
		head     = PLAYER_HEAD_CENTER + body_offset,
		neck     = PLAYER_NECK + body_offset,
		shoulder = PLAYER_SHOULDER + body_offset,
		hip      = PLAYER_HIP + body_offset,
	}

	for side in 0 ..< 2 {
		// The two legs are half a cycle apart; the arms counter the leg
		// on their own side, which is what makes a run read as a run.
		phase := stride + math.PI * f32(side)
		wobble :=
			PLAYER_WOBBLE_AMOUNT *
			math.sin(time / PLAYER_WOBBLE_PERIOD * 2 * math.PI + math.PI * f32(side)) *
			dream

		// Legs. The knee flexes hardest while the leg is behind and being
		// pulled through, which is the single detail that separates a run
		// from two sticks swinging.
		thigh := PLAYER_LEG_SWING * math.sin(phase) * grounded + wobble
		recovery := max(-math.sin(phase - 0.6), 0)
		knee_bend := (PLAYER_KNEE_BASE + PLAYER_KNEE_SWING * recovery) * grounded
		knee_bend += PLAYER_KNEE_BASE * dream

		// Arms, opposite the leg on the same side, elbow bent forward.
		arm := -PLAYER_ARM_SWING * math.sin(phase) * grounded - wobble
		elbow := arm + PLAYER_ELBOW_BEND * grounded

		// The threshold pose: limbs spread wide, knees loosely tucked,
		// everything drifting on one slow sine. Reached by lerping the
		// running pose into it rather than by switching to it, so a flip
		// that only brushes the middle shows a hint of the same shape.
		side_sign: f32 = side == 0 ? 1 : -1
		open_arm := PLAYER_FLOAT_ARM * side_sign + PLAYER_SWAY_LIMB * sway * side_sign
		open_thigh := PLAYER_FLOAT_LEG_SPREAD * side_sign - PLAYER_SWAY_LIMB * 0.5 * sway * side_sign

		thigh += (open_thigh - thigh) * open
		knee_bend += (PLAYER_FLOAT_KNEE - knee_bend) * open
		arm += (open_arm - arm) * open
		elbow += (open_arm + PLAYER_FLOAT_ELBOW_OPEN * side_sign - elbow) * open

		figure.knees[side] = limb_end(figure.hip, thigh, PLAYER_THIGH_LENGTH)
		figure.feet[side] = limb_end(figure.knees[side], thigh - knee_bend, PLAYER_SHIN_LENGTH)
		figure.elbows[side] = limb_end(figure.shoulder, arm, PLAYER_UPPER_ARM_LENGTH)
		figure.hands[side] = limb_end(figure.elbows[side], elbow, PLAYER_FOREARM_LENGTH)
	}

	return figure
}

// Draws every bone as a thick line with rounded ends, at the given
// thickness in local units. Called twice: once fat in the world's light
// to make the rim, once at true weight in the silhouette color on top.
@(private)
draw_player_bones :: proc(
	pose: PlayerPose,
	figure: PlayerFigure,
	extra_thickness: f32,
	color: rl.Color,
) {
	limb := PLAYER_LIMB_THICKNESS * pose.unit + extra_thickness
	torso := PLAYER_TORSO_THICKNESS * pose.unit + extra_thickness
	head_radius := PLAYER_HEAD_RADIUS * pose.unit + extra_thickness * 0.5

	bone :: proc(pose: PlayerPose, a, b: rl.Vector2, thickness: f32, color: rl.Color) {
		start := pose_point(pose, a)
		end := pose_point(pose, b)
		rl.DrawLineEx(start, end, thickness, color)
		// Round the joints: a capsule instead of a bare rectangle, so
		// limbs bend without opening a notch at the elbow or knee.
		rl.DrawCircleV(start, thickness * 0.5, color)
		rl.DrawCircleV(end, thickness * 0.5, color)
	}

	for side in 0 ..< 2 {
		bone(pose, figure.hip, figure.knees[side], limb, color)
		bone(pose, figure.knees[side], figure.feet[side], limb, color)
		bone(pose, figure.shoulder, figure.elbows[side], limb, color)
		bone(pose, figure.elbows[side], figure.hands[side], limb, color)
	}

	bone(pose, figure.shoulder, figure.hip, torso, color)
	bone(pose, figure.neck, figure.shoulder, limb, color)
	rl.DrawCircleV(pose_point(pose, figure.head), head_radius, color)
}

draw_player :: proc(player: game.Player, world: game.World, palettes: core.PaletteSet) {
	// The terrain is drawn against the world nudged forward by the
	// leftover fraction of a simulation step (main/interpolated_world),
	// so the body is placed on that same ground rather than on the ground
	// of the last whole step. Without it the character walks down a slope
	// in 60 Hz steps while the slope itself slides smoothly underneath,
	// which is most visible exactly where the frame rate is highest.
	// A local copy: render never mutates game state.
	player := player
	player.position.y = game.get_player_y(player, world)

	pose := new_player_pose(player)

	opening := player.opening

	// A forward lean on top of the flip's rotation: posture, not motion.
	// Mirrored with the figure, so it leans into the run in both worlds.
	// The suspended body has no run to lean into, so the lean gives way
	// to the threshold's slow roll.
	mirror := get_player_mirror(player)
	sway := math.sin(world.elapsed_time / PLAYER_SWAY_PERIOD * 2 * math.PI)
	pose.rotation += PLAYER_LEAN * mirror * (1 - opening)
	pose.rotation += PLAYER_SWAY_ROTATION * sway * opening

	stride := world.scroll_offset / PLAYER_STRIDE_LENGTH * 2 * math.PI
	figure := new_player_figure(stride, world.elapsed_time, palettes.world_t, opening)

	// The aura: the world's light gathered around the body, brightest at
	// the peak of a flip. The body itself never takes a world's color —
	// only what is around it does (Design Doc, section 12).
	// Brightest at the peak of the turn, and brighter still the longer the
	// body stays open at the threshold — the one place the light is
	// supposed to be washed out and everywhere at once.
	glow_strength: f32 = PLAYER_GLOW_STRENGTH
	glow_strength += PLAYER_FLIP_GLOW_BOOST * math.sin(game.get_whip_progress(player) * math.PI)
	glow_strength += PLAYER_SUSPENDED_GLOW * opening
	draw_glow_circle(
		pose_point(pose, figure.hip),
		player.size.y * PLAYER_GLOW_RADIUS,
		palettes.current.light,
		glow_strength,
	)

	// Rim first, body over it: only the edges of the fatter silhouette
	// survive, which is a lit outline for the price of drawing the figure
	// twice.
	draw_player_bones(pose, figure, PLAYER_RIM_THICKNESS * 2, palettes.current.light)
	draw_player_bones(pose, figure, 0, palettes.current.silhouette)

	draw_player_eyes(pose, figure, palettes.current.accent)
}

// Two points of light on the head, set toward the front. They are the
// only part of the character allowed a bright color, and they carry the
// facing: authored in local space, they follow the mirror and the
// rotation without a special case.
@(private)
draw_player_eyes :: proc(pose: PlayerPose, figure: PlayerFigure, color: rl.Color) {
	radius := PLAYER_EYE_RADIUS * pose.unit
	front := rl.Vector2{figure.head.x + PLAYER_HEAD_RADIUS * 0.45, figure.head.y - 0.02}

	for side in 0 ..< 2 {
		offset := PLAYER_EYE_SPACING * (f32(side) - 0.5)
		center := pose_point(pose, rl.Vector2{front.x - offset * 0.35, front.y + offset})
		rl.DrawCircleV(center, radius, color)
	}
}
