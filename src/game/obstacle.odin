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
* Two types here, and the design has a third coming (the Sentinel, R4.4).
* They split on the design doc's own axis (section 6):
*
*   the Cube   something that is *there*. In R1 it still kills on
*              contact; from R2.3 it stops killing and starts costing
*              ground, which is the whole point of the rewrite and the
*              reason it is the only obstacle allowed on both lanes at
*              once.
*   the Gap    the lane failing to be there. It kills only whoever is
*              still resting on that lane when it passes, so being
*              mid-flip answers it as completely as being on the other
*              lane does (see collision.odin).
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
import "core:math/rand"
import rl "vendor:raylib/v55"

// Obstacle reference size in pixels — same footprint as the player.
OBSTACLE_SIZE :: 54

ObstacleType :: enum {
	Cube, // either lane, full: sticks out into the lane
	Gap, // either lane: the surface is simply not there
}

// True for the type that is an *absence* rather than a thing. It is also
// exactly the set the terrain draws rather than draw_obstacle: only the
// code that knows where its own surface is can cut a hole in it.
is_gap :: proc(obstacle_type: ObstacleType) -> bool {
	return obstacle_type == .Gap
}

Obstacle :: struct {
	arrival_time:  f32, // world.elapsed_time value at which this obstacle reaches PLAYER_X
	lane:          core.Lane,
	size:          rl.Vector2,
	obstacle_type: ObstacleType,
}

// Gap width variants. Picked randomly at creation — flavour, and the one
// random choice left in an obstacle, so a pattern still knows exactly
// what it is asking of the player. GAP_WIDTH_LONG is what
// validate_pattern_pool checks against, since it is the worst case.
GAP_WIDTH_SHORT :: OBSTACLE_SIZE * 1.2
GAP_WIDTH_MEDIUM :: OBSTACLE_SIZE * 1.9
GAP_WIDTH_LONG :: OBSTACLE_SIZE * 2.6

// The widest this type can ever turn out to be. Used by the fairness
// check, which has to reason about a pattern before its random choices
// have been made.
get_max_width :: proc(obstacle_type: ObstacleType) -> f32 {
	return obstacle_type == .Gap ? GAP_WIDTH_LONG : OBSTACLE_SIZE
}

// Creates an obstacle that will arrive at the player's x position at the
// given time.
//
// Takes the caller's random generator rather than reaching for the global
// one: every random choice a run makes has to come from the run's own
// seed to stay reproducible (see PatternGenerator in pattern.odin).
new_obstacle :: proc(
	arrival_time: f32,
	lane: core.Lane,
	obstacle_type: ObstacleType,
	rng: rand.Generator,
) -> Obstacle {
	width: f32 = OBSTACLE_SIZE
	if obstacle_type == .Gap {
		roll := rand.float32(rng)
		switch {
		case roll < 0.4:
			width = GAP_WIDTH_SHORT
		case roll < 0.75:
			width = GAP_WIDTH_MEDIUM
		case:
			width = GAP_WIDTH_LONG
		}
	}

	return Obstacle {
		arrival_time = arrival_time,
		lane = lane,
		size = rl.Vector2{width, OBSTACLE_SIZE},
		obstacle_type = obstacle_type,
	}
}

// An obstacle's size right now.
//
// Nothing animates yet, so this is the stored size — but the world stays
// in the signature because the floating cube (roadmap R4.2) makes it a
// function of the obstacle's *own* age again. That rule is worth stating
// where it will be read: an animation driven by the global clock presents
// a different face every time the same pattern is generated, so the
// author cannot say what the player will face and the player cannot
// learn it.
get_obstacle_size :: proc(obstacle: Obstacle, world: World) -> rl.Vector2 {
	return obstacle.size
}

// Computes the obstacle's current on-screen position, derived from how
// much time remains until (or has passed since) its arrival_time.
//
// The world scrolls; obstacles do not move through it. y comes from the
// terrain, so an obstacle sits on the surface of its own lane however
// uneven that surface is.
get_obstacle_position :: proc(obstacle: Obstacle, world: World) -> rl.Vector2 {
	time_until_arrival := obstacle.arrival_time - world.elapsed_time
	x := core.PLAYER_X + time_until_arrival * world.scroll_speed
	size := get_obstacle_size(obstacle, world)
	return rl.Vector2{x, core.get_lane_y(get_ground(world), obstacle.lane, x, size)}
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
