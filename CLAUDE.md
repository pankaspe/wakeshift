# CLAUDE.md — Working notes for Wake Shift

Operational rules for developing this project.

- **What and why** → `docs/design_doc.md` (v1.1)
- **How, in what order, with which model** → `ROADMAP.md` (Italian; the user's working file, not public docs)
- **How we work** → this file

---

## The project in one paragraph

Wake Shift is a one-button reflex arcade game in Odin + raylib. The character runs
automatically at a fixed screen X while the world scrolls past. `SPACE` flips gravity
between the floor (**Real world**) and the ceiling (**Dream world**); holding it suspends
the player in the middle band (**Limen**), a third playable state. Obstacles are authored
as *events in time*, never as pixel positions, so scroll speed can be rebalanced without
redrawing a single pattern. The visual identity is silhouette-and-light: dark shapes,
colored rim light, bloom, and a palette that blends continuously between the three states.

---

## Language rules — non-negotiable

- **All code is English.** Identifiers, procedure names, constants, struct fields, file
  names — everything.
- **All comments are English.** No exceptions, including quick inline notes.
- **All commit messages are English.**
- **Conversation with the user is Italian.** Explanations, proposals, questions, summaries.
- Markdown docs follow their existing language: `ROADMAP.md` and `docs/` are Italian
  (they are read by the user); `CLAUDE.md` is English (it governs the code).

---

## Build and run

```bash
odin check src            # type-check only, fast — run this after every edit
odin build src -out:build/wakeshift
odin run src              # what the user runs to playtest
```

Toolchain: Odin `dev-2026-07`, raylib bindings `vendor:raylib/v55` (imported as `rl`).
Always import raylib as `import rl "vendor:raylib/v55"` — never `v6`, the linker
expectations differ.

---

## Workflow

This is a long project, developed one phase at a time.

1. **One phase at a time.** Never start the next `ROADMAP.md` phase without the user's go-ahead.
   Phases are split into numbered tasks (`T<phase>.<n>`), each tagged with a recommended
   model (Sonnet for mechanical, fully specified work; Opus for open design decisions,
   state machines, determinism, shader math and collision rules). Respect the tagging —
   it is how the user budgets their plan.
2. **Claude writes code and proposes ideas. The user playtests and gives feedback.**
3. **Claude verifies only that it compiles and launches.** Never claim anything about how
   the game looks or feels — the user is the only one who can judge that. Say
   "compiles, launches, no crash in N seconds", nothing more.
4. **Report honestly.** If a phase is partially done, say which part and why. If a test
   fails, show the output.
5. Keep `odin check src` green at every intermediate step, especially during file moves.

---

## Architecture

### Package graph — strictly acyclic

```
core      ← imports nothing from the project
platform  ← core
fx        ← core
game      ← core, platform, fx
render    ← core, game, fx
ui        ← core, game
audio     ← core, game
main      ← everything
```

Odin forbids cyclic imports between packages, and one directory is exactly one package.
The split is **by level of abstraction, not by game entity** — `player`, `obstacle`,
`pattern` and `world` all live together inside `game/` because they reference each other
constantly, and splitting them would force premature interfaces.

### Golden rules

- **`game/` never draws.** No `rl.Draw*` call may appear anywhere under `game/`.
- **`render/` never mutates game state.** It takes state by value and produces pixels.
- **`fx/` knows nothing about the game.** It is a parametric particle/post-processing
  module; gameplay may emit into it, but it never imports `game`.
- **Input is passed in, never read inside gameplay.** Gameplay procedures take a
  `platform.Input` struct. This keeps the game testable, makes replays possible, and is a
  prerequisite for the server-side leaderboard validation described in the design doc.
- **Randomness is seeded and threaded explicitly.** Never call the global `rand.*`
  procedures; a run must be reproducible from its seed.
- **No hardcoded colors outside `render/palette.odin`.** Every color is sampled from the
  three-world palette.
- **No hardcoded pixel timings in patterns.** Patterns are time offsets; positions are
  derived at runtime from elapsed time and scroll speed.

### Save data and determinism

- Save files live in the **OS user data directory**, never in the working directory:
  `$XDG_DATA_HOME/wake-shift/` (Linux), `%APPDATA%\\wake-shift\\` (Windows),
  `~/Library/Application Support/wake-shift/` (macOS).
- The payload is CBOR (`core:encoding/cbor`) sealed with ChaCha20-Poly1305
  (`core:crypto/chacha20poly1305`). A save that fails to authenticate is **rejected and
  reset to defaults**, never trusted and never allowed to crash the game.
- Be honest about what this buys: the key ships inside the binary, so local sealing is a
  **deterrent against casual editing, not security**. Never describe it as protection for
  a leaderboard, in code comments or to the user.
- The real defense is server-side revalidation: the client submits a `RunManifest`
  (seed, game version, tick rate, input log, claimed score) and the server replays it.
  A locally computed score is never evidence of anything.
- Because of that, **determinism is a product feature, not tidiness**: seeded RNG, input
  as data, and a fixed timestep together buy leaderboard validation, replays, ghosts, and
  reproducible balancing. Do not weaken any of the three for convenience.

---

## Code conventions

These are taken from the existing code — match them, do not invent new ones.

**File header.** Every file opens with a block comment naming the file and stating its
responsibility, referencing the design doc section where relevant:

```odin
/*
* Player
* Holds the player character state and drives the flip state machine
* (Design Doc, section 4).
*/
package game
```

**Naming**

| Kind | Style | Example |
|---|---|---|
| Types | `PascalCase` | `Player`, `ObstacleType`, `PatternEvent` |
| Procedures | `snake_case` | `update_player`, `get_lane_y` |
| Constants | `SCREAMING_SNAKE` with `::` | `PLAYER_SIZE`, `TRANSITION_DURATION` |
| Struct fields | `snake_case` | `transition_timer`, `arrival_time` |

**Procedure shapes** — keep the established trio:

```odin
new_player  :: proc() -> Player            // constructor, returns by value
update_player :: proc(player: ^Player, ...) // mutates through a pointer
draw_player :: proc(player: Player)         // takes by value, never mutates
```

Accessors that derive a value follow `get_<thing>_<property>`, e.g. `get_obstacle_size`.

**Formatting**: tabs for indentation, `odinfmt` defaults. Run it if available before
finishing a phase.

**Comments**: explain *why*, not *what*. The existing code does this well — keep the habit
of citing the design doc section a decision comes from, and of flagging known simplifications
explicitly rather than leaving them silent.

**Memory**: prefer fixed pre-allocated pools over per-frame allocation, especially in
`fx/`. Where a dynamic array is unavoidable, `defer delete(...)` at the same scope it was
created.

---

## Design pillars

Check every proposed feature against these before implementing it. If a feature breaks one,
raise it with the user before writing code.

1. **One key, two gestures.** `SPACE` is the only gameplay input. Tap flips; hold suspends
   in the Limen; release completes the journey. No second gameplay key, ever. (Menus may
   use arrows/enter/escape — the pillar covers gameplay, not UI.)
2. **Readable in two seconds.** Someone watching a video understands the goal without
   explanation. When beauty and readability conflict, readability wins.
3. **Every run is different, every run is fair.** Procedural but never unsolvable and never
   a surprise: an obstacle always has a visible arrival phase before it is lethal.
4. **The theme is not decoration.** Real / Limen / Dream must shape mechanics, visuals and
   feedback — not just the color scheme.
5. **One question at every instant: where should I be?** Three possible answers, never more.
   Every obstacle threatens some bands and leaves others open.
6. **Never color alone.** The three states are always distinguishable by position and by
   type of motion as well as by color. This is an accessibility constraint, not a preference.

---

## Known issues carried forward

Tracked here so they are not rediscovered. Each is scheduled in `ROADMAP.md`.

- `Chasm` and `DreamHole` use the same collision rule as `Block` — four types, one behavior.
  (T6.3)
- `Chasm` renders at `y = SCREEN_HEIGHT - 54`, above the terrain surface line at ~690-706,
  so it reads as a solid block standing on the floor rather than a hole. (T6.2)
- `PulsingShape` phase is driven by global elapsed time rather than the obstacle's own
  `arrival_time`, so identical patterns can present a 55px wall or an ignorable 8px stub.
  (T6.4)
- Obstacles are never removed from the list once passed. (T2.9)
- The DRAW switch in `main.odin` repeats the same gameplay draw calls three times. (T1.6)
- The player silhouette inverts body and rim colors between worlds, contradicting the
  design doc's "same character, different lighting" rule. (T3.5)
