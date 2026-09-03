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

// Vertical split of the play area (Design Doc, section 6):
// Dream lane 30% / Limen 40% / Real lane 30%.
// Nothing reads these: they describe the *reading* of the column, and the
// two walls are where the terrain says they are (core/terrain.odin) while
// the Limen is the midpoint of the journey between them.
DREAM_LANE_RATIO :: 0.30
LIMEN_RATIO :: 0.40
REAL_LANE_RATIO :: 0.30

// Fixed horizontal position of the player on screen (Design Doc, section 5):
// the player stays put, the world scrolls past it. Lives here rather than
// with the player because obstacle position math depends on it too, and
// obstacle code has no reason to know about the player just for this.
PLAYER_X :: 200
