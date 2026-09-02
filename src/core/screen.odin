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
// Nothing reads these yet: the Limen only becomes a playable state in
// roadmap phase 5, and until then both lanes are derived straight from
// the screen edges by get_lane_y.
DREAM_LANE_RATIO :: 0.30
LIMEN_RATIO :: 0.40
REAL_LANE_RATIO :: 0.30

// Fixed horizontal position of the player on screen (Design Doc, section 5):
// the player stays put, the world scrolls past it. Lives here rather than
// with the player because obstacle position math depends on it too, and
// obstacle code has no reason to know about the player just for this.
PLAYER_X :: 200

// Shared border weight for every silhouette in the game (player, obstacles,
// terrain) — one "line weight" for the whole project, not a player detail.
// Likely to move to render/palette.odin once the visual identity lands in
// roadmap phase 3.
RIM_THICKNESS :: 1.8
