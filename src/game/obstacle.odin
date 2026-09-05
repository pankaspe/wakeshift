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
* THE CUBE IS A SKYLINE, AND THE SKYLINE IS DATA
*
* Everything the design asks of the obstacle set is a run of columns on a
* lane, and the pattern authors the numbers: CubeProfile is the whole
* vocabulary and this file knows the name of no shape at all. What a
* column does — stop the body, hold it up, or be drawn — is answered in
* one place, get_cube_column, so the three readers cannot disagree.
*
* **"The width is the price" is the design's intent and not currently the
* game's behaviour.** Measured by replay when the unit was halved: every
* shape costs the same ground as every other, because what is actually
* charged is the time spent pinned, and the two ways out of a pin — one
* flip to the free lane, or a landing on top of the box — are both width-
* independent. Shapes differ today in what they *say*, not in what they
* take. See CUBE_UNIT below for the numbers.
*
* What the profile did change is that a shape can now be *entered*. A
* staircase has a low step that is really a step: land on it and the wall
* becomes the next column along, which is a thing no version of the six
* forms could express, because they all collided as one filled box.
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

// A CUBE IS A SKYLINE, AND THE SKYLINE IS DATA
//
// A cube is a run of columns, each CUBE_UNIT wide, each a whole number of
// units tall. The pattern authors the numbers; nothing here knows the
// name of a shape. `{1, 2, 3}` is a staircase, `{3, 0, 3}` is two towers
// with a canyon between them, `{1}` is the primitive.
//
// It replaced a six-entry enum whose shapes were welded into three
// different files — the box in get_cube_size, the staircase in
// render/terrain.odin, and nothing at all in the collision, which is the
// part that mattered: the pyramid was *drawn* as steps and *collided* as
// its bounding box, so the low step it showed you could not be stood on.
// One profile read by all three is what makes the mark and the hitbox the
// same thing, which is the rule the rest of the renderer already keeps.
//
// **A zero is a column that is not there**, and it is a legal thing to
// author: the skyline drops to the lane's own surface and comes back. It
// is not the same as a hole — the ground is still there to stand on.
//
// The old vocabulary is now four literals and one deletion. Standard is
// {1}, Wide {1,1}, Stack {3}, Pyramid {1,2,3}; Float stopped being a
// shape at all and became `floating`, which is orthogonal and always
// should have been. Small is gone: it was half a unit, and the halving in
// T2 left it a fragment of a column rather than an arrangement of them —
// at the current unit a single column *is* the bump it was there to be.
CubeProfile :: []u8

// What an event gets when it says nothing about its cube.
PROFILE_PRIMITIVE := CubeProfile{1}

// The shapes that earned a name, so a pattern reads as prose where it
// wants to and as numbers where it has something particular to say.
PROFILE_WIDE := CubeProfile{1, 1}
PROFILE_STACK := CubeProfile{3}
PROFILE_PYRAMID := CubeProfile{1, 2, 3}

// The bounds validate_pattern_pool holds an authored profile inside.
//
// **Height is the one with teeth.** An obstacle belongs to a lane, and
// blocks_player only ever tests the lane it stands on — so a floor cube
// tall enough to reach a body hanging from the ceiling would pass
// straight through them without stopping them, which is a mark that lies
// about what it does. The corridor is never narrower than TRACK_SPAN_MIN,
// so the tallest column that always clears a body on the far lane is
// (250 - 45) / 27 = 7.6 units.
//
// Seven is therefore the answer and it is **tight, not comfortable**:
// replayed against a body hanging from the ceiling at TRACK_SPAN_MIN, a
// seven-unit column leaves 16 px of daylight and an eight-unit one
// overlaps it by 11. There is no room here for a shape that is "only a
// bit taller".
//
// Width is a softer bound and is here to keep the lane's polyline inside
// STROKE_MAX_POINTS: a column costs two vertices, so eight columns make a
// cube 18 points instead of 4, and a screen tiled with the widest legal
// cubes comes to about 123 against a cap of 256 (render/stroke.odin).
CUBE_MAX_COLUMNS :: 8
CUBE_MAX_HEIGHT :: 7

// A FLOATING CUBE ORBITS
//
// It rises and falls off the surface of its lane, and it drifts along the
// lane at the same time, on one clock: lift is CUBE_FLOAT_LIFT/2 *
// (1 - cos), drift is CUBE_FLOAT_DRIFT * sin, both of the same angle. Two
// axes at one frequency and a quarter turn apart is an **ellipse**, so
// the cube travels a closed orbit rather than doing two unrelated things,
// which is what keeps it learnable (pillar 3): watch it once and you know
// where it will be.
//
// The lift is comfortably over the player's own height, so at the top of
// its travel the box is entirely clear of the body and the character
// runs under it (over it, hanging from the ceiling — same picture with
// the mirror applied). Anything under PLAYER_SIZE blocks.
//
// **Where the phases sit is load-bearing twice, and neither is taste.**
//
// The drift is zero at the top and the bottom of the orbit, so the cube
// is at exactly the x its pattern authored at both moments the author
// cares about — fully down and blocking, fully up and open. The arrival
// time keeps meaning what it meant.
//
// And the cube never closes on the player faster than the world *while it
// is able to block*. Its horizontal velocity is CUBE_FLOAT_DRIFT * 2pi /
// PERIOD * cos, which is at its most positive — moving right, away from a
// player it is approaching from the right — exactly where the lift is
// least, which is the only place it can touch anybody. That matters
// because the pin's pushback is capped at one step's scroll
// (advance_ground): a face closing faster than the world would eat into
// the body instead of pushing it, and the overlap would never close.
//
// **Measured, and it is tight rather than comfortable.** Swept over both
// lanes and forty phases: the fastest a face approaches while blocking is
// 260.3 px/s against a scroll of 270, so the cap has 9.7 px/s of margin;
// anywhere in the orbit, blocking or not, it peaks at 427.2. Replayed
// against a real pin, a body caught from the side takes 0 px of
// interpenetration over 214 pinned steps.
//
// That margin is **borrowed from CUBE_FLOAT_LIFT being well over the
// body**, and the two constants are coupled because of it. Blocking stops
// at lift = PLAYER_SIZE, which at a lift of 96 is cos = 0.0625 — still
// positive, which is the whole property. Drop the lift toward the body's
// own height and that angle goes past the quarter turn, cos goes
// negative, and the cube starts closing faster than the world. Re-measure
// this if either number moves.
CUBE_FLOAT_LIFT :: 96
CUBE_FLOAT_DRIFT :: 40
CUBE_FLOAT_PERIOD :: 1.6

// The drift may never outrun the world, or the cube would swim upstream:
// a shape crossing the screen rightward reads as another object entirely,
// and it could re-enter a player it had already passed. The bound is the
// slowest a run ever scrolls, so it holds for the whole game.
#assert(CUBE_FLOAT_DRIFT * 2 * math.PI / CUBE_FLOAT_PERIOD < INITIAL_SCROLL_SPEED)

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

	// Cube only. The profile is the shape; floating says whether it rests
	// on its lane or bobs off it, and the phase decides where in that bob
	// it is at the moment it reaches the anchor — so a pattern can author
	// "this one blocks" and "this one you go under" out of the same
	// obstacle.
	//
	// The profile is a slice of the pattern's own static data, never
	// allocated and never owned, so an Obstacle stays a plain value that
	// can be copied and compacted like any other.
	profile:      CubeProfile,
	floating:     bool,
	float_phase:  f32,
}

// A cube's profile, with the empty one resolved to the primitive. Every
// reader goes through this, so "says nothing" means one thing everywhere.
get_cube_profile :: proc(obstacle: Obstacle) -> CubeProfile {
	return len(obstacle.profile) > 0 ? obstacle.profile : PROFILE_PRIMITIVE
}

// One column of a skyline, in screen coordinates.
CubeColumn :: struct {
	rect:    rl.Rectangle, // the box it occupies; zero-height if the column is absent
	contact: f32, // the edge a body meets it at: its top on the floor, its bottom on the ceiling
}

// Column `index` of a cube, given the obstacle's own bounding box —
// which every caller already has, so the track is not resampled per
// column.
//
// The far edge of the box is what the columns grow from: for a cube
// standing on its lane that is the lane's surface, and for a floating one
// it is the underside of the box. So a lifted cube needs no special case
// here — its single column is the box itself, and a body can land on top
// of it exactly as it can on ground.
get_cube_column :: proc(obstacle: Obstacle, rect: rl.Rectangle, index: int) -> CubeColumn {
	profile := get_cube_profile(obstacle)
	height := f32(profile[index]) * CUBE_UNIT
	if obstacle.floating {
		height = rect.height
	}

	is_floor := obstacle.lane == .Real
	base := is_floor ? rect.y + rect.height : rect.y
	contact := is_floor ? base - height : base + height

	return CubeColumn {
		rect = rl.Rectangle {
			rect.x + f32(index) * CUBE_UNIT,
			min(contact, base),
			CUBE_UNIT,
			height,
		},
		contact = contact,
	}
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

// The box a profile stands in, before its lane decides which way up it
// is: as wide as it has columns, as tall as its tallest one.
//
// It is the *bounding* box, and since the profile arrived it is no longer
// the hitbox — a skyline with a short column has air inside this
// rectangle that nothing collides with. It stays because the position,
// the culling and the fairness windows all reason about where a whole
// obstacle is, and because get_cube_column measures the columns from its
// far edge.
get_cube_size :: proc(profile: CubeProfile) -> rl.Vector2 {
	columns := len(profile) > 0 ? profile : PROFILE_PRIMITIVE

	tallest: u8 = 0
	for height in columns {
		tallest = max(tallest, height)
	}
	return rl.Vector2{f32(len(columns)) * CUBE_UNIT, f32(tallest) * CUBE_UNIT}
}

// The widest this event can ever turn out to be. Used by the fairness
// check, which has to reason about a pattern before its random choices
// have been made.
get_max_width :: proc(obstacle_type: ObstacleType, profile: CubeProfile) -> f32 {
	switch obstacle_type {
	case .Gap:
		return GAP_WIDTH_LONG
	case .Cube:
		return get_cube_size(profile).x
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
	profile: CubeProfile,
	floating: bool,
	float_phase: f32,
	rng: rand.Generator,
) -> Obstacle {
	size := get_cube_size(profile)

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
	// the profile already gave us the box
	}

	return Obstacle {
		arrival_time = arrival_time,
		lane = lane,
		size = size,
		obstacle_type = obstacle_type,
		profile = profile,
		floating = floating,
		float_phase = float_phase,
	}
}

// How far a floating cube currently stands off the surface of its lane.
// Zero for every cube that rests on it.
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
	if obstacle.obstacle_type != .Cube || !obstacle.floating {
		return 0
	}
	return CUBE_FLOAT_LIFT * 0.5 * (1 - math.cos(cube_orbit_angle(obstacle, world)))
}

// How far along its lane a floating cube has drifted from the x its
// pattern authored. Zero for every cube that rests on the surface.
//
// The other half of the orbit above, on the same clock and a quarter turn
// out of phase, so the two are one motion rather than two. Positive is
// toward the right of the screen, which is *later*: a cube drifting
// forward arrives after its own arrival_time, and one drifting back
// arrives before it. That is the whole of why the fairness windows have
// to be widened by this amplitude (event_window in pattern.odin) — an
// obstacle that moves in x changes when it reaches you, so two events
// that never overlap where they were authored can overlap where they
// actually are.
get_cube_drift :: proc(obstacle: Obstacle, world: World) -> f32 {
	if obstacle.obstacle_type != .Cube || !obstacle.floating {
		return 0
	}
	return CUBE_FLOAT_DRIFT * math.sin(cube_orbit_angle(obstacle, world))
}

// Where a floating cube is in its orbit, in radians.
//
// A function of the obstacle's **own age** and its authored phase, never
// of the global clock — so the same pattern presents the same face every
// time it is generated, and the display can evaluate it a fraction of a
// step ahead and get the answer the simulation would.
@(private)
cube_orbit_angle :: proc(obstacle: Obstacle, world: World) -> f32 {
	age := world.elapsed_time - obstacle.arrival_time
	return (age / CUBE_FLOAT_PERIOD + obstacle.float_phase) * 2 * math.PI
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

	// The drift is part of where the cube *is*, so it is added before the
	// ground is sampled: a floating cube reads the surface under the x it
	// has drifted to, not the one it was authored at.
	x := core.WORLD_ANCHOR_X + time_until_arrival * world.scroll_speed
	x += get_cube_drift(obstacle, world)
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
