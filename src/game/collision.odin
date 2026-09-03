/*
* Collision
* Answers the one question that ends a run: is this obstacle killing the
* player right now? Obstacle geometry is derived from world time (see
* obstacle.odin), so this always tests where an obstacle actually is on
* this step, never where it was authored.
*
* Until phase 6 there was one rule — "do not be in this lane when it
* arrives" — wearing four different skins. There are two rules now, and
* the split is the design doc's own (section 5, full vs void):
*
*   a presence kills whoever touches it. Block, Pulsing Shape, Patroller:
*   rectangles, tested against the player's rectangle.
*
*   an absence kills whoever is *resting on it*. A chasm is not something
*   you touch, it is the floor failing to be there, so what matters is
*   whether the player is still standing on that floor when the hole
*   passes underneath — not whether two boxes overlap.
*
* The Step (T7.5.5) is the second rule again, read the third way: the
* floor rising instead of failing. It kills whoever is on the ground for
* the same reason a Chasm does, and it is answered the same way — by
* being anywhere else at all.
*
* That second rule is what makes the two read differently at speed. A
* Block is a narrow instant: be elsewhere exactly when it goes by. A
* Chasm is up to two and a half times as wide and only cares about the
* ground, so it is a *stretch* to not be standing in, and it is answered
* by being anywhere else at all — the ceiling, mid-flip, or the Limen.
* One asks "move now", the other asks "do not be down here".
*/
package game

import rl "vendor:raylib/v55"

// Converts a position/size pair into a raylib Rectangle, for collision checks.
to_rect :: proc(position, size: rl.Vector2) -> rl.Rectangle {
	return rl.Rectangle{position.x, position.y, size.x, size.y}
}

// Whether the player and an obstacle are passing each other horizontally.
// The only test a void obstacle needs, since it occupies its whole lane
// vertically by definition.
@(private)
horizontally_overlapping :: proc(player: Player, obstacle: Obstacle, world: World) -> bool {
	rect := get_obstacle_rect(obstacle, world)
	return player.position.x < rect.x + rect.width && rect.x < player.position.x + player.size.x
}

// Checks whether an obstacle is currently killing the player.
//
// Invulnerability (Design Doc, section 4, during the first 0.15s of a
// flip) blocks everything: it exists to forgive the flip started at the
// last possible instant. It runs out well before a journey ends, and it
// is cleared outright on entering the Limen — the suspension is a state,
// not a prolonged grace period.
check_player_obstacle_collision :: proc(player: Player, obstacle: Obstacle, world: World) -> bool {
	if player.is_invulnerable {
		return false
	}
	if !horizontally_overlapping(player, obstacle, world) {
		return false
	}

	switch obstacle.obstacle_type {
	case .Chasm:
		// The floor is missing here. Only whoever is still standing on it
		// falls: mid-flip, suspended in the Limen, or hanging from the
		// ceiling are all simply *not on the floor*.
		return player.state == .Real

	case .DreamHole:
		// The same rule mirrored: the ceiling has dissolved, and only
		// what was hanging from it comes away.
		return player.state == .Dream

	case .Step:
		// The floor is not missing here, it is in the way. Same rule as
		// the Chasm and for the same reason — the ground is what is doing
		// it, so it reaches whoever is standing on the ground and nobody
		// else. There is no jump in this game, so a raised stretch is not
		// something to get on top of: it is a wall to be elsewhere for.
		return player.state == .Real

	case .Feint:
		// Never lethal, and that is the whole point of it. It is a
		// question about what the player does next, not a threat.
		return false

	case .Block, .PulsingShape, .Patroller:
		return rl.CheckCollisionRecs(
			to_rect(player.position, player.size),
			get_obstacle_rect(obstacle, world),
		)
	}

	return false
}
