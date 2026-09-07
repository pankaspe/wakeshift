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
*
* AND IT IS STILL NOT ENOUGH — MEASURED, AND OPEN
*
* A solver run over the *assembled* world says so. Of the cells a player
* can reach from the start, **3.18% are cells from which no route gains
* another twenty columns** (16 seeds, 260 columns each, 5184 reachable
* cells, 165 of them terminal; the worst seed had 28). Every one of them
* is a run that is over, and pillar 5 says never.
*
* The per-chunk numbers do not see it and cannot: trap_free only checks
* cells `reached` by cheapest_crossing, and that search stops at the first
* exit it pops, so everything dearer than the crossing is never examined.
* The band and the trap test are about the route; this is about the rest
* of the maze.
*
* It is L2's remaining half — the deterministic repair, not more
* attempts — and it is unchanged by the fragments: the identical census
* run against the previous commit returns the identical 165.
*
* One thing does answer it, and it was not designed to: the Dream's
* pierce frees **165 of 165**. That is a nice property and it is not a
* fix. A player without a full bar is still walled in.
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

// Where column 0 lands on screen at camera 0. Chosen so the first
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

	repairs:   int, // walls the repair had to take down
	repaired:  bool, // false if it gave up and the chunk was kept anyway

	// The seam hole `cells` and `moves` were measured from: the *worst*
	// entry, the one the difficulty band is stated against. Kept because
	// everything measured on the chunk afterwards — where a fragment is
	// worth putting, above all — has to be measured against the same
	// route the chunk was graded on, or the two numbers describe
	// different games.
	entry_row: int,
}

Chunk :: struct {
	index:        int,
	live:         bool,
	cells:        CellGrid,
	metrics:      ChunkMetrics,

	// What is lying in it to be picked up, and what has already been
	// taken (game/fragment.odin).
	//
	// **The taken flags do not survive eviction**, because a chunk is
	// rebuilt from the seed and its index alone. That is only safe
	// because an evicted chunk is three chunks behind the camera and the
	// Corruption reaches at most CORRUPTION_MAX_LEAD back: by the time a
	// slot is reused, the ground it held is gone from the world.
	pickups:      [MAX_PICKUPS_PER_CHUNK]Pickup,
	pickup_count: int,
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

	// What a fragment has to cost, in **cells of detour** off the
	// cheapest crossing. Not a place on the grid and not a probability:
	// the generator already knows the exact price of every cell, so
	// "somewhere that costs about a second" is a query rather than a
	// guess (Design Doc §9).
	//
	// Below the floor the fragment is on the way and is not a decision;
	// above the ceiling it is not an offer, it is a trap with a reward
	// painted on it. Both ends grow with the level.
	fragment_min:  f32,
	fragment_max:  f32,
	fragments:     int, // how many to try to place per chunk

	// A Lucid is only worth its name where the plain route will not go:
	// it has to be dear without a pierce and cheap with one, or the
	// bonus is not paying for the bonus.
	lucid_min:     f32, // cells of detour on the plain slide graph
	lucid_max:     f32, // cells of detour once one wall a move may be pierced
	lucids:        int,
}

// Where the first level starts. Wide band and a very high braid rate: the
// opening minute is meant to be readable, not tight.
DEFAULT_MAZE_PARAMS :: MazeParams {
	wall_bias    = 2.4,
	braid_rate   = 0.90,
	min_ratio    = 1.05,
	max_ratio    = 2.00,

	// A cell is 60 px and a slide covers 900 px/s, so **15 cells is one
	// second**. The opening band is a fifth of a second to a little over
	// one: cheap enough that a first run can afford every fragment it
	// sees, dear enough that taking one is a thing the player decided to
	// do. Against the front's opening 190 px/s, an 18-cell detour costs
	// 228 px of the 2000 px starting lead.
	//
	// Measured, 1000 chunks over 40 seeds: **2.26 fragments a chunk**
	// rather than the 3 asked for, detour mean 10.6 cells, min 3, max 18.
	// 34 chunks in 1000 got none at all. A slice with nothing in the band
	// is left empty rather than widened, which is the shortfall and is
	// the right shortfall to have.
	fragment_min = 3,
	fragment_max = 18,
	fragments    = 3,

	// A chunk is 32 columns, so three fragments is one about every ten
	// columns, and FRAGMENTS_TO_FILL of them is two chunks of collecting
	// (game/dream.odin).
	//
	// Measured over the same 1000: **1.87 Lucids a chunk**, and 62% of
	// them sit where the walking maze cannot reach them *at all* — mean
	// 53.7 cells of detour for the rest — against a mean 5.3 cells once a
	// move may pierce. The bonus is paying for the bonus.
	lucid_min    = 22,
	lucid_max    = 12,
	lucids       = 2,
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
//
// `Rng` and `mix` are visible to the package rather than to this file
// alone, and that is deliberate: fragment placement (game/fragment.odin)
// has to draw from the *same* lineage as the carve it is placing into, or
// two chunks with the same walls could end up with different fragments.
// One seed, one generator, one run.

@(private = "file")
splitmix64 :: proc(state: ^u64) -> u64 {
	state^ += 0x9E3779B97F4A7C15
	z := state^
	z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ~ (z >> 27)) * 0x94D049BB133111EB
	return z ~ (z >> 31)
}

mix :: proc(a, b: u64) -> u64 {
	state := a ~ (b + 0x9E3779B97F4A7C15 + (a << 6) + (a >> 2))
	return splitmix64(&state)
}

Rng :: struct {
	state: u64,
}

next_u64 :: proc(rng: ^Rng) -> u64 {
	return splitmix64(&rng.state)
}

next_f32 :: proc(rng: ^Rng) -> f32 {
	return f32(next_u64(rng) >> 40) / f32(1 << 24)
}

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
maze_screen_x :: proc(world_x: f32, camera_x: f32) -> f32 {
	return MAZE_ORIGIN_X + world_x - camera_x
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


// --- The repair ---
//
// WHY RE-ROLLING IS NOT AN ANSWER HERE
//
// The band is a preference and re-rolling is the right tool for it: a
// chunk outside the difficulty asked for is still a chunk, so throwing it
// away costs nothing but a sub-seed. A pocket is not a preference. Pillar
// 5 says *never*, and "never" is not something a loop of twenty-four
// attempts can promise — it can only make it rarer, and rarer is what the
// generator was already doing while 3.18% of the cells a player could
// reach were cells no route leaves.
//
// So the pockets are opened rather than re-drawn. One wall at a time, at
// the cell that is furthest along, and always the same wall for the same
// maze — the whole loop is a function of the walls it is handed, so it
// costs the run's reproducibility nothing.
//
// WHY IT HAS TO RE-MEASURE AFTER EVERY SINGLE WALL
//
// Safety is **not monotone in openings**, which is the one thing about
// this that is not obvious. Taking a wall down does not only add a move,
// it *lengthens a slide*: a cell that used to stop on safe ground now
// runs past it and may end somewhere worse. So a batch of openings cannot
// be reasoned about, only a sequence of them, each one measured. That is
// also why the loop's convergence is a measurement below and not an
// argument here.
//
// WHAT IT WILL NOT TOUCH
//
// The west wall of column 0 is the seam, and the seam is a function of
// its boundary's column index so that two chunks agree on it without
// meeting. Opening it here would make this chunk disagree with the one
// before it. The direction is simply not offered — both edges fall out of
// the bounds check for free.

// How many walls the repair may take down before it gives up and lets the
// chunk be re-rolled instead.
//
// Measured over 1000 chunks: 74.7% need one at all, and the mean is 3.21.
// The cap is not there for the mean, it is there for the tail — a chunk
// that wants two dozen walls down is a chunk the carve made badly, and
// re-rolling it costs a sub-seed while opening it costs the maze. Giving
// up is the cheaper failure, and generate_chunk already scores an
// unrepaired chunk below any repaired one.
REPAIR_MAX_STEPS :: 24

// Preference order. Right first, because the cell being repaired is the
// pocket's furthest one and east is where the crossing is; vertical next,
// which is the cheapest way out of a horizontal pocket; left last,
// because sending the player backwards is the move the scroll charges
// most for.
@(private = "file")
repair_dirs :: proc() -> [4]core.Direction {
	return {.Right, .Up, .Down, .Left}
}

// Takes down one wall, at the cell furthest along that cannot reach a
// crossing and *has a wall left to take down*.
//
// The second half of that is not a detail. A cell whose four sides are
// already open can still be unsafe — every one of its slides ends
// somewhere unsafe — and there is nothing to do at that cell. Stopping
// there was worth 1 chunk in 1000 shipping with a pocket in it; walking on
// to the next unsafe cell instead costs a few lines and takes it to zero.
// Something further back opens, the slides lengthen, and the cell that
// could not be touched is reached from somewhere new.
//
// Furthest along first, and a fixed tie-break, so the same walls come down
// for the same maze every time.
@(private = "file")
open_one_wall :: proc(
	cells: ^CellGrid,
	safe: ^[CHUNK_COLUMNS][MAZE_ROWS]bool,
) -> (
	any_unsafe: bool,
	col, row: int,
	dir: core.Direction,
) {
	dirs := repair_dirs()
	for c := CHUNK_COLUMNS - 1; c >= 0; c -= 1 {
		for r := MAZE_ROWS - 1; r >= 0; r -= 1 {
			if safe[c][r] {
				continue
			}
			any_unsafe = true
			for candidate in dirs {
				next_col, next_row := core.step_cell(c, r, candidate)
				// Both chunk edges fall out here for free, and the left
				// one is the seam: opening it would make this chunk
				// disagree with the one before it.
				if next_col < 0 || next_col >= CHUNK_COLUMNS {
					continue
				}
				if next_row < 0 || next_row >= MAZE_ROWS {
					continue
				}
				if !crosses_wall(cells[c][r], cells[next_col][next_row], candidate) {
					continue // already open; taking it down again is a no-op loop
				}
				open_wall(cells, c, r, candidate)
				return true, c, r, candidate
			}
		}
	}
	return any_unsafe, 0, 0, .None
}

// Opens walls until every cell in the chunk can still reach a crossing.
//
// Every cell, not only the ones an entry happens to reach: a chunk has to
// be verifiable on its own, and chunk-local reachability is an
// underestimate anyway — the player can slide back into this chunk from
// the next one, through a seam this measurement is blind past.
repair_chunk :: proc(
	cells: ^CellGrid,
	left_seam: [MAZE_ROWS]bool,
	exits: [MAZE_ROWS]bool,
) -> (
	opened: int,
	ok: bool,
) {
	table := build_slide_table(cells, left_seam)
	for _ in 0 ..< REPAIR_MAX_STEPS {
		safe := cells_that_can_still_get_out(&table, exits)
		any_unsafe, col, row, dir := open_one_wall(cells, &safe)
		if !any_unsafe {
			return opened, true
		}
		// Every unsafe cell in the chunk is already open on all four
		// sides. Nothing here can fix it, so the caller re-rolls.
		if dir == .None {
			return opened, false
		}
		opened += 1

		// Patch the table instead of rebuilding it. A west wall belongs to
		// one row and a north wall to one column, and nothing else can
		// have changed.
		#partial switch dir {
		case .Left, .Right:
			refresh_slide_row(&table, cells, left_seam, row)
		case .Up, .Down:
			refresh_slide_column(&table, cells, left_seam, col)
		}
	}

	// The last step of the loop opens a wall and falls out without looking
	// again, and that wall may well have been the one. Ask once more
	// rather than reporting a failure the chunk did not have.
	final := cells_that_can_still_get_out(&table, exits)
	for col in 0 ..< CHUNK_COLUMNS {
		for row in 0 ..< MAZE_ROWS {
			if !final[col][row] {
				return opened, false
			}
		}
	}
	return opened, true
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
// A slide that goes through the wall that stopped it and runs on to the
// next one — the Dream's one verb (game/dream.odin), on a chunk that is
// being measured rather than played.
//
// Exactly one wall, and only where there is a cell on the far side of it:
// a pierce may never carry the body out through the floor, the ceiling or
// the chunk's own edges. Refusing at the edges is also what keeps the
// pierced measurement as blind past the chunk as the plain one is.
@(private = "file")
grid_slide_pierced :: proc(
	cells: ^CellGrid,
	col, row: int,
	dir: core.Direction,
) -> (
	end_col, end_row, travelled: int,
) {
	end_col, end_row, travelled = grid_slide(cells, col, row, dir)
	next_col, next_row := core.step_cell(end_col, end_row, dir)
	if next_col < 0 || next_col >= CHUNK_COLUMNS || next_row < 0 || next_row >= MAZE_ROWS {
		return
	}
	beyond_col, beyond_row, beyond := grid_slide(cells, next_col, next_row, dir)
	return beyond_col, beyond_row, travelled + 1 + beyond
}

@(private = "file")
fill_slide :: proc(
	table: ^SlideTable,
	cells: ^CellGrid,
	left_seam: [MAZE_ROWS]bool,
	col, row, dir_index: int,
	pierce: bool,
) {
	dir := slide_dirs()[dir_index]
	end_col, end_row, travelled := grid_slide(cells, col, row, dir)
	if pierce {
		end_col, end_row, travelled = grid_slide_pierced(cells, col, row, dir)
	}
	if dir == .Left && end_col == 0 && left_seam[end_row] {
		travelled = 0
	}
	table.end_col[col][row][dir_index] = i16(end_col)
	table.end_row[col][row][dir_index] = i16(end_row)
	table.travelled[col][row][dir_index] = i16(travelled)
}

build_slide_table :: proc(
	cells: ^CellGrid,
	left_seam: [MAZE_ROWS]bool,
	pierce: bool = false,
) -> SlideTable {
	table: SlideTable
	for col in 0 ..< CHUNK_COLUMNS {
		for row in 0 ..< MAZE_ROWS {
			for dir_index in 0 ..< 4 {
				fill_slide(&table, cells, left_seam, col, row, dir_index, pierce)
			}
		}
	}
	return table
}

// What one opened wall actually changes in the table, which is far less
// than everything.
//
// **A horizontal slide reads only west walls and a vertical one reads only
// north walls**, and a wall lives in exactly one row or one column. So
// taking down a west wall in row r can only change the Left and Right
// entries of row r — twelve columns' worth of one row, not the whole
// grid — and a north wall in column c only that column's Up and Down.
//
// The repair opens a wall and re-measures, over and over, so this is the
// difference between the loop costing four milliseconds a chunk and
// costing well under one. It is the only reason the repair fits inside a
// simulation step.
@(private = "file")
refresh_slide_row :: proc(
	table: ^SlideTable,
	cells: ^CellGrid,
	left_seam: [MAZE_ROWS]bool,
	row: int,
) {
	for col in 0 ..< CHUNK_COLUMNS {
		fill_slide(table, cells, left_seam, col, row, 0, false) // .Left
		fill_slide(table, cells, left_seam, col, row, 1, false) // .Right
	}
}

@(private = "file")
refresh_slide_column :: proc(
	table: ^SlideTable,
	cells: ^CellGrid,
	left_seam: [MAZE_ROWS]bool,
	col: int,
) {
	for row in 0 ..< MAZE_ROWS {
		fill_slide(table, cells, left_seam, col, row, 2, false) // .Up
		fill_slide(table, cells, left_seam, col, row, 3, false) // .Down
	}
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
		solvable  = true,
		entry_row = MAZE_START_ROW,
	}
	graded := false
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
		if !graded || crossing > metrics.cells {
			metrics.cells = crossing
			metrics.moves = moves
			metrics.entry_row = row
			graded = true
		}
	}
	if !metrics.solvable {
		metrics.cells = 0
		metrics.moves = 0
		return metrics
	}

	// **Every cell, not the ones the crossing search happened to reach.**
	// It used to be the latter and that is what hid the pockets:
	// cheapest_crossing returns at the first exit it pops, so `reached`
	// holds only what is cheaper than the crossing and everything dearer
	// was never looked at. A solver over the assembled world found 3.18%
	// of reachable cells terminal while every chunk reported green.
	//
	// `reached` is kept because the fragment placement is graded on the
	// same route, and because a test is easier to trust when the thing it
	// used to check is still there to compare against.
	safe := cells_that_can_still_get_out(&table, exits)
	metrics.trap_free = true
	for col in 0 ..< CHUNK_COLUMNS {
		for row in 0 ..< MAZE_ROWS {
			if !safe[col][row] {
				metrics.trap_free = false
			}
		}
	}
	_ = reached
	return metrics
}


// --- The price of every cell ---
//
// The band above says whether the chunk is crossable in time. This says
// what every *other* cell in it costs, which is the question a fragment
// answers to (Design Doc §9): a fragment is not dropped somewhere pretty,
// it is placed where the detour costs what the level asked for.
//
// MEASURE COLLECTING, NOT STOPPING
//
// The obvious number — cheapest cost to *stop* on a cell, plus cheapest
// cost from there to an exit — is a proxy, and it is wrong in the
// direction that matters. A pickup is taken by passing over it, and a
// slide passes over every cell between its ends without stopping on any
// of them. A cell sitting in the middle of the optimal route's own
// straight run would price as an expensive detour while actually being
// free, and the risk/reward junction the design is built on would be
// decorated with fragments that cost nothing.
//
// So `cover` is the cheapest **whole route through the chunk that passes
// over the cell**: for every slide the route could take, the cost of
// reaching its start, plus the slide, plus the cheapest way out of its
// end — charged to every cell the slide crosses. Subtract the crossing
// and what is left is what the cell costs to collect, in cells travelled.
// It is zero for anything the player was going to drive over anyway.

ChunkCosts :: struct {
	// Cheapest cost to come to rest on each cell, from the graded entry.
	to_cell:  [CHUNK_COLUMNS][MAZE_ROWS]int,

	// Cheapest cost from each cell to a hole in the right-hand seam.
	to_exit:  [CHUNK_COLUMNS][MAZE_ROWS]int,

	// Cheapest whole crossing that passes over each cell. See above.
	cover:    [CHUNK_COLUMNS][MAZE_ROWS]int,

	// The cheapest crossing from that entry — the baseline every detour
	// is measured against.
	crossing: int,
	found:    bool,
}

// Whether a cost read out of a ChunkCosts is a real number or the absence
// of any such route. Callers ask this rather than being handed the
// sentinel, so there is one place that knows what "no route" is spelled.
cost_is_real :: proc(cost: int) -> bool {
	return cost < UNREACHED
}

// Everything above, for one chunk, entered at one row.
//
// `pierce` swaps the slide graph for the one the Dream plays on — every
// move goes through the wall that stopped it and runs to the next. The
// entry slide is deliberately *not* pierced in either case, so the two
// results share a starting position and their costs can be subtracted
// from each other.
chunk_costs :: proc(
	cells: ^CellGrid,
	seed: u64,
	index: int,
	entry_row: int,
	pierce: bool = false,
) -> (
	costs: ChunkCosts,
) {
	left := seam_openings(seed, index * CHUNK_COLUMNS)
	exits := seam_openings(seed, (index + 1) * CHUNK_COLUMNS)
	any_entry := false
	for row in 0 ..< MAZE_ROWS {
		any_entry ||= left[row]
	}

	table := build_slide_table(cells, left, pierce)
	dirs := slide_dirs()

	// The player is carried in by the slide that crossed the seam, exactly
	// as measure_chunk assumes. The first chunk of a run is the exception:
	// nothing carried them in, so it really does begin at rest.
	start_col, start_row, entry_cost := 0, entry_row, 0
	if any_entry {
		start_col, start_row, entry_cost = grid_slide(cells, 0, entry_row, .Right)
	}

	for col in 0 ..< CHUNK_COLUMNS {
		for row in 0 ..< MAZE_ROWS {
			costs.to_cell[col][row] = UNREACHED
			costs.to_exit[col][row] = UNREACHED
			costs.cover[col][row] = UNREACHED
		}
	}
	costs.to_cell[start_col][start_row] = entry_cost

	// Forward, to completion this time: cheapest_crossing stops at the
	// first exit because that is all the band needs, and every cell's
	// price needs the whole thing. Exits stay absorbing for the reason
	// they are absorbing there — the slide that reaches one does not stop,
	// it carries the player into the next chunk.
	done: [CHUNK_COLUMNS][MAZE_ROWS]bool
	for _ in 0 ..< CELL_COUNT {
		best := UNREACHED
		best_col, best_row := -1, -1
		for col in 0 ..< CHUNK_COLUMNS {
			for row in 0 ..< MAZE_ROWS {
				if !done[col][row] && costs.to_cell[col][row] < best {
					best = costs.to_cell[col][row]
					best_col, best_row = col, row
				}
			}
		}
		if best_col < 0 {
			break
		}
		done[best_col][best_row] = true

		if best_col == CHUNK_COLUMNS - 1 && exits[best_row] {
			if !costs.found {
				costs.crossing = best
				costs.found = true
			}
			continue
		}

		for dir_index in 0 ..< 4 {
			travelled := int(table.travelled[best_col][best_row][dir_index])
			if travelled == 0 {
				continue
			}
			end_col := int(table.end_col[best_col][best_row][dir_index])
			end_row := int(table.end_row[best_col][best_row][dir_index])
			candidate := best + travelled
			if candidate < costs.to_cell[end_col][end_row] {
				costs.to_cell[end_col][end_row] = candidate
			}
		}
	}
	if !costs.found {
		return
	}

	// Backward, by the same fixpoint sweep cells_that_can_still_get_out
	// uses and for the same reason: 384 cells and four moves each is
	// cheaper to sweep than a reversed adjacency list is to build.
	for row in 0 ..< MAZE_ROWS {
		if exits[row] {
			costs.to_exit[CHUNK_COLUMNS - 1][row] = 0
		}
	}
	for {
		changed := false
		for col in 0 ..< CHUNK_COLUMNS {
			for row in 0 ..< MAZE_ROWS {
				if col == CHUNK_COLUMNS - 1 && exits[row] {
					continue
				}
				best := UNREACHED
				for dir_index in 0 ..< 4 {
					travelled := int(table.travelled[col][row][dir_index])
					if travelled == 0 {
						continue
					}
					end_col := int(table.end_col[col][row][dir_index])
					end_row := int(table.end_row[col][row][dir_index])
					if !cost_is_real(costs.to_exit[end_col][end_row]) {
						continue
					}
					candidate := travelled + costs.to_exit[end_col][end_row]
					if candidate < best {
						best = candidate
					}
				}
				if best < costs.to_exit[col][row] {
					costs.to_exit[col][row] = best
					changed = true
				}
			}
		}
		if !changed {
			break
		}
	}

	// And the one that is actually read: charge every route to every cell
	// it drives over.
	charge :: proc(
		costs: ^ChunkCosts,
		from_col, from_row, to_col, to_row: int,
		dir: core.Direction,
		total: int,
	) {
		col, row := from_col, from_row
		for {
			if total < costs.cover[col][row] {
				costs.cover[col][row] = total
			}
			if col == to_col && row == to_row {
				return
			}
			col, row = core.step_cell(col, row, dir)
			if col < 0 || col >= CHUNK_COLUMNS || row < 0 || row >= MAZE_ROWS {
				return
			}
		}
	}

	for col in 0 ..< CHUNK_COLUMNS {
		for row in 0 ..< MAZE_ROWS {
			if !cost_is_real(costs.to_cell[col][row]) {
				continue
			}
			for dir_index in 0 ..< 4 {
				travelled := int(table.travelled[col][row][dir_index])
				if travelled == 0 {
					continue
				}
				end_col := int(table.end_col[col][row][dir_index])
				end_row := int(table.end_row[col][row][dir_index])
				if !cost_is_real(costs.to_exit[end_col][end_row]) {
					continue
				}
				total :=
					costs.to_cell[col][row] + travelled + costs.to_exit[end_col][end_row]
				charge(&costs, col, row, end_col, end_row, dirs[dir_index], total)
			}
		}
	}

	// The entry slide is a move too, and the cells it carried the player
	// over are collected on the way in like any others.
	if cost_is_real(costs.to_exit[start_col][start_row]) {
		charge(
			&costs,
			0,
			entry_row,
			start_col,
			start_row,
			.Right,
			entry_cost + costs.to_exit[start_col][start_row],
		)
	}
	return
}

// Takes a wall down in the *live* maze, which is the Dream's pierce
// (game/player.odin) and the only thing in the game that writes to a
// chunk after it was generated.
//
// A wall belongs to exactly one cell — its own north or west — so the
// direction is resolved to that owner here and nowhere else, which is the
// same rule crosses_wall reads by. Refusing at the corridor's own edges
// is not a special case for tidiness: it is what stops a pierce carrying
// the body out through the floor.
//
// It makes a chunk stop being a pure function of its seed until the slot
// is reused, and that is accepted rather than overlooked — see Chunk.
maze_open_wall :: proc(maze: ^Maze, col, row: int, dir: core.Direction) {
	owner_col, owner_row := col, row
	wall: Wall
	switch dir {
	case .Right:
		owner_col, wall = col + 1, .West
	case .Left:
		wall = .West
	case .Down:
		owner_row, wall = row + 1, .North
	case .Up:
		wall = .North
	case .None:
		return
	}
	if owner_row < 0 || owner_row >= MAZE_ROWS || owner_col < 0 {
		return
	}
	chunk := ensure_chunk(maze, owner_col / CHUNK_COLUMNS)
	chunk.cells[owner_col % CHUNK_COLUMNS][owner_row] -= {wall}
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
// Measured at **5.8 ms a chunk**, of which the carve-and-measure loop is
// the 4.1 ms it always was and placing the pickups is the rest. One chunk
// is generated about every seven seconds of play and it lands inside a
// 16.7 ms step, so it fits — but it is the largest single thing a step
// ever does, and anything added to placement is paid there.
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

	left := seam_openings(maze.seed, index * CHUNK_COLUMNS)
	exits := seam_openings(maze.seed, (index + 1) * CHUNK_COLUMNS)

	for attempt in 0 ..< MAZE_MAX_ATTEMPTS {
		cells := carve_chunk(maze.seed, index, mix(base, u64(attempt)), maze.params)

		// Before the measurement, not after: the band has to describe the
		// chunk that ships, and the repair takes walls down, which makes
		// the crossing cheaper. Measuring first would grade a maze nobody
		// is given.
		repairs, repaired := repair_chunk(&cells, left, exits)

		metrics := measure_chunk(&cells, maze.seed, index)
		metrics.attempts = attempt + 1
		metrics.repairs = repairs
		metrics.repaired = repaired

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

	// Once, on the chunk that won — not on every attempt. Placement reads
	// the walls that shipped, and measuring the ones that did not would be
	// paying twenty-four times for an answer about a maze nobody plays.
	place_pickups(maze, chunk)
}

// --- What the camera can see, and what has to exist before it does ---

// The columns the screen covers, with a margin so a wall entering from the
// right is already there when its first pixel is.
get_visible_columns :: proc(world: World, margin: int = 1) -> (first, last: int) {
	left := world.camera_x - MAZE_ORIGIN_X
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
// still get the right walls — but it would pay 5.8 ms for them in the
// middle of a frame, and it would do it at a moment decided by the camera rather
// than by the simulation. Doing it here means the cost lands on a step,
// where a fixed timestep can absorb it, and the renderer only ever reads.
ensure_maze_ahead :: proc(maze: ^Maze, world: World) {
	first, last := get_visible_columns(world)
	last += CHUNK_COLUMNS // one chunk beyond the pen
	for index in first / CHUNK_COLUMNS ..= last / CHUNK_COLUMNS {
		ensure_chunk(maze, index)
	}
}
