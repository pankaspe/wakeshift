# Wake Shift

A minimalist endless runner about flipping between two worlds — Reality and the Dream — built to teach myself [Odin](https://odin-lang.org/) through a real project.

Full design reference: `WakeShift_Design_Doc.md`
Full development plan: `WakeShift_Roadmap_Sviluppo.md`

## Stack

- **Language**: Odin (`dev-2026-07`)
- **Graphics/Input/Audio**: `vendor:raylib/v55` (raylib 5.5 bindings)
  > Note: `vendor:raylib/v6` bindings are currently broken on this system's Odin install (bad linker archive). Using v55 as a stable workaround until resolved.

## Running

```bash
odin run .
```

## Project structure

```
main.odin      — entry point, game loop
lane.odin      — shared two-lane concepts (Lane enum, screen size, lane-to-position math)
player.odin    — player state, flip mechanic, transition animation
world.odin     — scroll state (elapsed time, scroll speed), floor/ceiling visuals
obstacle.odin  — obstacle as a time-based event, position derivation, drawing
pattern.odin   — hand-authored obstacle patterns, chaining into obstacle lists
game.odin      — game state (Playing/GameOver), collision checks
```

## Development Progress

- [x] **Section 0** — Project setup, Odin + raylib window, 60 FPS game loop
- [x] **Section 1** — Player struct, drawn as placeholder rectangle, anchored to floor
- [x] **Section 2** — Flip mechanic (instant lane switch via Space)
- [x] **Section 3** — Player state machine (`Real` / `Dream` / `Transitioning`)
- [x] **Section 4** — Flip animation (ease-out interpolation) + invulnerability window
- [x] **Section 5** — Scrolling world (floor/ceiling tick marks, constant scroll speed)
- [x] **Section 6** — First obstacle (hardcoded, no collision yet)
  - [x] Refactor: extracted `Lane`, `SCREEN_WIDTH/HEIGHT`, `get_lane_y` into `lane.odin` (shared between player and obstacles)
- [x] **Section 7** — AABB collision + game over ("Awakening"), restart on ENTER
- [x] **Section 8** — Obstacles as time-based events (refactor)
  - Obstacles now store an `arrival_time` instead of a mutable x position; on-screen position is derived every frame from `world.elapsed_time` and `scroll_speed`. Keeps timing correct if `scroll_speed` changes later.
- [x] **Section 9** — Patterns + pool
  - Hand-authored `Pattern`s (sequences of `PatternEvent`s with entry/exit lane hooks) chained into a concrete `[dynamic]Obstacle` list via `build_obstacles_from_patterns`. 3 patterns for the Real World pool so far, played in fixed order (random selection comes in Section 10).
- [ ] **Section 10** — Procedural pattern generator
- [ ] **Section 11** — Multiple obstacle types + Dream World
- [ ] **Section 12** — Score (Dream Depth)
- [ ] **Section 13** — UI: Menu, HUD, Pause
- [ ] **Section 14** — End-run report + local high score persistence
- [ ] **Section 15** — Squash & stretch, base particles
- [ ] **Section 16** — Audio (SFX + music crossfade)
- [ ] **Section 17** — Lucidity streak system
- [ ] **Section 18** — Difficulty tiers
- [ ] **Section 19** — Balancing, polish → Alpha

## Controls

- `SPACE` — flip between Reality and Dream lanes
- `ESC` — close window
