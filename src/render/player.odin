/*
* Player Render
* The character: a small robed figure under a pointed hat, drawn as **one
* closed stroke** — the same mark the world is made of, at the weight
* nothing else on screen is allowed to reach (Design Doc, section 10).
* No sprite, no texture; the sense of quality is meant to come from the
* math of the movement, not from the detail of the shapes.
*
* WHY IT IS A ROBE, AND WHY IT IS ONE MARK
*
* It was a stick figure until this pass: a bulb head, four limbs and a
* sprout, nine strokes over a 45 px box. On screen that is not a figure,
* it is a knot — nine marks in forty-five pixels have nowhere to be, and
* the playtest screenshot showed exactly that. A robe solves it by
* deleting the problem rather than tuning it: with the legs and arms
* inside the cloth there is **one contour**, and a contour is a
* silhouette, which is the thing that reads at this size.
*
* Three features are all a 45 px figure can carry, so it has three: a
* pointed hat, a pinch under it, and a bell that widens to the hem. Read
* at a glance that is somebody in a robe, and it is nothing like
* Cavandoli's man — which matters, because his character is protected and
* "one that reminds you of him, made of our own stroke" is the line.
*
* AND IT CURVES, BECAUSE THE DANGER CORNERS
*
* Every segment of the contour is a bowed curve, never a straight run and
* never a right angle. That is not decoration: **the world curves, the
* danger corners** is the rule the whole picture is kept readable by, so
* a figure built out of straight edges would be wearing the one shape
* that means "this costs you". It is also why the robe is a bell and not
* a triangle.
*
* Three things are happening at once here, and they are deliberately
* kept separate:
*
*   the profile   a fixed set of anchors in a local unit box, authored
*                 once below and never touched by animation
*   the pose      how that box lands on screen: rotation, squash &
*                 stretch, and the mirror that keeps the character facing
*                 forward while upside down
*   the animation where those anchors are for this instant: the run's
*                 step under the hem, and the drift that replaces it as
*                 the Dream takes over
*
* The mark does not change world. It is drawn out of the *neutral*
* palette, and what changes between the Real and the Dream is what is
* behind it and how much it burns (Design Doc, section 10: "il personaggio
* è lo stesso segno in entrambi i mondi"). The old code inverted body and
* rim between worlds, which read as two different characters; a mark that
* changes colour is a milder version of the same mistake.
*
* The poses are layers over one figure rather than two animations:
*
*   the run      the base, crossfaded with the Dream's drift by world_t.
*                With no legs to swing it is the hem that steps — one
*                corner lifts at a time and the cloth's lowest point
*                slides with it, which is what walking looks like under a
*                robe
*   the whip     the turn's own shape: the robe tucks in and lifts. It
*                rides sin(whip * PI), so it is nothing at both ends of
*                the turn and everything at the middle, which lets it
*                grow out of the run and settle back into it with no seam
*
* Accessibility (pillar 6): the two worlds are never told apart by colour
* alone. The character steps on a hard, regular cycle in the Real world
* and drifts on a slow float in the Dream one, and the two blend
* continuously through world_t, so the type of motion says which world is
* live even with the colour removed entirely.
*/
package render

import "../core"
import "../game"
import "core:math"
import rl "vendor:raylib/v55"

// --- The profile, in fractions of the player's box ---
//
// Origin at the box centre, +x forward (the direction of travel), +y
// down. Everything is authored here once; a pose is only ever a
// transform of these numbers.
//
//                      tip            the hat's point, which leans
//                      /\
//                    /    \
//                  /        \
//        brim ----+          +----    the widest the figure gets on top
//                  \        /
//        waist ------+    +------     the pinch that says "somebody"
//                   /      \
//                 /          \
//     hem -------+            +----   the cloth on the ground
//                 \____ ____/
//                      deep           the one point that touches
//
// The vertical rule, and it is not cosmetic: the *lowest* point of the
// hem has to sit exactly on the bottom of the box, because since T7.5.1
// that bottom is the ground the character stands on. It reaches half a
// stroke past its own anchor, so the anchor sits half a stroke inside —
// derived rather than written down, because the stroke's weight is a
// knob and a number kept in step by hand goes stale the first time
// somebody turns it.
//
// The robe collapsed a chain that used to hang off this. When the figure
// had legs, the feet had to touch the ground *and* cover as much of it
// as the world scrolled, or the character skated — so the leg length and
// the stride were both derived from the stroke's weight. With the legs
// inside the cloth there are no feet to skate, and only the first half of
// the rule survives.

PLAYER_HEM_DEEP_Y ::
	0.5 - (TERRAIN_STROKE_THICKNESS * PLAYER_STROKE_WEIGHT * 0.5) / f32(game.PLAYER_SIZE)

// The hem's two corners sit above its lowest point, so the cloth's arc
// bottoms out in the middle and the contact point is the same one every
// frame whatever the corners are doing.
PLAYER_HEM_RISE :: 0.030
PLAYER_HEM_FRONT_X :: 0.215
PLAYER_HEM_BACK_X :: -0.245

// The pinch. Not a neck — there is no room for one at this size — but a
// local minimum in the figure's width, which is what makes the eye read
// a head above a body instead of a single lump.
// The shoulders, a short step in under the brim.
//
// It is deliberately *not* a neck. A 45 px figure drawn with a 4.3 px pen
// cannot hold internal detail — a notch narrower than the pen is a notch
// the pen fills in — so nothing here tries to draw one. What separates
// the head from the body is the outline changing direction three times,
// not a gap the eye has to find. The whole read is **a cone on a bell**,
// and it lives in the difference between the hat's width and the hem's.
PLAYER_WAIST_Y :: -0.075
PLAYER_WAIST_FRONT_X :: 0.124
PLAYER_WAIST_BACK_X :: -0.131

// The hat's brim: the widest the figure gets above the waist.
// The hat's brim. Clearly **narrower than the hem**, which is the single
// number that decides whether this reads as somebody in a robe or as an
// abstract diamond: a hat as wide as the robe's base makes an hourglass,
// and the first version of this figure was one.
PLAYER_BRIM_Y :: -0.175
PLAYER_BRIM_FRONT_X :: 0.178
PLAYER_BRIM_BACK_X :: -0.182

// The cone, measured from the middle of the brim.
PLAYER_HAT_HEIGHT :: 0.340
PLAYER_BRIM_CENTER_X :: (PLAYER_BRIM_FRONT_X + PLAYER_BRIM_BACK_X) * 0.5

// Radians forward of straight up, at rest: the hat is worn at an angle,
// which is most of what stops the figure reading as symmetrical.
PLAYER_HAT_CURVE :: 0.19

// How far each segment of the contour bows sideways, in local units.
// Positive is away from the figure's centre line. The robe bells, the
// pinch is smooth, and the hat is very slightly concave — a witch's-hat
// curve rather than a triangle's straight edge.
PLAYER_BOW_HAT :: -0.048
PLAYER_BOW_PINCH :: -0.008
PLAYER_BOW_ROBE :: 0.048

// How deep the hem's arc hangs between its corners, as a control offset.
PLAYER_BOW_HEM :: 0.9

// How many points each bowed segment is tessellated into. Seven segments
// at this makes a 37-point contour, which is one mark and nowhere near
// STROKE_MAX_POINTS.
PLAYER_CURVE_STEPS :: 5

// Where the eye rides, inside the figure just under the brim.
PLAYER_HEAD_CENTER :: rl.Vector2{0.015, -0.170}

// --- The step under the hem ---
//
// Pixels of world scroll per full two-step cycle. Tying it to distance
// rather than to time means the cadence speeds up with the world on its
// own, through every tier change, with nothing to keep in sync.
//
// A plain number again since the robe arrived. It used to be derived from
// the leg's length, because feet that cover less ground than the world
// does are feet that skate; cloth does not skate, so the only thing this
// has to be is a cadence that looks like walking.
PLAYER_STRIDE_LENGTH :: 58

PLAYER_HEM_STEP :: 0.055 // how far a hem corner lifts on its own beat
PLAYER_HEM_SLIDE :: 0.075 // how far the cloth's lowest point slides with it
PLAYER_LEAN :: 0.12 // radians of forward lean, a walker's posture
PLAYER_BOUNCE :: 0.045 // vertical bob per step, in box fractions

// How much of the body's bob the hem's corners take. Not all of it: the
// body bobs *inside* the cloth, so the hem follows late and its lowest
// point does not follow at all — which is what keeps the contact exact
// while the figure is moving.
PLAYER_HEM_FOLLOW :: 0.30

// --- The Dream drift, which replaces the step as world_t rises ---

PLAYER_FLOAT_PERIOD :: 2.6 // seconds per full rise and fall
PLAYER_FLOAT_AMOUNT :: 0.055 // box fractions
PLAYER_WOBBLE_PERIOD :: 1.7
PLAYER_WOBBLE_AMOUNT :: 0.030 // how far the hem undulates, out of phase

// --- The whip: the turn's own pose ---
//
// A flip already turned and stretched; what it had no shape for was the
// turn itself. The robe tucks — the hem pulls in toward the waist and
// lifts — and it belongs to the impulse, so it is weighted by
// sin(whip * PI) and is gone by the time the journey ends.

PLAYER_WHIP_TUCK :: 0.45 // how far the hem's corners pull toward the waist
PLAYER_WHIP_LIFT :: 0.075 // how far the whole hem rises

// --- The hat's inertia ---
//
// The one part of the character that is not doing anything: it only
// answers to what the rest of the body already did. That is the point of
// it — a lag is movement for free, and free movement is what reads as
// alive. It was the sprout's before the robe arrived; the machinery is
// untouched, only the thing on the end of it changed.

// How far back it is looking, in seconds. Everything that moves the body
// is a pure function of the world's clock, so "where was it a moment ago"
// is one more evaluation rather than a piece of state — which matters,
// because state kept in the renderer would have to survive the frame and
// be reproduced by a replay to mean anything.
//
// Deliberately shorter than the gap between the end of the whip and the
// end of the journey (0.14 s): the trail has decayed to nothing before
// the character lands, so a landing has nothing to snap back from.
PLAYER_HAT_LAG :: 0.07

PLAYER_HAT_TURN_TRAIL :: 0.20 // lean per radian the body turned
PLAYER_HAT_RISE_TRAIL :: 2.6 // lean per box fraction the body rose
PLAYER_HAT_MAX_LEAN :: 0.75 // radians; a whip is fast enough to need this

// --- Squash & stretch ---

STRETCH_AMOUNT :: 0.16 // vertical stretch at the peak of a flip
SETTLE_DURATION :: 0.22 // length of the post-landing squash bounce
SETTLE_SQUASH_AMOUNT :: 0.28

// --- The mark ---
//
// A weight as a multiple of the world's own stroke, because the hierarchy
// is the rule and the absolute number is not: the character is the
// thickest line on screen and the world is the second thickest, and
// saying so in the arithmetic means tuning one cannot silently invert the
// other (Design Doc, section 10).
//
// One weight, because there is one mark. The stick figure needed five.
PLAYER_STROKE_WEIGHT :: 1.55

// The whitest core on screen, against the world's 0.30. It is the second
// half of the hierarchy: heavier *and* brighter, or a thick line in the
// same value as the ground is just a thick line.
PLAYER_CORE_LIGHT :: 0.62

// Kept well under the terrain's, and reaching less far. The contour comes
// close to itself at the waist, and a halo that reached across the pinch
// would fill in the one gap that says "head" and "body" are two things.
PLAYER_STROKE_GLOW :: 0.22
PLAYER_STROKE_SPREAD :: 2.3

// Extra halo at the peak of a flip. It rides the same sin(whip * PI) the
// stretch does, so the character flares as it turns and is back to itself
// by the time it lands — on its own line, not inside a disc around it.
PLAYER_FLIP_GLOW_BOOST :: 0.22

// --- Light ---

// One eye, not two (art direction, T7.5.3). More readable at 45 px, and
// it has no axis of symmetry to keep honest when the figure mirrors
// halfway through a turn. It is the character's own light, and the one
// part of it allowed to take the world's colour.
PLAYER_EYE_RADIUS :: 0.034
PLAYER_EYE_OFFSET :: rl.Vector2{0.030, 0.010} // from the head centre
PLAYER_EYE_GLOW :: 0.55

// How the figure's local box lands on screen.
PlayerPose :: struct {
	origin:   rl.Vector2, // where local (0,0) sits
	rotation: f32, // radians, clockwise on screen
	scale:    rl.Vector2, // squash & stretch; scale.x is negative when mirrored
	unit:     f32, // pixels per local unit
}

// The anchors the contour runs through, in local coordinates, for this
// instant. Index 0 is the front of the figure and 1 is the back.
PlayerFigure :: struct {
	tip:      rl.Vector2,
	brim:     [2]rl.Vector2,
	waist:    [2]rl.Vector2,
	hem:      [2]rl.Vector2,
	hem_deep: rl.Vector2,
	head:     rl.Vector2, // not on the contour: where the eye rides
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

// How far a rotation overshoots before it settles: Robert Penner's
// easeOutBack, with his constant.
//
// It lives here rather than in a shared easing file because it is not a
// generic curve, it is **the shape of this game's flip** — the most tuned
// number in the project, and one a playtest has already had an opinion
// about (the first version lingered mid-journey and was thrown out,
// because a flourish placed on the player's own motion is friction and
// not decoration).
//
// RL.7 moved the rest of core/ease.odin to core:math/ease and kept this
// one, because the two are not the same curve. The standard library's
// back_out is AHEasing's, and it is far wilder: measured over the flip's
// half turn, ours overshoots by **18 degrees** and peaks at t=0.57, while
// back_out overshoots by **68** and peaks at t=0.47 — an overshoot in the
// middle of the journey rather than an impulse at the end of it, which is
// precisely the version the playtest killed. Swapping to it is a game
// feel decision, not a tidy-up.
PLAYER_WHIP_OVERSHOOT :: 1.70158


@(private)
whip_ease :: proc(t: f32) -> f32 {
	u := t - 1
	return 1 + (PLAYER_WHIP_OVERSHOOT + 1) * u * u * u + PLAYER_WHIP_OVERSHOOT * u * u
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
	return from + math.PI * whip_ease(game.get_whip_progress(player))
}

// Half a turn leaves the character upside down *and* facing backwards,
// so hanging from the ceiling also mirrors the figure horizontally: the
// two together are exactly the vertical mirror the pose wants, with the
// rotation carrying the motion.
//
// A mirror cannot be interpolated — it is a change of handedness — so it
// snaps, and it snaps halfway through the *turn*, where the figure is
// side-on and turning at full speed. The turn takes 120 ms whatever the
// journey does, so that is one frame around frame 4. If it ever reads as
// a pop on screen, the fix is to squash the figure thin at the same
// instant, not to slow the rotation down.
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

// A point measured from straight *up* and turning toward the front — the
// direction a hat points, rather than the direction a limb hangs.

@(private)
up_from :: proc(from: rl.Vector2, angle, length: f32) -> rl.Vector2 {
	return rl.Vector2{from.x + math.sin(angle) * length, from.y - math.cos(angle) * length}
}

// How far the whole body sits from its rest position, in local units.
//
// Its own procedure because the hat needs it twice — now, and a moment
// ago — to know how fast the body has been moving. Everything in it is a
// pure function of the clock and the distance run, so asking about the
// past costs an evaluation rather than a piece of remembered state.
player_body_offset :: proc(stride, time, world_t: f32) -> rl.Vector2 {
	dream := clamp(world_t, 0, 1)
	grounded := 1 - dream

	// The body rises twice per stride while walking, and breathes slowly
	// while floating.
	bounce := -PLAYER_BOUNCE * abs(math.sin(stride)) * grounded
	float := PLAYER_FLOAT_AMOUNT * math.sin(time / PLAYER_FLOAT_PERIOD * 2 * math.PI) * dream
	return rl.Vector2{0, bounce + float}
}

// Builds the figure for this instant.
//
// stride comes from distance travelled and drives the step; time drives
// the Dream's drift. world_t crossfades between them, so there is no
// moment where the character switches animation — it stops walking and
// starts floating the same way the palette stops being blue and starts
// being violet.
new_player_figure :: proc(stride, time, world_t, whip, hat_lean: f32) -> PlayerFigure {
	dream := clamp(world_t, 0, 1)
	grounded := 1 - dream
	turn := clamp(whip, 0, 1)

	body := player_body_offset(stride, time, world_t)

	figure := PlayerFigure {
		head = PLAYER_HEAD_CENTER + body,
		brim =  {
			rl.Vector2{PLAYER_BRIM_FRONT_X, PLAYER_BRIM_Y} + body,
			rl.Vector2{PLAYER_BRIM_BACK_X, PLAYER_BRIM_Y} + body,
		},
		waist =  {
			rl.Vector2{PLAYER_WAIST_FRONT_X, PLAYER_WAIST_Y} + body,
			rl.Vector2{PLAYER_WAIST_BACK_X, PLAYER_WAIST_Y} + body,
		},
	}

	// The hat, hung off the middle of the brim so a lean swings it round
	// rather than sliding it sideways.
	brim_center := rl.Vector2{PLAYER_BRIM_CENTER_X, PLAYER_BRIM_Y} + body
	figure.tip = up_from(brim_center, PLAYER_HAT_CURVE + hat_lean, PLAYER_HAT_HEIGHT)

	// The step. One hem corner lifts at a time and the cloth's lowest
	// point slides with it, which is what walking looks like under a
	// robe; in the Dream the same two numbers undulate slowly instead.
	swing := math.sin(stride) * grounded
	wobble := math.sin(time / PLAYER_WOBBLE_PERIOD * 2 * math.PI) * dream

	front_lift := PLAYER_HEM_STEP * max(swing, 0) + PLAYER_WOBBLE_AMOUNT * max(wobble, 0)
	back_lift := PLAYER_HEM_STEP * max(-swing, 0) + PLAYER_WOBBLE_AMOUNT * max(-wobble, 0)

	hem_y := PLAYER_HEM_DEEP_Y - PLAYER_HEM_RISE + body.y * PLAYER_HEM_FOLLOW
	figure.hem = {
		rl.Vector2{PLAYER_HEM_FRONT_X, hem_y - front_lift},
		rl.Vector2{PLAYER_HEM_BACK_X, hem_y - back_lift},
	}
	figure.hem_deep = rl.Vector2 {
		PLAYER_HEM_SLIDE * (swing + wobble),
		PLAYER_HEM_DEEP_Y,
	}

	// The whip's pose, over the top of whatever the step was doing: the
	// robe pulls in and lifts. Weighted so it is nothing at both ends of
	// the turn and grows out of the walk rather than replacing it.
	for side in 0 ..< 2 {
		figure.hem[side].x += (figure.waist[side].x - figure.hem[side].x) * PLAYER_WHIP_TUCK * turn
		figure.hem[side].y -= PLAYER_WHIP_LIFT * turn
	}
	figure.hem_deep.y -= PLAYER_WHIP_LIFT * turn

	return figure
}

// --- Drawing ---

// One quadratic through a control point that bows the segment sideways.

@(private)
bezier_point :: proc(a, control, b: rl.Vector2, t: f32) -> rl.Vector2 {
	u := 1 - t
	return a * (u * u) + control * (2 * u * t) + b * (t * t)
}

// Appends a bowed segment from a to b, *excluding* b, so consecutive
// segments chain into one polyline with no doubled vertex at the join.
//
// bow is in local units and positive means away from the figure's centre
// line, which is why every caller multiplies it by the side's sign.

@(private)
append_curve :: proc(points: ^[dynamic]rl.Vector2, a, b: rl.Vector2, bow: f32) {
	control := rl.Vector2{(a.x + b.x) * 0.5 + bow, (a.y + b.y) * 0.5}
	for i in 0 ..< PLAYER_CURVE_STEPS {
		append(points, bezier_point(a, control, b, f32(i) / f32(PLAYER_CURVE_STEPS)))
	}
}

// The contour, in local coordinates: down the front from the hat's point
// to the hem, along the cloth, and back up the rear.
//
// One closed polyline, so the whole character is a single mark with
// mitred turns — no bead where two strokes would have met, and no place
// for the additive halo to add twice (render/stroke.odin).

@(private)
build_player_outline :: proc(figure: PlayerFigure, out: ^[dynamic]rl.Vector2) {
	clear(out)

	// Down the front.
	append_curve(out, figure.tip, figure.brim[0], PLAYER_BOW_HAT)
	append_curve(out, figure.brim[0], figure.waist[0], PLAYER_BOW_PINCH)
	append_curve(out, figure.waist[0], figure.hem[0], PLAYER_BOW_ROBE)

	// The cloth on the ground. Its control is placed so the arc's lowest
	// point lands exactly on hem_deep at the middle of the segment, which
	// is what makes the contact the same point every frame.
	hem_control := rl.Vector2 {
		2 * figure.hem_deep.x - 0.5 * (figure.hem[0].x + figure.hem[1].x),
		2 * figure.hem_deep.y - 0.5 * (figure.hem[0].y + figure.hem[1].y),
	}
	for i in 0 ..< PLAYER_CURVE_STEPS * 2 {
		append(
			out,
			bezier_point(
				figure.hem[0],
				hem_control,
				figure.hem[1],
				f32(i) / f32(PLAYER_CURVE_STEPS * 2),
			),
		)
	}

	// And back up the rear, where "away from the centre" is the other way.
	append_curve(out, figure.hem[1], figure.waist[1], -PLAYER_BOW_ROBE)
	append_curve(out, figure.waist[1], figure.brim[1], -PLAYER_BOW_PINCH)
	append_curve(out, figure.brim[1], figure.tip, -PLAYER_BOW_HAT)
}

// The character's mark.
//
// The colour is the *neutral* palette's, never the current world's: the
// character is the same mark wherever it stands, and only what is behind
// it and gathered around it changes (Design Doc, section 10). It still
// converges with depth, because every palette in the set does.

@(private)
player_stroke :: proc(palette: core.Palette, flare: f32, gain: GlowGain) -> Stroke {
	line := new_stroke(palette.light, TERRAIN_STROKE_THICKNESS * PLAYER_STROKE_WEIGHT)
	line.glow = PLAYER_STROKE_GLOW + PLAYER_FLIP_GLOW_BOOST * flare
	line.spread = PLAYER_STROKE_SPREAD
	line.core_light = PLAYER_CORE_LIGHT
	line.closed = true
	// "The character is the same mark in both worlds; what changes is what
	// is behind it and *how much it burns*" (Design Doc, section 10). The
	// profile and the colour stay put; this is the half that moves.
	apply_glow_gain(&line, gain)
	return line
}


@(private)
draw_player_marks :: proc(
	pose: PlayerPose,
	figure: PlayerFigure,
	palette: core.Palette,
	flare: f32,
	gain: GlowGain,
) {
	local := make([dynamic]rl.Vector2, 0, 48, context.temp_allocator)
	build_player_outline(figure, &local)
	if len(local) < 3 {
		return
	}

	screen := make([dynamic]rl.Vector2, 0, len(local), context.temp_allocator)
	for point in local {
		append(&screen, pose_point(pose, point))
	}
	draw_stroke(screen[:], player_stroke(palette, flare, gain))
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
	// Mirrored with the figure, so it leans into the walk in both worlds.
	mirror := get_player_mirror(player)
	pose.rotation += PLAYER_LEAN * mirror

	stride := world.scroll_offset / PLAYER_STRIDE_LENGTH * 2 * math.PI

	// What the hat is answering to, and it answers late. Two things move
	// the body — the whip of a flip and the bob of the walk — so the lean
	// is how much of each happened over the last PLAYER_HAT_LAG seconds.
	// That is what inertia is: a response to velocity, not to position,
	// and a velocity is a difference between two evaluations of something
	// the clock already decides.
	earlier := player
	earlier.transition_timer = max(player.transition_timer - PLAYER_HAT_LAG, 0)
	turn := get_player_rotation(player) - get_player_rotation(earlier)

	stride_earlier :=
		(world.scroll_offset - world.scroll_speed * PLAYER_HAT_LAG) /
		PLAYER_STRIDE_LENGTH *
		2 *
		math.PI
	rise :=
		player_body_offset(stride, world.elapsed_time, palettes.world_t).y -
		player_body_offset(stride_earlier, world.elapsed_time - PLAYER_HAT_LAG, palettes.world_t).y

	// The turn is measured on screen, where the mirror does not apply; the
	// lean is authored in the figure's own frame, where it does — so the
	// mirror has to be undone on the way in or the hat trails the wrong
	// way round in one of the two worlds.
	lean := -turn * PLAYER_HAT_TURN_TRAIL * mirror + rise * PLAYER_HAT_RISE_TRAIL
	lean = clamp(lean, -PLAYER_HAT_MAX_LEAN, PLAYER_HAT_MAX_LEAN)

	// Zero at both ends of the turn and one in the middle: the same shape
	// the stretch and the glow boost ride, so all three peak together.
	whip := math.sin(game.get_whip_progress(player) * math.PI)

	figure := new_player_figure(
		stride = stride,
		time = world.elapsed_time,
		world_t = palettes.world_t,
		whip = whip,
		hat_lean = lean,
	)

	gain := glow_gain(palettes.world_t)
	draw_player_marks(pose, figure, palettes.neutral, whip, gain)
	draw_player_eye(pose, figure, palettes.current.accent, gain)
}

// The one point of light inside the figure, set toward the front.
//
// It is the whole of the character's own light, and it is drawn with the
// neon stroke's dot (T7.5.2): a halo in the world's accent with a core
// lifted toward white. Authored in local space, so it follows the mirror
// and the rotation with no special case — and being single, it has no
// symmetry to break when the figure turns over.

@(private)
draw_player_eye :: proc(pose: PlayerPose, figure: PlayerFigure, color: rl.Color, gain: GlowGain) {
	// It rides the head rather than the box: the body moves with the bob
	// and the float, and an eye that did not would swim inside the robe.
	centre := pose_point(pose, figure.head + PLAYER_EYE_OFFSET)
	eye := new_stroke(color, PLAYER_EYE_RADIUS * 2 * pose.unit)
	eye.glow = PLAYER_EYE_GLOW
	apply_glow_gain(&eye, gain)
	draw_stroke_dot(centre, eye)
}
