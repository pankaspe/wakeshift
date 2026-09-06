/*
* Fragment
* The first thing in this game that is a *reward* rather than a danger,
* and the beginning of an answer to "why go to the Dream at all" (phase
* F1).
*
* WHY IT IS NOT A THIRD OBSTACLE TYPE
*
* The design's rule — two elements that combine are a game, three that
* each say their own thing are a list — is about **dangers**. A fragment
* is not a third danger, it is the first reward, which is a different
* axis entirely: it never blocks, never kills, and is never something to
* be answered. Nothing about the fairness rule has an opinion on it.
*
* Making it an ObstacleType would have cost a "not applicable" case in
* report_skyline_faults, report_same_lane_overlap, get_max_width, the
* terrain's welding, get_blocking_face and get_support_y — six places
* that would each have to say "except this one", which is how a type
* starts lying about what it is. A separate list costs one field on
* Pattern instead. The part that is genuinely shared *is* shared: an
* obstacle is an **event in time** rather than a pixel position, and that
* lives in core/track.odin, not in ObstacleType.
*
* ONE REPRESENTATION, THREE PLACEMENTS
*
* A fragment is a lane and an offset *into the corridor*, and that is all
* three of the placements F1 exists to choose between:
*
*   on the lane      offset of half a body: the diamond sits in the path
*                    of a character running along that lane, and is
*                    collected by being there.
*   in the corridor  offset of half the corridor. No settled body is ever
*                    at that height — measured at 145 px short of it from
*                    either lane — so it could only be taken **mid-flip
*                    at the right x**, in a window measured at 233 ms.
*   in a trail       several events in a row. Not a different fragment, a
*                    different number of them, and the line they draw is
*                    what tells the player where to go.
*
* THE PLAYTEST PICKED THE FIRST, AND ONLY ON THE CEILING
*
* The corridor placement is gone. It was the clever one — the 0.167 s a
* flip spends crossing the corridor is otherwise dead space, and a target
* inside it would have made the one gesture the game is built on
* something that could be *aimed* as well as chosen. It read as fiddly
* rather than as skilful, and a mechanic nobody enjoys executing is not
* saved by being interesting on paper. FRAGMENT_CORRIDOR went with it;
* the measurement stays above, because the next idea that wants a target
* inside the flip should start from the numbers rather than re-derive
* them.
*
* What survives is a diamond on the **Dream lane**, which is the shape F2
* needs anyway: the reward is in the world that is worth going to. The
* trail is not a second placement, it is several of the first.
*
* A fragment sitting where the player already is costs nothing — replayed
* with a run that never touches the key, it is collected anyway — so
* placing them is the whole of making them mean something. That is F3.
*
* WHAT F1 DELIBERATELY DOES NOT DO
*
* Collecting one changes nothing yet except a counter. The economy — the
* Corruption gaining ground on its own and fragments buying it back — is
* F2, and it is second on purpose: an always-gaining front with nothing
* to spend against it is a countdown, not a mechanic, which is precisely
* the objection corruption.odin already raises against chasers.
*/
package game

import "../core"
import rl "vendor:raylib/v55"

// The diamond's full width and height.
//
// Well under half the body (38) and well under a column (27), which is
// what keeps a filled diamond from being mistaken for a filled square —
// see render/fragment.odin for why it is filled at all. It came down
// from 24 by playtest.
//
// It is also the collection window's only knob. A body running along a
// lane meets a diamond in its path for (FRAGMENT_SIZE + PLAYER_SIZE) /
// scroll_speed seconds, so at 16 that is exactly 200 ms at the opening
// speed. Nothing else in the placement changes it.
FRAGMENT_SIZE :: 16

// The one height a fragment is authored at, measured from its own lane
// surface into the corridor: half a body, so the diamond sits in the
// middle of a character running along that lane.
//
// There was a second, FRAGMENT_CORRIDOR at half the corridor, and the
// playtest threw it out — see the header.
FRAGMENT_ON_LANE :: PLAYER_SIZE / 2

// Extra distance past the left edge before a fragment is discarded — the
// same slack obstacles get, and for the same reason (OBSTACLE_CULL_MARGIN).
FRAGMENT_CULL_MARGIN :: 200

// How many collections one step may report a position for.
//
// A step can only collect what overlaps a 38 px body, so this is already
// far more than can physically happen; the cap exists so that the caller
// can hand in a fixed array instead of allocating inside a simulation
// step. Going over it loses the *burst*, never the fragment — the count
// is incremented either way.
FRAGMENT_MAX_PER_STEP :: 8

Fragment :: struct {
	// world.elapsed_time at which this diamond is centred on a body at
	// rest at the anchor. Same contract an obstacle's arrival_time has,
	// measured to the middle rather than to the leading edge because a
	// fragment is a point to hit and a cube is a wall to meet.
	arrival_time: f32,
	lane:         core.Lane,

	// Pixels from that lane's surface, into the corridor, to the centre.
	offset:       f32,
}

// What a pattern authors. The run-time Fragment differs only in carrying
// an absolute arrival time instead of an offset from its pattern's start.
FragmentEvent :: struct {
	time_offset: f32,
	lane:        core.Lane,
	offset:      f32,
}

// One collection, as the simulation reports it: where the diamond was
// and which world it belonged to.
//
// The simulation decides *that* it happened and hands over the two facts
// presentation needs; it has no idea a burst of particles is what becomes
// of them. That is the same split every other piece of feedback in the
// game follows, and it is what keeps `game` from ever drawing.
FragmentPickup :: struct {
	at:   rl.Vector2,
	lane: core.Lane,
}

// Everything a run's fragments are.
//
// The count lives here rather than in Score because Score is the distance
// travelled and nothing else, deliberately (score.odin) — and because
// what a fragment will eventually buy is **room**, not points (F2).
Fragments :: struct {
	live:      [dynamic]Fragment,
	collected: int,
}

// Where the diamond's centre is right now.
//
// Straight through the one map between world time and screen x that
// every obstacle also goes through (core/track.odin), so a fragment
// authored as a moment lands where the moment is, at any scroll speed.
// The half-body shift is what makes arrival_time mean "it is on you"
// rather than "its left edge has reached your left edge".
get_fragment_center :: proc(fragment: Fragment, world: World) -> rl.Vector2 {
	x := core.ground_x_at_time(get_ground(world), fragment.arrival_time) + PLAYER_SIZE / 2

	// The offset is measured *into the corridor*, so it is upward off the
	// floor and downward off the ceiling: the same number, mirrored, which
	// is what lets one authored value mean the same thing in both worlds.
	surface := core.track_surface_y(fragment.lane)
	y := fragment.lane == .Real ? surface - fragment.offset : surface + fragment.offset

	return rl.Vector2{x, y}
}

// The diamond's bounding box, which is what is actually collided against.
get_fragment_rect :: proc(fragment: Fragment, world: World) -> rl.Rectangle {
	centre := get_fragment_center(fragment, world)
	half := f32(FRAGMENT_SIZE) * 0.5
	return rl.Rectangle{centre.x - half, centre.y - half, FRAGMENT_SIZE, FRAGMENT_SIZE}
}

// Takes every fragment the body is touching, reports where each one was,
// and removes them.
//
// The test is the diamond's **bounding box**, which is deliberately more
// generous than the diamond: the box is twice the area of the shape
// inside it, so a corner counts as a touch. That bias is the right way
// round for a reward — being stingy about a thing the player is trying
// to take feels broken, and being generous costs them nothing. The
// opposite bias is the one that matters, which is why a hole is tested
// against the body's *centre* instead (collision.odin).
//
// Returns how many pickups were written into `picked`. The caller turns
// those into a burst; the simulation itself has no opinion about
// particles.
collect_fragments :: proc(
	fragments: ^Fragments,
	player: Player,
	world: World,
	picked: []FragmentPickup,
) -> int {
	body := to_rect(player.position, player.size)
	reported := 0
	kept := 0

	for index in 0 ..< len(fragments.live) {
		fragment := fragments.live[index]

		if rl.CheckCollisionRecs(body, get_fragment_rect(fragment, world)) {
			fragments.collected += 1
			if reported < len(picked) {
				picked[reported] = FragmentPickup {
					at   = get_fragment_center(fragment, world),
					lane = fragment.lane,
				}
				reported += 1
			}
			continue
		}

		fragments.live[kept] = fragment
		kept += 1
	}

	resize(&fragments.live, kept)
	return reported
}

// True once a fragment is off the left edge and can no longer be taken.
is_fragment_finished :: proc(fragment: Fragment, world: World) -> bool {
	centre := get_fragment_center(fragment, world)
	return centre.x + FRAGMENT_SIZE < -FRAGMENT_CULL_MARGIN
}

// Drops fragments that are finished with, the same compaction
// remove_finished_obstacles does and for the same reason: they do not go
// out of scope in the order they arrived, so a prefix scan would stop at
// the first survivor and leak everything behind it.
remove_finished_fragments :: proc(fragments: ^Fragments, world: World) {
	kept := 0
	for index in 0 ..< len(fragments.live) {
		if !is_fragment_finished(fragments.live[index], world) {
			fragments.live[kept] = fragments.live[index]
			kept += 1
		}
	}
	resize(&fragments.live, kept)
}
