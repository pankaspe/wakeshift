/*
* World
* holds global world state, like scroll speed, and drives everything
* that moves automatically with it (floor, ceiling, obstacles)
*
* THE PLAYER SETS THE WORLD'S CLOCK (F4)
*
* The world runs faster while the character is on the ceiling. One key
* already chose *where* to be; since F4 it also chooses *how fast the
* game happens*, which is the whole of the phase.
*
* **It is a clock, not a speed, and that distinction is the entire
* implementation.** The obvious way to build it is to raise
* scroll_speed on the Dream lane. That is wrong here, and provably so:
* an obstacle's screen x is
*
*     anchor + (arrival_time - elapsed_time) * scroll_speed
*
* so raising the speed multiplies the *distance* to everything not yet
* arrived. A flip to the ceiling would slide the whole world to the
* right — 26% of its distance from the anchor, which is 240 px at the
* screen's edge — and a flip back would pull it in again. The world
* would breathe horizontally on every press. Worse, it would not even be
* faster in the way the phase means: arrival times would not move, so
* the *rate* at which obstacles arrive would be unchanged and only the
* spacing would grow.
*
* So scroll_speed is left alone and **elapsed_time advances at `pace`
* seconds per real second** instead. Everything falls out of that:
*
*   nothing slides   the mapping above is anchored on a constant, so no
*                    obstacle moves when the pace changes. Only the rate
*                    at which the clock runs does.
*   it is really
*   faster           obstacles arrive sooner, the generator produces
*                    them sooner, and the world crosses the screen at
*                    scroll_speed * pace px per real second.
*   score, depth,
*   the Corruption   all of them are already measured in scrolled
*                    distance, and scroll_offset advances at the same
*                    pace, so every one of them speeds up with no line
*                    of code that knows about F4.
*   the pool is
*   still valid      every window the fairness check computes is
*                    (body + width) / scroll_speed *world* seconds, and
*                    scroll_speed no longer moves. The geometry is
*                    pace-invariant by construction, so there was
*                    nothing to revalidate — which is not what F4 was
*                    expected to need, and is the reason it was built
*                    this way.
*
* WHAT THE PACE ACTUALLY TRADES
*
* The economy is measured per *pixel* end to end — the Corruption gains
* per pixel scrolled, a pin costs ground at the world's own rate, a
* fragment is worth 60 px of front — so the pace changes none of it.
* What it does change is the one clock that does *not* dilate: the
* player's own. A flip is FLIP_DURATION of **real** time, because "the
* gesture never changes with the world" is older than this phase
* (core/track.odin), so at pace 1.35 a flip costs 0.216 world seconds
* instead of 0.160 and the corridor is 35% wider in the only units that
* matter.
*
* That is the trade, and it is the whole of it: **the ceiling buys score
* and difficulty per second, and pays in reaction time.** Nothing else
* is different up there, which is what makes the choice readable.
*
* **The pace is a cost, not a purchase, and that is worth saying out
* loud.** A run ends when the front reaches the character, the front
* gains per pixel, and depth *is* distance — so a run dies at the same
* distance and scores the same number whatever pace it was run at. Going
* fast does not earn more, it earns the same sooner. What makes the
* ceiling worth visiting is the fragments F3 put up there, and the pace
* is the price of them. When Slancio (roadmap R6.3) finally raises
* INITIAL_SCROLL_SPEED, *that* will be the purchase, and it is a
* different axis: it moves the base the clock is measured against.
*
* MEASURED
*
*   nothing slides    following one obstacle across a flip, the largest
*                     move it makes in a step is 6.08 px, which is exactly
*                     one step at the ceiling's rate, and the largest on a
*                     step where the pace actually changed is 6.07.
*                     Raising scroll_speed instead would have slid that
*                     same obstacle 247 px over the flip, and the right
*                     edge of the screen 322.
*   the pool          validate_pattern_pool is silent, unchanged, and it
*                     was never going to be otherwise: see above.
*   determinism       two runs of one seed agree to the step.
*   60 replayed runs  the greedy bot's median goes from 16150 px in 60 s
*                     to 15180 px in **47.6 s**, averaging 319 px/s with
*                     47% of its steps at the ceiling's pace. Distance is
*                     almost unchanged, as the argument above says it must
*                     be; a fifth of the real time is gone.
*   the reward gets
*   harder to take    a fragment's collection window is 0.2 seconds of
*                     *world* time, which is 0.148 real seconds at the
*                     ceiling. The same bot collects 10.6 a run against
*                     12.8 before F4.
*
* The bot understates the cost, and any conclusion drawn from it should
* say so: it reacts in one step and never needs to look ahead, so the
* thing the pace mostly takes away — 3.41 seconds of warning down to 2.52
* — is worth almost nothing to it and a great deal to a person.
*/
package game

import "../core"
import rl "vendor:raylib/v55"

// Initial scroll speed, in pixels per second (Design Doc, section 6: ~260-280 px/s)
INITIAL_SCROLL_SPEED :: 270

// How fast the world's clock runs on each lane, as a multiple of real
// time. The floor is the tempo the game has always had; the ceiling is
// the only thing that has ever moved it.
//
// **One direction, deliberately.** The floor could have been slowed
// below 1 to make the band symmetrical, and it is not: the tempo the
// game was playtested at should stay the tempo of the lane a run starts
// on and returns to, so that "faster" is something the player *does*
// rather than a baseline they have to notice.
//
// 1.35 is 364 px/s of screen, which puts 920 px of look-ahead at 2.5 s
// against the floor's 3.4 — the same pair of numbers C3 used to describe
// what speed changes (difficulty.odin), and comfortably inside the band
// the old tiers used to run at (270, 330, 400) and the pool was
// validated across.
WORLD_PACE_REAL :: 1.0
WORLD_PACE_DREAM :: 1.35

// The pace at a given height in the corridor, 0 on the floor and 1 at
// the ceiling.
//
// Continuous across the flip rather than switched at the end of it, and
// on the *journey's* clock rather than on the drawn body's height
// (get_player_pace_t). A body standing on a twelve-unit tower is 324 px
// up the corridor and still on the floor, so anything that read the
// drawn y would have the world nearly at Dream pace while the character
// was plainly running along the ground.
get_world_pace :: proc(pace_t: f32) -> f32 {
	t := clamp(pace_t, 0, 1)
	return WORLD_PACE_REAL + (WORLD_PACE_DREAM - WORLD_PACE_REAL) * t
}

World :: struct {
	scroll_speed:  f32,

	// World seconds per real second, set every step from where the
	// character is in the corridor. It is the only thing F4 added, and
	// everything else in the game reads its effects rather than it.
	pace:          f32,
	scroll_offset: f32, // total distance scrolled so far, in pixels
	elapsed_time:  f32, // total seconds since this run started

	// How many fixed simulation steps this run has taken. With a fixed
	// timestep the step count *is* the clock: unlike elapsed_time it
	// carries no floating point drift, so it is the stable way to say
	// "when" something happened — which is how a recorded input log
	// indexes its events (roadmap T2.8).
	tick:          u64,
}

new_world :: proc() -> World {
	return World {
		scroll_speed = INITIAL_SCROLL_SPEED,
		scroll_offset = 0,

		// A run opens on the floor, so it opens at the floor's tempo.
		// Set here rather than left at the zero value, because a pace of
		// zero is a world that does not move at all.
		pace = WORLD_PACE_REAL,
	}
}

// How fast the world is crossing the screen right now, in pixels per
// **real** second.
//
// Everything that means "how much world went by this step" goes through
// this rather than through scroll_speed, which since F4 is the base rate
// the clock is measured against rather than the rate anything actually
// moves at. The two were the same number until the ceiling started
// running fast, and code written before that read scroll_speed to mean
// both.
get_scroll_rate :: proc(world: World) -> f32 {
	return world.scroll_speed * world.pace
}

// The world reduced to what the scrolling depends on (core/track.odin):
// the run's clock and its current speed, which is everything the map
// between world time and screen x needs. Handing over those two rather
// than the whole World is what lets core own that map without importing
// anything.
get_ground :: proc(world: World) -> core.Ground {
	return core.Ground{time = world.elapsed_time, speed = world.scroll_speed}
}

// Where the lanes are. Constants since C1, and re-exported here only so
// that game code asks one package about the world instead of two.
get_lane_y :: proc(lane: core.Lane, size: rl.Vector2) -> f32 {
	return core.get_lane_y(lane, size)
}

get_surface_y :: proc(lane: core.Lane) -> f32 {
	return core.track_surface_y(lane)
}

// How quickly scroll_speed eases toward a new target, in seconds —
// smaller is snappier, larger is smoother.
//
// Nothing moves the target today: C3 took speed out of the difficulty
// curve, so a run scrolls at INITIAL_SCROLL_SPEED from the first metre to
// the last. The easing is kept for the thing that will move it, which is
// the player buying Slancio (roadmap R6.3) — a purchase that snapped the
// world to a new speed would slide every obstacle already on screen.
SCROLL_SPEED_EASE_TIME :: 1.0

// Advances the scroll offset and the run timer by exactly one simulation
// step. scroll_speed eases toward target_scroll_speed rather than
// snapping, so obstacles already generated (Section 8's time-based
// positioning) don't visibly jump when the target moves (Section 18).
//
// delta_time is always core.FIXED_TIMESTEP in the running game; it stays
// a parameter so a test can step the world at whatever rate it wants.
// pace is world seconds per real second (F4). delta_time stays *real*
// time — the step is the step, and the tick count has to keep meaning
// "how many steps has this run taken" for a replay to index into it.
update_world :: proc(world: ^World, delta_time: f32, target_scroll_speed: f32, pace: f32) {
	world.tick += 1
	world.pace = pace

	ease_factor := delta_time / SCROLL_SPEED_EASE_TIME
	if ease_factor > 1 {
		ease_factor = 1
	}
	world.scroll_speed += (target_scroll_speed - world.scroll_speed) * ease_factor

	// Both on the world's clock, and both by the same factor: the world
	// covering more ground per real second and its clock running faster
	// are the same statement, and writing them as two would let them
	// disagree.
	world.scroll_offset += get_scroll_rate(world^) * delta_time
	world.elapsed_time += delta_time * world.pace
}

// --- Standing on things ---

// The surface a body of the given size rests on at this x, obstacles
// included: the track, or the top of a cube it is already above.
//
// WHY "ALREADY ABOVE" IS THE WHOLE RULE
//
// A cube cannot simply be ground, or it would stop being a price: the
// moment its leading edge slid under any part of the body the support
// would jump 54 px and the character would ride over every obstacle in
// the game. It cannot simply not be ground either, which is what it was
// until 5 September — a flip onto an occupied lane then left the
// character standing *inside* the box, 100% of every form, for up to two
// and a half seconds, because mid-flip nothing on a lane may block them
// so the cube scrolls over their x while they cross.
//
// The discriminator is the one a platformer uses and it needs no physics:
// **you rest on a surface your feet were already at or above.** Coming
// down onto a cube, they are; walking into one side-on, they are not, and
// it stays a wall that blocks (collision.odin). The body's last position
// is already state and already deterministic, so nothing has to be
// remembered that a replay could not reproduce.
//
// Hanging from the ceiling is the same sentence mirrored: cubes hang
// down, the contact edge is the top of the box, and "above" is "below".
// Which edge it is belongs to **the lane being asked about**, not to the
// lane the character is on — mid-flip the two endpoints are resolved
// separately and each one has to use its own side, or the ceiling is
// tested with the floor's foot and a journey starts by teleporting.
get_support_y :: proc(
	world: World,
	obstacles: []Obstacle,
	lane: core.Lane,
	x, width: f32,
	body_y, body_height: f32,
) -> f32 {
	support := core.track_surface_y(lane)

	// How much of a step's worth of slack the test gets. Without it a body
	// resting exactly on a cube fails its own test on the next frame, the
	// support drops away and it flickers.
	tolerance := world.scroll_speed * core.FIXED_TIMESTEP + 1

	for obstacle in obstacles {
		if !blocks_lane(obstacle.obstacle_type) || obstacle.lane != lane {
			continue
		}
		rect := get_obstacle_rect(obstacle, world)
		if rect.x >= x + width || rect.x + rect.width <= x {
			continue
		}

		// Column by column, because a skyline is not one surface: a body
		// straddling a staircase rests on the highest step under its
		// width, exactly as it rests on the highest ground under it. A
		// column of height zero offers nothing and is skipped — the track
		// underneath is already the answer there.
		//
		// **A body is never on one column.** It is 45 px and a column is
		// 27, so it always spans two and takes the higher of them, which
		// is worth knowing before authoring a staircase: landing on one
		// puts the character on the *upper* of the two steps they cover,
		// not the one their leading edge touched. Verified by replay.
		for index in 0 ..< get_cube_columns(obstacle) {
			column := get_cube_column(obstacle, rect, index)
			if column.rect.height <= 0 {
				continue
			}
			if column.rect.x >= x + width || column.rect.x + column.rect.width <= x {
				continue
			}

			switch lane {
			case .Real:
				if body_y + body_height <= column.contact + tolerance {
					support = min(support, column.contact)
				}
			case .Dream:
				if body_y >= column.contact - tolerance {
					support = max(support, column.contact)
				}
			}
		}
	}
	return support
}

// Where a body of the given size rests against one lane at x, standing on
// whatever is actually there. The obstacle-aware get_lane_y.
get_stand_y :: proc(
	world: World,
	obstacles: []Obstacle,
	lane: core.Lane,
	x: f32,
	size: rl.Vector2,
	body_y: f32,
) -> f32 {
	surface := get_support_y(world, obstacles, lane, x, size.x, body_y, size.y)
	switch lane {
	case .Real:
		return surface - size.y
	case .Dream:
		return surface
	}
	return surface
}
