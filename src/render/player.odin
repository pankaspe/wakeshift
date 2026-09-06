/*
* Player Render
* The character: a **filled square**, the size of its own box, in the
* colour of the lane it is standing on.
*
* WHY A SQUARE, AND WHY FILLED
*
* It was a robed figure under a pointed hood until 6 September — one
* closed spline through nine anchors, with a hat that lagged behind the
* turn and an eye set toward the front. Before that it was a stick figure
* with four limbs. Both went the same way and for the same reason, one
* step further each time: **a 45 px shape drawn with a 4 px pen cannot
* hold detail**, and every feature that does not read is noise the eye has
* to sort through while the player is trying to read the world.
*
* So the character is now the simplest thing that can be a character, and
* the interest moves entirely into how it *moves*. That is not a
* retreat — it is the same argument the design has made twice already,
* taken to its end: the sense of quality comes from the math of the
* movement, not from the detail of the shape.
*
* Two decisions carry the whole read, and they are both about telling it
* apart from everything else on screen:
*
*   **It is filled, and nothing else is.** Since RL.3 the field was the
*   only filled surface in the game — this is the second, and it is the
*   deliberate exception. The obstacles are *also* squares, welded into
*   the lane's own line, and they are hollow. Fill is therefore the whole
*   of "this one is you", which is a stronger discriminator than any
*   silhouette a 45 px figure could carry.
*
*   **It takes its lane's colour**, and it is the only mark that changes
*   colour between the worlds. The old figure was drawn out of the
*   *neutral* palette on purpose, on the reading that a mark which changes
*   colour is the mild version of the mistake that inverting body and rim
*   was. A filled block is a different case: the fill is its identity, and
*   a block wearing the colour of the line it is standing on belongs to
*   that world instead of visiting it. Mid-flip the colour travels with
*   the body, so it arrives already belonging to where it lands.
*
* NO ROTATION, AND THAT IS NOT AN OMISSION
*
* The flip used to be a half turn with an overshoot — Penner's easeOutBack,
* the most tuned number in the project. A square's half turn is invisible,
* so all that would survive of it is the overshoot, which would read as a
* small unrequested tumble on the one gesture the whole game is made of.
* CLAUDE.md's oldest game feel lesson applies exactly here: **a flourish
* placed on the player's own motion is not decoration, it is friction.**
* The turn is gone and `whip_ease` went with it; the only rotation left is
* the death fall's, where a tumbling block is the point.
*
* WHAT SURVIVED UNTOUCHED: THE SQUASH AND STRETCH
*
* It was already the right machinery and it was already playtested, so it
* is the same code against a different shape:
*
*   the stretch   rides sin(whip * PI), so it is nothing at both ends of
*                 the turn and everything in the middle. The block draws
*                 out along the direction of travel as it launches.
*   the bounce    a decaying oscillation on settle_timer, seconds since
*                 landing: it arrives squashed, overshoots into a slight
*                 stretch and settles. That is the "molleggio" the whole
*                 redesign was asked for.
*
* Both preserve volume roughly — x moves opposite to y — and both scale
* about the surface the block is touching rather than about its centre,
* or a landing would look like it happened above the ground.
*
* PILLAR 6 STILL HOLDS: THE TWO WORLDS MOVE DIFFERENTLY
*
* The two lanes are never told apart by colour alone, and with the robe
* gone the step and the drift had to be re-said for a block. They are:
*
*   Real    a hard, regular **beat**. The block compresses and springs
*           back on the stride's clock, planted on the floor — which is
*           what a bounce looks like when the thing bouncing has no legs.
*   Dream   a slow **float**. It lifts off the ceiling and settles back
*           on a long period, and never compresses.
*
* They crossfade continuously on world_t, so the *type* of motion says
* which world is live with the colour removed entirely. A beat that lifts
* the block off the floor was tried and is wrong: on the floor the contact
* is the thing that reads, so the Real world's motion has to be a squash
* and the Dream's a lift.
*/
package render

import "../core"
import "../game"
import "core:math"
import rl "vendor:raylib/v55"

// --- The mark ---

// The fill's opacity, and it is the whole of the mark: there is no edge.
//
// **The block had a neon outline until the playtest asked for it gone**,
// and taking it away is what makes the character *the lane's colour*
// rather than a lit object standing in front of it. The number is
// TERRAIN_RIM_ALIVE, the alpha the live lane's own line is drawn at, so
// the block and the line it stands on land on the same colour over the
// same field. That is what "it blends into the lane" means as arithmetic
// rather than as an intention, and it is checked by reading the frame
// back rather than by looking: measured, the block and the line agree to
// within 4 channel values of 255 in the Real world and 7 in the Dream,
// against 22 before the core lift was matched.
//
// **It knowingly breaks a written rule.** No filled surface may exceed
// 0.298, the lowest bloom threshold minus half a level
// (core/palette.odin) — but that rule is about the *field*, which is the
// whole screen, and haze over the entire frame is what it exists to
// prevent. This surface is 38 px and it is *supposed* to bloom: with the
// outline gone, the frame's own bloom pass is the only thing the
// character glows by. CLAUDE.md already preferred that resolution —
// where a halo looks doubled, remove the primitive one rather than
// lowering the bloom.
PLAYER_FILL_ALPHA :: 0.85

// --- Squash & stretch ---

// The two numbers a playtest will want to argue with, and the only two
// that decide how springy the block feels.
//
// The squash came down from 0.28 when the robe became a block: cloth can
// deform by a third and read as cloth, and at 0.28 a 45 px square drew
// itself as 51 x 32 on landing, which is jelly rather than a landing. A
// block reads its own edges much more sharply, so the same motion needs
// less of it.
STRETCH_AMOUNT :: 0.16 // vertical stretch at the peak of a flip
SETTLE_DURATION :: 0.22 // length of the post-landing squash bounce
SETTLE_SQUASH_AMOUNT :: 0.20

// The block acknowledging a fragment: one quick pop and back (phase F1).
//
// **Uniform on both axes, and that is the whole design of it.** Every
// other motion the block has is *anti*-correlated — the run's beat, the
// landing bounce and the flip's stretch all squash one axis exactly as
// they stretch the other, because all three are about a surface being
// pressed against. Growing in both at once is the one thing none of them
// can produce, so it reads as a different kind of event rather than as a
// louder landing. Nothing had to be added to the palette or the outline
// to say so.
//
// It multiplies whatever scale the block already has rather than
// replacing it, so a fragment taken mid-flip pops the stretch instead of
// cancelling it.
//
// A pure decay with no oscillation, for the same reason: the landing
// already owns the bounce. Full amount on the frame it happens and gone
// in a fifth of a second — an acknowledgement, not an animation.
PICKUP_DURATION :: 0.20
PICKUP_AMOUNT :: 0.20

// --- The idle motion: a beat in the Real world, a float in the Dream ---

// Pixels of world scroll per beat. Tied to distance rather than to time,
// so the cadence speeds up with the world on its own, whatever moves the
// speed, with nothing to keep in sync.
//
// **It is 120 because the robe's 58 was measured and was wrong here.**
// That number was a two-step walk cycle, so 29 px a step — 0.107 s at the
// opening speed, nine footfalls a second. Under a robe that is a small
// character walking quickly; on a block it is a 9 Hz vibration. One beat
// per 120 px is 2.3 a second, which is a pulse you can count.
PLAYER_STRIDE_LENGTH :: 120

// How far the block compresses on the beat, as a fraction of its height.
// Small: it is a pulse under the shape, not a second animation, and it
// must not compete with the landing bounce that is the real event.
PLAYER_STEP_SQUASH :: 0.045

// The Dream's float: how far off the ceiling it drifts, in pixels, and
// how long a full rise and fall takes. Slow and shallow — the point is
// that it is a different *kind* of motion, not a bigger one.
PLAYER_FLOAT_PERIOD :: 2.6
PLAYER_FLOAT_LIFT :: 5.0

// --- Falling out of the world ---
//
// Presentation only: the run is already over when this starts, it runs on
// the frame clock in main beside the other display state, and no
// simulation step can see it.

PLAYER_DEATH_FALL_TIME :: 1.1
PLAYER_DEATH_FALL_DISTANCE :: 225
PLAYER_DEATH_SPIN :: 1.6 // radians over the whole fall

// How the block lands on screen.
PlayerPose :: struct {
	centre:   rl.Vector2,
	size:     rl.Vector2, // already squashed and stretched
	rotation: f32, // radians; zero except during the death fall
}

// Which lane the shape should be anchored to: mid-flip we anchor to where
// we are headed, not where we came from.
get_player_anchor_lane :: proc(player: game.Player) -> core.Lane {
	if player.state == .Transitioning {
		return player.target_lane
	}
	return player.lane
}

// A per-axis scale multiplier, 1.0 being the box's own size.
//
// Values over 1 on y draw the block out tall and thin; under 1 squash it
// short and wide. x always moves opposite to y, for a rough sense of
// preserved volume — a classic animation trick, not physically exact.
get_player_scale :: proc(player: game.Player, beat_squash: f32) -> rl.Vector2 {
	whip := game.get_whip_progress(player)
	if whip < 1 {
		// A bell peaking mid-turn and back to 1 at both ends. On the
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

	// Settled: the run's own beat, which is nothing at all in the Dream.
	return rl.Vector2{1 + beat_squash * 0.6, 1 - beat_squash}
}

// The idle motion, crossfaded on world_t: how much the block is
// compressed by the run's beat, and how far it floats off its lane.
//
// Only one of them is ever really happening — the beat belongs to the
// Real world and the float to the Dream — and the crossfade is what makes
// the change of world readable in the *type* of motion (pillar 6).
player_idle :: proc(stride, time, world_t: f32) -> (squash, lift: f32) {
	t := clamp(world_t, 0, 1)

	// One compression per cycle. Squared, so it spends most of the beat
	// near zero and compresses briefly: a contact, rather than a sine
	// breathing in and out.
	beat := 0.5 - 0.5 * math.cos(stride)
	squash = PLAYER_STEP_SQUASH * beat * beat * (1 - t)

	rise := 0.5 - 0.5 * math.cos(time / PLAYER_FLOAT_PERIOD * 2 * math.PI)
	lift = PLAYER_FLOAT_LIFT * rise * t
	return squash, lift
}

// The colour of the lane the block is in, travelling with it across a
// flip so that it arrives already belonging to where it lands.
//
// It samples the two worlds' palettes directly rather than
// `palettes.current`, which rides world_t and therefore lags a flip by
// design (it is what the *field* is doing). The block is the thing
// crossing, so it moves on the journey's own clock.
//
// **The core lift is what makes it the lane's colour rather than merely
// its hue.** A neon line is not its own colour at the centre — the colour
// is what the light does to the air around it, and the middle is closer
// to white the brighter it is (core/palette.odin). The terrain lifts its
// core by TERRAIN_CORE_LIGHT, so a block drawn from the raw `light` came
// out 22 values of 255 under the line it was standing on: the same hue,
// visibly deeper, which is exactly "not quite the same colour". Using the
// terrain's own recipe closes it to one.
player_lane_color :: proc(player: game.Player, palettes: core.PaletteSet) -> rl.Color {
	real := core.lighten_color(palettes.real.light, TERRAIN_CORE_LIGHT)
	dream := core.lighten_color(palettes.dream.light, TERRAIN_CORE_LIGHT)

	toward_dream: f32 = player.lane == .Dream ? 1 : 0
	if player.state == .Transitioning {
		t := clamp(player.transition_timer / game.FLIP_DURATION, 0, 1)
		toward_dream = player.target_lane == .Dream ? t : 1 - t
	}
	return core.lerp_color(real, dream, toward_dream)
}

new_player_pose :: proc(player: game.Player, scale: rl.Vector2, lift: f32) -> PlayerPose {
	size := rl.Vector2{player.size.x * scale.x, player.size.y * scale.y}

	// Keep the block planted on the surface it is touching while it
	// squashes and stretches, instead of scaling about its centre —
	// otherwise a landing looks like it happens above the ground. The
	// float is measured the same way, into the corridor rather than down.
	into_corridor: f32 = get_player_anchor_lane(player) == .Real ? -1 : 1
	anchor_shift := (player.size.y - size.y) * 0.5 * -into_corridor

	return PlayerPose {
		centre = rl.Vector2 {
			player.position.x + player.size.x * 0.5,
			player.position.y + player.size.y * 0.5 + anchor_shift + lift * into_corridor,
		},
		size = size,
		rotation = 0,
	}
}

// obstacles goes in because the ground is not only the track any more: a
// cube the character came down onto is something they stand on
// (game/world.odin), and the drawn body has to be placed on the same
// ground the simulation put it on.
//
// `falling` is 0 for a living character and runs to 1 over
// PLAYER_DEATH_FALL_TIME once they have gone through a hole. It is the
// only argument here that is not a fact about the simulation: the run has
// ended by the time it is anything but zero.
// How much bigger the block is, this many seconds after taking a
// fragment. One outside the window, which is where a run starts and where
// it spends almost all of its time.
@(private)
pickup_pop :: proc(pickup: f32) -> f32 {
	if pickup < 0 || pickup >= PICKUP_DURATION {
		return 1
	}
	remaining := 1 - pickup / PICKUP_DURATION
	return 1 + PICKUP_AMOUNT * remaining * remaining
}

draw_player :: proc(
	player: game.Player,
	world: game.World,
	obstacles: []game.Obstacle,
	palettes: core.PaletteSet,
	falling: f32 = 0,
	pickup: f32 = -1,
) {
	// The terrain is drawn against the world nudged forward by the
	// leftover fraction of a simulation step (main/interpolated_world),
	// so the body is placed on that same ground rather than on the ground
	// of the last whole step. A local copy: render never mutates game
	// state.
	player := player
	player.position.y = game.get_player_y(player, world, obstacles)

	stride := world.scroll_offset / PLAYER_STRIDE_LENGTH * 2 * math.PI
	squash, lift := player_idle(stride, world.elapsed_time, palettes.world_t)

	scale := get_player_scale(player, squash)

	// The fragment pop rides on top of whatever the block was already
	// doing, so it never cancels a flip's stretch or a landing's bounce.
	// The pose still anchors the result to the surface being touched, so
	// growing does not lift the block off the lane.
	pop := pickup_pop(pickup)
	scale *= pop

	pose := new_player_pose(player, scale, lift)

	// Through the hole. Away from the corridor — down off the floor, up
	// through the ceiling — because a hole in the Dream is a way out
	// rather than a fall.
	fall := clamp(falling, 0, 1)
	if fall > 0 {
		away: f32 = player.lane == .Real ? 1 : -1
		pose.centre.y += fall * fall * PLAYER_DEATH_FALL_DISTANCE * away
		pose.rotation = fall * PLAYER_DEATH_SPIN * away
	}

	// One rectangle, and that is the whole character.
	//
	// Drawn with raylib's own primitive rather than with two triangles of
	// our own, because **a triangle's winding is not free**: raylib culls
	// back faces and asks for counter-clockwise vertices, and getting it
	// backwards is a shape that silently does not appear — the same trap
	// that cost a whole ribbon in render/stroke.odin.
	//
	// It thins out as it falls through a hole: it is being taken by the
	// absence, so it stops rather than gets covered.
	color := player_lane_color(player, palettes)
	fill := core.with_alpha(color, PLAYER_FILL_ALPHA * (1 - fall))
	rl.DrawRectanglePro(
		rl.Rectangle{pose.centre.x, pose.centre.y, pose.size.x, pose.size.y},
		rl.Vector2{pose.size.x * 0.5, pose.size.y * 0.5},
		pose.rotation * math.DEG_PER_RAD,
		fill,
	)
}
