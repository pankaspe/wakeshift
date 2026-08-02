# Wake Shift

A minimalist endless runner about flipping between two worlds — Reality and the Dream — built to teach myself [Odin](https://odin-lang.org/) through a real project.

Full design reference: `WakeShift_Design_Doc.md`
Full development plan: `WakeShift_Roadmap_Sviluppo.md`

**Current status**: Alpha in progress — Section 14 of 19 complete. Core loop, procedural obstacle generation, full menu/pause navigation, and local high score persistence are all in place.

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
player_render.odin — player silhouette rendering (Real/Dream color schemes, eyes)
world.odin     — scroll state (elapsed time, scroll speed), floor/ceiling visuals
obstacle.odin  — obstacle as a time-based event, position derivation, drawing
pattern.odin   — hand-authored obstacle patterns, procedural generator, pool validation
game.odin      — game state (MainMenu/Playing/Paused/GameOver), collision checks, run reset
score.odin     — Dream Depth score, lane-dependent growth rate
menu.odin      — reusable navigable menu widget (used by Main Menu and Pause)
ui.odin        — per-screen drawing (menu, HUD, pause overlay, game over)
persistence.odin — local high score save/load (plain text file)
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
- [x] **Section 14** — End-run report + local high score persistence
  - `persistence.odin`: `load_high_score`/`save_high_score` read/write a plain text file (`highscore.txt`) next to the executable. High score is checked and saved once, exactly at the moment of collision — not every frame. Main Menu and Game Over both display it; Game Over shows "NEW BEST!" when the just-finished run ties or beats it.
  - **Lesson learned (nightly Odin API drift)**: `core:os` file I/O signatures changed since older docs/tutorials — `read_entire_file`/`write_entire_file` now take an explicit allocator and return an `Error` union (check `err != nil`), not a `bool` (`ok`). Same category of gotcha as the `vendor:raylib` versioned path in Section 0: on a `dev-*` nightly compiler, don't trust remembered/tutorial signatures — check the compiler's own suggested overloads or pkg.odin-lang.org for the exact current API.
- [ ] **Section 15** — Visual identity pass (Hollow Knight–inspired silhouette style, Design Doc section 12). Split into sub-sections, each with its own test:
  - [x] **15.1** — Player: proper shape + silhouette/rim light (replaces the placeholder square)
    - `player_render.odin` (split from `player.odin`: state/logic vs rendering). Rounded body + rim light (drawn twice, larger silhouette behind a smaller one — no shader needed) + two eyes shifted toward the direction of travel.
    - Real lane: light body, dark rim, dark eyes. Dream lane: full negative (dark body, light rim, light eyes), eyes mirrored top-to-bottom to read as upside-down (hanging from the ceiling).
    - Known minor imprecision (same category as Section 12's score): color/eye scheme switches on `player.lane`, which only updates when a transition *completes* — so during the ~0.12s flip the old scheme briefly persists, then snaps. Candidate for animating in 15.2.
  - [x] **15.2** — Player: squash & stretch (now meaningful on a real shape, not a square)
    - Two-phase deformation in `player_render.odin`: a sine-based stretch (taller/thinner) peaking mid-flip, followed by a decaying cosine "bounce" (squash → slight overshoot → settle) over `SETTLE_DURATION` seconds after landing. Volume-preservation is approximate (opposite X/Y scaling), not physically simulated — a standard animation shortcut.
    - Shape scales anchored to the surface being touched (floor/ceiling) via `get_player_anchor_lane`, not from center, so it doesn't visually "float" while deforming. Eyes now take the already-scaled `body_rect` so they move with the deformation instead of staying fixed.
  - [ ] **15.3** — Obstacles: distinct silhouettes per type (Block/Chasm/PulsingShape/DreamHole stop being interchangeable rectangles)
  - [ ] **15.4** — Terrain: floor/ceiling get an irregular profile instead of flat tick marks
  - [ ] **15.5** — Particles: impact, flip, ambient
  - [ ] **15.6** — Light & shadow: rim light, Dream-lane glow, contact shadows
  - All vector-drawn (no external sprites/images) for now. Folder-based modularity if any single file grows unwieldy (e.g. a `visuals/` or `fx/` folder), rather than forcing everything into the existing per-system files.
- [ ] **Section 16** — Audio (SFX + music crossfade)
- [ ] **Section 17** — Lucidity streak system
- [ ] **Section 18** — Difficulty tiers
- [ ] **Section 19** — Balancing, polish → Alpha
