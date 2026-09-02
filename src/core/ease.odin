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

// Ease-out with a small overshoot past the target before settling back.
// The flip's whip uses it: a rotation that arrives *slightly* too far and
// snaps back reads as an impulse, which is exactly what the tap is meant
// to feel like (Design Doc, section 12).
EASE_BACK_OVERSHOOT :: 1.70158

ease_out_back :: proc(t: f32) -> f32 {
	u := t - 1
	return 1 + (EASE_BACK_OVERSHOOT + 1) * u * u * u + EASE_BACK_OVERSHOOT * u * u
}

// Symmetric acceleration and deceleration — for a value that should
// leave and arrive gently, unlike ease_out_quad which starts at full
// speed.
ease_in_out_quad :: proc(t: f32) -> f32 {
	if t < 0.5 {
		return 2 * t * t
	}
	u := -2 * t + 2
	return 1 - u * u / 2
}
