/*
* Maze Render
* The walls, as the one mark the whole picture is made of.
*
* MERGE FIRST, DRAW SECOND
*
* A screen of maze is about 560 individual cell edges. Drawn one at a time
* that is 560 polylines, each with its own halo passes, and CLAUDE.md
* flagged it as the known technical risk of this phase. Welding collinear
* edges into single runs takes it to **82 strokes a screen, measured** —
* a factor of seven — and every run is two points, so STROKE_MAX_POINTS is
* not in play at all here. It could become so if a wall ever curves.
*
* THE TWO FRONTS ARE THE SAME TWO LINES OF ARITHMETIC AS BEFORE
*
* A run is clipped to [front_x, DRAW_FRONT_X] and that is the whole of
* both ideas: the Corruption eats the world on the left, the pen writes it
* on the right, and no wall needs an appearance animation or a state of
* its own. A run entirely outside the window is skipped rather than drawn
* at zero length.
*
* THE OUTER BOUNDARY IS NUDGED, AND ONLY IN THE DRAWING
*
* Twelve rows of 60 px fill 720 px exactly, so the ceiling sits on y = 0
* and the floor on y = 720 — each would show half a stroke and none of its
* halo. The drawn line is therefore pulled in by half its own width. The
* *cells* are not moved: the grid, the collision and the generator all
* still divide 720 exactly, and the lie is 1.4 px in one place.
*/
package render

import "../core"
import "../game"
import rl "vendor:raylib/v55"

// The rung the whole weight hierarchy is a multiple or a fraction of.
// Every stroke in the game derives from this one number, so tuning the
// world cannot silently invert the order (CLAUDE.md).
WORLD_STROKE_THICKNESS :: 2.8

// How far a neon line's core is lifted toward white. A line is not its own
// colour at the centre — the colour is what the light does to the air
// around it — so anything meant to read as *the same colour* as a wall has
// to be lifted by the same amount, the block included.
WORLD_CORE_LIGHT :: 0.5

// The corridor's own edge against everything inside it. The boundary is
// heavier than the walls so the eye reads the outside of the world before
// it reads its furniture, and the ratio between them is what carries that
// — not the absolute weights, which went up a third after the first
// playtest asked for a slightly heavier line.
MAZE_BOUND_WEIGHT :: 1.3
MAZE_WALL_WEIGHT :: 1.0

MAZE_GLOW :: 0.40
MAZE_SPREAD :: 4.0

@(private = "file")
clipped_span :: proc(a, b, low, high: f32) -> (f32, f32, bool) {
	start := max(min(a, b), low)
	end := min(max(a, b), high)
	if end <= start {
		return 0, 0, false
	}
	return start, end, true
}

// The y the boundary lines are actually drawn at — see the header.
@(private = "file")
boundary_y :: proc(row_boundary: int, half: f32) -> f32 {
	y := f32(row_boundary) * game.CELL_SIZE
	if row_boundary == 0 {
		return half
	}
	if row_boundary == game.MAZE_ROWS {
		return f32(core.SCREEN_HEIGHT) - half
	}
	return y
}

draw_maze :: proc(
	maze: ^game.Maze,
	world: game.World,
	palettes: core.PaletteSet,
	front_x: f32,
) {
	first, last := game.get_visible_columns(world)

	colour := palettes.current.light
	wall := new_stroke(colour, WORLD_STROKE_THICKNESS * MAZE_WALL_WEIGHT)
	wall.glow = MAZE_GLOW
	wall.spread = MAZE_SPREAD
	wall.round_caps = false
	apply_glow_gain(&wall, glow_gain(palettes.world_t))

	bound := new_stroke(colour, WORLD_STROKE_THICKNESS * MAZE_BOUND_WEIGHT)
	bound.glow = MAZE_GLOW
	bound.spread = MAZE_SPREAD
	apply_glow_gain(&bound, glow_gain(palettes.world_t))

	left := front_x
	right := f32(DRAW_FRONT_X)

	// Horizontal runs: one per unbroken row of north walls, the ceiling
	// and the floor included. maze_walls answers "solid" for a row outside
	// the corridor, which is what makes the floor need no special case.
	for row_boundary in 0 ..= game.MAZE_ROWS {
		edge := row_boundary == 0 || row_boundary == game.MAZE_ROWS
		stroke := edge ? bound : wall
		y := boundary_y(row_boundary, stroke.thickness * 0.5)

		run := -1
		for col in first ..= last + 1 {
			present :=
				col <= last && .North in game.maze_walls(maze, col, row_boundary)
			if present && run < 0 {
				run = col
			}
			if !present && run >= 0 {
				x0 := game.maze_screen_x(f32(run) * game.CELL_SIZE, world.camera_x)
				x1 := game.maze_screen_x(f32(col) * game.CELL_SIZE, world.camera_x)
				if start, end, ok := clipped_span(x0, x1, left, right); ok {
					draw_stroke_line(rl.Vector2{start, y}, rl.Vector2{end, y}, stroke)
				}
				run = -1
			}
		}
	}

	// Vertical runs: one per unbroken column of west walls. A whole run is
	// on one x, so it is in or out of the window as a unit.
	for col_boundary in first ..= last + 1 {
		x := game.maze_screen_x(f32(col_boundary) * game.CELL_SIZE, world.camera_x)
		if x < left || x > right {
			continue
		}
		run := -1
		for row in 0 ..= game.MAZE_ROWS {
			present :=
				row < game.MAZE_ROWS && .West in game.maze_walls(maze, col_boundary, row)
			if present && run < 0 {
				run = row
			}
			if !present && run >= 0 {
				y0 := boundary_y(run, wall.thickness * 0.5)
				y1 := boundary_y(row, wall.thickness * 0.5)
				draw_stroke_line(rl.Vector2{x, y0}, rl.Vector2{x, y1}, wall)
				run = -1
			}
		}
	}

	// The pen, on the two lines that are always there. One nib per
	// horizontal wall would be a dotted column at the right edge, which is
	// the bright vertical bar draw_front.odin exists to refuse.
	draw_nib(rl.Vector2{right, boundary_y(0, bound.thickness * 0.5)}, palettes)
	draw_nib(
		rl.Vector2{right, boundary_y(game.MAZE_ROWS, bound.thickness * 0.5)},
		palettes,
	)
}
