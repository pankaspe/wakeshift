/*
* Collision
* Answers the one question that ends a run: is this obstacle killing the
* player right now? Obstacle geometry is derived from world time (see
* obstacle.odin), so this always tests where an obstacle actually is on
* this step, never where it was authored.
*
* Two rules, and the split is the design doc's own (section 6):
*
*   a presence kills whoever touches it. The Cube: two rectangles,
*   tested against each other.
*
*   an absence kills whoever is *resting on it*. A gap is not something
*   you touch, it is the lane failing to be there, so what matters is
*   whether the player is still standing on that lane when the hole
*   passes underneath — not whether two boxes overlap.
*
* That second rule is what makes the two read differently at speed. A
* cube is a narrow instant: be elsewhere exactly when it goes by. A gap
* is up to two and a half times as wide and only cares about the surface,
* so it is a *stretch* not to be standing in, and it is answered by being
* anywhere else at all — the other lane, or simply mid-flip. One asks
* "move now", the other asks "do not be down here".
*
* **This file changes in roadmap R2.3**, and it is the centre of the
* rewrite: the Cube stops killing and starts *blocking*. A mistake will
* cost ground rather than the run, which is what finally makes it legal
* for both lanes to be threatened at once (Design Doc, pillar 7).
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
@(private)
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
		return rl.CheckCollisionRecs(
			to_rect(player.position, player.size),
			get_obstacle_rect(obstacle, world),
		)
	}

	return false
}
