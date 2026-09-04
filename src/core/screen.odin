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

// The screen x that world time maps onto: an obstacle whose arrival_time
// is *now* is drawn here, and the ground drawn here is the ground at the
// world's current time.
//
// It used to be called PLAYER_X, and that name was doing two jobs at
// once. Since R2.1 the player's own x is game state — they lose ground
// when a cube pins them and win it back running free — so "where the
// player is" and "where world time lands on screen" are different
// questions, and only the second one may be a constant. Every conversion
// between screen space and world time reads this and nothing else, which
// is what keeps the level from sliding against itself the moment the
// player falls behind.
WORLD_ANCHOR_X :: 360

// Where a player running free settles.
//
// Equal to the anchor, so that at rest a pattern's timing means exactly
// what it says: an event authored to arrive at t = 1.2 arrives at the
// character at t = 1.2. They need not be equal — a player resting ahead
// of the anchor would meet everything early — but nothing wants that
// today, and the equality is worth one less thing to reason about.
//
// It is also, with the Corruption front behind it, the entire health bar:
// how far the character sits from the front *is* how much room is left to
// make mistakes in (Design Doc, section 5).
PLAYER_HOME_X :: WORLD_ANCHOR_X
