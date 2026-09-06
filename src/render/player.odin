/*
* Player Render
* The character: a **filled square**, centred in the cell it is in.
*
* WHY A SQUARE, AND WHY FILLED
*
* It was a robed figure under a pointed hood until 6 September, and a
* stick figure before that. Both went the same way and for the same
* reason: **a 38 px shape drawn with a 3 px pen cannot hold detail**, and
* every feature that does not read is noise the eye has to sort through
* while the player is trying to read the world.
*
* So the character is the simplest thing that can be a character, and the
* interest lives entirely in how it *moves*. Two decisions carry the read:
*
*   **It is filled, and only the field is too.** Every wall in the maze is
*   a hollow line. Fill is therefore the whole of "this one is you", which
*   is a stronger discriminator than any silhouette this size could carry.
*
*   **It is the accent**, the one colour the palette allows to shout. In a
*   screen of lattice the eye has to find the body in well under a second
*   (pillar 2), and hue is the only channel not already spent on walls.
*
* THE AIR AROUND IT IS FREE
*
* The block is 38 px in a 60 px cell, so 11 px of each side is empty. None
* of it is mechanical: collision is a question to the maze about a wall
* between two cells, never an overlap between two rectangles, so there is
* no pixel at which the block can catch on a corner. The padding is
* entirely a matter of how the corridor reads.
*
* WHAT THE STRETCH IS FOR, AND WHAT IT IS NOT
*
* A slide draws the block out along the direction it left in, over a fixed
* window at the start of the journey rather than over the journey itself —
* the impulse is what has a shape, not the travelling, and a slide can be
* one cell or fifteen. x moves opposite to y for a rough sense of
* preserved volume.
*
* There is no rotation. CLAUDE.md's oldest game-feel lesson applies
* exactly here: **a flourish placed on the player's own motion is not
* decoration, it is friction**, and this is the one gesture the whole game
* is made of.
*/
package render

import "../core"
import "../game"
import "core:math"
import rl "vendor:raylib/v55"

PLAYER_FILL_ALPHA :: 0.96

// How long the launch stretch lasts, in seconds, and how far it goes.
// A fixed window, so a fifteen-cell slide does not stretch for its whole
// length.
STRETCH_DURATION :: 0.10
STRETCH_AMOUNT :: 0.22

// How much of the stretch's length is paid back in width.
STRETCH_VOLUME :: 0.6

// Where the block is on screen, and how big, this frame.
PlayerPose :: struct {
	centre: rl.Vector2,
	size:   rl.Vector2,
}

// 0 at the instant a slide begins, 1 once the launch window has passed.
// Measured off distance travelled rather than a timer, because distance is
// already state the simulation keeps and a timer would be a second clock.
get_launch_progress :: proc(player: game.Player) -> f32 {
	if player.dir == .None {
		return 1
	}
	window := f32(game.RUNNER_SPEED) * STRETCH_DURATION
	if window <= 0 {
		return 1
	}
	return clamp(player.travelled / window, 0, 1)
}

// A per-axis scale multiplier, 1.0 being the block's own size. The long
// axis is whichever way the body is going.
get_player_scale :: proc(player: game.Player) -> rl.Vector2 {
	launch := get_launch_progress(player)
	if launch >= 1 {
		return rl.Vector2{1, 1}
	}

	// A bell: nothing at both ends of the window, everything in the
	// middle of it.
	stretch := STRETCH_AMOUNT * math.sin_f32(launch * math.PI)
	along := 1 + stretch
	across := 1 - stretch * STRETCH_VOLUME

	#partial switch player.dir {
	case .Left, .Right:
		return rl.Vector2{along, across}
	case .Up, .Down:
		return rl.Vector2{across, along}
	}
	return rl.Vector2{1, 1}
}

new_player_pose :: proc(player: game.Player, world: game.World) -> PlayerPose {
	position := game.get_player_world(player)
	scale := get_player_scale(player)
	return PlayerPose {
		centre = rl.Vector2 {
			game.maze_screen_x(position.x, world.scroll_offset),
			position.y,
		},
		size = rl.Vector2{game.PLAYER_SIZE * scale.x, game.PLAYER_SIZE * scale.y},
	}
}

draw_player :: proc(player: game.Player, world: game.World, palettes: core.PaletteSet) {
	pose := new_player_pose(player, world)

	// One rectangle, and that is the whole character.
	//
	// raylib's own primitive rather than two triangles of our own, because
	// **a triangle's winding is not free**: raylib culls back faces, and
	// getting it backwards is a shape that silently does not appear — the
	// same trap that once cost a whole ribbon in render/stroke.odin.
	//
	// The core is lifted the same amount a wall's is, so the block belongs
	// to the same light rather than merely sharing its hue.
	fill := core.with_alpha(
		core.lighten_color(palettes.current.accent, WORLD_CORE_LIGHT),
		PLAYER_FILL_ALPHA,
	)
	rl.DrawRectanglePro(
		rl.Rectangle{pose.centre.x, pose.centre.y, pose.size.x, pose.size.y},
		rl.Vector2{pose.size.x * 0.5, pose.size.y * 0.5},
		0,
		fill,
	)
}
