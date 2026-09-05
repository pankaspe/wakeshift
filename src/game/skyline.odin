/*
* Skyline
* What a pattern says about the shape of a cube, and how the generator
* turns it into columns.
*
* THE PATTERN AUTHORS THE RHYTHM; THE GENERATOR DRAWS THE SHAPE
*
* A pattern says when something arrives, which lane it is on, and what it
* asks of the player. It does *not* say which boxes it is made of: it
* declares a **form** and the bounds around it, and the run's own
* generator draws the columns inside them. So one authored moment is a
* different ridge on every seed, and the pattern still knows exactly what
* it is asking — a staircase is a staircase whatever its steps come out
* as.
*
* This is the same shape of decision as the hole's width, which has rolled
* its own size since long before the profile existed. It works for the
* same reason: get_max_width lets the fairness check reason about an event
* *before* its random choices are made, so a pool that validates validates
* on every seed. Everything here that a validator needs is a bound, never
* an outcome.
*
* WHY A FORM ENUM IS NOT THE ONE T3 DELETED
*
* T3 deleted CubeForm, and it was right to: the shape lived in three files
* at once — a box in get_cube_size, a staircase in the renderer, nothing
* at all in the collision — so a pyramid was *drawn* as steps and
* *collided* as a filled box, and showed you a low step you could not
* stand on.
*
* The form here never survives generation. draw_skyline resolves it into
* columns once, at the moment the obstacle is created, and from there on
* the obstacle holds numbers and nothing anywhere knows the name of a
* shape. The mark, the hitbox and the support still read the same digits
* through get_cube_column. A form is a *recipe*, not a type of obstacle.
*
* WHAT EACH FORM SAYS
*
* The player meets an obstacle's left edge first, because the world
* scrolls toward them. That is what makes Rise and Fall different
* questions rather than one shape and its mirror:
*
*   Wall     one height, however many columns. The tower and the plateau,
*            and at one column one unit it is the primitive: a bump.
*            It says "not here" and means it for its whole width.
*   Rise     a staircase presenting its low step first. The only form
*            that can be *entered*: land on the low step and the wall
*            becomes the next column along.
*   Fall     the same staircase the other way round. It shows its full
*            height first and lets you off gently, which reads as a
*            different object even though it is the same boxes.
*   Canyon   two towers with the lane's own surface between them. The
*            zero-height column is a place to stand, not a hole — the
*            ground is still there — so it is the one form with a safe
*            middle, and the widest thing the set can say without
*            becoming a wall.
*/
package game

import "core:math/rand"

// An inclusive range the generator draws inside. Both ends equal pins the
// value, which is how a pattern authors an exact shape when it needs one
// — a facing pair, whose width the mirror bounds hold to two columns.
SkylineRange :: struct {
	low:  int,
	high: int,
}

SkylineForm :: enum {
	Wall,
	Rise,
	Fall,
	Canyon,
}

// The recipe an event declares. The zero value is the primitive — one
// column, one unit — so an event that says nothing about its cube gets
// the bump, exactly as it did when the field was an empty profile.
Skyline :: struct {
	form:    SkylineForm,
	columns: SkylineRange,
	height:  SkylineRange,
}

// The named recipes, so a pattern reads as prose where it has nothing
// particular to say and as bounds where it has.
//
// Constants rather than variables, which the authored profiles could not
// be: a Skyline is plain numbers, where a CubeProfile was a slice and had
// to live in mutable global storage.
SHAPE_BUMP :: Skyline {
	form    = .Wall,
	columns = {1, 1},
	height  = {1, 1},
}

// The two-column wall, and the only width a facing pair may be
// (MIRROR_MIN_WIDTH / MIRROR_MAX_WIDTH in pattern.odin bound it to 54 px
// from both sides). Its height is free, which is what lets two of them
// face each other as a constriction rather than as twins.
SHAPE_FACING :: Skyline {
	form    = .Wall,
	columns = {2, 2},
	height  = {1, 3},
}

SHAPE_TOWER :: Skyline {
	form    = .Wall,
	columns = {1, 3},
	height  = {3, 5},
}

SHAPE_PLATEAU :: Skyline {
	form    = .Wall,
	columns = {4, 6},
	height  = {2, 4},
}

SHAPE_STAIRS_UP :: Skyline {
	form    = .Rise,
	columns = {3, 5},
	height  = {3, 6},
}

SHAPE_STAIRS_DOWN :: Skyline {
	form    = .Fall,
	columns = {3, 5},
	height  = {3, 6},
}

SHAPE_CANYON :: Skyline {
	form    = .Canyon,
	columns = {4, 7},
	height  = {3, 6},
}

// A ridge: the widest and tallest thing the set draws, and the one that
// holds a lane for most of a second. It is a plateau in name only — at
// this width the answer stops being "flip once" and starts being "be
// somewhere else for a while", which is the question a hole asks.
SHAPE_RIDGE :: Skyline {
	form    = .Wall,
	columns = {6, 8},
	height  = {4, 7},
}

// The bounds a declaration allows, for a validator that has to reason
// about an event before the draw happens. Everything static about a
// skyline is one of these three.
skyline_min_columns :: proc(shape: Skyline) -> int {
	return max(1, shape.columns.low)
}

skyline_max_columns :: proc(shape: Skyline) -> int {
	return max(skyline_min_columns(shape), shape.columns.high)
}

skyline_max_height :: proc(shape: Skyline) -> int {
	return max(max(1, shape.height.low), shape.height.high)
}

// Draws one value out of an inclusive range.
//
// From the caller's generator and never the global one: a run has to
// generate byte-identical content from its seed for a replay or a score
// to mean anything (pattern.odin).
@(private)
draw_range :: proc(range: SkylineRange, rng: rand.Generator) -> int {
	low := max(1, range.low)
	high := max(low, range.high)
	if high == low {
		return low
	}
	roll := low + int(rand.float32(rng) * f32(high - low + 1))
	return min(roll, high)
}

// Turns a declaration into columns. Called once, when the obstacle is
// created, and the result is all any later reader ever sees.
//
// The count comes back separately rather than as a slice: an Obstacle is
// copied by value all over the game — into the renderer's steps, into the
// interpolated world — and a slice into one of those copies would point
// at a body that has already gone.
draw_skyline :: proc(
	shape: Skyline,
	rng: rand.Generator,
) -> (
	profile: [CUBE_MAX_COLUMNS]u8,
	count: int,
) {
	count = min(draw_range(shape.columns, rng), CUBE_MAX_COLUMNS)
	height := min(draw_range(shape.height, rng), CUBE_MAX_HEIGHT)

	switch shape.form {
	case .Wall:
		for i in 0 ..< count {
			profile[i] = u8(height)
		}

	case .Rise, .Fall:
		// The step is derived rather than authored, so a staircase of any
		// width climbs to exactly the height it declared: column i tops
		// out at its share of the climb, never lower than one unit,
		// because a zero in the middle of a staircase is a canyon and
		// this form is not that one.
		for i in 0 ..< count {
			step := int(f32(height) * f32(i + 1) / f32(count) + 0.5)
			profile[i] = u8(max(1, step))
		}
		if shape.form == .Fall {
			for i in 0 ..< count / 2 {
				profile[i], profile[count - 1 - i] = profile[count - 1 - i], profile[i]
			}
		}

	case .Canyon:
		// Two towers and the lane's own surface between them. A canyon
		// needs three columns to have a middle at all; the validator says
		// so, and this floors it anyway rather than silently drawing a
		// pair of walls with nothing between them.
		count = max(count, 3)
		for i in 0 ..< count {
			profile[i] = 0
		}
		profile[0] = u8(height)
		profile[count - 1] = u8(height)
	}

	return profile, count
}
