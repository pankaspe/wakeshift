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
// The only test a gap needs, since it occupies its whole lane vertically
// by definition.
horizontally_overlapping :: proc(player: Player, obstacle: Obstacle, world: World) -> bool {
	rect := get_obstacle_rect(obstacle, world)
	return player.position.x < rect.x + rect.width && rect.x < player.position.x + player.size.x
}

// Checks whether an obstacle is currently killing the player.
//
// Invulnerability (the first INVULNERABILITY_DURATION of a flip) blocks
// everything: it exists to forgive the flip started at the last possible
// instant, and it runs out well before a journey ends.
check_player_obstacle_collision :: proc(player: Player, obstacle: Obstacle, world: World) -> bool {
	if player.is_invulnerable {
		return false
	}
	if !horizontally_overlapping(player, obstacle, world) {
		return false
	}

	switch obstacle.obstacle_type {
	case .Gap:
		// The surface is missing here. Only whoever is still resting on it
		// falls: mid-flip and on the other lane are both simply *not on
		// this one*.
		return player.state != .Transitioning && player.lane == obstacle.lane

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
	if obstacle.obstacle_type != .Cube {
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
