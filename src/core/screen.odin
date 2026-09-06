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
// **THE RUNWAY AND THE PREVIEW ARE THE SAME 1280 PX, SPLIT BY THIS**
//
// Every pixel this moves right is health bought with warning time, and
// every pixel left is the reverse. There is no third place for either to
// come from, which is why the first maze playtest could not be answered
// by this constant alone: moving it right *and* slowing the world by a
// matching proportion buys the health without spending the warning, and
// neither does that on its own. At 560 against a 220 px/s world the block
// sees 3.05 s of maze ahead of it — which is what it saw at 360 against
// 270, to within a twentieth of a second.
PLAYER_HOME_X :: 560
