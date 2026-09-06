/*
* Maze
* The corridor is a grid, and this file is the whole of it: where the
* walls are, how a chunk of them is made, and what a slide from a cell
* runs into.
*
* THE GRID
*
* Twelve rows of 60 px fill the 720 px canvas exactly, and the columns run
* on forever. Vertically the division has to be whole or the corridor
* would not close against the floor; horizontally it never has to be,
* because the world scrolls and the fraction is just where the camera is.
*
* Each cell owns two walls, its **north** and its **west**. The south wall
* of a cell is the north wall of the cell below it, and storing that twice
* is the classic way to let the two copies drift apart. Two bits per cell,
* 384 bytes for a chunk of 32 columns.
*
* THE WALLS ARE EDGES, NOT BLOCKS
*
* Not an aesthetic preference: CLAUDE.md says two things are filled, the
* field and the character. A maze of solid cells would be a third, and it
* would stop being La Linea. So a wall is a line on the boundary between
* two cells and a cell is always somewhere the body can be.
*
* A CHUNK IS GENERATED ALONE, AND THAT IS THE POINT
*
* The seams are **not** handed forward from one chunk to the next. The
* openings on a chunk boundary are a function of the boundary's column
* index alone (seam_openings), so chunk N and chunk N+1 independently
* compute the same set of holes and agree without ever meeting. That buys
* three things at once: a chunk can be dropped from the ring buffer and
* regenerated identically, a chunk can be verified on its own in a test,
* and nothing has to be generated in order.
*
* THE INVARIANT IS A BUDGET, NOT A CONNECTION
*
* "A path exists" is too weak here. The world scrolls whether the player
* is making progress or not, so a path that costs three cells of climbing
* for every column it gains is a path that kills you. The generator
* therefore **measures** every chunk it makes — the cheapest crossing, in
* cells travelled and in slides taken — and re-rolls the chunk with
* another sub-seed if the numbers fall outside the band asked for. The
* loop is deterministic from the seed, so the run stays reproducible.
*
* The measurement walks *slides*, not cells, because that is what the
* player actually does: one press travels until a wall stops it. Measuring
* cell adjacency instead would be measuring a game nobody is playing.
*/
package game

import "../core"
import "core:slice"

// --- The grid ---

MAZE_ROWS :: 12
CELL_SIZE :: 60

// Columns per chunk. 32 cells is 1920 px, about one and a half screens,
// which is the smallest unit that still contains a decision worth
// measuring.
CHUNK_COLUMNS :: 32

// Chunks held at once: the two or three on screen, one ahead of the pen,
// one behind the Corruption. Fixed, so the maze never allocates.
CHUNK_SLOTS :: 5

// Where column 0 lands on screen at scroll_offset 0. Chosen so the first
// cell's centre sits exactly on core.PLAYER_HOME_X.
MAZE_ORIGIN_X :: f32(core.PLAYER_HOME_X) - CELL_SIZE * 0.5

Wall :: enum u8 {
	North,
	West,
}

WallSet :: bit_set[Wall;u8]

ALL_WALLS :: WallSet{.North, .West}

// One chunk's cells, addressed chunk-locally.
CellGrid :: [CHUNK_COLUMNS][MAZE_ROWS]WallSet

// What the generator found out about the chunk it just made. Kept on the
// chunk rather than thrown away, because the difficulty band is stated in
// these numbers and a test has to be able to read them back.
ChunkMetrics :: struct {
	solvable:  bool, // every way in reaches a way out
	trap_free: bool, // every cell you can get to, you can still get out of
	cells:     int, // the worst entry's cheapest crossing, in cells travelled
	moves:     int, // slides taken along that same crossing
	attempts:  int, // how many re-rolls it took to land in the band
	accepted:  bool, // false if the band was never met and the closest was kept
}

Chunk :: struct {
	index:   int,
	live:    bool,
	cells:   CellGrid,
	metrics: ChunkMetrics,
}

// The knobs, all continuous, all growing with the level (Design Doc §12).
MazeParams :: struct {
	// How much the carve prefers to leave left-right corridors intact.
	// 1.0 is no preference; larger delays the removal of horizontal walls
	// and so grows the length of the straight runs.
	wall_bias:  f32,

	// Fraction of dead ends opened back up. High means a wrong branch
	// rejoins the maze instead of ending; low means it costs you the walk
	// back out. A *perfect* maze is braid_rate 0 and is exactly wrong
	// here — without the ability to turn round against the scroll, a dead
	// end does not cost time, it kills.
	braid_rate: f32,

	// The accepted band for (cheapest crossing in cells) / CHUNK_COLUMNS.
	// 1.0 is a straight corridor. The ceiling that matters is
	// RUNNER_SPEED / scroll speed: above that ratio the cheapest crossing
	// loses ground even played perfectly.
	min_ratio:  f32,
	max_ratio:  f32,
}

// Where the first level starts. Wide band and a very high braid rate: the
// opening minute is meant to be readable, not tight.
DEFAULT_MAZE_PARAMS :: MazeParams {
	wall_bias  = 2.4,
	braid_rate = 0.90,
	min_ratio  = 1.05,
	max_ratio  = 2.00,
}

// How many times a chunk may be re-rolled before the closest attempt is
// kept anyway. A chunk that cannot meet the band is still playable — it
// is only outside the difficulty the level asked for — so failing is
// never allowed to stop the game.
MAZE_MAX_ATTEMPTS :: 24

Maze :: struct {
	seed:   u64,
	params: MazeParams,
	slots:  [CHUNK_SLOTS]Chunk,
}

new_maze :: proc(seed: u64, params: MazeParams = DEFAULT_MAZE_PARAMS) -> Maze {
	return Maze{seed = seed, params = params}
}

// --- Randomness ---
//
// Its own generator rather than core:math/rand, for the reason CLAUDE.md
// gives: every draw has to be threaded explicitly so a run is reproducible
// from its seed. splitmix64 is also a *hash*, which is what lets a seam be
// computed from its column index alone.

@(private = "file")
splitmix64 :: proc(state: ^u64) -> u64 {
	state^ += 0x9E3779B97F4A7C15
	z := state^
	z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ~ (z >> 27)) * 0x94D049BB133111EB
	return z ~ (z >> 31)
}

@(private = "file")
mix :: proc(a, b: u64) -> u64 {
	state := a ~ (b + 0x9E3779B97F4A7C15 + (a << 6) + (a >> 2))
	return splitmix64(&state)
}

@(private = "file")
Rng :: struct {
	state: u64,
}

@(private = "file")
next_u64 :: proc(rng: ^Rng) -> u64 {
	return splitmix64(&rng.state)
}

@(private = "file")
next_f32 :: proc(rng: ^Rng) -> f32 {
	return f32(next_u64(rng) >> 40) / f32(1 << 24)
}

@(private = "file")
next_int :: proc(rng: ^Rng, n: int) -> int {
	if n <= 0 {
		return 0
	}
	return int(next_u64(rng) % u64(n))
}

// --- Seams ---

SEAM_MIN_OPENINGS :: 1
SEAM_MAX_OPENINGS :: 3

// The holes in the vertical line at a chunk boundary, as a function of
// that boundary's absolute column and nothing else. Both chunks that
// touch the boundary call this and get the same answer.
//
// Column 0 is the level's left wall and has no holes: the run starts
// inside the maze, not outside it.
seam_openings :: proc(seed: u64, boundary_col: int) -> (open: [MAZE_ROWS]bool) {
	if boundary_col <= 0 {
		return
	}
	rng := Rng{mix(seed, u64(boundary_col) * 0x2545F4914F6CDD1D)}
	count := SEAM_MIN_OPENINGS + next_int(&rng, SEAM_MAX_OPENINGS - SEAM_MIN_OPENINGS + 1)
	// Collisions are left alone: two draws landing on the same row simply
	// mean a narrower seam, which is a fine thing for a seam to be.
	for _ in 0 ..< count {
		open[next_int(&rng, MAZE_ROWS)] = true
	}
	return
}

// --- The one rule about walls ---

// Whether a move from a cell into the next one crosses a wall.
//
// `here` is the source cell's set and `ahead` the destination's. Right and
// Down read the wall the *destination* owns; Left and Up read the source's
// own. Every query in the file goes through this, so the two directions of
// one wall can never disagree.
crosses_wall :: proc(here, ahead: WallSet, dir: core.Direction) -> bool {
	switch dir {
	case .Right:
		return .West in ahead
	case .Left:
		return .West in here
	case .Down:
		return .North in ahead
	case .Up:
		return .North in here
	case .None:
		return true
	}
	return true
}

// --- Reading the live maze ---

@(private = "file")
slot_of :: proc(index: int) -> int {
	return ((index % CHUNK_SLOTS) + CHUNK_SLOTS) % CHUNK_SLOTS
}

// The chunk covering this index, generated on demand. A slot holding a
// different chunk is simply rebuilt: generation is a pure function of the
// seed and the index, so an evicted chunk comes back identical.
ensure_chunk :: proc(maze: ^Maze, index: int) -> ^Chunk {
	chunk := &maze.slots[slot_of(index)]
	if !chunk.live || chunk.index != index {
		generate_chunk(maze, chunk, index)
	}
	return chunk
}

maze_walls :: proc(maze: ^Maze, col, row: int) -> WallSet {
	// Outside the corridor everything is solid, which is what makes the
	// floor and the ceiling need no special case anywhere else.
	if row < 0 || row >= MAZE_ROWS || col < 0 {
		return ALL_WALLS
	}
	chunk := ensure_chunk(maze, col / CHUNK_COLUMNS)
	return chunk.cells[col % CHUNK_COLUMNS][row]
}

maze_is_open :: proc(maze: ^Maze, col, row: int, dir: core.Direction) -> bool {
	if dir == .None {
		return false
	}
	next_col, next_row := core.step_cell(col, row, dir)
	if next_row < 0 || next_row >= MAZE_ROWS || next_col < 0 {
		return false
	}
	return !crosses_wall(maze_walls(maze, col, row), maze_walls(maze, next_col, next_row), dir)
}

// Where a slide from this cell ends, and how many cells it covers. Zero
// cells means the move was into a wall and never started.
maze_slide :: proc(
	maze: ^Maze,
	col, row: int,
	dir: core.Direction,
) -> (
	end_col, end_row, travelled: int,
) {
	end_col, end_row = col, row
	for maze_is_open(maze, end_col, end_row, dir) {
		end_col, end_row = core.step_cell(end_col, end_row, dir)
		travelled += 1
	}
	return
}

// --- Where a cell is ---

cell_centre_x :: proc(col: int) -> f32 {
	return f32(col) * CELL_SIZE + CELL_SIZE * 0.5
}

cell_centre_y :: proc(row: int) -> f32 {
	return f32(row) * CELL_SIZE + CELL_SIZE * 0.5
}

// World x to screen x. The one conversion; nothing else may invent its
// own, or the maze slides against the body drawn on it.
maze_screen_x :: proc(world_x: f32, scroll_offset: f32) -> f32 {
	return MAZE_ORIGIN_X + world_x - scroll_offset
}

// --- Generation ---

@(private = "file")
EDGE_CAPACITY :: (CHUNK_COLUMNS - 1) * MAZE_ROWS + CHUNK_COLUMNS * (MAZE_ROWS - 1)

@(private = "file")
CELL_COUNT :: CHUNK_COLUMNS * MAZE_ROWS

@(private = "file")
Edge :: struct {
	key:  f32,
	col:  i16,
	row:  i16,
	wall: Wall,
}

@(private = "file")
find_root :: proc(parent: ^[CELL_COUNT]i16, node: i16) -> i16 {
	root := node
	for parent[root] != root {
		root = parent[root]
	}
	// Path compression, so the union-find stays flat without a rank array.
	walk := node
	for parent[walk] != root {
		next := parent[walk]
		parent[walk] = root
		walk = next
	}
	return root
}

// One attempt at a chunk: carve a spanning tree, then open the dead ends.
@(private = "file")
carve_chunk :: proc(seed: u64, index: int, attempt_seed: u64, params: MazeParams) -> CellGrid {
	cells: CellGrid
	for col in 0 ..< CHUNK_COLUMNS {
		for row in 0 ..< MAZE_ROWS {
			cells[col][row] = ALL_WALLS
		}
	}

	// The left seam is not carved, it is given: both chunks that touch
	// this boundary derive it from the boundary's column index.
	left := seam_openings(seed, index * CHUNK_COLUMNS)
	for row in 0 ..< MAZE_ROWS {
		if left[row] {
			cells[0][row] -= {.West}
		}
	}

	rng := Rng{attempt_seed}

	// Every wall that could be removed, with a random key. Walls between
	// left and right neighbours keep their key as drawn; walls between a
	// cell and the one below get theirs multiplied by wall_bias, so they
	// tend to be considered later and survive — which is what makes the
	// corridors run left to right.
	edges: [EDGE_CAPACITY]Edge
	edge_count := 0
	for col in 0 ..< CHUNK_COLUMNS {
		for row in 0 ..< MAZE_ROWS {
			if col > 0 {
				edges[edge_count] = Edge {
					key  = next_f32(&rng),
					col  = i16(col),
					row  = i16(row),
					wall = .West,
				}
				edge_count += 1
			}
			if row > 0 {
				edges[edge_count] = Edge {
					key  = next_f32(&rng) * params.wall_bias,
					col  = i16(col),
					row  = i16(row),
					wall = .North,
				}
				edge_count += 1
			}
		}
	}

	slice.sort_by(edges[:edge_count], proc(a, b: Edge) -> bool {
		return a.key < b.key
	})

	parent: [CELL_COUNT]i16
	for i in 0 ..< CELL_COUNT {
		parent[i] = i16(i)
	}

	// Kruskal: take a wall down whenever it joins two parts that were not
	// yet connected. What comes out is a spanning tree, so every cell in
	// the chunk is reachable from every other and the crossing exists
	// before anything has been measured.
	for edge_index in 0 ..< edge_count {
		edge := edges[edge_index]
		col, row := int(edge.col), int(edge.row)
		other_col, other_row := col, row
		if edge.wall == .West {
			other_col -= 1
		} else {
			other_row -= 1
		}
		a := find_root(&parent, i16(col * MAZE_ROWS + row))
		b := find_root(&parent, i16(other_col * MAZE_ROWS + other_row))
		if a == b {
			continue
		}
		parent[a] = b
		cells[col][row] -= {edge.wall}
	}

	braid_chunk(&cells, &rng, params.braid_rate)
	return cells
}

// Opens a second way out of dead ends, so a wrong branch rejoins the maze
// instead of ending in a wall the player cannot afford to walk back out
// of. Horizontal openings are preferred for the same reason the carve
// prefers them: a corridor that runs with the scroll is one the player can
// read at speed.
@(private = "file")
braid_chunk :: proc(cells: ^CellGrid, rng: ^Rng, rate: f32) {
	for col in 0 ..< CHUNK_COLUMNS {
		for row in 0 ..< MAZE_ROWS {
			if count_open(cells, col, row) != 1 {
				continue
			}
			if next_f32(rng) >= rate {
				continue
			}

			// Candidates, horizontal first, each one a wall that exists
			// and whose far side is still inside the chunk.
			candidates: [4]core.Direction
			candidate_count := 0
			order := [4]core.Direction{.Left, .Right, .Up, .Down}
			if next_f32(rng) < 0.5 {
				order[0], order[1] = order[1], order[0]
			}
			if next_f32(rng) < 0.5 {
				order[2], order[3] = order[3], order[2]
			}
			for dir in order {
				next_col, next_row := core.step_cell(col, row, dir)
				if next_col < 0 || next_col >= CHUNK_COLUMNS {
					continue
				}
				if next_row < 0 || next_row >= MAZE_ROWS {
					continue
				}
				if !crosses_wall(cells[col][row], cells[next_col][next_row], dir) {
					continue
				}
				candidates[candidate_count] = dir
				candidate_count += 1
			}
			if candidate_count == 0 {
				continue
			}

			// The list is already in preference order, so taking the first
			// is taking a horizontal one whenever there is one.
			open_wall(cells, col, row, candidates[0])
		}
	}
}

@(private = "file")
open_wall :: proc(cells: ^CellGrid, col, row: int, dir: core.Direction) {
	switch dir {
	case .Left:
		cells[col][row] -= {.West}
	case .Up:
		cells[col][row] -= {.North}
	case .Right:
		cells[col + 1][row] -= {.West}
	case .Down:
		cells[col][row + 1] -= {.North}
	case .None:
	}
}

@(private = "file")
count_open :: proc(cells: ^CellGrid, col, row: int) -> int {
	total := 0
	for dir in ([4]core.Direction{.Left, .Right, .Up, .Down}) {
		if grid_is_open(cells, col, row, dir) {
			total += 1
		}
	}
	// A hole in the chunk's left seam is a way out too, and a cell that
	// has one is not a dead end even if it has nothing else.
	if col == 0 && .West not_in cells[0][row] {
		total += 1
	}
	return total
}

// --- Reading a chunk on its own ---
//
// The same wall rule as the live maze, bounded by the chunk instead of by
// the world. It is deliberately blind past the last column: measuring a
// chunk must not reach into the next one, or a chunk would stop being
// verifiable alone.

grid_is_open :: proc(cells: ^CellGrid, col, row: int, dir: core.Direction) -> bool {
	if dir == .None {
		return false
	}
	next_col, next_row := core.step_cell(col, row, dir)
	if next_col < 0 || next_col >= CHUNK_COLUMNS {
		return false
	}
	if next_row < 0 || next_row >= MAZE_ROWS {
		return false
	}
	return !crosses_wall(cells[col][row], cells[next_col][next_row], dir)
}

grid_slide :: proc(
	cells: ^CellGrid,
	col, row: int,
	dir: core.Direction,
) -> (
	end_col, end_row, travelled: int,
) {
	end_col, end_row = col, row
	for grid_is_open(cells, end_col, end_row, dir) {
		end_col, end_row = core.step_cell(end_col, end_row, dir)
		travelled += 1
	}
	return
}

// --- The measurement ---
//
// WHY SLIDING IS NOT THE SAME AS WALKING, AND WHY IT MATTERS HERE
//
// A carve leaves every cell connected to every other, so on a walking
// grid the chunk is trivially crossable. The player does not walk. A
// press travels until a wall stops it, so the player can only *stop*
// where there is something to stop against — a junction in the middle of
// a straight run is passed over, not turned at.
//
// Slide-connectivity is therefore strictly weaker than cell-connectivity,
// and every number below is computed on the slide graph. Measuring cell
// adjacency instead would be measuring a game nobody is playing.
//
// Two separate questions come out of it, and the generator asks both:
//
//   solvable  — every way in reaches a way out. The player does not
//               choose which hole in the seam the previous chunk spat
//               them through, so it is not enough that *one* of them
//               works.
//   trap_free — every cell you can get to, you can still get out of.
//               This is pillar 5 stated exactly: being stuck must be the
//               consequence of a route the player chose, never of a maze
//               that had no answer.

@(private = "file")
UNREACHED :: 1 << 28

// Where each slide from each cell ends, built once and read by everything
// below. `travelled` of 0 means the move was into a wall.
@(private = "file")
SlideTable :: struct {
	end_col:   [CHUNK_COLUMNS][MAZE_ROWS][4]i16,
	end_row:   [CHUNK_COLUMNS][MAZE_ROWS][4]i16,
	travelled: [CHUNK_COLUMNS][MAZE_ROWS][4]i16,
}

// The four moves, in the order every table in this file is indexed by.
@(private = "file")
slide_dirs :: proc() -> [4]core.Direction {
	return {.Left, .Right, .Up, .Down}
}

// BOTH EDGES OF A CHUNK LIE, AND THEY LIE IN OPPOSITE DIRECTIONS
//
// grid_slide is blind past the chunk, so it reports a stop at each edge
// where the live maze reports a journey continuing. Neither lie is
// harmless, and both of them are about a row the seam has a hole in:
//
//   right edge — the slide does not stop, it carries the player into the
//     next chunk. That is the crossing, so the state is absorbing and
//     never a stepping stone (see cheapest_crossing).
//   left edge — the slide does not stop either, it carries them back into
//     the *previous* chunk, which this measurement cannot see. So the
//     move is struck out entirely: conservative, since a chunk wrongly
//     called hard is re-rolled and a chunk wrongly called easy is shipped.
//
// Left in, the two lies let the search stand still at an edge and use it
// to climb into rows the player can never stop in. Every chunk came out
// green and the live maze was walled shut three chunks in.
@(private = "file")
build_slide_table :: proc(cells: ^CellGrid, left_seam: [MAZE_ROWS]bool) -> SlideTable {
	table: SlideTable
	dirs := slide_dirs()
	for col in 0 ..< CHUNK_COLUMNS {
		for row in 0 ..< MAZE_ROWS {
			for dir_index in 0 ..< 4 {
				dir := dirs[dir_index]
				end_col, end_row, travelled := grid_slide(cells, col, row, dir)
				if dir == .Left && end_col == 0 && left_seam[end_row] {
					travelled = 0
				}
				table.end_col[col][row][dir_index] = i16(end_col)
				table.end_row[col][row][dir_index] = i16(end_row)
				table.travelled[col][row][dir_index] = i16(travelled)
			}
		}
	}
	return table
}

// The cheapest crossing from one entry row, in cells travelled, plus the
// number of slides along that same crossing. Cells travelled is the
// reading that matters: cells are time, and time is ground lost to the
// front. Slides are the second reading — how many decisions the chunk
// asks for.
@(private = "file")
cheapest_crossing :: proc(
	table: ^SlideTable,
	start_col, start_row, start_cost: int,
	exits: [MAZE_ROWS]bool,
	reached: ^[CHUNK_COLUMNS][MAZE_ROWS]bool,
) -> (
	cells: int,
	moves: int,
	found: bool,
) {
	dist: [CHUNK_COLUMNS][MAZE_ROWS]int
	steps: [CHUNK_COLUMNS][MAZE_ROWS]int
	done: [CHUNK_COLUMNS][MAZE_ROWS]bool
	for col in 0 ..< CHUNK_COLUMNS {
		for row in 0 ..< MAZE_ROWS {
			dist[col][row] = UNREACHED
		}
	}
	dist[start_col][start_row] = start_cost

	// Arriving at the right edge in a row the seam has a hole in *is* the
	// crossing: the slide that got there does not stop, it carries the
	// player into the next chunk. So an exit is absorbing — it is never
	// expanded, and never used as a stepping stone to somewhere else.
	//
	// This cost a whole afternoon. Without it the chunk is measured blind
	// past its last column, which hands the player a standstill at the
	// right edge that they never actually get, and the search happily
	// climbs through those phantom stops into rows nothing can reach. The
	// per-chunk numbers came out green while the live maze was walled
	// shut three chunks in.
	if exits[start_row] && start_col == CHUNK_COLUMNS - 1 {
		return start_cost, 0, true
	}

	// Dijkstra by linear scan: 384 nodes, so the scan costs less than a
	// heap would and has nothing to get wrong.
	for _ in 0 ..< CELL_COUNT {
		best := UNREACHED
		best_col, best_row := -1, -1
		for col in 0 ..< CHUNK_COLUMNS {
			for row in 0 ..< MAZE_ROWS {
				if !done[col][row] && dist[col][row] < best {
					best = dist[col][row]
					best_col, best_row = col, row
				}
			}
		}
		if best_col < 0 {
			break
		}
		done[best_col][best_row] = true
		reached[best_col][best_row] = true

		// Absorbing, and popped in cost order, so the first one reached is
		// the cheapest crossing there is.
		if best_col == CHUNK_COLUMNS - 1 && exits[best_row] {
			return best, steps[best_col][best_row], true
		}

		for dir_index in 0 ..< 4 {
			travelled := int(table.travelled[best_col][best_row][dir_index])
			if travelled == 0 {
				continue
			}
			end_col := int(table.end_col[best_col][best_row][dir_index])
			end_row := int(table.end_row[best_col][best_row][dir_index])
			candidate := best + travelled
			if candidate < dist[end_col][end_row] {
				dist[end_col][end_row] = candidate
				steps[end_col][end_row] = steps[best_col][best_row] + 1
			}
		}
	}

	// Every reachable cell was popped and none of them was an exit.
	return 0, 0, false
}

// Which cells can still reach an exit, by relaxing the slide graph
// backwards until it stops changing. A fixpoint rather than a reversed
// adjacency list: 384 cells and four moves each, so the sweep is cheaper
// than the bookkeeping the list would need.
@(private = "file")
cells_that_can_still_get_out :: proc(
	table: ^SlideTable,
	exits: [MAZE_ROWS]bool,
) -> (
	safe: [CHUNK_COLUMNS][MAZE_ROWS]bool,
) {
	for row in 0 ..< MAZE_ROWS {
		if exits[row] {
			safe[CHUNK_COLUMNS - 1][row] = true
		}
	}
	for {
		changed := false
		for col in 0 ..< CHUNK_COLUMNS {
			for row in 0 ..< MAZE_ROWS {
				if safe[col][row] {
					continue
				}
				for dir_index in 0 ..< 4 {
					if table.travelled[col][row][dir_index] == 0 {
						continue
					}
					end_col := int(table.end_col[col][row][dir_index])
					end_row := int(table.end_row[col][row][dir_index])
					if safe[end_col][end_row] {
						safe[col][row] = true
						changed = true
						break
					}
				}
			}
		}
		if !changed {
			break
		}
	}
	return
}

// The row the run starts on, and the row a chunk with no left seam is
// entered at. The middle of the corridor, so the opening frame does not
// state a preference for the floor or the ceiling.
MAZE_START_ROW :: MAZE_ROWS / 2

measure_chunk :: proc(cells: ^CellGrid, seed: u64, index: int) -> ChunkMetrics {
	left := seam_openings(seed, index * CHUNK_COLUMNS)
	exits := seam_openings(seed, (index + 1) * CHUNK_COLUMNS)

	// The first chunk of a level has no left seam — the run starts inside
	// it — so it is entered at the middle row instead.
	entries := left
	any_entry := false
	for row in 0 ..< MAZE_ROWS {
		any_entry ||= left[row]
	}
	if !any_entry {
		entries[MAZE_START_ROW] = true
	}

	table := build_slide_table(cells, left)

	metrics := ChunkMetrics {
		solvable = true,
	}
	reached: [CHUNK_COLUMNS][MAZE_ROWS]bool
	for row in 0 ..< MAZE_ROWS {
		if !entries[row] {
			continue
		}

		// **The player does not arrive at rest on the boundary.** They are
		// carried in by the slide that crossed it and stop where this
		// chunk first stops them, which can be most of the way across.
		// Measuring from a standstill at column 0 would hand them a
		// stopping place they never get, and the whole point of measuring
		// slides instead of cells is not to model a game nobody plays.
		//
		// The first chunk is the exception: nothing carried the player in,
		// so the run really does begin at rest.
		start_col, start_row, entry_cost := 0, row, 0
		if any_entry {
			start_col, start_row, entry_cost = grid_slide(cells, 0, row, .Right)
		}

		crossing, moves, found := cheapest_crossing(
			&table,
			start_col,
			start_row,
			entry_cost,
			exits,
			&reached,
		)
		if !found {
			metrics.solvable = false
			continue
		}
		// The worst entry, not the best: the player does not get to
		// choose which hole the previous chunk spat them through.
		if crossing > metrics.cells {
			metrics.cells = crossing
			metrics.moves = moves
		}
	}
	if !metrics.solvable {
		metrics.cells = 0
		metrics.moves = 0
		return metrics
	}

	safe := cells_that_can_still_get_out(&table, exits)
	metrics.trap_free = true
	for col in 0 ..< CHUNK_COLUMNS {
		for row in 0 ..< MAZE_ROWS {
			if reached[col][row] && !safe[col][row] {
				metrics.trap_free = false
			}
		}
	}
	return metrics
}

// --- Accept or re-roll ---

@(private = "file")
band_distance :: proc(ratio: f32, params: MazeParams) -> f32 {
	if ratio < params.min_ratio {
		return params.min_ratio - ratio
	}
	if ratio > params.max_ratio {
		return ratio - params.max_ratio
	}
	return 0
}

// Fills a slot with the chunk at this index: generate, measure, and
// re-roll until the crossing costs what the level asked for.
//
// The loop always terminates with something playable. A chunk that never
// lands in the band is kept anyway — that is a tuning problem, not a
// reason to have no maze — and it says so in `accepted` so a test can
// count how often it happens.
generate_chunk :: proc(maze: ^Maze, chunk: ^Chunk, index: int) {
	base := mix(maze.seed, u64(index) + 1)

	best_cells: CellGrid
	best_metrics: ChunkMetrics
	best_score: f32 = 1e30

	// Nothing has been kept yet, so the first attempt must win whatever it
	// scores. Without this an all-failing chunk would ship the zero value
	// of a CellGrid, which is a grid with no walls at all.
	best_score = max(f32)

	for attempt in 0 ..< MAZE_MAX_ATTEMPTS {
		cells := carve_chunk(maze.seed, index, mix(base, u64(attempt)), maze.params)
		metrics := measure_chunk(&cells, maze.seed, index)
		metrics.attempts = attempt + 1

		// Lexicographic, so the fallback degrades in the order the design
		// cares about: a chunk that can be crossed beats one that cannot,
		// a chunk with no trap in it beats one with, and only then does
		// the difficulty band get a say. Scoring them all as "failed"
		// would let a maze with no way through win over a merely hard one.
		score: f32 = band_distance(f32(metrics.cells) / f32(CHUNK_COLUMNS), maze.params)
		if !metrics.trap_free {
			score += 1e6
		}
		if !metrics.solvable {
			score += 1e12
		}
		if score < best_score {
			best_score = score
			best_cells = cells
			best_metrics = metrics
		}
		if score == 0 {
			best_metrics.accepted = true
			break
		}
	}

	chunk.index = index
	chunk.live = true
	chunk.cells = best_cells
	chunk.metrics = best_metrics
}

// --- What the camera can see, and what has to exist before it does ---

// The columns the screen covers, with a margin so a wall entering from the
// right is already there when its first pixel is.
get_visible_columns :: proc(world: World, margin: int = 1) -> (first, last: int) {
	left := world.scroll_offset - MAZE_ORIGIN_X
	first = int(left / CELL_SIZE) - margin
	last = int((left + f32(core.SCREEN_WIDTH)) / CELL_SIZE) + margin
	if first < 0 {
		first = 0
	}
	return
}

// Builds every chunk the next screen and a half will need, from inside a
// simulation step.
//
// Generation is pure and idempotent, so a draw that triggered it would
// still get the right walls — but it would pay 4 ms for them in the middle
// of a frame, and it would do it at a moment decided by the camera rather
// than by the simulation. Doing it here means the cost lands on a step,
// where a fixed timestep can absorb it, and the renderer only ever reads.
ensure_maze_ahead :: proc(maze: ^Maze, world: World) {
	first, last := get_visible_columns(world)
	last += CHUNK_COLUMNS // one chunk beyond the pen
	for index in first / CHUNK_COLUMNS ..= last / CHUNK_COLUMNS {
		ensure_chunk(maze, index)
	}
}
