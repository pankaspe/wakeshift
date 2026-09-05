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
*   **what times you.** A Sentinel. It is the only danger that asks
*   *when*: a pulsar on one lane fires a ray across the corridor to the
*   other, the ray kills what it touches, and the lane it starts on is
*   the one that clears first. Standing still does not survive it, which
*   is the point — it is the one obstacle that requires a press.
*
* That split is what makes the three read differently. A cube is a price:
* be elsewhere when it goes by, or pay. A gap is a stretch not to be
* standing in, and it is answered by being anywhere else at all. A
* Sentinel is a crossing to be made behind the ray. One asks "move now or
* pay", the second says "do not be down here", the third says "move, and
* on the beat".
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
// The only test a gap needs, since it occupies its whole lane vertically
// by definition.
horizontally_overlapping :: proc(player: Player, obstacle: Obstacle, world: World) -> bool {
	rect := get_obstacle_rect(obstacle, world)
	return player.position.x < rect.x + rect.width && rect.x < player.position.x + player.size.x
}

// Checks whether an obstacle is currently killing the player.
//
// Invulnerability is decided **per type**, not once at the top, and that
// is the whole reason this is a switch. The grace period exists to
// forgive the flip started at the last possible instant against a hole —
// but against a Sentinel the flip *is* the mistake, so a rule that
// forgave the first tenth of a second of every journey would hand out a
// free crossing to anyone who left it late, which is exactly the player
// the Sentinel is aimed at.
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
		// this one*.
		return player.state != .Transitioning && player.lane == obstacle.lane

	case .Sentinel:
		// The ray is a thing travelling across the corridor and it kills
		// what it touches, so this is a plain overlap — the only one in
		// the file, because it is the only danger that is neither an
		// absence nor a wall.
		//
		// Not forgiven by the grace period. That exists to excuse the flip
		// started at the last possible instant against a hole, where being
		// mid-journey is the answer; here being mid-journey is the answer
		// *and* the risk, and a tenth of a second of free passage through
		// a moving ray would be handed to exactly the player who left it
		// too late.
		return rl.CheckCollisionRecs(
			to_rect(player.position, player.size),
			get_obstacle_rect(obstacle, world),
		)

	case .Cube:
		return false // it costs, it does not kill — see blocks_player
	}

	return false
}

// Whether this obstacle is holding the character back right now.
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
blocks_player :: proc(player: Player, obstacle: Obstacle, world: World) -> bool {
	if !blocks_lane(obstacle.obstacle_type) {
		return false
	}
	if player.state == .Transitioning || player.lane != obstacle.lane {
		return false
	}
	return rl.CheckCollisionRecs(
		to_rect(player.position, player.size),
		get_obstacle_rect(obstacle, world),
	)
}
