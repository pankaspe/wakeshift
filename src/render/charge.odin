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
* It is drawn in the world's *light* rather than the accent the body is,
* so it reads as something around the block instead of part of it — and
* so it goes lavender with the Dream, which is the one moment its meaning
* changes.
*/
package render

import "../core"
import "../game"
import rl "vendor:raylib/v55"

// How far outside the block the ring sits, in px. The cell leaves 11 px
// of air on each side of the body; this spends most of it, so the ring
// is clearly not the block's edge and still clearly not the wall.
CHARGE_GAP :: 7.0

CHARGE_WEIGHT :: 0.55 // multiples of the world's stroke: lighter than a wall
CHARGE_GLOW :: 0.35
CHARGE_SPREAD :: 3.6

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

	ring := new_stroke(palettes.current.light, WORLD_STROKE_THICKNESS * CHARGE_WEIGHT)
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
