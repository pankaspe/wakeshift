/*
* Ease
* Easing curves shared across the project. Every transition in the game —
* the flip, obstacles entering, color changes — is animated through one of
* these rather than linearly (Design Doc, section 12): the implementation
* cost is a few lines, the perceived quality difference is not.
*/
package core

// Ease-out quadratic: starts fast, slows down towards the end.
// t goes from 0 (start) to 1 (end) and so does the returned value.
ease_out_quad :: proc(t: f32) -> f32 {
	return 1 - (1 - t) * (1 - t)
}
