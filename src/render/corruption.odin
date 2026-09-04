/*
* Corruption Render
* The left-hand front: where the world comes apart.
*
* Since RL.6 that is not a figure of speech and not a filter. The world
* is a line now, so the Corruption is **the line ceasing to be there** —
* the terrain is clipped at the front exactly the way it is clipped at
* the pen on the right (render/draw_front.odin), and the mark it makes is
* the line fraying into dust as it arrives (fx/particles.odin). A sign,
* not a filter (Design Doc, section 10).
*
* THE TWO FRONTS ARE A PAIR, AND THAT IS THE PICTURE
*
* On the right the pen writes the world; on the left it comes apart. Both
* are one x with a clip on it, which is what RL.2 bought by putting the
* obstacles inside the terrain's own polyline. Neither needs a per-object
* animation, and a shape straddling either front truncates itself.
*
* What they are not is the same *mark*. The pen is marked by absence plus
* a nib, because it threatens nothing; this one keeps its lit vertical
* edge, because it is lethal and pillar 2 wants a line nobody can miss.
*
* WHAT HAPPENED TO THE SHADER
*
* fx/corruption.odin drained everything behind the front to black, and it
* is still there and still compiles — it is switched off in main, in one
* line, and the roadmap asks for it to stay that way until a playtest says
* otherwise. Going to black came out of a playtest (R2.6), so it gets
* undone by another one rather than on paper. What made it necessary was
* that the world behind the front was still *drawn*: with the line clipped
* there is nothing left there to drain, only the field, and a field with no
* drawing on it is exactly what "the world is not here" looks like on
* paper.
*
* THE EDGE ITSELF
*
* Drawn in the world rather than filtered onto it, for two reasons.
*
* **Readability.** A gradient of falling saturation is a subtle thing on a
* dark picture, and what the player has to see in two seconds is not "the
* colour is a bit lower over there" but "the edge is *this* far away".
* Pillar 2 wants a line.
*
* **It must not depend on a shader.** If the desaturation pass fails to
* compile the game keeps running, and a lethal front nobody can see would
* be the one thing in this game that kills without showing the blow
* coming (pillar 3). This is drawn with primitives and cannot fail.
*
* What it deliberately is *not* is a wall. The design considered and
* rejected a solid chaser: in a game where you cannot run faster, a wall
* is a countdown in a costume. So this is an edge and a glow, and the
* mass on the far side of it stays whatever the world already was — only
* drained of colour.
*/
package render

import "../core"
import "../fx"
import "../game"
import rl "vendor:raylib/v55"

// The edge's own weight, and how far its halo reaches.
CORRUPTION_EDGE_THICKNESS :: 2.2
CORRUPTION_EDGE_SPREAD :: 26

// --- The fray ---
//
// How much dust each lane's line throws off as it arrives at the front,
// in particles per second. It grows with the pressure for the same reason
// the edge's brightness does: the same information twice, which is what a
// cue the player must not miss is allowed to do.
FRAY_RATE_BASE :: 40
FRAY_RATE_PRESSURE :: 70

// Where it goes. Mostly backwards into the void, and *outward* from the
// corridor — down from the floor, up from the ceiling — so the dust never
// drifts across the part of the screen the game is played in (art
// direction, decision 3).
FRAY_DRIFT_BACK :: 30
FRAY_DRIFT_OUT :: 26
FRAY_SCATTER :: rl.Vector2{34, 30}
FRAY_SPREAD :: rl.Vector2{7, 3}
FRAY_DRAG :: 1.9

FRAY_LIFE :: 0.80
FRAY_LIFE_JITTER :: 0.30
FRAY_SIZE :: 2.1
FRAY_SIZE_JITTER :: 0.9

// The dust is the line's own colour, not the front's: it is what the line
// was, coming apart. The edge is the neutral one, because the boundary
// belongs to neither world — those are two different statements and they
// are meant to look different.
FRAY_ALPHA :: 0.85

// How present the edge is when it is far away, and how much it gains as
// it closes in. It has to be legible from the moment it starts moving,
// and insistent by the time it is a real threat — the same information
// twice, which is what a cue the player must not miss is allowed to do.
CORRUPTION_EDGE_BASE :: 0.30
CORRUPTION_EDGE_PRESSURE :: 0.55
CORRUPTION_GLOW_STRENGTH :: 0.45

// Where each lane's line currently meets the front, which is the place it
// comes apart. False while the front is still off the left edge, which is
// the whole of the first nine seconds of a run.
fray_points :: proc(
	world: game.World,
	corruption: game.Corruption,
) -> (
	floor, ceiling: rl.Vector2,
	ok: bool,
) {
	x := corruption.front_x
	if x <= 0 {
		return {}, {}, false
	}
	return rl.Vector2{x, game.get_surface_y(world, .Real, x)},
		rl.Vector2{x, game.get_surface_y(world, .Dream, x)},
		true
}

// Throws one frame's worth of dust off both lanes.
//
// Runs on the frame clock and never touches the simulation, which is why
// it is called from main next to the other presentation state rather than
// from inside a draw: the pool has to be advanced whether or not this
// frame drew anything.
//
// It does not ask whether a hole happens to be under the front. The edges
// of a hole are being eaten too, and dust over one costs nothing to be
// wrong about — where it would matter is the pen, and that one does check
// (render/terrain.odin).
emit_fray :: proc(
	particles: ^fx.Particles,
	world: game.World,
	corruption: game.Corruption,
	player: game.Player,
	palettes: core.PaletteSet,
	dt: f32,
) {
	floor, ceiling, ok := fray_points(world, corruption)
	if !ok {
		return
	}

	rate := f32(FRAY_RATE_BASE) + FRAY_RATE_PRESSURE * game.get_corruption_pressure(corruption, player)

	lane :: proc(origin: rl.Vector2, outward: f32, rate: f32, palette: core.Palette) -> fx.Emitter {
		return fx.Emitter {
			origin = origin,
			spread = FRAY_SPREAD,
			velocity = rl.Vector2{-FRAY_DRIFT_BACK, FRAY_DRIFT_OUT * outward},
			scatter = FRAY_SCATTER,
			drag = FRAY_DRAG,
			rate = rate,
			life = FRAY_LIFE,
			life_jitter = FRAY_LIFE_JITTER,
			size = FRAY_SIZE,
			size_jitter = FRAY_SIZE_JITTER,
			color = core.with_alpha(palette.light, FRAY_ALPHA),
		}
	}

	fx.emit(particles, 0, lane(floor, 1, rate, palettes.real), dt)
	fx.emit(particles, 1, lane(ceiling, -1, rate, palettes.dream), dt)
}

draw_corruption :: proc(
	corruption: game.Corruption,
	player: game.Player,
	palettes: core.PaletteSet,
) {
	x := corruption.front_x
	if x <= 0 {
		return // still off the left edge: nothing to draw
	}

	pressure := game.get_corruption_pressure(corruption, player)
	presence := CORRUPTION_EDGE_BASE + CORRUPTION_EDGE_PRESSURE * pressure

	top := rl.Vector2{x, 0}
	bottom := rl.Vector2{x, core.SCREEN_HEIGHT}

	// The neutral palette's light, not the current world's: the front
	// belongs to neither world, and it is the one thing on screen that
	// must not change colour when the player flips.
	draw_glow_line(
		top,
		bottom,
		CORRUPTION_EDGE_THICKNESS,
		CORRUPTION_EDGE_SPREAD,
		palettes.neutral.light,
		CORRUPTION_GLOW_STRENGTH * presence,
	)
	rl.DrawLineEx(
		top,
		bottom,
		CORRUPTION_EDGE_THICKNESS,
		core.with_alpha(palettes.neutral.light, presence),
	)
}
