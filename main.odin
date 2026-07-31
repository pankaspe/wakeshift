/*
* Wake Shift
* main.odin
* game built with Odin and Raylib
*/

package main
import "core:fmt"
import rl "vendor:raylib/v55"

main :: proc() {

	// set window size but need to do dynamic for full screen and adapt resolution
	rl.InitWindow(1280, 720, "Wake Shift")
	defer rl.CloseWindow()

	// set fps
	rl.SetTargetFPS(60)

	// create the player, anchored to the floor in the real lane
	player := new_player()

	// create the world (scroll, state)
	world := new_world()

	// start main loop until close
	for !rl.WindowShouldClose() {

		// start drawing frames
		rl.BeginDrawing()
		defer rl.EndDrawing()

		// clear background color for each frame
		rl.ClearBackground(rl.BEIGE)

		// update the world (scroll)
		update_world(&world, rl.GetFrameTime())

		// update the player (input, state)
		update_player(&player)

		// draw the world (floor/ceiling marks)
		draw_world(world)

		// draw the player
		draw_player(player)
	}
}
