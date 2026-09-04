/*
* Particles
* A fixed pool of short-lived marks, and nothing else. It knows what a
* position, a velocity and a colour are; it does not know that a game is
* what is emitting into it (the golden rule for this package).
*
* Brought forward from phase R7 by RL.6, which needs it for the one thing
* the art direction turned from a filter into a mark: the world's line
* fraying away behind the Corruption's front.
*
* THE POOL IS FIXED AND PRE-ALLOCATED
*
* No allocation ever happens here, at any frame rate, for any number of
* emitters. The live particles occupy the front of the array and a dead
* one is filled by swapping the last live particle into its slot, which
* is why nothing in here may ever depend on the order they are in. An
* emission that would overflow the pool is dropped rather than growing
* it: dust that is not there is invisible, and a frame that allocates is
* a hitch the player can feel.
*
* IT IS PRESENTATION, AND IT HAS ITS OWN RANDOMNESS
*
* Everything here runs on the frame clock and may never reach the
* simulation. The randomness is therefore the pool's own generator,
* seeded once and threaded like every other generator in the project —
* not the global rand, and deliberately not the run's, which has to stay
* reproducible from a seed for the replay and the score to mean anything
* (CLAUDE.md, "Save data and determinism"). Dust that differs between two
* replays of the same run is correct; a run that differs because of dust
* would be a bug.
*
* THE INTEGRATION IS EXACT, NOT STEPPED
*
* Drag is an exponential, so both the velocity and the distance it covers
* are closed forms. A particle therefore lands in the same place at 30 fps
* as at 240, which is not vanity: the pool is advanced from the frame
* clock, and a per-frame multiply would make the dust thicker on a fast
* machine.
*/
package fx

import "core:math"
import "core:math/rand"
import rl "vendor:raylib/v55"

// How many marks can be alive at once. Measured against the worst case
// RL.6 asks for — two streams at their most insistent, about 180 alive —
// with room for whatever phase R7 adds on top.
PARTICLE_CAPACITY :: 512

// How many independent emitters can keep a fractional debt. Each stream
// carries the part of a particle it was owed last frame, so a rate of
// 40/s still emits at 240 fps instead of rounding to nothing every frame.
PARTICLE_STREAMS :: 4

// Below this, drag is treated as zero rather than dividing by it.
PARTICLE_MIN_DRAG :: 1e-3

Particle :: struct {
	position: rl.Vector2,
	velocity: rl.Vector2,
	drag:     f32,
	age:      f32,
	life:     f32,
	size:     f32,
	color:    rl.Color,
}

// What one stream of dust looks like. Every jitter is a half-range around
// the mean, so a spec with all of them at zero emits identical particles.
Emitter :: struct {
	origin:      rl.Vector2,
	spread:      rl.Vector2, // how far the origin is jittered
	velocity:    rl.Vector2, // the mean drift, in px/s
	scatter:     rl.Vector2, // how far the drift is jittered
	drag:        f32, // 1/s; how fast the drift dies away
	rate:        f32, // particles per second
	life:        f32,
	life_jitter: f32,
	size:        f32,
	size_jitter: f32,
	color:       rl.Color,
}

Particles :: struct {
	pool:  [PARTICLE_CAPACITY]Particle,
	count: int,
	debt:  [PARTICLE_STREAMS]f32,
	rng:   rand.Default_Random_State,
}

// The seed is a constant: there is nothing to reproduce, and a pool that
// looked different every launch would make a screenshot impossible to
// compare against another one.
PARTICLE_SEED :: 0x5EED_D057

new_particles :: proc() -> Particles {
	return Particles{rng = rand.create(PARTICLE_SEED)}
}

// Empties the pool. Called when a run starts, so the last run's dust does
// not arrive with the new one.
clear_particles :: proc(particles: ^Particles) {
	particles.count = 0
	particles.debt = {}
}

@(private)
jitter :: proc(particles: ^Particles, half_range: f32) -> f32 {
	if half_range == 0 {
		return 0
	}
	generator := rand.default_random_generator(&particles.rng)
	return (rand.float32(generator) * 2 - 1) * half_range
}

// Runs one emitter for one frame's worth of time.
//
// `stream` is which fractional debt this emitter keeps. Two emitters
// sharing a stream index is not an error, it just means they share the
// rounding; a caller with more than PARTICLE_STREAMS of them should raise
// the constant rather than reuse an index by accident.
emit :: proc(particles: ^Particles, stream: int, emitter: Emitter, dt: f32) {
	if dt <= 0 || emitter.rate <= 0 || stream < 0 || stream >= PARTICLE_STREAMS {
		return
	}

	particles.debt[stream] += emitter.rate * dt
	for particles.debt[stream] >= 1 {
		particles.debt[stream] -= 1
		if particles.count >= PARTICLE_CAPACITY {
			particles.debt[stream] = 0
			return
		}

		particles.pool[particles.count] = Particle {
			position = emitter.origin +
			rl.Vector2{jitter(particles, emitter.spread.x), jitter(particles, emitter.spread.y)},
			velocity = emitter.velocity +
			rl.Vector2{jitter(particles, emitter.scatter.x), jitter(particles, emitter.scatter.y)},
			drag = emitter.drag,
			life = max(emitter.life + jitter(particles, emitter.life_jitter), 0.05),
			size = max(emitter.size + jitter(particles, emitter.size_jitter), 0.5),
			color = emitter.color,
		}
		particles.count += 1
	}
}

// Advances the pool by one frame and retires whatever has finished.
//
// Exact under exponential drag: the velocity decays by exp(-drag*dt) and
// the distance covered is its integral, so the result does not depend on
// how the frame was cut up.
update_particles :: proc(particles: ^Particles, dt: f32) {
	if dt <= 0 {
		return
	}

	index := 0
	for index < particles.count {
		particle := &particles.pool[index]
		particle.age += dt

		if particle.age >= particle.life {
			// Swap-remove: the last live particle fills the hole, and this
			// slot is examined again rather than skipped.
			particles.count -= 1
			particles.pool[index] = particles.pool[particles.count]
			continue
		}

		if particle.drag > PARTICLE_MIN_DRAG {
			decay := math.exp(-particle.drag * dt)
			particle.position += particle.velocity * (1 - decay) / particle.drag
			particle.velocity *= decay
		} else {
			particle.position += particle.velocity * dt
		}
		index += 1
	}
}

// Draws the pool additively, each particle fading and shrinking over its
// life.
//
// One circle each, with no halo of its own: the frame's bloom is what
// makes them glow, the same resolution CLAUDE.md reaches for every time a
// primitive halo and a real one end up doing the same job. That also
// keeps a full pool at 512 draw calls rather than 2 500.
draw_particles :: proc(particles: Particles) {
	if particles.count == 0 {
		return
	}

	rl.BeginBlendMode(.ADDITIVE)
	for index in 0 ..< particles.count {
		particle := particles.pool[index]
		remaining := 1 - particle.age / particle.life

		color := particle.color
		color.a = u8(f32(particle.color.a) * remaining * remaining)
		rl.DrawCircleV(particle.position, particle.size * (0.4 + 0.6 * remaining), color)
	}
	rl.EndBlendMode()
}
