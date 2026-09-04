/*
* Player Render
* The character: the Sprout, a bulb head, a small body, four limbs and a
* sprout growing out of its crown — since phase RL.3 drawn entirely as
* open strokes, the same mark the world is made of (Design Doc, section
* 10 — "il tratto"). No sprite, no texture; the sense of quality is meant
* to come from the math of the movement, not from the detail of the
* shapes.
*
* The proportions come from docs/sketch/spirito_foresta.jpeg (T7.5.3) and
* they are what makes it read as a sprout rather than as a small person:
* the head is a bit under two fifths of the figure, the body is a
* remainder, and there is no neck to speak of. It was a change of numbers
* and one extra appendage, not a rewrite, which is the whole reason the
* skeleton was authored as fractions of a box in the first place.
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
* THE CHARACTER IS A CONTINUATION OF THE LINE
*
* Nothing here is filled any more. The figure used to be drawn twice — a
* fattened shape in the world's light to make a rim, then the same shape
* at true weight in the silhouette colour on top — and phase RL.3
* replaced both passes with one: every bone is a stroke, and the bulb is
* a closed stroke around the outline of the two circles that make it.
*
* The weight hierarchy is a rule and not a taste (Design Doc, section
* 10): the character is **the thickest stroke and the whitest core on
* screen**, above the live lane, which is above the dormant one, which is
* above the parallax. That is why the weights here are multiples of the
* world's own stroke rather than numbers of their own — tune
* TERRAIN_STROKE_THICKNESS and the character stays above it by
* construction.
*
* The mark itself does not change world. It is drawn out of the *neutral*
* palette, and what changes between the Real and the Dream is what is
* behind it and what is gathered around it (Design Doc, section 10: "il
* personaggio è lo stesso segno in entrambi i mondi"). The old code
* inverted body and rim between worlds — a light body in the Real world,
* a dark one in the Dream — which read as two different characters; a
* mark that changes colour is a milder version of the same mistake.
*
* There are two poses, and they are layers over one figure rather than
* two animations. Each is a 0..1 quantity the pose so far is lerped
* toward, in this order:
*
*   the run      the base, crossfaded with the Dream's drift by world_t
*   the whip     the turn's own shape: streamlined, arms and legs swept
*                back. It rides sin(whip * PI), so it is nothing at both
*                ends of the turn and everything at the middle — which is
*                what lets it grow out of the run and settle back into it
*                with no seam
*
* There was a third — the tuck, the curled "hypnotised" body of the
* suspended state. It went with that state in the design rewrite (roadmap
* R1.1). The *layering* is what survives it and what matters: because the
* poses are layers and not states, there is exactly one figure builder
* and one place a limb angle comes from, which is the property to keep
* when a new pose arrives.
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

// The vertical layout rule, and it is not cosmetic: the *visible* figure
// has to reach the bottom of the 45 px box exactly, because since T7.5.1
// the bottom of that box is the ground the character stands on. Getting
// it wrong is precisely what "the character floats" and "the character
// sinks" look like.
//
// RL.3 changed the arithmetic and, rather than restate a number that
// would go stale the moment the stroke is tuned, made it derive. A
// silhouette plus its rim reached 1.7 + 2.4 px past the feet joint,
// which is why the joint used to sit at 0.409; a stroke
// reaches only half its own width, so the joint has to sit lower. The leg
// is stretched to put it there (PLAYER_LEG_STRETCH), and the run cycle's
// stride is stretched with it so the feet keep covering exactly as much
// ground as the world does.
//
// The feet are the only part that touches anything. Hanging from the
// ceiling is half a turn plus a mirror, which is a vertical flip, so the
// feet are at the top of the box there and the sprout points down into
// open air. That is why the sprout may overhang the box and the feet
// may not.

PLAYER_HEAD_CENTER :: rl.Vector2{0.055, -0.190}
PLAYER_HEAD_RADIUS :: 0.170

// The bulb tapers onto the shoulders instead of sitting on a neck: a
// second, smaller circle low in the head, which merges with the first
// into one egg. Two circles are the cheapest shape that stops the head
// reading as a ball balanced on a stick.
PLAYER_HEAD_LOBE_CENTER :: rl.Vector2{0.035, -0.075}
PLAYER_HEAD_LOBE_RADIUS :: 0.110

PLAYER_NECK :: rl.Vector2{0.030, -0.060}
PLAYER_SHOULDER :: rl.Vector2{0.020, -0.020}
PLAYER_HIP_Y :: 0.134
PLAYER_HIP :: rl.Vector2{-0.015, PLAYER_HIP_Y}

// The leg as authored, before it is stretched to put the feet on the
// ground. The proportions are these two numbers; where they end up is
// PLAYER_LEG_STRETCH's business.
PLAYER_THIGH_BASE :: 0.145
PLAYER_SHIN_BASE :: 0.130
PLAYER_UPPER_ARM_LENGTH :: 0.105
PLAYER_FOREARM_LENGTH :: 0.095

// --- The sprout on the crown ---
//
// Two bones and two leaves, and it is the one part of the character that
// is not doing anything: it only answers to what the rest of the body
// already did. That is the point of it — a lag is movement for free, and
// free movement is what reads as alive.

PLAYER_SPROUT_BASE :: rl.Vector2{0.075, -0.335} // on the crown, a little forward
PLAYER_SPROUT_STEM :: 0.075
PLAYER_SPROUT_TIP :: 0.045

// Radians forward of straight up, at rest. The stem leans a little and
// the tip leans more, which is the curve the sheet draws.
PLAYER_SPROUT_CURVE_STEM :: 0.16
PLAYER_SPROUT_CURVE_TIP :: 0.42

PLAYER_LEAF_LENGTH :: 0.090
PLAYER_LEAF_SPREAD :: 1.15 // radians either side of the tip, from the joint

// How far back the sprout is looking, in seconds. Everything that moves
// the head is a pure function of the world's clock, so "where was it a
// moment ago" is one more evaluation rather than a piece of state — which
// matters, because state kept in the renderer would have to survive the
// frame and be reproduced by a replay to mean anything.
//
// Deliberately shorter than the gap between the end of the whip and the
// end of the journey (0.14 s): the trail has decayed to nothing before
// the character lands, so a landing has nothing to snap back from.
PLAYER_SPROUT_LAG :: 0.07

PLAYER_SPROUT_TURN_TRAIL :: 0.20 // lean per radian the body turned
PLAYER_SPROUT_RISE_TRAIL :: 2.6 // lean per box fraction the head rose
PLAYER_SPROUT_MAX_LEAN :: 0.75 // radians; a whip is fast enough to need this
PLAYER_SPROUT_TIP_FOLLOW :: 1.6 // the tip lags more than the stem does

// --- The run cycle ---

// Pixels of world scroll per full two-step stride. Tying the cycle to
// distance rather than to time means the legs speed up with the world on
// their own, through every tier change, with nothing to keep in sync.
//
// Shortened with the Sprout's proportions (T7.5.4). A foot reaches
// 2*sin(LEG_SWING)*leg px either side of the hip, and the legs lost a
// third of their length in T7.5.3, so at the old cadence the feet covered
// a third less ground per step while the world went by just as fast —
// which is the character skating. This keeps the ratio between what the
// feet cover and what the ground does where it was: small legs, quick
// steps.
// Stretched with the leg, so the ratio survives whatever the stroke's
// weight turns out to be.
PLAYER_STRIDE_LENGTH :: 50 * PLAYER_LEG_STRETCH

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

// --- The whip: the turn's own pose ---
//
// A flip already turned and stretched; what it had no shape for was the
// turn itself. The sheet's jump pose is streamlined — arms swept back,
// legs trailing, knees nearly straight — and it belongs to the impulse,
// so it is weighted by sin(whip * PI) and is gone by the time the
// journey ends.

PLAYER_WHIP_ARM :: -0.95 // radians behind the body
PLAYER_WHIP_ARM_SPLIT :: 0.30 // one arm leads the other
PLAYER_WHIP_ELBOW :: 0.25 // nearly straight
PLAYER_WHIP_THIGH :: -0.70 // legs trailing
PLAYER_WHIP_THIGH_SPLIT :: 0.28
PLAYER_WHIP_KNEE :: 0.20

// --- Squash & stretch ---

STRETCH_AMOUNT :: 0.16 // vertical stretch at the peak of a flip
SETTLE_DURATION :: 0.22 // length of the post-landing squash bounce
SETTLE_SQUASH_AMOUNT :: 0.28

// --- The mark ---
//
// Weights as multiples of the world's own stroke, because the hierarchy
// is the rule and the absolute number is not: the character is the
// thickest line on screen and the world is the second thickest, and
// saying so in the arithmetic means tuning one cannot silently invert the
// other (Design Doc, section 10).

PLAYER_STROKE_WEIGHT :: 1.55 // limbs: the character's own weight
PLAYER_TORSO_WEIGHT :: 1.90 // the spine, a shade heavier again
PLAYER_HEAD_WEIGHT :: 1.85 // the bulb's outline
PLAYER_SPROUT_WEIGHT :: 1.15 // the stem, which is the lightest thing on the body
PLAYER_LEAF_WEIGHT :: 1.35
PLAYER_SPROUT_TAPER :: 0.72 // the stem thins toward the tip

// The whitest core on screen, against the world's 0.30. It is the second
// half of the hierarchy: heavier *and* brighter, or a thick line in the
// same value as the ground is just a thick line.
PLAYER_CORE_LIGHT :: 0.62

// Kept well under the terrain's, and reaching less far, because the
// figure is nine overlapping strokes whose halos add — and because the
// bulb is fifteen pixels across, so a halo that reaches eight of them
// floods the one part of the character that has to stay hollow.
//
// This is the character's whole light now. RL.3 deleted the aura that
// used to be drawn under it: a 60 px disc of the world's light centred on
// the hip, which worked only for as long as an opaque body sat on top of
// it and covered the middle. With the body gone it lit the inside of the
// figure, which is the doubled-halo case CLAUDE.md answers the same way
// every time — remove the primitive one.
PLAYER_STROKE_GLOW :: 0.22
PLAYER_STROKE_SPREAD :: 2.6

// Extra halo at the peak of a flip. It rides the same sin(whip * PI) the
// stretch does, so the character flares as it turns and is back to itself
// by the time it lands — and it flares on its *own* line now rather than
// inside a disc around it.
PLAYER_FLIP_GLOW_BOOST :: 0.22

// How many segments each of the bulb's two arcs is tessellated into.
PLAYER_HEAD_ARC_STEPS :: 14

// Where the feet joint has to sit for the drawn figure to end exactly on
// the bottom of its box: half the character's own stroke inside it.
PLAYER_FOOT_REACH ::
	0.5 - (TERRAIN_STROKE_THICKNESS * PLAYER_STROKE_WEIGHT * 0.5) / f32(game.PLAYER_SIZE)

// What the leg has to be multiplied by to reach it, thigh and shin
// keeping their proportion to each other.
PLAYER_LEG_STRETCH ::
	(PLAYER_FOOT_REACH - PLAYER_HIP_Y) / (PLAYER_THIGH_BASE + PLAYER_SHIN_BASE)

PLAYER_THIGH_LENGTH :: PLAYER_THIGH_BASE * PLAYER_LEG_STRETCH
PLAYER_SHIN_LENGTH :: PLAYER_SHIN_BASE * PLAYER_LEG_STRETCH

// --- Light ---

// One eye, not two (art direction, T7.5.3). More readable at 45 px, and
// it has no axis of symmetry to keep honest when the figure mirrors
// halfway through a turn. It is the character's own light: the body is
// the same dark shape in both worlds, and this is the only part of it
// allowed to be bright.
PLAYER_EYE_RADIUS :: 0.052
PLAYER_EYE_OFFSET :: rl.Vector2{0.085, -0.030} // from the head centre: forward, a little up
PLAYER_EYE_GLOW :: 0.55

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

	// The sprout: the crown it grows from, the joint where the two
	// leaves sit, and the tip.
	sprout_base:  rl.Vector2,
	sprout_joint: rl.Vector2,
	sprout_tip:   rl.Vector2,
	leaves:       [2]rl.Vector2,
}

// Which lane the shape should currently be anchored to, for scaling
// purposes: mid-flip we anchor to where we're headed, not where we came
// from.
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
	whip := game.get_whip_progress(player)
	if whip < 1 {
		// Bell curve peaking mid-turn, back to 1 at both ends. On the
		// whip's clock, not the journey's: the stretch belongs to the
		// impulse, not to the travelling.
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

	if player.state == .Transitioning {
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
// the Dream's drift. world_t crossfades between them, so there is no
// moment where the character switches animation — it stops running and
// starts floating the same way the palette stops being blue and starts
// being violet.
// How far the whole body sits from its rest position, in local units.
//
// Its own procedure because the sprout needs it twice — now, and a moment
// ago — to know how fast the head has been moving. Everything in it is a
// pure function of the clock and the distance run, so asking about the
// past costs an evaluation rather than a piece of remembered state.
player_body_offset :: proc(stride, time, world_t: f32) -> rl.Vector2 {
	dream := clamp(world_t, 0, 1)
	grounded := 1 - dream

	// The body rises twice per stride while running, and breathes slowly
	// while floating.
	bounce := -PLAYER_BOUNCE * abs(math.sin(stride)) * grounded
	float := PLAYER_FLOAT_AMOUNT * math.sin(time / PLAYER_FLOAT_PERIOD * 2 * math.PI) * dream
	return rl.Vector2{0, bounce + float}
}

// The far end of a sprout bone, measured from straight *up* and turning
// toward the front — the direction a sprout grows, rather than the
// direction a limb hangs. Same helper underneath, half a turn away.

@(private)
sprout_end :: proc(from: rl.Vector2, angle, length: f32) -> rl.Vector2 {
	return limb_end(from, math.PI - angle, length)
}

new_player_figure :: proc(stride, time, world_t, whip, sprout_lean: f32) -> PlayerFigure {
	dream := clamp(world_t, 0, 1)
	grounded := 1 - dream
	turn := clamp(whip, 0, 1)

	body_offset := player_body_offset(stride, time, world_t)

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

		side_sign: f32 = side == 0 ? 1 : -1

		// The whip's pose, over the top of whatever the run was doing.
		// Weighted by sin(whip * PI), so it is nothing at the start and the
		// end of the turn: it grows out of the run cycle and settles back
		// into it instead of replacing it.
		whip_arm := PLAYER_WHIP_ARM + PLAYER_WHIP_ARM_SPLIT * side_sign
		whip_thigh := PLAYER_WHIP_THIGH + PLAYER_WHIP_THIGH_SPLIT * side_sign

		thigh += (whip_thigh - thigh) * turn
		knee_bend += (PLAYER_WHIP_KNEE - knee_bend) * turn
		arm += (whip_arm - arm) * turn
		elbow += (whip_arm + PLAYER_WHIP_ELBOW - elbow) * turn

		figure.knees[side] = limb_end(figure.hip, thigh, PLAYER_THIGH_LENGTH)
		figure.feet[side] = limb_end(figure.knees[side], thigh - knee_bend, PLAYER_SHIN_LENGTH)
		figure.elbows[side] = limb_end(figure.shoulder, arm, PLAYER_UPPER_ARM_LENGTH)
		figure.hands[side] = limb_end(figure.elbows[side], elbow, PLAYER_FOREARM_LENGTH)
	}

	// The sprout. Two bones and two leaves, leaning by however much the
	// head has been moving — the lean arrives measured, from the one place
	// that can see both the turn and the bounce (draw_player).
	//
	// The tip leans further than the stem does, and that single number is
	// what makes two bones read as one whip instead of as a bent stick.
	stem := PLAYER_SPROUT_CURVE_STEM + sprout_lean
	tip := PLAYER_SPROUT_CURVE_TIP + sprout_lean * PLAYER_SPROUT_TIP_FOLLOW

	figure.sprout_base = PLAYER_SPROUT_BASE + body_offset
	figure.sprout_joint = sprout_end(figure.sprout_base, stem, PLAYER_SPROUT_STEM)
	figure.sprout_tip = sprout_end(figure.sprout_joint, tip, PLAYER_SPROUT_TIP)

	for side in 0 ..< 2 {
		spread: f32 = side == 0 ? PLAYER_LEAF_SPREAD : -PLAYER_LEAF_SPREAD
		figure.leaves[side] = sprout_end(figure.sprout_joint, tip + spread, PLAYER_LEAF_LENGTH)
	}

	return figure
}

// One of the character's strokes.
//
// The colour is the *neutral* palette's, never the current world's: the
// character is the same mark wherever it stands, and only what is behind
// it and gathered around it changes (Design Doc, section 10). It still
// converges with depth, because every palette in the set does.

@(private)
player_stroke :: proc(palette: core.Palette, weight, flare: f32) -> Stroke {
	line := new_stroke(palette.light, TERRAIN_STROKE_THICKNESS * weight)
	line.glow = PLAYER_STROKE_GLOW + PLAYER_FLIP_GLOW_BOOST * flare
	line.spread = PLAYER_STROKE_SPREAD
	line.core_light = PLAYER_CORE_LIGHT
	return line
}

// A polyline of local joints, through the pose and onto the screen.

@(private)
draw_player_bone :: proc(
	pose: PlayerPose,
	locals: []rl.Vector2,
	stroke: Stroke,
	scratch: ^[dynamic]rl.Vector2,
) {
	clear(scratch)
	for local in locals {
		append(scratch, pose_point(pose, local))
	}
	draw_stroke(scratch[:], stroke)
}

// One circle's arc between two points on it, taking whichever of the two
// arcs lies *outside* the other circle.
//
// Which one that is is decided by probing the midpoint rather than by
// deriving it, because the derivation turns on which of the two
// intersection points came out of the radical construction first — a sign
// that is easy to get backwards and silent when you do, since both
// answers are a closed loop. Probing asks the question the shape actually
// poses. It runs in the figure's own frame, before the pose, so the
// mirror cannot reach it.
//
// The arc is emitted from `from` up to but not including `to`, so two of
// these chain into a closed loop with no doubled vertex at the join.

@(private)
append_head_arc :: proc(
	out: ^[dynamic]rl.Vector2,
	pose: PlayerPose,
	centre: rl.Vector2,
	radius: f32,
	from, to: rl.Vector2,
	other_centre: rl.Vector2,
	other_radius: f32,
) {
	on_circle :: proc(centre: rl.Vector2, radius, angle: f32) -> rl.Vector2 {
		return centre + rl.Vector2{math.cos(angle) * radius, math.sin(angle) * radius}
	}

	start := math.atan2(from.y - centre.y, from.x - centre.x)
	end := math.atan2(to.y - centre.y, to.x - centre.x)
	sweep := end - start
	for sweep <= 0 {
		sweep += 2 * math.PI
	}

	probe := on_circle(centre, radius, start + sweep * 0.5)
	away := probe - other_centre
	if math.sqrt(away.x * away.x + away.y * away.y) < other_radius {
		// The wrong half: the same two points, the other way round.
		sweep -= 2 * math.PI
	}

	for i in 0 ..< PLAYER_HEAD_ARC_STEPS {
		angle := start + sweep * f32(i) / f32(PLAYER_HEAD_ARC_STEPS)
		append(out, pose_point(pose, on_circle(centre, radius, angle)))
	}
}

// The bulb, as one closed line: the outline of the union of the head
// circle and the lobe that tapers it onto the shoulders.
//
// Two overlapping circle outlines would show the arcs crossing inside the
// head, and the inside of the head is the one place a line drawing cannot
// afford a stray mark — it is four pixels across at this size.

@(private)
build_head_outline :: proc(pose: PlayerPose, figure: PlayerFigure, out: ^[dynamic]rl.Vector2) {
	clear(out)

	head := figure.head
	lobe := PLAYER_HEAD_LOBE_CENTER + (figure.head - PLAYER_HEAD_CENTER)
	r1 := f32(PLAYER_HEAD_RADIUS)
	r2 := f32(PLAYER_HEAD_LOBE_RADIUS)

	delta := lobe - head
	d := math.sqrt(delta.x * delta.x + delta.y * delta.y)

	// The two circles move together, so this cannot happen with the
	// authored numbers — but the arithmetic below divides by d, and a
	// plain ring is the right answer if anyone ever changes them.
	if d < 1e-6 || d >= r1 + r2 || d <= abs(r1 - r2) {
		steps := PLAYER_HEAD_ARC_STEPS * 2
		for i in 0 ..< steps {
			angle := f32(i) / f32(steps) * 2 * math.PI
			append(
				out,
				pose_point(pose, head + rl.Vector2{math.cos(angle) * r1, math.sin(angle) * r1}),
			)
		}
		return
	}

	// Where the two circles cross: the standard radical-line construction.
	a := (d * d + r1 * r1 - r2 * r2) / (2 * d)
	h := math.sqrt(max(r1 * r1 - a * a, 0))
	direction := delta / d
	normal := rl.Vector2{-direction.y, direction.x}
	base := head + direction * a

	first := base + normal * h
	second := base - normal * h

	append_head_arc(out, pose, head, r1, first, second, lobe, r2)
	append_head_arc(out, pose, lobe, r2, second, first, head, r1)
}

// The whole figure, as strokes. Nine marks and an eye, and not one of
// them is filled.
//
// Each limb is its own stroke rather than one polyline through the hip:
// two legs welded into a single mark would lay the ribbon over itself
// wherever they are nearly parallel — which the whip pose makes them —
// and additive geometry that overlaps itself adds twice
// (render/stroke.odin). Overlapping only at the joints is a bead where a
// joint is, which is what a joint looks like.

@(private)
draw_player_marks :: proc(
	pose: PlayerPose,
	figure: PlayerFigure,
	palette: core.Palette,
	flare: f32,
) {
	scratch := make([dynamic]rl.Vector2, 0, 64, context.temp_allocator)

	limb := player_stroke(palette, PLAYER_STROKE_WEIGHT, flare)
	torso := player_stroke(palette, PLAYER_TORSO_WEIGHT, flare)

	// The spine first and underneath: it is the heaviest mark, and the
	// limbs read as growing out of it rather than as crossing it.
	spine := [3]rl.Vector2{figure.hip, figure.shoulder, figure.neck}
	draw_player_bone(pose, spine[:], torso, &scratch)

	for side in 0 ..< 2 {
		leg := [3]rl.Vector2{figure.feet[side], figure.knees[side], figure.hip}
		arm := [3]rl.Vector2{figure.hands[side], figure.elbows[side], figure.shoulder}
		draw_player_bone(pose, leg[:], limb, &scratch)
		draw_player_bone(pose, arm[:], limb, &scratch)
	}

	// The sprout is one tapering mark from the crown to the tip, which is
	// what the taper was built for; the leaves are two short heavier ones
	// off the joint. It is part of the figure, not a decoration laid over
	// it, so it is the same colour at a lighter weight.
	stem := player_stroke(palette, PLAYER_SPROUT_WEIGHT, flare)
	stem.taper = PLAYER_SPROUT_TAPER
	sprout := [3]rl.Vector2{figure.sprout_base, figure.sprout_joint, figure.sprout_tip}
	draw_player_bone(pose, sprout[:], stem, &scratch)

	leaf := player_stroke(palette, PLAYER_LEAF_WEIGHT, flare)
	for leaf_end in figure.leaves {
		blade := [2]rl.Vector2{figure.sprout_joint, leaf_end}
		draw_player_bone(pose, blade[:], leaf, &scratch)
	}

	// The bulb last, so its core is the crispest thing on the character.
	outline := make([dynamic]rl.Vector2, 0, PLAYER_HEAD_ARC_STEPS * 2, context.temp_allocator)
	build_head_outline(pose, figure, &outline)
	bulb := player_stroke(palette, PLAYER_HEAD_WEIGHT, flare)
	bulb.closed = true
	draw_stroke(outline[:], bulb)
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

	// A forward lean on top of the flip's rotation: posture, not motion.
	// Mirrored with the figure, so it leans into the run in both worlds.
	mirror := get_player_mirror(player)
	pose.rotation += PLAYER_LEAN * mirror

	stride := world.scroll_offset / PLAYER_STRIDE_LENGTH * 2 * math.PI

	// What the sprout is answering to, and it answers late. Two things
	// move the head — the whip of a flip and the bounce of the run — so
	// the lean is how much of each happened over the last PLAYER_SPROUT_LAG
	// seconds. That is what inertia is: a response to velocity, not to
	// position, and a velocity is a difference between two evaluations of
	// something the clock already decides.
	earlier := player
	earlier.transition_timer = max(player.transition_timer - PLAYER_SPROUT_LAG, 0)
	turn := get_player_rotation(player) - get_player_rotation(earlier)

	stride_earlier :=
		(world.scroll_offset - world.scroll_speed * PLAYER_SPROUT_LAG) /
		PLAYER_STRIDE_LENGTH *
		2 *
		math.PI
	rise :=
		player_body_offset(stride, world.elapsed_time, palettes.world_t).y -
		player_body_offset(stride_earlier, world.elapsed_time - PLAYER_SPROUT_LAG, palettes.world_t).y

	// The turn is measured on screen, where the mirror does not apply; the
	// lean is authored in the figure's own frame, where it does — so the
	// mirror has to be undone on the way in or the sprout trails the wrong
	// way round in one of the two worlds.
	lean := -turn * PLAYER_SPROUT_TURN_TRAIL * mirror + rise * PLAYER_SPROUT_RISE_TRAIL
	lean = clamp(lean, -PLAYER_SPROUT_MAX_LEAN, PLAYER_SPROUT_MAX_LEAN)

	// Zero at both ends of the turn and one in the middle: the same shape
	// the stretch and the glow boost ride, so all three peak together.
	whip := math.sin(game.get_whip_progress(player) * math.PI)

	figure := new_player_figure(
		stride = stride,
		time = world.elapsed_time,
		world_t = palettes.world_t,
		whip = whip,
		sprout_lean = lean,
	)

	// One pass, and the mark does not change world: the neutral palette's
	// light is the character wherever it stands (Design Doc, section 10).
	// What changes between the two worlds is the field behind it and how
	// much it burns — never its profile and never its colour.
	draw_player_marks(pose, figure, palettes.neutral, whip)

	draw_player_eye(pose, figure, palettes.current.accent)
}

// The one point of light on the head, set toward the front.
//
// It is the whole of the character's own light, and it is drawn with the
// neon stroke's dot (T7.5.2): a halo in the world's accent with a core
// lifted toward white, which is what "dark body, emitting head" means in
// primitives. Authored in local space, so it follows the mirror and the
// rotation with no special case — and being single, it has no symmetry
// to break when the figure turns over.

@(private)
draw_player_eye :: proc(
	pose: PlayerPose,
	figure: PlayerFigure,
	color: rl.Color,
) {
	// The eye rides the head rather than the box: the head moves with the
	// bounce and the float, and an eye that did not would swim inside it.
	local := figure.head + PLAYER_EYE_OFFSET
	centre := pose_point(pose, local)
	eye := new_stroke(color, PLAYER_EYE_RADIUS * 2 * pose.unit)
	eye.glow = PLAYER_EYE_GLOW
	draw_stroke_dot(centre, eye)
}
