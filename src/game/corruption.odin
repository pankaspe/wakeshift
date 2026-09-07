/*
* Corruption
* The dream going out behind the player: a wall advancing through the
* world, and the only thing that can end a run.
*
* It is not a resource, not a meter and not a number in a corner. It is a
* **front**: everything behind it is gone, it comes on by itself, and it
* ends the run when it touches the body. The distance between the two is
* the entire health bar, and it is drawn at full size in the picture the
* player is already looking at — right up until it is so large that the
* front is off the screen, which is the same statement said louder.
*
* WHY A CHASER IS A MECHANIC HERE AND USUALLY IS NOT
*
* A chaser in a game where you cannot go faster is not a mechanic, it is
* a countdown in a costume: there is nothing to interact with. This one
* is a mechanic because the player sets their own pace — a clean run
* through a chunk covers ground at roughly two and a half times what the
* front does, so **playing well is what pushes it away** and hesitating is
* what brings it back. It is fed and starved by the same skill the maze
* is testing.
*
* It also keeps pillar 3 better than any meter could. A number draining in
* a corner is a blow nobody sees coming; a thing crossing the screen
* toward you is visible for the whole of its approach, and its *absence*
* from the screen is the clearest way there is of saying "you are fine".
*
* THE BANK IS NO LONGER THE SCREEN, AND THAT IS A REVERSAL
*
* Until the first maze playtest the front lived in *screen* space and was
* clamped at the left edge, so lead beyond one screen was thrown away —
* deliberately, on the reading that a hidden surplus is a meter nobody can
* see. The maze reversed it, for a reason the two-lane game never had:
* **reading a maze takes time that a runner never needed.** Going back a
* few cells to take the other branch, or simply stopping to look, is the
* game, and a bank capped at one screen priced it out.
*
* So the front has a world position, the lead is unbounded up to
* CORRUPTION_MAX_LEAD, and a player who is doing well genuinely cannot see
* it. What is given up is that the health bar is unreadable while it is
* off screen. That is the right trade *only* because being off screen
* means safe, which is the one state that needs no reading.
*
* WHAT IT IS TUNED AGAINST, AND WHAT IT MUST NEVER BE TUNED AGAINST AGAIN
*
* Its speed is set against what the maze costs to cross — nothing else,
* because nothing else exists yet. The generator measures every chunk's
* cheapest crossing at a mean of 1.50 cells travelled per column gained
* (game/maze.odin), so a perfect crossing advances through the world at
* RUNNER_SPEED / 1.50 = 600 px/s, and a competent one nearer 450.
*
* The pair below is drawn so the front is comfortably slower than that at
* the opening and still slower than a good line at the top. **When
* fragments and the Dream land, redraw this against the new income rather
* than nudging it.** The numbers that were here before were calibrated
* against a fragment economy that had already been deleted, which is worse
* than an arbitrary number because it looks justified.
*/
package game

import "../core"

// How far behind the body the front starts, in world pixels.
//
// Two and a half screens, which at the opening speed is about eleven
// seconds of standing still. A run opens with the front nowhere in sight
// on purpose: the first thing the player does is read a maze, and the
// game should not be shouting at them while they learn what it is.
CORRUPTION_START_LEAD :: 2000

// The most lead there can be, in world pixels.
//
// Room you cannot use is not room. Past this the front is towed along
// behind the body instead of falling further back, so a player who is
// well ahead stays safe without becoming immortal — and so the front is
// never so far away that catching up to it later reads as arbitrary.
//
// It is deliberately far larger than a screen: the whole point of the
// reversal above is that the bank stopped being the picture.
CORRUPTION_MAX_LEAD :: 3400

// How fast the front eats the world, in world pixels per second, at the
// opening of the curve and at the top of it.
//
// Against the 600 px/s a perfect crossing makes and the ~450 of a
// competent one: at the opening the front takes a third of a good line's
// pace, so the first minute is for learning to read. At the top it is
// past what a competent line sustains, which is how the old promise
// survives the reversal — **the front still wins in the end**, it just no
// longer wins against someone who is playing well.
//
// Standing still at the opening costs the whole starting lead in about
// eleven seconds. That is the number the first playtest was really asking
// for: it was 1.26 s.
CORRUPTION_SPEED_OPEN :: 190
CORRUPTION_SPEED_TOP :: 500

// How fast it runs *backwards* in the Dream, in world pixels per second.
//
// This is the whole payout of the loop, and it is a speed rather than a
// snap on purpose: a front that jumped back would be a number changing,
// while a front visibly sliding away is the sawtooth being drawn at full
// size in the picture the player is already watching (Design Doc §7).
//
// 300 px/s over the 6 s of a full bar is 1800 px given back. Against the
// ~4 s of detour a bar costs to fill (game/dream.odin): 760 px of ground
// spent at the opening speed, 2000 at the top. So the Dream pays well
// early and stops paying late, which is the front still winning in the
// end without ever winning against someone playing well.
//
// It is bounded by CORRUPTION_MAX_LEAD like everything else, and measured,
// that is not the footnote it reads as: at the opening speed a good line
// sits against the cap nearly the whole time, so the retreat is mostly
// thrown away and collecting comes out a net **loss** (game/dream.odin has
// the runs). The reasoning stands — the Dream recovers ground, and there
// is none to recover when none was lost — but it means the loop cannot
// pay until the Real stops being net positive, which is the front redraw
// the design asks for and the author has to make.
CORRUPTION_DREAM_RETREAT :: 300

// The distance the speed takes to travel between those two. Long, because
// it has to grow across the whole of a long run rather than saturating in
// the first minute.
CORRUPTION_FULL_DISTANCE :: 50000

Corruption :: struct {
	// World x of the boundary. Everything behind it is gone; a body whose
	// trailing edge reaches it is out of room.
	world_x: f32,
}

new_corruption :: proc() -> Corruption {
	return Corruption{world_x = cell_centre_x(0) - CORRUPTION_START_LEAD}
}

// How fast the front is eating right now. A straight line in depth,
// crossed with the Dream.
//
// dream_t is the crossing rather than the phase, so the front decelerates,
// stops and reverses over DREAM_CROSSING_TIME instead of changing sign in
// one step. That is the one place the world turning is *felt* rather than
// seen, and it is why the crossing had to be simulation state.
get_corruption_speed :: proc(depth: f32, dream_t: f32 = 0) -> f32 {
	t := clamp(depth / CORRUPTION_FULL_DISTANCE, 0, 1)
	forward := f32(CORRUPTION_SPEED_OPEN) + (CORRUPTION_SPEED_TOP - CORRUPTION_SPEED_OPEN) * t
	k := clamp(dream_t, 0, 1)
	return forward + (-f32(CORRUPTION_DREAM_RETREAT) - forward) * k
}

// One step of the front: it comes on, and it is towed if it has fallen
// further behind than a player can spend.
update_corruption :: proc(
	corruption: ^Corruption,
	player: Player,
	dream: Dream,
	delta_time: f32,
) {
	depth := get_player_world(player).x
	corruption.world_x += get_corruption_speed(depth, dream.world_t) * delta_time
	corruption.world_x = max(corruption.world_x, depth - CORRUPTION_MAX_LEAD)
}

// Where the front is on screen. Well off the left of it whenever the
// player is doing well, which is the point.
get_corruption_screen_x :: proc(corruption: Corruption, world: World) -> f32 {
	return maze_screen_x(corruption.world_x, world.camera_x)
}

// How much room is left, in world pixels. The whole health bar.
get_player_lead :: proc(corruption: Corruption, player: Player) -> f32 {
	return get_player_world(player).x - PLAYER_SIZE * 0.5 - corruption.world_x
}

// True once the front has caught up: the run is over.
//
// A comparison of two *world* positions, never of two screen ones. That
// is what lets the camera lag, chase and be as pretty as it likes without
// any of it reaching the thing that decides the run.
corruption_has_reached :: proc(corruption: Corruption, player: Player) -> bool {
	return get_player_lead(corruption, player) <= 0
}

// 0..1, how much of the *visible* runway is gone — 0 while the front is
// still off the screen. Presentation reads it; the simulation does not,
// because what matters there is the lead itself and this is only a way of
// describing it.
get_corruption_pressure :: proc(corruption: Corruption, player: Player) -> f32 {
	return clamp(1 - get_player_lead(corruption, player) / f32(core.PLAYER_HOME_X), 0, 1)
}
