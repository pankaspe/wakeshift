/*
* Direction
* The four ways a body can be sent, and the rest state that means "not
* going anywhere". Vocabulary rather than behaviour, so it lives here:
* core.Input has to say which way the player pressed, and the maze in
* game/ has to say which way a slide ran — two packages that may not
* import each other, both needing the same word.
*
* .None is a real member and not an absence. A slide that has finished
* and a press that never came are the same state as far as everything
* downstream is concerned, and giving it a name means no caller has to
* carry a second boolean beside the direction.
*/
package core

Direction :: enum u8 {
	None,
	Up,
	Down,
	Left,
	Right,
}

// Where a step in this direction lands, on a grid whose rows grow
// downward. The one place that decides what "up" means in coordinates.
step_cell :: proc(col, row: int, dir: Direction) -> (int, int) {
	switch dir {
	case .Up:
		return col, row - 1
	case .Down:
		return col, row + 1
	case .Left:
		return col - 1, row
	case .Right:
		return col + 1, row
	case .None:
		return col, row
	}
	return col, row
}
