/*
* Pierce Render
* The two marks a wall gets when the Dream goes through it: the flash, and
* the wake.
*
* The flash is here; the wake is drawn with the maze it belongs to
* (render/maze.odin), because a pierced wall is a piece of the world's
* line rather than an effect, and it has to be welded, clipped and
* scrolled with the rest of it.
*
* WHY THERE WAS NOTHING TO SEE, AND WHY THAT WAS THE BUG
*
* The mechanic worked from the day it landed and read as a glitch, and the
* reason is that nothing marked the event. In a screen of walls, one wall
* quietly ceasing to exist is not an event — it is indistinguishable from
* the wall never having been there, which is exactly what the maze is full
* of. What was missing was not a better effect, it was *any* statement
* that something happened at a place.
*
* THE FLASH IS WARM AND THE WAKE IS COLD, AND THAT IS THE SENTENCE
*
* The ring is drawn in the body's own colour, because it marks something
* **you did** and the warm hue is the one the eye is already tracking. The
* wake is the world's light, dimmed and broken, because it is what the
* world was left like afterwards. An act and a consequence, told apart the
* way the palette tells anything apart.
*/
package render

import "../core"
import "../fx"
import "../game"
import rl "vendor:raylib/v55"

// The ring. It starts a little wider than nothing so the first frame is
// already a ring rather than a dot, and it stops a bit under a cell —
// wide enough to own the wall it came from, narrow enough not to reach
// into the corridor beyond it.
PIERCE_RING_LIFE :: 0.36
PIERCE_RING_FROM :: 7
PIERCE_RING_TO :: 46
PIERCE_RING_THICKNESS :: 4.0
PIERCE_RING_ALPHA :: 0.85

// The shards. They leave along the axis the body was travelling, both
// ways, because a wall that is gone through breaks *forwards* with the
// body and *backwards* against it.
PIERCE_SHARD_COUNT :: 18
PIERCE_SHARD_SPEED :: 130
PIERCE_SHARD_SPREAD :: 26 // along the wall, which is how long the wall is
PIERCE_SHARD_DRAG :: 5.5
PIERCE_SHARD_LIFE :: 0.38
PIERCE_SHARD_SIZE :: 2.2
PIERCE_SHARD_ALPHA :: 0.9

// Marks the wall the body has just gone through.
//
// Called from main when the run's pierce count changed across a frame's
// steps, which is how presentation learns that an *instant* happened
// (game/player.odin). Everything here is on the frame clock and none of
// it is ever read back.
emit_pierce :: proc(
	particles: ^fx.Particles,
	rings: ^fx.Rings,
	player: game.Player,
	world: game.World,
	palettes: core.PaletteSet,
) {
	a, b := game.wall_segment(player.pierce_col, player.pierce_row, player.pierce_dir)
	midpoint := (a + b) * 0.5

	// The ring keeps its world x and is put on screen at draw time, so it
	// stays on the wall while the wall scrolls (fx/rings.odin).
	fx.spawn_ring(
		rings,
		fx.Ring {
			world_x = midpoint.x,
			y = midpoint.y,
			life = PIERCE_RING_LIFE,
			from_radius = PIERCE_RING_FROM,
			to_radius = PIERCE_RING_TO,
			thickness = PIERCE_RING_THICKNESS,
			color = core.with_alpha(palettes.actor_figure, PIERCE_RING_ALPHA),
		},
	)

	// The shards are dust and dust is emitted in screen space, which is
	// what the pool already assumes. Over PIERCE_SHARD_LIFE the world moves
	// a fraction of a cell, so the two marks do not visibly disagree.
	screen := rl.Vector2{game.maze_screen_x(midpoint.x, world.camera_x), midpoint.y}

	// Along the travel axis, and spread along the wall itself. A vertical
	// wall is gone through horizontally and the other way round, so the
	// two vectors are simply swapped.
	vertical_wall :=
		player.pierce_dir == .Left || player.pierce_dir == .Right
	away :=
		vertical_wall \
		? rl.Vector2{PIERCE_SHARD_SPEED, 0} \
		: rl.Vector2{0, PIERCE_SHARD_SPEED}
	along :=
		vertical_wall \
		? rl.Vector2{4, PIERCE_SHARD_SPREAD} \
		: rl.Vector2{PIERCE_SHARD_SPREAD, 4}

	fx.burst(
		particles,
		fx.Emitter {
			origin = screen,
			spread = along,
			// Zero mean with a scatter the size of the speed: the shards
			// go both ways along the axis instead of all one way, which is
			// what a wall breaking looks like and what a drift would not.
			scatter = away + rl.Vector2{6, 6},
			drag = PIERCE_SHARD_DRAG,
			life = PIERCE_SHARD_LIFE,
			life_jitter = 0.12,
			size = PIERCE_SHARD_SIZE,
			size_jitter = 0.8,
			color = core.with_alpha(palettes.actor_figure, PIERCE_SHARD_ALPHA),
		},
		PIERCE_SHARD_COUNT,
	)
}
