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

## Picking up in a new session

Development runs one roadmap phase per session, so most sessions start cold. Read in this
order before touching anything:

1. **`ROADMAP.md`** — the phase table says exactly what is done (✅) and what is next. Each
   phase lists numbered tasks with a recommended model.
2. **`docs/design_doc.md`** — binding on *what* to build. v1.3 is current.
3. The rest of this file — architecture rules and conventions.

**Where the project stands:** phases 0-6 are complete. The code is split into packages with an acyclic dependency
graph, saves are encrypted in the OS user data directory, and the simulation is
deterministic and verified (seeded generation, input as data, fixed timestep, run
manifests recorded). The game opens in fullscreen at the monitor's own resolution, has an
options screen reachable from the main menu and the pause menu, and remembers what was set
there. The visual identity has begun: every color on screen is sampled from the three-world
palette, the two worlds are drawn at once with a horizon between them, and the character
has a body that runs and whips through the flip. What is still missing there is real bloom
(phase 4), particles (phase 9) and parallax scenery (phase 10).

**How verification works here:** `odin check src` after every edit, `odin build src` and a
short launch before reporting a task done. For anything with real logic, write a throwaway
program that exercises the module directly and run it — that habit has caught several bugs
type-checking could not (`make_directory_all` returning `.Exist`, the input latch, the
AEAD size assertions, a window call that silently changed the desktop's resolution, a
near-miss rule that paid for dodges that never happened).

**When the thing to verify is pixels, read the pixels back.** `rl.LoadImageFromTexture` on
the render target turns "does the bloom look right" into arithmetic: draw the frame twice,
once with the effect and once without, and compare per-row brightness. That is how phase 4
established that the composite is not upside down (the light lands on the row that emitted
it, not its mirror) and that the Real world's bloom was invisible before it was retuned —
neither of which any amount of staring at the code would have shown. Give a readback test
an *asymmetric* subject: the first version of that check used the game's own frame, whose
brightest band is the horizon, and the horizon sits at the exact middle where a flip is
undetectable.

Build it as a package *inside* `src/` — `src/scratch_check/`, `odin build src/scratch_check
-out:<scratchpad>/sc` — not in the scratchpad, because the relative imports (`../core`)
only resolve from there. It is invisible to `odin build src`, which compiles only what
`main.odin` imports, so it cannot break the game; delete the directory before committing.

When a check involves the window rather than the simulation, do not trust what raylib
reports about itself: read the live window's state from the outside (`wmctrl -lG`,
`xprop -id <id> _NET_WM_STATE`). raylib claimed `IsWindowFullscreen() = true` for a window
the compositor had maximized into the work area with the panel still on top of it.

Never claim anything about how the game looks or feels; the user judges that.

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
6. **Compress the phase in `ROADMAP.md` when it closes**, before moving on: a ✅ heading, a
   paragraph on what was done, and only the decisions still binding on future work. The
   task table goes — it existed to execute the phase, not to remember it. The file is read
   at the start of every session, so a phase that stays at full length is a tax on every
   session after it.

   What was learned along the way is not discarded, it is **moved somewhere it will be
   read again**: a library trap into the comment of the file that hits it, an architecture
   rule into this file, a gameplay detail into the design doc. If a note has no home
   elsewhere, give it one before deleting it from the roadmap.

---

## Architecture

### Package graph — strictly acyclic

```
core      ← imports nothing from the project
platform  ← core
game      ← core
render    ← core, game
ui        ← core, game
main      ← everything

fx        ← core          (created in phase 4: bloom. Particles join it in phase 9)
audio     ← core, game    (roadmap phase 11, not created yet)
```

Note that `game` does not currently import `platform`: input arrives as a
`core.Input` value, so gameplay needs nothing from the platform layer at all.
Keep it that way if you can — it is what makes the simulation testable without
a window.

Three things live in `core` that look like they belong elsewhere — `Input`, `Settings` and
`Palette` — and all three for the same reason: two packages that may not import each other
both need them. `ui` renders settings and `platform` applies them; `ui` draws menus out of
the palette and `render` draws the world out of it. When something is *vocabulary* rather
than *behavior*, `core` is where it goes; the package that owns the behavior keeps the half
that needs game state (`render/palette.odin` derives `world_t` and `depth_t` from a Player
and a World, and that is all it does).

Odin forbids cyclic imports between packages, and one directory is exactly one package.
The split is **by level of abstraction, not by game entity** — `player`, `obstacle`,
`pattern` and `world` all live together inside `game/` because they reference each other
constantly, and splitting them would force premature interfaces.

### Obstacles

Six types, and — since phase 6 — six behaviours rather than one behaviour with six skins.
The split follows the design doc's own axis (section 5):

- **Full vs void.** A Block is something that appears; a Chasm is the floor failing to be
  there. That is two *rules*, not two sprites: a presence kills whoever overlaps it, an
  absence kills only whoever is resting on it. A Chasm therefore does nothing to a player
  who is mid-flip, suspended, or on the ceiling, and being wider than a Block it asks
  "do not be down here for this stretch" where a Block asks "move, now".
- **The terrain owns the holes.** `render/terrain.odin` is the only code that knows where
  its own surface is, so it samples the surface as a function of x, subtracts the void
  obstacles from the width of the screen, and draws what is left one span at a time.
  `draw_obstacle` returns early for `Chasm` and `DreamHole`. Drawing them as objects is
  what made them read as boxes standing on the floor for the whole of the prototype.
- **The floor breaks, the ceiling dissolves.** Hard lit edges and a dark pit on one side;
  edges fading out over tens of pixels and a faint glow on the other. Same cut, opposite
  reading.

### Presentation

The game draws in a fixed 1280x720 coordinate space (`core/screen.odin`) and always will:
no gameplay, layout or render code knows what monitor it is on. What changed in phase 2.5
is only where those coordinates land.

- The render target is allocated at the **real output resolution**, and
  `platform.begin_game_canvas` pushes a `Camera2D` zoom that maps a 1280x720 coordinate
  onto a native pixel. Draw in canvas coordinates as before; the pixels are native.
- The target is sized to the *scaled canvas*, not to the window. Letterbox bars are the
  part of the window the blit does not cover, and stay outside the target — a bright-pass
  bloom (phase 4) must not see them.
- It is rebuilt only on the frames the output size actually changes
  (`platform.update_display`, called once per frame from the main loop).
- Fullscreen means **real fullscreen at the desktop's existing video mode** — the game
  never changes a monitor's resolution. Borderless windowed was tried first and does not
  work: on KDE a screen-sized undecorated window is still a normal window, so the
  compositor maximizes it into the work area and keeps the panel on top of it. The file
  header of `platform/window.odin` records the three raylib behaviors that make this
  delicate — read it before touching a window call, because two of them silently change
  the player's desktop resolution or drop the window out of fullscreen.
- A mode change is a short negotiation, not one call. `platform.apply_display_mode` does
  **one step** and is idempotent; the main loop calls it for `WINDOW_SETTLE_FRAMES` frames
  after any change. Never assume a window call has taken effect on the line after it.
- `core.Settings` lives in `core` for the same reason `core.Input` does: `ui` renders it
  and `platform` applies it, and `ui` may not import `platform`. `platform/window.odin` is
  the only file that turns a Settings value into window calls.
- Presentation may read a wall clock (`display_time` in `main`, accumulated from the same
  single `rl.GetFrameTime()` call) for things that are drawn but not simulated — the menu's
  drift between worlds, the horizon's breathing. It must never reach the simulation, which
  advances only in whole `core.FIXED_TIMESTEP` steps out of the accumulator.
- **Post-processing runs on the finished frame, between the canvas closing and the blit.**
  `fx.apply_bloom` reads the render target and composites back into it in place, so
  `platform` never learns that bloom exists and `fx` never learns that a game does. The
  order in `main` is: `end_game_canvas` -> `apply_bloom` -> `present_display`.
- **Render textures are stored bottom-up, and the flip happens exactly once**, in
  `present_display`. Every intermediate pass in `fx/` draws with a positive source rect,
  which carries that convention through the chain unchanged. A second flip anywhere in the
  middle silently mirrors the light away from whatever emitted it.
- Drawing rate is a setting; the simulation rate is not. Whatever vsync and the frame
  limit are set to, the simulation advances at `core.TICK_RATE` in fixed steps.

### Golden rules

- **`game/` never draws.** No `rl.Draw*` call may appear anywhere under `game/`.
- **`render/` never mutates game state.** It takes state by value and produces pixels.
- **`fx/` knows nothing about the game.** It is a parametric particle/post-processing
  module; gameplay may emit into it, but it never imports `game`.
- **The Limen is a pause in the flip, not a separate move.** A flip is one journey with one
  clock; holding freezes that clock at its midpoint and releasing resumes it, which is why
  nothing anywhere needs to remember which wall the player came from. Any change to the
  flip has to keep that true — the moment suspension becomes its own motion, the one
  sentence that explains the controls stops being true.
- **Input is passed in, never read inside gameplay.** Gameplay and UI procedures take a
  `core.Input` value. Exactly one procedure in the project polls the keyboard
  (`platform.read_input`) and exactly one reads the clock (`rl.GetFrameTime`, in the main
  loop). Adding a second of either breaks replay.
- **Randomness is seeded and threaded explicitly.** Never call the global `rand.*`
  procedures; every draw goes through the run's own generator so the run is reproducible
  from its seed.
- **The simulation advances in fixed steps.** `core.FIXED_TIMESTEP`, never a raw frame
  time. A frame may run zero, one, or several steps; input is latched until a step
  consumes it. Anything that must not change a run's outcome — culling, rendering — has
  to be provably neutral, not just probably neutral.
- **No hardcoded colors outside `core/palette.odin`.** Every color is sampled from the
  three-world palette, through `world_t` (where the player is) and `depth_t` (how deep the
  run has gone). A color literal anywhere else is a bug, including in `ui/`.
- **The body is dark in all three worlds; only the light changes.** Player, obstacles and
  terrain all take `palette.silhouette`; what tells the worlds apart is the rim and the
  glow (Design Doc, section 12). Inverting a silhouette between worlds reads as two
  different characters, which is exactly what phase 3 fixed.
- **No hardcoded pixel timings in patterns.** Patterns are time offsets; positions are
  derived at runtime from elapsed time and scroll speed.

### Save data and determinism

- Save files live in the **OS user data directory**, never in the working directory
  (`platform/paths.odin` resolves it per platform via `os.user_data_dir`).
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
  reproducible balancing. All three are in place and verified. Do not weaken any of them
  for convenience.
- Changing `SaveData`'s shape means bumping `SAVE_FORMAT_VERSION`, which makes every
  existing save unreadable — decoding deliberately refuses versions it does not know
  rather than guessing. That is the right default, but it discards the player's data, so
  say so before doing it.
- `SaveData` returned by `load_save` owns heap allocations; free it with
  `destroy_save_data`. A `SaveData` built in memory does not own them — its manifest
  borrows the live recorder's tick log — so never destroy one of those.

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

- A pattern's `entry_lane`/`exit_lane` contract does not know the Limen exists. A pattern
  solved by suspending comes out in the opposite lane to the one solved by flipping, so
  `exit_lane` names the flipping answer and the pattern carries a second of slack
  afterwards for the other one. Teaching the contract about the third state is T7.1.
- Difficulty still comes mostly from scroll speed. There are six readings now, but the
  tier table only changes how fast they arrive. (T7.3)
- Menus, HUD and the options screen now take their colors from the palette, but still use
  raylib's default bitmap font. Everything drawn from primitives is crisp at native
  resolution and only the text is not — a real font is the remaining half of that job.
  (T13.3)
- `Lucidity` changed meaning in phase 5: it is a spendable resource in 0..LUCIDITY_MAX, not
  a streak counter. Anything that used to read `lucidity.streak` wants `lucidity.value`.
- There are now two glows: the real frame-wide bloom in `fx/bloom.odin`, and the stacked
  additive primitives in `render/glow.odin` that predate it. The second was a stand-in for
  the first and now feeds it — a primitive halo is bright, so the bright pass picks it up
  and blooms it again. Worth knowing before phase 9: particles will go through the same
  pass. Where a halo looks doubled, remove the primitive one rather than lowering the bloom.
- Bloom is LDR: the frame is an RGBA8 texture, so "bright" means "near white", and the
  thresholds in `fx/bloom.odin` are tuned against **what reaches the frame**, not against
  the palette. A rim drawn at 0.7 alpha over a dark background lands near 0.66, not at the
  0.91 its color names.
- Recorded run manifests are saved but never played back — there is no replay or ghost in
  the game yet, only the data needed for one. (Phase 13 / post-MVP)
