/*
* Time
* The simulation's clock. The game advances in steps of one fixed length,
* never by however long the last frame happened to take.
*
* Why it matters beyond tidiness: with a variable timestep the same input
* at the same moment produces a slightly different result on every
* machine and every run, so a recorded run cannot be replayed and a
* server cannot revalidate a score (Design Doc, section 10). A fixed step
* is the third piece of that, alongside seeded generation and input as
* data — and the one the other two are useless without.
*
* Reproducibility, not precision, is what is required: f32 accumulation
* drifts, but it drifts *identically* given the same sequence of steps,
* which is all a replay needs.
*/
package core

// Simulation steps per second. 60 matches the frame rate the game has
// always targeted, so the feel is unchanged from when timing came
// straight off the display.
//
// The rate is the primary value and the step length is derived from it,
// not the other way round: a manifest records the rate a run was played
// at (core/manifest.odin), and that has to be an exact integer rather
// than something recovered from a float that never held exactly 1/60.
TICK_RATE :: 60

// Length of one simulation step, in seconds.
FIXED_TIMESTEP :: f32(1.0) / f32(TICK_RATE)

// Ceiling on how much real time one frame may contribute to the
// accumulator. Without it, a long stall — dragging the window, a
// breakpoint, the machine going to sleep — hands the loop a huge frame
// time, which becomes hundreds of catch-up steps, which takes even
// longer, which makes the next frame time larger still. Better to let
// the simulation fall behind real time than to spiral.
MAX_FRAME_TIME :: f32(0.25)
