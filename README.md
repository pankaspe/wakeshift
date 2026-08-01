# Wake Shift

A minimalist endless runner about flipping between two worlds — Reality and the Dream — built to teach myself [Odin](https://odin-lang.org/) through a real project.

Full design reference: `WakeShift_Design_Doc.md`
Full development plan: `WakeShift_Roadmap_Sviluppo.md`

**Current status**: Alpha in progress — Section 13 of 19 complete. Core loop, procedural obstacle generation, and full menu/pause navigation are all in place.

## Stack

- **Language**: Odin (`dev-2026-07`)
- **Graphics/Input/Audio**: `vendor:raylib/v55` (raylib 5.5 bindings)
  > Note: `vendor:raylib/v6` bindings are currently broken on this system's Odin install (bad linker archive). Using v55 as a stable workaround until resolved.

## Running

```bash
odin run .
```

## Controls

- `UP` / `DOWN` — navigate menus
- `ENTER` — confirm menu selection / retry after Game Over
- `SPACE` — flip between the Real (floor) and Dream (ceiling) lanes, in-run
- `ESC` — pause / resume

## Project structure

```
main.odin      — entry point, game loop (update + draw, run every frame)
lane.odin      — shared two-lane concepts (Lane enum, screen size, lane-to-position math)
player.odin    — player state, flip mechanic, transition animation
world.odin     — scroll state (elapsed time, scroll speed), floor/ceiling visuals
obstacle.odin  — obstacle as a time-based event, position derivation, drawing
pattern.odin   — hand-authored obstacle patterns, procedural generator, pool validation
game.odin      — game state (MainMenu/Playing/Paused/GameOver), collision checks, run reset
score.odin     — Dream Depth score, lane-dependent growth rate
menu.odin      — reusable navigable menu widget (used by Main Menu and Pause)
ui.odin        — per-screen drawing (menu, HUD, pause overlay, game over)
```

## Design notes & lessons learned

A running log of decisions and gotchas worth remembering, beyond what's in the Design Doc itself:

- **Obstacles are time-based events, not pixel positions.** An obstacle stores `arrival_time`; its on-screen x is derived every frame from `world.elapsed_time` and `scroll_speed`. Changing scroll speed later (difficulty tiers, Section 18) will never desync obstacle timing.
- **The pattern pool is a lane graph.** Every pattern declares an `entry_lane` and `exit_lane`. If no pattern in the pool leads back from a given lane, the procedural generator gets permanently stuck in that lane. Any pattern added later must keep both lanes reachable from each other.
- **Obstacle type is tied to lane by theme**, not enforced by the type system: Real lane → `Block`/`Chasm` (full, static), Dream lane → `PulsingShape`/`DreamHole` (void, dynamic). `validate_pattern_pool` runs once at startup and warns (without blocking) if a pattern breaks this pairing — a safety net for when the pool grows.
- **Update and draw are two separate switches over the same `game_state`**, run in sequence every frame: update reads input and decides what happens (and may change `game_state`); draw only renders whatever state update just settled on. Keeping them separate — rather than merging logic and rendering per state — keeps each one easy to reason about on its own.

## Development Progress

- [x] **Section 0** — Project setup, Odin + raylib window, 60 FPS game loop
- [x] **Section 1** — Player struct, drawn as placeholder rectangle, anchored to floor
- [x] **Section 2** — Flip mechanic (instant lane switch via Space)
- [x] **Section 3** — Player state machine (`Real` / `Dream` / `Transitioning`)
- [x] **Section 4** — Flip animation (ease-out interpolation) + invulnerability window
- [x] **Section 5** — Scrolling world (floor/ceiling tick marks, constant scroll speed)
- [x] **Section 6** — First obstacle (hardcoded, no collision yet)
  - Refactor: extracted `Lane`, `SCREEN_WIDTH/HEIGHT`, `get_lane_y` into `lane.odin` (shared between player and obstacles)
- [x] **Section 7** — AABB collision + game over ("Awakening"), restart on ENTER
- [x] **Section 8** — Obstacles as time-based events (refactor)
- [x] **Section 9** — Patterns + pool
- [x] **Section 10** — Procedural pattern generator
- [x] **Section 11** — Multiple obstacle types + Dream World
- [x] **Section 12** — Score (Dream Depth)
  - 10 pts/s in Real lane, 25 pts/s in Dream lane. Real HUD styling still pending polish (Section 15+).
- [x] **Section 13** — UI: Main Menu, HUD, Pause
  - Reusable `Menu` widget (UP/DOWN navigate, ENTER confirms), shared between Main Menu (Start Run / Quit) and Pause (Resume / Main Menu). Centered text throughout. `reset_run` centralizes the "start a fresh run" logic used by Main Menu, Game Over retry, and Pause → Main Menu.
- [ ] **Section 14** — End-run report + local high score persistence
- [ ] **Section 15** — Squash & stretch, base particles
- [ ] **Section 16** — Audio (SFX + music crossfade)
- [ ] **Section 17** — Lucidity streak system
- [ ] **Section 18** — Difficulty tiers
- [ ] **Section 19** — Balancing, polish → Alpha
