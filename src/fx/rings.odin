/*
* Rings
* An expanding ring of light: the second thing fx can make, after a
* particle.
*
* WHY IT IS NOT A BURST OF PARTICLES ARRANGED IN A CIRCLE
*
* It was going to be, and it does not work. A ring of dust is a ring of
* dots, and at the size this is drawn — a shockwave off one 60 px wall —
* the dots stay dots: the eye reads scattered sparks rather than an edge
* travelling outward. What says "something opened here" is a *continuous*
* edge that grows and thins, which is one primitive raylib already has and
* a particle pool cannot express at any count worth paying for.
*
* IT RIDES THE WORLD, AND THAT IS THE ONE THING IT DOES DIFFERENTLY
*
* Particles are emitted at a screen position and stay there. That is fine
* for the fray, which lives at a front that barely moves on screen, and it
* is wrong here: a pierce marks a *wall*, the wall scrolls, and a ring
* nailed to the screen while the wall it belongs to slides out from under
* it is CLAUDE.md's "a world element nailed to the screen reads as two
* pictures", at 600 px/s.
*
* So a ring stores its **world x** and draw takes the offset to put it on
* screen. That is arithmetic, not game knowledge — fx still knows nothing
* about a camera, a maze or a run.
*
* Everything else is the particle pool's rules, and for the same reasons:
* a fixed pool with no allocation ever, swap-remove so nothing may depend
* on order, and the frame clock rather than a simulation step, because a
* ring decides nothing.
*/
package fx

import rl "vendor:raylib/v55"

// How many can be alive at once. A pierce is one ring and lasts a third
// of a second, so this is many more than a player can ask for; the pool
// is small because each one is a real draw call with geometry behind it.
RING_CAPACITY :: 16

// How many segments a ring is drawn with. Enough to be a circle at the
// radii this reaches and no more — the cost of a ring is this number.
RING_SEGMENTS :: 32

Ring :: struct {
	// World x, screen y. The wall it marks scrolls horizontally and never
	// vertically, so only one axis needs the treatment.
	world_x:     f32,
	y:           f32,
	age:         f32,
	life:        f32,
	from_radius: f32,
	to_radius:   f32,
	thickness:   f32,
	color:       rl.Color,
}

Rings :: struct {
	pool:  [RING_CAPACITY]Ring,
	count: int,
}

new_rings :: proc() -> Rings {
	return Rings{}
}

// Empties the pool. Called when a run starts, so the last run's marks do
// not arrive with the new one.
clear_rings :: proc(rings: ^Rings) {
	rings.count = 0
}

// Starts one. A full pool drops the request rather than overwriting the
// oldest: at RING_CAPACITY there is already more happening on screen than
// can be read, and the one that would be lost is the one being asked for
// now — which is the only one anybody is looking at.
spawn_ring :: proc(rings: ^Rings, ring: Ring) {
	if rings.count >= RING_CAPACITY {
		return
	}
	rings.pool[rings.count] = ring
	rings.pool[rings.count].age = 0
	rings.count += 1
}

update_rings :: proc(rings: ^Rings, dt: f32) {
	if dt <= 0 {
		return
	}
	index := 0
	for index < rings.count {
		rings.pool[index].age += dt
		if rings.pool[index].age >= rings.pool[index].life {
			// Swap-remove, exactly as the particle pool does: the last
			// live one fills the hole and this slot is examined again.
			rings.count -= 1
			rings.pool[index] = rings.pool[rings.count]
			continue
		}
		index += 1
	}
}

// Draws the pool additively. `offset_x` is what turns a world x into a
// screen x — the caller's one conversion, handed in rather than derived,
// so this file still knows nothing about a camera.
//
// The radius eases *out*, fast at the start and slowing, because that is
// what an edge leaving a source looks like; the alpha and the thickness
// both fall away with it, so the ring thins as it goes instead of
// stopping.
draw_rings :: proc(rings: Rings, offset_x: f32) {
	if rings.count == 0 {
		return
	}

	rl.BeginBlendMode(.ADDITIVE)
	defer rl.EndBlendMode()

	for index in 0 ..< rings.count {
		ring := rings.pool[index]
		t := clamp(ring.age / ring.life, 0, 1)

		// The radius eases out — 1 - (1-t)^2, written out rather than
		// reached for, since core:math/ease would be an import for one
		// curve — and the fade is 1 - t^2, which holds and then drops.
		//
		// Those two are not the same shape and it matters. Measured by
		// reading the frame back: with the fade quadratic in (1-t) as
		// well, the ring was already under an alpha of 14 at three
		// quarters of its life, so the last quarter drew nothing and what
		// was left read as a pop rather than as something opening. Holding
		// the brightness while the radius runs away is what makes it a
		// ring travelling outward.
		eased := 1 - (1 - t) * (1 - t)
		radius := ring.from_radius + (ring.to_radius - ring.from_radius) * eased
		fade := 1 - t * t
		half := max(ring.thickness * 0.5 * (0.35 + 0.65 * fade), 0.5)

		color := ring.color
		color.a = u8(f32(ring.color.a) * fade)
		if color.a == 0 {
			continue
		}
		rl.DrawRing(
			rl.Vector2{ring.world_x + offset_x, ring.y},
			max(radius - half, 0),
			radius + half,
			0,
			360,
			RING_SEGMENTS,
			color,
		)
	}
}
