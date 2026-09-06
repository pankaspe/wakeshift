/*
* World
* The camera, and the run's clock.
*
* THE CAMERA IS NOT THE PRESSURE ANY MORE, AND THAT IS THE WHOLE CHANGE
*
* It used to advance at a constant speed whether the player was making
* progress or not, which quietly made it the game's real threat: measured
* at the opening speed, the front took 10.8 px/s and the camera took 270
* for every second the body was not sliding right — 96% of the ground a
* player lost was the thing with no name on it. Two consequences followed
* and both were wrong:
*
*   - **going back cost more than it was worth.** Sliding a few cells left
*     to take the other branch is how a maze is *read*, and the camera
*     charged for it at full price on top of the ground itself.
*   - **a good run could not bank anything.** The most lead there could
*     ever be was one screen, because past a fixed screen x the camera
*     dragged the body along with it.
*
* So the camera stopped being a clock and went back to being a camera. It
* follows the body, forwards *and* backwards, and the Corruption advances
* through the world on its own (game/corruption.odin). Everything the
* design wanted falls out of the swap:
*
*   - the lead is measured in the world and is not bounded by the screen,
*     so a player who runs well pushes the front **off the picture** and
*     buys real seconds to read the maze with;
*   - going back costs exactly what it is worth and nothing more;
*   - the front arriving at the left edge becomes a legible *event*
*     instead of a permanent fixture, and it is the only warning the game
*     needs (pillar 3).
*
* WHY IT CHASES INSTEAD OF FOLLOWING
*
* A body that leaves at 900 px/s would drag the whole world with it in
* one jolt. The camera lags on an exact exponential, so a sustained slide
* holds the body a little ahead of where it rests and the world settles
* behind it — which is what reads as thrust. The lag is the animation;
* there is no other one.
*
* WHY THE CHASE IS IN THE SIMULATION
*
* It could be presentation: nothing about a camera decides a run, because
* death compares two *world* positions and the generator is driven off the
* body (game/corruption.odin, game/maze.odin). It is stepped anyway,
* because the maze is drawn against it and a camera advanced on the frame
* clock would put the walls in a slightly different place at 30 fps than
* at 240. Provably neutral is worth more here than architecturally pure.
*/
package game

import "../core"
import "core:math"

// Seconds for the camera to cover most of the distance to the body.
//
// Small enough that the body never approaches the edge of the picture,
// large enough that a slide reads as thrust: at this constant a sustained
// 900 px/s slide holds the body about 160 px ahead of where it rests, and
// it settles back within a fifth of a second of stopping.
CAMERA_LAG :: 0.18

World :: struct {
	// Where the camera's own origin sits in world x. Everything drawn goes
	// through maze_screen_x against this and nothing else, which is what
	// keeps the maze from sliding against the body drawn on it.
	camera_x:     f32,
	elapsed_time: f32, // seconds since this run started

	// Completed simulation steps. With a fixed timestep the step count
	// *is* the clock: unlike elapsed_time it carries no floating point
	// drift, so it is the stable way to say when something happened —
	// which is how a recorded input log indexes its events.
	tick:         u64,
}

// Where the camera wants to be for the body to sit at its resting place.
camera_target :: proc(player_world_x: f32) -> f32 {
	return MAZE_ORIGIN_X + player_world_x - f32(core.PLAYER_HOME_X)
}

new_world :: proc() -> World {
	return World{camera_x = camera_target(cell_centre_x(0))}
}

// The chase on its own, so a frame can run it over the leftover fraction
// of a step for drawing without touching the run's clock.
//
// Exact rather than stepped, the same closed form fx/particles.odin uses:
// the camera lands in the same place whatever the step size, so a frame
// that runs two steps and a frame that runs one do not drift apart.
advance_camera :: proc(world: ^World, delta_time: f32, player_world_x: f32) {
	k := 1 - math.exp(-delta_time / CAMERA_LAG)
	world.camera_x += (camera_target(player_world_x) - world.camera_x) * k
}

// Advances the camera and the run timer by exactly one simulation step.
//
// delta_time is always core.FIXED_TIMESTEP in the running game; it stays a
// parameter so a test can step the world at whatever rate it wants.
update_world :: proc(world: ^World, delta_time: f32, player_world_x: f32) {
	world.tick += 1
	advance_camera(world, delta_time, player_world_x)
	world.elapsed_time += delta_time
}
