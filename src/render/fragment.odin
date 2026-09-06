/*
* Fragment Render
* The one mark in the game that is a reward, and the whole job is telling
* it apart from the two that are not (phase F1).
*
* IT IS FILLED, AND THAT IS THE THIRD EXCEPTION
*
* CLAUDE.md's rule is that two things are filled — the field and the
* character — and that the character's fill is the whole of "this one is
* you", because the obstacles are squares too and only fill separates
* them. A filled diamond is a deliberate third, taken at a playtest, and
* it is safe for a reason worth writing down: **the discriminator moves
* from "filled" to "filled square".**
*
*   it is **rotated**. Every other right angle in the game is square to
*   the screen; this is the only turned one.
*   it is **small** — 16 px against a 38 px body, well under half.
*   it is **the accent colour**, which nothing else on screen uses. The
*   block wears its lane's `light`; this wears the one colour the palette
*   calls "allowed to shout".
*
* And below about 20 px filling it is not a choice at all. An outline at
* this size is drawn with a 2.2 px pen on a 16 px shape, so most of the
* mark is pen and the interior is a few pixels — the same arithmetic that
* took the character from a stick figure to a block ("a 45 px shape drawn
* with a 4 px pen cannot hold detail"). Asking for it smaller and asking
* for it filled are the same request.
*
* THE GLOW IS MOSTLY THE FRAME'S
*
* The halo here is deliberately weak. A filled surface in the accent
* colour is far over every bright-pass threshold there is, so the bloom
* already makes it glow (fx/bloom.odin) — and where a primitive halo and
* a real one do the same job, CLAUDE.md's answer is to take the primitive
* one down rather than the bloom. The character resolved exactly this way
* when it lost its outline. What is left is a small, tight halo whose one
* job is being *findable* from across the screen, since a reward the
* player cannot see early is a reward they cannot route toward.
*
* IT IS CUT AT BOTH FRONTS, LIKE EVERYTHING ELSE
*
* Written by the pen on the right, eaten by the Corruption on the left,
* and never faded in (RL.5). Filling it is what changed *how*: it is
* drawn as vertical spans, and the clip is the two x values and nothing
* else. See draw_filled_diamond for why it is not a triangle fan.
*/
package render

import "../core"
import "../fx"
import "../game"
import rl "vendor:raylib/v55"

// How much light the diamond sits in, over and above what the frame's
// bloom gives it for free. Down from 0.42 by playtest, along with the
// reach: what was there read as a lamp rather than as a thing.
FRAGMENT_GLOW_STRENGTH :: 0.15
FRAGMENT_GLOW_RADIUS :: 0.85

// How solid the fill is. Just short of opaque, so the field reads through
// it a little and it sits *in* the corridor rather than on top of the
// picture.
FRAGMENT_FILL_ALPHA :: 0.94

// The width of one span of the fill, in pixels. One is exact at every
// output resolution the canvas is scaled to, and a 16 px diamond is
// sixteen of them.
FRAGMENT_SPAN_STEP :: 1.0

// The burst a fragment comes apart into when it is taken. It is half of
// the feedback that says "that counted" — the other half is the block's
// own pop (render/player.odin).
//
// Outward in every direction and stopped quickly by drag, which is what
// makes it read as a thing breaking rather than as a thing leaving: the
// dust behind the Corruption drifts, and these must not look like that.
// They are the fragment's own colour for the same reason that dust is the
// lane's — it is what the mark *was*, an instant later.
FRAGMENT_BURST_COUNT :: 12
FRAGMENT_BURST_SCATTER :: 190
FRAGMENT_BURST_DRAG :: 7.0
FRAGMENT_BURST_LIFE :: 0.38
FRAGMENT_BURST_LIFE_JITTER :: 0.12
FRAGMENT_BURST_SIZE :: 2.2
FRAGMENT_BURST_SIZE_JITTER :: 0.9
FRAGMENT_BURST_ALPHA :: 0.95

draw_fragment :: proc(
	fragment: game.Fragment,
	world: game.World,
	palettes: core.PaletteSet,
	front_x: f32,
) {
	centre := game.get_fragment_center(fragment, world)
	half := f32(game.FRAGMENT_SIZE) * 0.5

	from, to, _, _, any := drawn_extent(centre.x - half, game.FRAGMENT_SIZE, front_x)
	if !any {
		return
	}

	is_real := fragment.lane == .Real
	palette := is_real ? palettes.real : palettes.dream
	alive := is_real ? palettes.real_alive : palettes.dream_alive
	gain := glow_gain(palettes.world_t)

	// The halo grows out of the front with the shape and goes with it at
	// the other end: it is part of the object rather than an announcement
	// of it, which is the rule the floating cube's halo already follows.
	draw_glow_circle(
		rl.Vector2{(from + to) * 0.5, centre.y},
		(to - from) * FRAGMENT_GLOW_RADIUS * gain.spread,
		palette.accent,
		FRAGMENT_GLOW_STRENGTH * (0.4 + 0.6 * alive) * gain.strength,
	)

	draw_filled_diamond(
		centre,
		half,
		from,
		to,
		core.with_alpha(palette.accent, FRAGMENT_FILL_ALPHA),
	)
}

// Fills the diamond between two x values, as vertical spans.
//
// **Not a triangle fan, and that is not fussiness.** raylib culls back
// faces, so a fan whose winding comes out the other way round is a shape
// that silently does not appear — the trap that cost a whole ribbon in
// stroke.odin and the reason the character's block goes through
// DrawRectanglePro rather than through two triangles of its own.
// DrawRectanglePro would in fact draw this shape for free, since a
// diamond *is* a square at 45 degrees, but it cannot be cut at the two
// fronts, and every mark in this game is cut rather than faded (RL.5).
//
// Spans give both at once: the clip is `from` and `to` and nothing else,
// and a rectangle has no winding to get wrong. Nothing here is
// anti-aliased in any case, so the result is what a triangle pair would
// have rasterised anyway.
@(private)
draw_filled_diamond :: proc(centre: rl.Vector2, half, from, to: f32, color: rl.Color) {
	left := max(centre.x - half, from)
	right := min(centre.x + half, to)

	for x := left; x < right; x += FRAGMENT_SPAN_STEP {
		width := min(f32(FRAGMENT_SPAN_STEP), right - x)

		// The edge is |dx| + |dy| = half, so the half-height falls off
		// linearly from the centre. Sampled at the span's middle, which is
		// the honest place to sample a band of finite width.
		reach := half - abs(x + width * 0.5 - centre.x)
		if reach <= 0 {
			continue
		}

		rl.DrawRectangleRec(rl.Rectangle{x, centre.y - reach, width, reach * 2}, color)
	}
}

// The mark coming apart, at the point it was taken from.
//
// Emitted by the caller from the frame clock, never from a simulation
// step: the collection is simulation, the dust that says so is not. The
// simulation hands over a position and a lane and has no idea what
// happens to them (fx/particles.odin).
burst_fragment :: proc(
	particles: ^fx.Particles,
	at: rl.Vector2,
	lane: core.Lane,
	palettes: core.PaletteSet,
) {
	palette := lane == .Real ? palettes.real : palettes.dream

	fx.burst(
		particles,
		fx.Emitter {
			origin = at,
			scatter = rl.Vector2{FRAGMENT_BURST_SCATTER, FRAGMENT_BURST_SCATTER},
			drag = FRAGMENT_BURST_DRAG,
			life = FRAGMENT_BURST_LIFE,
			life_jitter = FRAGMENT_BURST_LIFE_JITTER,
			size = FRAGMENT_BURST_SIZE,
			size_jitter = FRAGMENT_BURST_SIZE_JITTER,
			color = core.with_alpha(palette.accent, FRAGMENT_BURST_ALPHA),
		},
		FRAGMENT_BURST_COUNT,
	)
}
