/*
* Obstacle
* Obstacles are described as events in time (when they should reach the
* player), not as absolute pixel positions. Their on-screen x position is
* derived every frame from the world's elapsed time and scroll speed.
* This means changing scroll speed later never breaks perceived timing —
* which matters more than it used to, because from roadmap R6 the scroll
* speed is something the *player* buys mid-run (Design Doc, sections 4
* and 8).
*
* Three types, three verbs (Design Doc, section 6):
*
*   the Cube      something that is *there*. It does not kill, it
*                 **blocks**: you are stopped against its face and you
*                 lose ground for as long as you stay. It is the only
*                 thing in the game allowed on both lanes at once,
*                 precisely because it is not lethal.
*   the Gap       the lane failing to be there. It kills only whoever is
*                 still resting on that lane when it passes, so being
*                 mid-flip answers it as completely as being on the other
*                 lane does (see collision.odin).
*   the Sentinel  an emitter on one lane firing a curtain of light across
*                 the corridor toward the other, stopping short of it. It
*                 asks *when*: its own lane is lethal and the far one is
*                 clear, and it is authored in facing pairs, so what it
*                 really wants is one flip made in the gap between two
*                 shots.
*
* THE CUBE IS ONE PRIMITIVE AT SIX SIZES
*
* Everything the design asks of the obstacle set is a box on a lane at a
* different size or a different height, and CubeForm is the whole
* vocabulary. Mechanically only two numbers matter — the width, which is
* the price, and whether the box is in the body's band at all — so a
* stack and a pyramid cost exactly what they are wide and their height is
* rhetoric. That is a feature: they are read at a glance as *worse* while
* costing the same, which is how the set gets variety without getting
* rules.
*
* Nothing here ever reads the player's position. An obstacle that adapts
* feels stolen even when it is survivable, and it breaks pillar 3: the
* threat has to be readable before the commitment, which means it has to
* have been decided before the player moved.
*
* The v1.x file had seven types and a lot of machinery for the four that
* are gone (roadmap R1.3). Two of them are worth remembering rather than
* rediscovering: everything an obstacle does over time has to be a
* function of *its own* arrival_time and never of the global clock, or
* the same pattern presents a different face every time it is generated;
* and any randomness in an obstacle has to come from the run's own
* generator, or fairness ends up in the hands of the seed.
*/
package game

import "../core"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib/v55"

// The side of the primitive, in pixels — every cube is some arrangement
// of boxes this size, and the player is a little smaller than one.
CUBE_UNIT :: 54

ObstacleType :: enum {
	Cube, // either lane: sticks out into it and blocks
	Gap, // either lane: the surface is simply not there
	Sentinel, // both lanes at once: crossing is what it forbids
}

// The cube vocabulary (Design Doc, section 6). Standard is first so that
// it is the zero value: a pattern event that says nothing about its cube
// gets the primitive.
CubeForm :: enum {
	Standard, // one unit square — the primitive
	Small, // half a unit: a bump rather than a wall
	Wide, // two units of width, which is two units of price
	Stack, // one wide, three tall: costs what it is wide, looks worse
	Pyramid, // three wide and stepped: says in advance which side to be on
	Float, // bobs in and out of the body's band — the one timing cube
}

// How high a floating cube rises above the surface of its lane, and how
// long a full rise-and-fall takes.
//
// The lift is comfortably over the player's own height, so at the top of
// its travel the box is entirely clear of the body and the character
// runs under it (over it, hanging from the ceiling — same picture with
// the mirror applied). Anything under PLAYER_SIZE blocks.
CUBE_FLOAT_LIFT :: 96
CUBE_FLOAT_PERIOD :: 1.6

// THE SENTINEL IS A CURTAIN, AND THEY COME IN PAIRS
//
// An emitter sits on one lane and fires a curtain of light across the
// corridor toward the other, stopping SENTINEL_CLEARANCE short of a body
// settled there. So a single one is simply "not this lane, not now": its
// own lane is lethal, the far one is clear, and crossing through it is
// death like anything else it touches.
//
// **The obstacle is the pair.** Two of them on opposite lanes, separated
// in time, make one forced and timed flip: be on the far lane for the
// first shot, cross in the gap between them, be on the other for the
// second. That is a demand neither of the other two dangers makes — the
// cube says *move or pay*, the hole says *not here*, and this says *now*
// — and it is the pattern pool's job to compose it, not this file's.
//
// WHY IT IS NOT A SLOT YOU FLY THROUGH
//
// The sketch it came from had two emitters facing each other across the
// corridor with a gap between the beams, and the character passing
// through the gap. It cannot exist, and the arithmetic is short. A flip
// crosses the corridor at about 2100 px/s, so a body is inside a 160 px
// slot for 0.054 s; but a beam threatens for as long as its x overlaps
// the body, and the body alone is 45 px wide, which at the opening speed
// is 0.167 s. The character cannot be in the middle for as long as the
// middle is dangerous, whatever the beam's width — including zero. The
// same wall killed the version before it, a single ray sweeping the whole
// corridor: two things closing head-on always meet.
//
// What survives from both attempts is the demand. Turning the pair from
// *across* the corridor to *along* it keeps "pass through the middle"
// exactly, and moves the middle somewhere the character can actually be.

// The curtain's thickness in x, and how much room it leaves at the far
// end.
//
// The thickness is what the collision uses and what is drawn, so the mark
// and the hitbox are the same thing. At the opening speed a body meets it
// for (18 + 45) / 270 = 0.23 s, and that shrinks as a run speeds up —
// which is the promise every obstacle here makes: speed is not a
// difficulty knob.
//
// The clearance is a body plus a margin, so a settled character on the
// far lane is clear of it at every legal span.
SENTINEL_BEAM_WIDTH :: 18
SENTINEL_CLEARANCE :: PLAYER_SIZE + 14

// What a pattern has to leave between two facing curtains, in seconds, for
// the flip between them to be possible at all: the journey itself plus
// the time the body takes to clear one beam. Below this the pair is
// unanswerable; the pool leaves comfortably more (pattern.odin).
SENTINEL_MIN_GAP_TIME :: FLIP_DURATION + 0.10

// True for the type that is an *absence* rather than a thing. It is also
// exactly the set the terrain draws rather than draw_obstacle: only the
// code that knows where its own surface is can cut a hole in it.
is_gap :: proc(obstacle_type: ObstacleType) -> bool {
	return obstacle_type == .Gap
}

// True for the types that end a run outright, as opposed to the ones that
// cost ground. It is what the fairness rule is written in terms of
// (pattern.odin): two *lethal* lanes at once is unanswerable, while two
// blocked lanes is a choice about which price to pay.
is_lethal :: proc(obstacle_type: ObstacleType) -> bool {
	return obstacle_type == .Gap || obstacle_type == .Sentinel
}

// True for a danger that is lethal to *both* lanes at once rather than to
// the one it stands on.
//
// Nothing is, any more, and that is a simplification worth having: the
// Sentinel used to be, which is why the fairness rule needed a second
// sentence about its window. A curtain belongs to the lane it is fired
// from, so the ordinary rule — at every instant at least one lane must be
// non-lethal — now covers it with no special case, and two facing
// curtains are legal exactly when they do not overlap in time, which is
// what makes the pair authorable at all.
is_lethal_to_both_lanes :: proc(obstacle_type: ObstacleType) -> bool {
	return false
}

// True for the type that costs ground instead of the run.
blocks_lane :: proc(obstacle_type: ObstacleType) -> bool {
	return obstacle_type == .Cube
}

Obstacle :: struct {
	arrival_time: f32, // world.elapsed_time at which this obstacle reaches WORLD_ANCHOR_X
	lane:         core.Lane, // meaningless for a Sentinel, which occupies both
	size:         rl.Vector2,
	obstacle_type: ObstacleType,

	// Cube only. The form decides the box; the phase decides where in its
	// bob a floating one is at the moment it reaches the anchor, so a
	// pattern can author "this one blocks" and "this one you go under"
	// out of the same obstacle.
	cube:         CubeForm,
	float_phase:  f32,
}

// Gap width variants. Picked randomly at creation — flavour, and the one
// random choice left in an obstacle, so a pattern still knows exactly
// what it is asking of the player. GAP_WIDTH_LONG is what
// validate_pattern_pool checks against, since it is the worst case.
GAP_WIDTH_SHORT :: CUBE_UNIT * 1.2
GAP_WIDTH_MEDIUM :: CUBE_UNIT * 1.9
GAP_WIDTH_LONG :: CUBE_UNIT * 2.6

// The box a cube form stands in, before its lane decides which way up it
// is. Width is the price; height is how the shape reads.
get_cube_size :: proc(form: CubeForm) -> rl.Vector2 {
	switch form {
	case .Standard:
		return rl.Vector2{CUBE_UNIT, CUBE_UNIT}
	case .Small:
		return rl.Vector2{CUBE_UNIT * 0.5, CUBE_UNIT * 0.5}
	case .Wide:
		return rl.Vector2{CUBE_UNIT * 2, CUBE_UNIT}
	case .Stack:
		return rl.Vector2{CUBE_UNIT, CUBE_UNIT * 3}
	case .Pyramid:
		return rl.Vector2{CUBE_UNIT * 3, CUBE_UNIT * 3}
	case .Float:
		return rl.Vector2{CUBE_UNIT, CUBE_UNIT}
	}
	return rl.Vector2{CUBE_UNIT, CUBE_UNIT}
}

// The widest this event can ever turn out to be. Used by the fairness
// check, which has to reason about a pattern before its random choices
// have been made.
get_max_width :: proc(obstacle_type: ObstacleType, form: CubeForm) -> f32 {
	switch obstacle_type {
	case .Gap:
		return GAP_WIDTH_LONG
	case .Sentinel:
		return SENTINEL_BEAM_WIDTH
	case .Cube:
		return get_cube_size(form).x
	}
	return CUBE_UNIT
}

// Creates an obstacle that will reach the world anchor at the given time.
// Which is where the player is, as long as they have not lost ground.
//
// Takes the caller's random generator rather than reaching for the global
// one: every random choice a run makes has to come from the run's own
// seed to stay reproducible (see PatternGenerator in pattern.odin).
new_obstacle :: proc(
	arrival_time: f32,
	lane: core.Lane,
	obstacle_type: ObstacleType,
	form: CubeForm,
	float_phase: f32,
	rng: rand.Generator,
) -> Obstacle {
	size := get_cube_size(form)

	switch obstacle_type {
	case .Gap:
		width: f32 = GAP_WIDTH_SHORT
		roll := rand.float32(rng)
		switch {
		case roll < 0.4:
			width = GAP_WIDTH_SHORT
		case roll < 0.75:
			width = GAP_WIDTH_MEDIUM
		case:
			width = GAP_WIDTH_LONG
		}
		size = rl.Vector2{width, CUBE_UNIT}
	case .Sentinel:
		// The curtain's height is the corridor's, so it is answered per
		// frame by get_obstacle_size rather than stored here.
		size = rl.Vector2{SENTINEL_BEAM_WIDTH, CUBE_UNIT}
	case .Cube:
	// the form already gave us the box
	}

	return Obstacle {
		arrival_time = arrival_time,
		lane = lane,
		size = size,
		obstacle_type = obstacle_type,
		cube = form,
		float_phase = float_phase,
	}
}

// How far a floating cube currently stands off the surface of its lane.
// Zero for every other form.
//
// A function of the obstacle's **own age**, never of the global clock: at
// age zero it is at the phase its pattern authored, so the author knows
// exactly what the player meets at the anchor and the player can learn
// it. Driven by the world's clock rather than by integrated state, so the
// display can evaluate it a fraction of a step ahead and get the same
// answer the simulation would.
//
// A player who has *lost* ground meets it earlier in its rise and a
// player who is running free meets it later — which is the one place in
// the game where how much room you have changes what an obstacle asks of
// you, and it is worth having.
get_cube_lift :: proc(obstacle: Obstacle, world: World) -> f32 {
	if obstacle.obstacle_type != .Cube || obstacle.cube != .Float {
		return 0
	}
	age := world.elapsed_time - obstacle.arrival_time
	turns := age / CUBE_FLOAT_PERIOD + obstacle.float_phase
	return CUBE_FLOAT_LIFT * 0.5 * (1 - math.cos(turns * 2 * math.PI))
}

// An obstacle's size right now.
//
// Stored for everything except the Sentinel, whose height is the
// corridor's whole span: it crosses from the floor to the ceiling, so it
// opens and closes with the world instead of being a bar of its own.
// Nothing in the simulation reads that height — the beam forbids
// *moving*, not standing anywhere — so it is the drawing's number, kept
// here because that is where an obstacle's geometry lives.
get_obstacle_size :: proc(obstacle: Obstacle, world: World) -> rl.Vector2 {
	if obstacle.obstacle_type != .Sentinel {
		return obstacle.size
	}
	time_until_arrival := obstacle.arrival_time - world.elapsed_time
	x := core.WORLD_ANCHOR_X + time_until_arrival * world.scroll_speed
	_, span := get_track_at_x(world, x)
	return rl.Vector2{SENTINEL_BEAM_WIDTH, max(span - SENTINEL_CLEARANCE, 0)}
}

// Computes the obstacle's current on-screen position, derived from how
// much time remains until (or has passed since) its arrival_time.
//
// The world scrolls; obstacles do not move through it. y comes from the
// track, so an obstacle sits on the surface of its own lane however the
// corridor is bending underneath it — and a Sentinel rides the spine,
// which is the only thing it can do and still mean "the middle".
get_obstacle_position :: proc(obstacle: Obstacle, world: World) -> rl.Vector2 {
	time_until_arrival := obstacle.arrival_time - world.elapsed_time
	x := core.WORLD_ANCHOR_X + time_until_arrival * world.scroll_speed
	size := get_obstacle_size(obstacle, world)

	if obstacle.obstacle_type == .Sentinel {
		// It grows out of its own lane toward the other, so on the floor
		// the box's *bottom* is the surface and on the ceiling its top is.
		surface := get_surface_y(world, obstacle.lane, x)
		return rl.Vector2{x, obstacle.lane == .Real ? surface - size.y : surface}
	}

	y := get_lane_y(world, obstacle.lane, x, size)

	// A lift is measured into the corridor, so it is upward on the floor
	// and downward from the ceiling. Same number, mirrored, which is what
	// keeps "it is high and you go under it" true in both worlds.
	lift := get_cube_lift(obstacle, world)
	y += obstacle.lane == .Real ? -lift : lift

	return rl.Vector2{x, y}
}

get_obstacle_rect :: proc(obstacle: Obstacle, world: World) -> rl.Rectangle {
	position := get_obstacle_position(obstacle, world)
	size := get_obstacle_size(obstacle, world)
	return rl.Rectangle{position.x, position.y, size.x, size.y}
}

// Extra distance past the left edge an obstacle must travel before it is
// discarded. Nothing needs the margin — it is slack, so that a future
// change to how far left something is drawn (a trailing particle, a
// shadow) cannot silently start culling things that are still visible.
OBSTACLE_CULL_MARGIN :: 200

// True once an obstacle can no longer affect anything.
//
// Position alone is the whole test now. It used to also wait for the
// near-miss to have been counted, and that condition went with the
// Lucidity it fed (roadmap R1.2).
is_obstacle_finished :: proc(obstacle: Obstacle, world: World) -> bool {
	position := get_obstacle_position(obstacle, world)
	return position.x + obstacle.size.x < -OBSTACLE_CULL_MARGIN
}

// Drops obstacles that are finished with, keeping the list from growing
// for the whole length of a run — without it a five-minute run leaves a
// few hundred dead entries to be walked on every single step.
//
// Compacts the whole list rather than dropping a finished prefix, because
// finished obstacles do not arrive in order: gaps are up to two and a
// half times as wide as a cube, so a newer but narrow obstacle can leave
// the screen before an older but wide one. A prefix scan would stop at
// the first survivor and leak everything behind it.
//
// Survivors keep their original order. Nothing downstream depends on that
// today, but obstacles are generated in ascending arrival_time and quietly
// scrambling it would be an unpleasant surprise for anything that later
// assumes it.
remove_finished_obstacles :: proc(obstacles: ^[dynamic]Obstacle, world: World) {
	kept := 0
	for index in 0 ..< len(obstacles) {
		if !is_obstacle_finished(obstacles[index], world) {
			obstacles[kept] = obstacles[index]
			kept += 1
		}
	}
	resize(obstacles, kept)
}
