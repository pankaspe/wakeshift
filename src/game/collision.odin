/*
* Collision
* Answers the one question that ends a run: is this obstacle killing the
* player right now? Obstacle geometry is derived from world time (see
* obstacle.odin), so this always tests where an obstacle actually is on
* this step, never where it was authored.
*
* Two questions, not one, and the split is the whole design (pillar 7):
*
*   **what kills.** Only an absence: a gap is the lane failing to be
*   there, so what matters is whether the player is still resting on that
*   lane when the hole passes underneath — not whether two boxes overlap.
*   Being mid-flip answers it as completely as being on the other lane.
*
*   **what costs.** A cube. It is a presence, and since R2.3 it does not
*   kill: it *blocks*. Two rectangles overlapping means the character is
*   stopped against its face and dragged backwards with it, losing ground
*   to the Corruption for as long as they stay there.
*
* That split is what makes the two read differently. A cube is a price:
* be elsewhere when it goes by, or pay. A gap is a stretch not to be
* standing in, and it is answered by being anywhere else at all. One asks
* "move now or pay", the other says "do not be down here".
*
* And it is what makes the design's centrepiece legal. Because a cube is
* not lethal, **both lanes may hold one at the same time** — a mirrored
* pair has no escape, only a choice about which price to pay. No design
* where every obstacle kills can put that on screen, because two lethal
* lanes is an unanswerable pattern.
*/
package game

import rl "vendor:raylib/v55"

// Converts a position/size pair into a raylib Rectangle, for collision checks.
to_rect :: proc(position, size: rl.Vector2) -> rl.Rectangle {
	return rl.Rectangle{position.x, position.y, size.x, size.y}
}

// Whether the player and an obstacle are passing each other horizontally.
horizontally_overlapping :: proc(player: Player, obstacle: Obstacle, world: World) -> bool {
	rect := get_obstacle_rect(obstacle, world)
	return player.position.x < rect.x + rect.width && rect.x < player.position.x + player.size.x
}

// Whether the ground has gone from under the *body*, which is not the
// same question as whether the two boxes touch.
//
// A hole takes you when there is nothing under your middle, not when your
// leading edge crosses the lip. Measured on 5 September: the box test
// ended the run **18 px — 0.07 s — before the body's centre reached the
// hole**, and 8 px before the drawn figure touched it at all, so the game
// was over while the character was still plainly standing on solid
// ground. That is the worst kind of unfair: not hard, just early.
//
// The centre and not the whole body, because a hole you are half over is
// a hole you have fallen into; and the centre rather than the drawn
// figure's own edge, because what the renderer happens to draw may never
// decide what the simulation does.
standing_over_gap :: proc(player: Player, obstacle: Obstacle, world: World) -> bool {
	rect := get_obstacle_rect(obstacle, world)
	centre := player.position.x + player.size.x * 0.5
	return centre >= rect.x && centre <= rect.x + rect.width
}

// Checks whether an obstacle is currently killing the player.
//
// Invulnerability is decided **per type**, not once at the top, and that
// is the whole reason this is a switch. The grace period exists to
// forgive the flip started at the last possible instant against a hole.
check_player_obstacle_collision :: proc(player: Player, obstacle: Obstacle, world: World) -> bool {
	if !horizontally_overlapping(player, obstacle, world) {
		return false
	}

	switch obstacle.obstacle_type {
	case .Gap:
		if player.is_invulnerable {
			return false
		}
		// The surface is missing here. Only whoever is still resting on it
		// falls: mid-flip and on the other lane are both simply *not on
		// this one*. And they fall when the hole is under their middle,
		// not when their leading edge reaches its lip.
		if player.state == .Transitioning || player.lane != obstacle.lane {
			return false
		}
		return standing_over_gap(player, obstacle, world)

	case .Cube:
		return false // it costs, it does not kill — see blocks_player
	}

	return false
}

// The face the character is stopped against right now, if any.
//
// **Which column, not which obstacle**, and that is what the profile
// bought. A skyline is only as much of a wall as the column the body has
// actually reached: walk into `{1, 2, 3}` and you are stopped at its left
// edge, but come down onto the low step from a flip and you stand on it,
// with the next column up becoming the face instead. Before the profile
// the whole bounding box blocked, so a pyramid was drawn as steps and
// collided as a block — it showed a low step it would not let you use.
//
// A column of height zero is not there and cannot stop anything, which is
// what makes a canyon in a skyline a place to be rather than a wall.
//
// Only a settled player is blocked. Mid-flip they are travelling between
// the lanes and nothing standing on one can reach them, which is what
// makes a tap the escape: the press frees them on the step it is made,
// with no window in which they are committed and still pinned.
//
// It is deliberately *not* gated on invulnerability. A block is not
// damage — nothing is being forgiven — and a grace period that also
// waved the character through solid cubes would let a well-timed flip
// walk straight through the one obstacle that is supposed to cost
// something.
get_blocking_face :: proc(
	player: Player,
	obstacle: Obstacle,
	world: World,
) -> (
	face: f32,
	blocked: bool,
) {
	if !blocks_lane(obstacle.obstacle_type) {
		return 0, false
	}
	if player.state == .Transitioning || player.lane != obstacle.lane {
		return 0, false
	}

	body := to_rect(player.position, player.size)
	rect := get_obstacle_rect(obstacle, world)
	if rect.x >= body.x + body.width || rect.x + rect.width <= body.x {
		return 0, false
	}

	// Left to right, so the face is the first column that is in the way
	// rather than the tallest one — the body is stopped by what it reaches
	// first.
	for index in 0 ..< len(get_cube_profile(obstacle)) {
		column := get_cube_column(obstacle, rect, index)
		if column.rect.height <= 0 {
			continue
		}
		if rl.CheckCollisionRecs(body, column.rect) {
			return column.rect.x, true
		}
	}
	return 0, false
}

// Whether this obstacle is holding the character back right now.
blocks_player :: proc(player: Player, obstacle: Obstacle, world: World) -> bool {
	_, blocked := get_blocking_face(player, obstacle, world)
	return blocked
}
