/*
* Player
* The block, and the one verb it has: it is sent in a direction and it
* travels until a wall stops it.
*
* EVERY MOVE IS A COMMITMENT (pillar 1)
*
* There is no steering. A press picks a direction, the body leaves, and
* nothing — including another press — can change where it is going until
* it arrives. What the next press buys is the *next* journey, which is why
* one press is latched while the current one finishes rather than dropped:
* a game about reading two moves ahead has to let the second one be given
* early.
*
* Junctions passed in the middle of a slide are not offered. The body only
* turns where something stopped it, which is what makes the length of the
* straight runs a difficulty knob and not a decoration: a long corridor is
* fast and asks nothing, a short one is slow and asks constantly.
*
* THE BODY LIVES ON THE GRID, AND THE GRID ANSWERS FOR IT
*
* Collision is a question to the maze about a wall between two cells, not
* an overlap between two rectangles. The block is drawn centred in its
* cell and is smaller than the cell, so the air around it is presentation
* and costs nothing: there is no pixel at which it can catch on a corner,
* because no pixel is ever consulted.
*/
package game

import "../core"
import rl "vendor:raylib/v55"

// The block, against a 60 px cell: 0.63 of the corridor, so it clears
// comfortably without rattling. Kept from the two-lane game, where the
// same number was arrived at for a different reason and happens to be
// right for this one.
PLAYER_SIZE :: 38

// How fast a slide travels, in px/s. It has to be well clear of the
// scroll speed or a perfect run would still lose ground: at 270 px/s of
// scroll this is 3.33x, which is also the budget the generator measures
// its chunks against (see MazeParams.max_ratio).
RUNNER_SPEED :: 900

Player :: struct {
	// The cell the body is leaving. At rest, the cell it is in.
	col:       int,
	row:       int,

	// The journey, if one is under way. .None means at rest.
	dir:       core.Direction,
	to_col:    int,
	to_row:    int,
	travelled: f32, // px covered so far
	length:    f32, // px the whole journey covers

	// One press held for the moment the body arrives. Exactly one: a queue
	// would let a player type a route in advance and stop reading the maze.
	queued:    core.Direction,
}

new_player :: proc() -> Player {
	return Player{col = 0, row = MAZE_START_ROW}
}

// Where the body is in world pixels, interpolated along its journey.
get_player_world :: proc(player: Player) -> rl.Vector2 {
	from := rl.Vector2{cell_centre_x(player.col), cell_centre_y(player.row)}
	if player.dir == .None || player.length <= 0 {
		return from
	}
	to := rl.Vector2{cell_centre_x(player.to_col), cell_centre_y(player.to_row)}
	t := clamp(player.travelled / player.length, 0, 1)
	return from + (to - from) * t
}

get_player_screen_x :: proc(player: Player, world: World) -> f32 {
	return maze_screen_x(get_player_world(player).x, world.camera_x)
}

// Which way the four keys point this step. .None if none of them went
// down; when two arrive on the same step the order here decides, and it
// puts forward first because forward is what the game is about.
input_direction :: proc(input: core.Input) -> core.Direction {
	switch {
	case input.move_right:
		return .Right
	case input.move_left:
		return .Left
	case input.move_up:
		return .Up
	case input.move_down:
		return .Down
	}
	return .None
}

@(private = "file")
start_slide :: proc(player: ^Player, maze: ^Maze, dir: core.Direction) {
	to_col, to_row, cells := maze_slide(maze, player.col, player.row, dir)
	if cells == 0 {
		return
	}
	player.dir = dir
	player.to_col = to_col
	player.to_row = to_row
	player.length = f32(cells) * CELL_SIZE
	player.travelled = 0
}

// One simulation step of the body.
//
// A press is taken whenever it arrives and spent when the body is free.
// The overshoot of the step that completes a journey is carried into the
// next one rather than thrown away, so the speed is exactly RUNNER_SPEED
// however the steps fall.
update_player :: proc(player: ^Player, maze: ^Maze, input: core.Input, delta_time: f32) {
	if pressed := input_direction(input); pressed != .None {
		player.queued = pressed
	}

	if player.dir == .None {
		if player.queued != .None {
			start_slide(player, maze, player.queued)
			player.queued = .None
		}
		return
	}

	player.travelled += RUNNER_SPEED * delta_time
	if player.travelled < player.length {
		return
	}

	overshoot := player.travelled - player.length
	player.col = player.to_col
	player.row = player.to_row
	player.dir = .None
	player.travelled = 0
	player.length = 0

	if player.queued != .None {
		start_slide(player, maze, player.queued)
		player.queued = .None
		if player.dir != .None {
			player.travelled = min(overshoot, player.length)
		}
	}
}
