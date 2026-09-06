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

// Where the block starts, and the whole of the health bar.
//
// The distance between here and the Corruption's front *is* how much room
// is left to make mistakes in, so this number is the size of the health
// bar and nothing else. It was 360 and it had a second name,
// WORLD_ANCHOR_X, because in the two-lane game it was also the screen x
// that world time mapped onto. The maze has no such mapping — column 0
// starts here and every other column follows from the grid — so the
// second job is gone and the second name went with it.
//
// **IT IS NOT THE HEALTH BAR ANY MORE, AND THAT FREED IT**
//
// It was, while the front lived in screen space: how far the body sat
// from the left edge *was* the room it had left, so every pixel this
// moved right was health bought with warning time and there was no third
// place for either to come from. The Corruption moved into the world
// after the first maze playtest (game/corruption.odin) and took the
// health bar with it, which leaves this constant with one job instead of
// two — deciding how much maze is visible ahead of the body.
//
// So it moved *left*, not right. At 440 the block sees 792 px of maze in
// front of it, a little over thirteen columns, which is three or four
// moves of reading. What is behind it is now only the distance the front
// has to cross on screen before it arrives: 2.3 s at the opening speed,
// which is warning and not health.
PLAYER_HOME_X :: 440
