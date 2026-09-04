/*
* Draw Front
* The right-hand half of the picture's central gag: the world is not
* already there and scrolling past — it is being **drawn**, at a fixed
* place near the right edge, and it scrolls toward the player from under
* the pen (Design Doc, section 10, decision 5).
*
* It is the mirror of the Corruption. Two fronts, one at each end of the
* screen: on the left the world comes apart, on the right it is made.
* They are mirrored in what they mean and deliberately *not* in how they
* are marked — see below.
*
* IT IS A CLIP, NOT AN ANIMATION
*
* This is the whole reason RL.5 sits in the same phase as RL.2 rather
* than being a job of its own. Once every obstacle lives inside the
* floor's own polyline, "the line writes the world" is one x beyond which
* nothing is drawn: the terrain's spans are cut at it exactly the way
* they are cut at a hole, an obstacle straddling it truncates itself, and
* nothing anywhere needs a per-object reveal animation or a state to
* remember how far along it is. Obstacles do not appear — the line
* reaches them.
*
* Because the world scrolls left and the front does not move, what the
* player sees is a shape emerging left-edge-first and growing rightward,
* which is a pen writing it.
*
* THE FRONT IS NOT A DIFFICULTY KNOB, AND MAY NEVER BECOME ONE
*
* Every pixel the front moves left is warning time taken away from the
* player, and pillar 3 promises every danger a visible arrival phase. So
* the inset is small, it is a constant, and nothing may make it a
* function of the tier, the depth or the score. At the opening speed
* DRAW_FRONT_INSET costs 0.18 s of the roughly 3.4 s of runway the player
* can see; that is the whole budget, and it is spent on making the nib
* visible rather than on tension.
*
* WHY THERE IS NO WALL HERE
*
* The Corruption is marked with a lit vertical edge across the full
* height of the screen, because it is lethal and pillar 2 wants a line
* nobody can miss (render/corruption.odin). Copying that mark here would
* be the worst possible mirroring: a bright vertical bar at the right
* edge reads as something approaching, and this is the one boundary in
* the game that threatens nothing at all. So the draw front is marked the
* other way — by *absence*, since the lines simply stop, plus a nib on
* each of them where the pen is touching the paper.
*/
package render

import "../core"
import rl "vendor:raylib/v55"

// How far inside the right edge the pen sits. Big enough that the nib and
// the line's round end are both fully on screen, and no bigger — see the
// header.
DRAW_FRONT_INSET :: 48

DRAW_FRONT_X :: f32(core.SCREEN_WIDTH) - DRAW_FRONT_INSET

// The nib: the point of the pen, on the line it is drawing.
//
// A dot rather than a shape, and one per lane, because there are two
// lines and the mark has to belong to the line rather than to the screen.
// Heavier than the stroke it sits on and brighter than anything else at
// that end of the picture, so the eye reads "this is where it comes from"
// without anything having to move.
NIB_WEIGHT :: 2.2 // multiples of the live lane's stroke
NIB_GLOW :: 0.55
NIB_SPREAD :: 4.5

// Drawn out of the neutral palette, like the Corruption's own edge and
// for the same reason: the pen belongs to neither world, and it must not
// change colour when the player flips.
draw_nib :: proc(point: rl.Vector2, palettes: core.PaletteSet) {
	nib := new_stroke(palettes.neutral.accent, TERRAIN_STROKE_THICKNESS * NIB_WEIGHT)
	nib.glow = NIB_GLOW
	nib.spread = NIB_SPREAD
	nib.core_light = 0.6
	apply_glow_gain(&nib, glow_gain(palettes.world_t))
	draw_stroke_dot(point, nib)
}
