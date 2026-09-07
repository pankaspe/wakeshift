/*
* Charge
* The bar, drawn as a ring closing around the body.
*
* WHY IT IS NOT A BAR IN A CORNER
*
* The HUD carries one number and has resisted every attempt to grow a
* second (ui/screens.odin). The reason it can is that this game draws its
* own state at full size: how far the front is *is* the health bar. The
* charge is the one thing that has no such picture — nothing else on
* screen says how close the world is to turning — so it genuinely needs a
* mark, and the question was only where.
*
* On the body, because that is where the eye already is. A player reading
* a maze at four columns a second is looking at the block and the three
* moves in front of it; a meter in a corner is read by looking away from
* the game, and pillar 2 is about what can be understood without doing
* that.
*
* WHY A RING AND NOT A FILL
*
* Two things are filled in this game, the field and the character, and a
* block that filled up would break the one discriminator the whole
* picture rests on. So the charge is line, like everything else that is
* not those two — a stroke that walks the block's own perimeter and
* closes on itself at full. A closed ring is a shape, not a length: the
* player does not read a percentage, they see it shut.
*
* It runs the same way in both directions, which is the whole of the
* Lucid rule needing no drawing of its own. In the Real it grows toward
* closing; in the Dream it opens back up as the phase drains, and a Lucid
* is simply the ring going backwards for a moment.
*
* IT IS DRAWN IN THE FRAGMENTS' OWN COLOUR
*
* Not the world's light, and not the body's. The ring **is** what has been
* picked up, laid round the thing that picked it up, so it takes `accent`
* — and the dust it throws off as it grows is the same colour arriving.
* That is one statement rather than three: the diamonds you took are the
* ring, and the ring is the world about to turn.
*
* It also means the ring does not wash out with depth, because none of the
* actors do (core/palette.odin), so the one thing telling you how close
* the Dream is stays legible for the whole run.
*/
package render

import "../core"
import "../game"
import "../fx"
import rl "vendor:raylib/v55"

// How far outside the block the ring sits, in px. The cell leaves 11 px
// of air on each side of the body; this spends most of it, so the ring
// is clearly not the block's edge and still clearly not the wall.
CHARGE_GAP :: 7.0

CHARGE_WEIGHT :: 0.55 // multiples of the world's stroke: lighter than a wall
CHARGE_GLOW :: 0.35
CHARGE_SPREAD :: 3.6

// --- The dust at the tip ---
//
// The ring's growing end is the only part of it that is *happening*, so
// that is where the dust comes from. It reads as the bar being written
// rather than being displayed, which is the same idea as the pen on the
// right-hand front.
//
// It also runs while the ring is *shrinking*, in the Dream, and that is
// deliberate: the tip is where the change is either way, and a bar
// burning down should look like it is burning.
CHARGE_DUST_RATE :: 34
CHARGE_DUST_SPEED :: 26
CHARGE_DUST_SCATTER :: rl.Vector2{30, 30}
CHARGE_DUST_DRAG :: 3.2
CHARGE_DUST_LIFE :: 0.42
CHARGE_DUST_SIZE :: 1.7
CHARGE_DUST_ALPHA :: 0.85

// Which fractional debt this emitter keeps (fx/particles.odin). The fray
// owns 0 and 1.
CHARGE_DUST_STREAM :: 2

// Under this the ring is a dot with nothing to say, so it is not drawn.
CHARGE_MIN_VISIBLE :: 0.02

// The ring's corners, walked clockwise from the top centre, with the
// distance along the perimeter at each. Starting at the top centre means
// the two ends meet where the eye is least likely to be, and that the
// first thing a run ever draws grows symmetrically.
@(private = "file")
ring_points :: proc(
	centre: rl.Vector2,
	half: f32,
	fraction: f32,
	out: ^[6]rl.Vector2,
) -> int {
	nodes := [6]rl.Vector2 {
		{centre.x, centre.y - half},
		{centre.x + half, centre.y - half},
		{centre.x + half, centre.y + half},
		{centre.x - half, centre.y + half},
		{centre.x - half, centre.y - half},
		{centre.x, centre.y - half},
	}
	marks := [6]f32{0, half, 3 * half, 5 * half, 7 * half, 8 * half}

	length := clamp(fraction, 0, 1) * 8 * half
	out[0] = nodes[0]
	count := 1
	for i in 1 ..< 6 {
		if marks[i] <= length {
			out[count] = nodes[i]
			count += 1
			continue
		}
		span := marks[i] - marks[i - 1]
		t := span > 0 ? (length - marks[i - 1]) / span : 0
		out[count] = nodes[i - 1] + (nodes[i] - nodes[i - 1]) * t
		count += 1
		break
	}
	return count
}

draw_charge :: proc(
	player: game.Player,
	dream: game.Dream,
	world: game.World,
	palettes: core.PaletteSet,
) {
	if dream.charge < CHARGE_MIN_VISIBLE {
		return
	}

	// The block's own centre, so the ring inherits the launch stretch's
	// position without inheriting its squash: a ring that stretched would
	// read as a second body rather than as a gauge.
	pose := new_player_pose(player, world)
	half := f32(game.PLAYER_SIZE) * 0.5 + CHARGE_GAP

	points: [6]rl.Vector2
	count := ring_points(pose.centre, half, dream.charge, &points)
	if count < 2 {
		return
	}

	ring := new_stroke(palettes.actor_accent, WORLD_STROKE_THICKNESS * CHARGE_WEIGHT)
	ring.glow = CHARGE_GLOW
	ring.spread = CHARGE_SPREAD
	ring.round_caps = false
	ring.closed = dream.charge >= 1
	apply_glow_gain(&ring, glow_gain(palettes.world_t))

	// Closed welds the last point back to the first, and the last point
	// *is* the first at full charge — so the duplicate is dropped rather
	// than welded onto itself, which would be the bead the mitre exists
	// to avoid.
	if ring.closed {
		count -= 1
	}
	draw_stroke(points[:count], ring)
}

// Where the ring's growing end currently is, in screen coordinates.
//
// Returns false at both ends of the bar: at empty there is no tip, and at
// full the ring is closed, so there is nothing being written and the dust
// would be a ring of sparks going nowhere.
charge_tip :: proc(
	player: game.Player,
	dream: game.Dream,
	world: game.World,
) -> (
	rl.Vector2,
	bool,
) {
	if dream.charge < CHARGE_MIN_VISIBLE || dream.charge >= 1 {
		return {}, false
	}
	pose := new_player_pose(player, world)
	points: [6]rl.Vector2
	count := ring_points(
		pose.centre,
		f32(game.PLAYER_SIZE) * 0.5 + CHARGE_GAP,
		dream.charge,
		&points,
	)
	if count < 2 {
		return {}, false
	}
	return points[count - 1], true
}

// One frame's worth of dust off the ring's tip.
//
// On the frame clock and never in the simulation, called from main beside
// the fray for the same reason: the pool has to be advanced whether or not
// this frame drew anything.
emit_charge_dust :: proc(
	particles: ^fx.Particles,
	player: game.Player,
	dream: game.Dream,
	world: game.World,
	palettes: core.PaletteSet,
	dt: f32,
) {
	tip, ok := charge_tip(player, dream, world)
	if !ok {
		return
	}
	fx.emit(
		particles,
		CHARGE_DUST_STREAM,
		fx.Emitter {
			origin = tip,
			spread = rl.Vector2{2, 2},
			velocity = rl.Vector2{0, -CHARGE_DUST_SPEED},
			scatter = CHARGE_DUST_SCATTER,
			drag = CHARGE_DUST_DRAG,
			rate = CHARGE_DUST_RATE,
			life = CHARGE_DUST_LIFE,
			life_jitter = 0.15,
			size = CHARGE_DUST_SIZE,
			size_jitter = 0.6,
			color = core.with_alpha(palettes.actor_accent, CHARGE_DUST_ALPHA),
		},
		dt,
	)
}
