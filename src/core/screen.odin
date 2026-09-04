/*
* Screen
* Reference resolution and the fixed vertical layout of the play area.
* Everything here is expressed against the virtual 1280x720 canvas (see
* platform/display), never against the real window size, so gameplay and
* layout code never has to know what monitor it is running on.
*/
package core

// Screen reference resolution (Design Doc, section 6)
SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720

// Where the player sits on screen: they stay put, the world scrolls past.
//
// **This becomes a variable in roadmap R2.1** — a resting position the
// character is pulled back toward, which they lose ground against when a
// cube pins them. Everything that converts a screen x into world time
// reads it, so it is the one constant in the project whose promotion
// touches the most code (Design Doc, section 5).
//
// Lives here rather than with the player because obstacle position maths
// depends on it too, and
// obstacle code has no reason to know about the player just for this.
PLAYER_X :: 200
