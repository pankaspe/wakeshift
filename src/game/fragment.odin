/*
* Fragment
* What is lying in the maze to be picked up, where it is put, and what it
* does when it is taken.
*
* ONE OBJECT, ONE JOB (Design Doc §8)
*
* A **Fragment** charges the bar and does nothing else. It does not slow
* the front, it does not add score, it does not extend anything. In the
* two-lane game a fragment slowed the Corruption directly, and the effect
* on the ground is still there — it just goes through the Dream now
* instead of stepping over it, which is what makes the Dream the only
* source of ground there is. An object with two jobs is an object with
* none the player can read.
*
* A **Lucid** is its counterpart in the Dream: it extends the phase, and
* it is the only thing up there worth going for. Each is collectable in
* one phase only, so the maze visibly changes what it contains at the
* moment the world turns — which pays pillar 6 in a third channel, on top
* of the colour and the pierce.
*
* WHERE THEY GO IS A QUERY, NOT A GUESS
*
* game/maze.odin already prices every cell in the chunk against the same
* crossing the difficulty band was measured on (ChunkCosts). So "a cell
* that costs about half a second of detour" is something to *ask*, and
* the risk/reward junction the whole design turns on — the short empty
* road against the long full one — is selected by measurement rather than
* drawn by hand.
*
* Two bands, and they say opposite things:
*
*   a Fragment must cost between fragment_min and fragment_max cells of
*     detour. Under the floor it is on the way and asks nothing; over the
*     ceiling it is not an offer, it is bait.
*   a Lucid must cost *more* than lucid_min on the plain slide graph and
*     less than lucid_max on the pierced one. That is "the normal route
*     does not go there, and the Dream's own verb is what fetches it" —
*     the bonus paying for the bonus, stated as arithmetic.
*
* THE SPREAD IS THE ONLY THING LEFT TO CHANCE
*
* The band decides what a cell is worth; it does not stop every qualifying
* cell being in the same corner. So the chunk is cut into as many column
* slices as there are pickups to place and one is drawn per slice, from
* the run's own generator. The measurement chooses the price, the slice
* chooses the spacing, and the draw is only which of the equally good
* cells it lands on.
*/
package game

import rl "vendor:raylib/v55"

// The most one chunk can hold. Fragments and Lucids share it: they are
// placed together and drawn from the same list, because a cell may hold
// one or the other and never both.
MAX_PICKUPS_PER_CHUNK :: 12

PickupKind :: enum u8 {
	Fragment,
	Lucid,
}

Pickup :: struct {
	col:   i16, // chunk-local, like everything else stored on a Chunk
	row:   i16,
	kind:  PickupKind,
	taken: bool,
}

// A pickup in world coordinates, which is the only form anything outside
// this file wants one in. render/ asks for these rather than being handed
// the chunks, so nothing that draws has to know the ring buffer exists.
VisiblePickup :: struct {
	position: rl.Vector2,
	kind:     PickupKind,
}

@(private = "file")
CANDIDATE_CAPACITY :: CHUNK_COLUMNS * MAZE_ROWS

@(private = "file")
Candidate :: struct {
	col: i16,
	row: i16,
}

// What one cell costs to collect, in cells travelled beyond the cheapest
// crossing. Zero for anything the route drives over anyway.
@(private = "file")
detour_of :: proc(costs: ChunkCosts, col, row: int) -> (cells: f32, ok: bool) {
	if !costs.found || !cost_is_real(costs.cover[col][row]) {
		return 0, false
	}
	return f32(costs.cover[col][row] - costs.crossing), true
}

// Fills the chunk's pickup list. Called once, on the accepted chunk.
place_pickups :: proc(maze: ^Maze, chunk: ^Chunk) {
	chunk.pickup_count = 0
	if !chunk.metrics.solvable {
		return
	}

	plain := chunk_costs(&chunk.cells, maze.seed, chunk.index, chunk.metrics.entry_row)
	if !plain.found {
		return
	}

	// A separate lineage from the carve's, so changing how many fragments
	// a level asks for cannot silently redraw its walls.
	rng := Rng{mix(maze.seed, u64(chunk.index) * 2 + 0xF3A6_1C0D_5E77_2B91)}

	taken: [CHUNK_COLUMNS][MAZE_ROWS]bool

	place_band(
		chunk,
		&rng,
		&taken,
		maze.params.fragments,
		.Fragment,
		proc(plain, pierced: ChunkCosts, params: MazeParams, col, row: int) -> bool {
			cells, ok := detour_of(plain, col, row)
			return ok && cells >= params.fragment_min && cells <= params.fragment_max
		},
		plain,
		plain,
		maze.params,
	)

	if maze.params.lucids <= 0 {
		return
	}
	pierced := chunk_costs(
		&chunk.cells,
		maze.seed,
		chunk.index,
		chunk.metrics.entry_row,
		true,
	)
	if !pierced.found {
		return
	}
	place_band(
		chunk,
		&rng,
		&taken,
		maze.params.lucids,
		.Lucid,
		proc(plain, pierced: ChunkCosts, params: MazeParams, col, row: int) -> bool {
			// Unreachable on the plain graph counts as "dearer than the
			// ceiling", which is the whole point of a Lucid: it is put
			// where the walking maze does not go at all.
			plain_cells, plain_ok := detour_of(plain, col, row)
			if plain_ok && plain_cells < params.lucid_min {
				return false
			}
			dream_cells, dream_ok := detour_of(pierced, col, row)
			return dream_ok && dream_cells <= params.lucid_max
		},
		plain,
		pierced,
		maze.params,
	)
}

// Draws `count` cells out of those the predicate accepts, one per column
// slice, and appends them to the chunk.
@(private = "file")
place_band :: proc(
	chunk: ^Chunk,
	rng: ^Rng,
	taken: ^[CHUNK_COLUMNS][MAZE_ROWS]bool,
	count: int,
	kind: PickupKind,
	accepts: proc(plain, pierced: ChunkCosts, params: MazeParams, col, row: int) -> bool,
	plain: ChunkCosts,
	pierced: ChunkCosts,
	params: MazeParams,
) {
	if count <= 0 {
		return
	}
	candidates: [CANDIDATE_CAPACITY]Candidate

	for slice_index in 0 ..< count {
		if chunk.pickup_count >= MAX_PICKUPS_PER_CHUNK {
			return
		}

		// The slice this one is drawn from. Integer arithmetic rather than
		// a float step so the last slice always ends on the last column.
		low := slice_index * CHUNK_COLUMNS / count
		high := (slice_index + 1) * CHUNK_COLUMNS / count

		found := 0
		for col in low ..< high {
			for row in 0 ..< MAZE_ROWS {
				if taken[col][row] {
					continue
				}
				if !accepts(plain, pierced, params, col, row) {
					continue
				}
				candidates[found] = Candidate{i16(col), i16(row)}
				found += 1
			}
		}
		// A slice with nothing in the band simply gets nothing. Widening
		// the band to fill it would be exactly the thing the measurement
		// exists to refuse.
		if found == 0 {
			continue
		}

		pick := candidates[next_int(rng, found)]
		taken[pick.col][pick.row] = true
		chunk.pickups[chunk.pickup_count] = Pickup {
			col  = pick.col,
			row  = pick.row,
			kind = kind,
		}
		chunk.pickup_count += 1
	}
}

// --- Reading them back ---

// Every pickup still lying between two absolute columns, in world
// coordinates. Returns how many were written into `out`.
gather_pickups :: proc(maze: ^Maze, first, last: int, out: []VisiblePickup) -> int {
	written := 0
	if last < first {
		return 0
	}
	low := max(first, 0)
	for index in low / CHUNK_COLUMNS ..= max(last, 0) / CHUNK_COLUMNS {
		chunk := ensure_chunk(maze, index)
		for i in 0 ..< chunk.pickup_count {
			pickup := chunk.pickups[i]
			if pickup.taken {
				continue
			}
			col := index * CHUNK_COLUMNS + int(pickup.col)
			if col < low || col > last {
				continue
			}
			if written >= len(out) {
				return written
			}
			out[written] = VisiblePickup {
				position = rl.Vector2 {
					cell_centre_x(col),
					cell_centre_y(int(pickup.row)),
				},
				kind     = pickup.kind,
			}
			written += 1
		}
	}
	return written
}

// Takes whatever the body is standing on, if the phase it belongs to is
// the one that is running.
//
// The cell is read off the body's own position rather than off the slide
// it is on, because a pickup is collected by **passing over** it and a
// slide passes over every cell between its ends. At 900 px/s a step
// covers 15 px of a 60 px cell, so no cell is ever stepped past — and
// that margin is what lets this be four lines instead of a sweep.
collect_pickups :: proc(maze: ^Maze, player: Player, dream: ^Dream) {
	position := get_player_world(player)
	col := int(position.x / CELL_SIZE)
	row := int(position.y / CELL_SIZE)
	if col < 0 || row < 0 || row >= MAZE_ROWS {
		return
	}

	chunk := ensure_chunk(maze, col / CHUNK_COLUMNS)
	local := i16(col % CHUNK_COLUMNS)
	for i in 0 ..< chunk.pickup_count {
		pickup := &chunk.pickups[i]
		if pickup.taken || pickup.col != local || pickup.row != i16(row) {
			continue
		}
		if pickup_phase(pickup.kind) != dream.phase {
			continue
		}
		pickup.taken = true
		switch pickup.kind {
		case .Fragment:
			dream.fragments += 1
			add_charge(dream, DREAM_CHARGE_PER_FRAGMENT)
		case .Lucid:
			dream.lucids += 1
			add_charge(dream, LUCID_EXTENSION)
		}
	}
}

// Which world each one belongs to. One object, one job, one phase.
pickup_phase :: proc(kind: PickupKind) -> DreamPhase {
	return kind == .Fragment ? .Real : .Dream
}
