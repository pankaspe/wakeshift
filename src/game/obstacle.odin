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
* Two types, two verbs (Design Doc, section 6):
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
* **"The width is the price" is the design's intent and not currently the
* game's behaviour.** Measured by replay when the unit was halved: every
* form costs the same ground as every other, because what is actually
* charged is the time spent pinned, and the two ways out of a pin — one
* flip to the free lane, or a landing on top of the box — are both width-
* independent. The forms differ today in what they *say*, not in what
* they take. See CUBE_UNIT below for the numbers.
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
// of boxes this size.
//
// **It is smaller than the character, and that is the point.** It used to
// be 54, a hair over the body's 45, so one unit was already a wall and a
// shape made of them could only ever be a bigger wall. At 27 the unit is
// a building block rather than an obstacle: it takes two to reach the
// body's width, so a *shape* is what threatens and a single one is a
// bump. That is what buys the column profiles the next step is about.
//
// Nothing that is not literally a cube is measured in it any more. The
// hole's widths and the mirrored pair's bounds used to be multiples of
// this constant and were never really about it — one is about the
// corridor, the other about the body — so they are absolute now and this
// number can move without dragging them along.
//
// **Halving it did not halve what a block costs, and that was the thing
// worth measuring.** Replayed against the real simulation at 54 and at
// 27, a lone cube costs the same at both: 9 pinned steps and 40.5 px for
// a player who takes 0.15 s to answer it, 2205 px for one who never
// presses, and 4.5 px — one step's scroll — for one who answers at once.
// The price of a block is **how long you stay**, and nothing else; width
// only ever entered through the mirrored pair, where it no longer does
// either (see MIRROR_MAX_WIDTH in pattern.odin).
//
// What it did change is how long a lane is held. A cube threatens a body
// at the anchor for (width + PLAYER_SIZE) / speed, so the primitive fell
// from 0.37 s to 0.27 s at the opening speed. Over 8 seeds × 120 s of the
// real pool with no player, that moved "at least one lane is threatened"
// from 16.5% of the time to 13.1%. The holes did not move at all —
// "at least one lane is lethal" is 3.7% on both sides of the change,
// which is the decoupling above doing exactly what it was for.
CUBE_UNIT :: 27

ObstacleType :: enum {
	Cube, // either lane: sticks out into it and blocks
	Gap, // either lane: the surface is simply not there
}

// The cube vocabulary (Design Doc, section 6). Standard is first so that
// it is the zero value: a pattern event that says nothing about its cube
// gets the primitive.
// Sizes in brackets are what each form comes to at the current unit. Two
// of them are worth reading twice: Standard is now well under the body's
// 45 px, so the primitive on its own is a bump, and Wide is exactly what
// Standard used to be — which is why the mirrored pair, whose whole
// subject is width, was moved onto it.
//
// Small is the one form the halving leaves stranded: at 13 px it is no
// longer an arrangement of unit boxes but a fragment of one, and it is
// the obvious thing for the column profiles of the next step to absorb.
CubeForm :: enum {
	Standard, // one unit square [27] — the primitive, and a bump on its own
	Small, // half a unit [13]: stranded below the unit, see above
	Wide, // two units of width [54], which is two units of price
	Stack, // one wide, three tall [27x81]: costs what it is wide, looks worse
	Pyramid, // three wide and stepped [81x81]: says in advance which side to be on
	Float, // bobs in and out of the body's band [27] — the one timing cube
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

// True for the type that is an *absence* rather than a thing. It is also
// exactly the set the terrain draws rather than draw_obstacle: only the
// code that knows where its own surface is can cut a hole in it.
is_gap :: proc(obstacle_type: ObstacleType) -> bool {
	return obstacle_type == .Gap
}

// True for the type that ends a run outright, as opposed to the one that
// costs ground. It is what the fairness rule is written in terms of
// (pattern.odin): two *lethal* lanes at once is unanswerable, while two
// blocked lanes is a choice about which price to pay.
is_lethal :: proc(obstacle_type: ObstacleType) -> bool {
	return obstacle_type == .Gap
}

// True for the type that costs ground instead of the run.
blocks_lane :: proc(obstacle_type: ObstacleType) -> bool {
	return obstacle_type == .Cube
}

Obstacle :: struct {
	arrival_time: f32, // world.elapsed_time at which this obstacle reaches WORLD_ANCHOR_X
	lane:         core.Lane,
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
//
// **Absolute pixels, deliberately not multiples of CUBE_UNIT.** They were
// 1.2 / 1.9 / 2.6 units back when the unit was 54, which is where these
// three numbers come from — but a hole is the corridor failing to be
// there, and it has nothing to do with how big a box is. Tying the two
// meant the unit could not move without resizing every hole in the game,
// which is exactly what stood in the way of shrinking it.
//
// What a hole is actually measured against is the body and the speed: at
// the opening 270 px/s the long one takes the floor away for 140 / 270 =
// 0.52 s, and less as a run speeds up.
GAP_WIDTH_SHORT :: 65
GAP_WIDTH_MEDIUM :: 103
GAP_WIDTH_LONG :: 140

// The hole's box height. Nothing reads it: the terrain cuts a hole using
// the rect's x and width alone, and standing_over_gap tests the body's
// centre against the same two numbers. It exists because an Obstacle
// carries a size and this one has to be *something* — kept off CUBE_UNIT
// so that "how big is a box" and "how wide is a hole" stay unrelated.
GAP_HEIGHT :: 54

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
		size = rl.Vector2{width, GAP_HEIGHT}
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
get_obstacle_size :: proc(obstacle: Obstacle, world: World) -> rl.Vector2 {
	return obstacle.size
}

// Computes the obstacle's current on-screen position, derived from how
// much time remains until (or has passed since) its arrival_time.
//
// The world scrolls; obstacles do not move through it. y comes from the
// track, so an obstacle sits on the surface of its own lane however the
// corridor is bending underneath it.
get_obstacle_position :: proc(obstacle: Obstacle, world: World) -> rl.Vector2 {
	time_until_arrival := obstacle.arrival_time - world.elapsed_time
	x := core.WORLD_ANCHOR_X + time_until_arrival * world.scroll_speed
	size := get_obstacle_size(obstacle, world)

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
