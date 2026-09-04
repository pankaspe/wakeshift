# CLAUDE.md — Working notes for Wake Shift

Operational rules for developing this project.

- **What and why** → `docs/design_doc.md` (**v2.0**)
- **What it looks like** → `docs/sketch/` — binding art direction, summarised in `ROADMAP.md`
  under "La direzione artistica". `docs/` is deliberately **not tracked by git**: it is the
  author's working material and lives only on their disk.
- **How, in what order, with which model** → `ROADMAP.md` (Italian; the user's working file)
- **How we work** → this file

---

## The project in one paragraph

Wake Shift is a one-button reflex arcade game in Odin + raylib. The character runs
automatically while the world scrolls past. `SPACE` flips gravity between the floor (**Real
world**) and the ceiling (**Dream world**) — one key, one gesture, two places to be. The world
is a **track**: two lanes that curve together and whose corridor narrows and widens. Behind the
player the **Corruption** advances from the left, and the distance between the two is the only
health bar there is. **A mistake costs ground, not the run**: a cube blocks rather than kills,
and while you are pinned the Corruption gains. Obstacles and track alike are authored as
*events in time*, never as pixel positions, so scroll speed can change without redrawing a
single pattern. The visual identity is silhouette-and-light: dark shapes, coloured rim light,
bloom, and a palette that blends continuously between the two worlds.

---

## Language rules — non-negotiable

- **All code is English.** Identifiers, procedures, constants, struct fields, file names.
- **All comments are English.** No exceptions, including quick inline notes.
- **All commit messages are English.**
- **Conversation with the user is Italian.** Explanations, proposals, questions, summaries.
- Markdown docs follow their existing language: `ROADMAP.md` and `docs/` are Italian (the user
  reads them); `CLAUDE.md` and `README.md` are English (they govern the code and face outward).

---

## Build and run

```bash
odin check src            # type-check only, fast — run this after every edit
odin build src -out:build/wakeshift
odin run src              # what the user runs to playtest
```

Toolchain: Odin `dev-2026-07`, raylib bindings `vendor:raylib/v55` (imported as `rl`). Always
import raylib as `import rl "vendor:raylib/v55"` — never `v6`, the linker expectations differ.

---

## Picking up in a new session

Development runs one roadmap phase per session, so most sessions start cold. Read in this
order before touching anything:

1. **`ROADMAP.md`** — the phase list says what is done (✅) and what is next. Each phase lists
   numbered tasks with a recommended model. Respect the tagging: it is how the user budgets
   their plan.
2. **`docs/design_doc.md` v2.0** — binding on *what* to build. `docs/sketch/` is binding on what
   it *looks* like: **`sketch_3` governs everything**, game and screens alike, and
   `spirito_foresta` the character. `sketch_1` and `sketch_2` are quarries, not references.
   Everything is reachable with primitives plus palette plus bloom — the project has no
   external art assets and is not getting any.
3. The rest of this file — architecture rules and conventions.

**Where the project stands.** The design was rewritten on 4 September 2026 (v1.3 → v2.0), and
**R1 and R2 are done**: two lanes, one gesture, a cube that *blocks* rather than kills, and a
Corruption front advancing from the left that eats the ground a mistake costs you. The heart of
the design is in the code. Still missing: the track that curves (R3), the Sentinel and the cube
variants (R4), the real pattern pool (R5), fragments and the Gate (R6).

Why it was rewritten, measured rather than guessed: 200 simulated runs that never touched the
key, **161 survived the whole first tier**, median death at 35 s; **86% of the time** nothing on
screen could kill in any position; **not once** in 24 000 seconds were both lanes threatened
together. It was structural, not tuning — the pattern contract *guaranteed* you entered every
pattern from the safe band, so standing still was almost always right.

---

## How verification works here

`odin check src` after every edit; `odin build src` and a short launch before reporting a task
done. **Never claim anything about how the game looks or feels** — the user is the only one who
can judge that. Say "compiles, launches, no crash in N seconds", nothing more.

For anything with real logic, write a throwaway program that exercises the module directly and
run it. That habit has caught several bugs type-checking could not: `make_directory_all`
returning `.Exist`, the input latch, the AEAD size assertions, a window call that silently
changed the desktop's resolution, a near-miss rule that paid for dodges that never happened,
and the 86%-dead-air measurement that ended the v1.x design.

**When the thing to verify is a rule about play, replay it.** Drive the real simulation with
scripted input and ask what actually survives. A claim about play is cheap to check and
expensive to be wrong about. Two traps learned the hard way:

- **Watch what your harness confounds.** A first pass measured "seconds each obstacle type is
  lethal" using a player who never pressed — so the run ended at the first Real-lane threat and
  every later Real obstacle scored zero. It looked exactly like a collision bug. Measure
  occupancy *without a player* when the question is about what the generator puts on screen.
- **Measure the thing, not a proxy for it.** "Is it too easy" became answerable only when it
  became "what fraction of the time is at least one lane lethal".

**When the thing to verify is pixels, read the pixels back.** `rl.LoadImageFromTexture` on the
render target turns "does the bloom look right" into arithmetic: draw the frame twice, once
with the effect and once without, and compare per-row brightness. That is how phase 4
established that the composite is not upside down and that the Real world's bloom was invisible
before it was retuned. Give a readback test an *asymmetric* subject — the first version used the
game's own frame, whose brightest band is the horizon, which sits exactly where a flip is
undetectable.

Build a throwaway as a package *inside* `src/` — `src/scratch_check/`,
`odin build src/scratch_check -out:<scratchpad>/sc` — not in the scratchpad, because the
relative imports (`../core`) only resolve from there. It is invisible to `odin build src`,
which compiles only what `main.odin` imports, so it cannot break the game. **Delete the
directory before committing.**

When a check involves the window rather than the simulation, do not trust what raylib reports
about itself: read the live window's state from the outside (`wmctrl -lG`,
`xprop -id <id> _NET_WM_STATE`). raylib claimed `IsWindowFullscreen() = true` for a window the
compositor had maximized into the work area with the panel still on top of it.

---

## Workflow

1. **One phase at a time.** Never start the next `ROADMAP.md` phase without the user's go-ahead.
2. **Claude writes code and proposes ideas. The user playtests and gives feedback.**
3. **Claude verifies only that it compiles and launches.**
4. **Report honestly.** If a phase is partially done, say which part and why. If a test fails,
   show the output.
5. Keep `odin check src` green at every intermediate step, especially during file moves.
6. **Compress the phase in `ROADMAP.md` when it closes**, before moving on: a ✅ heading, a
   paragraph on what was done, and only the decisions still binding on future work. The task
   table goes — it existed to execute the phase, not to remember it.

   What was learned is not discarded, it is **moved somewhere it will be read again**: a library
   trap into the comment of the file that hits it, an architecture rule into this file, a
   gameplay detail into the design doc. If a note has no home elsewhere, give it one before
   deleting it from the roadmap.

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

fx        ← core          (bloom; particles join it in phase R7)
audio     ← core, game    (phase R7, not created yet)
```

`game` does not import `platform`: input arrives as a `core.Input` value, so gameplay needs
nothing from the platform layer at all. Keep it that way — it is what makes the simulation
testable without a window.

Three things live in `core` that look like they belong elsewhere — `Input`, `Settings` and
`Palette` — all for the same reason: two packages that may not import each other both need
them. `ui` renders settings and `platform` applies them; `ui` draws menus out of the palette and
`render` draws the world out of it. When something is *vocabulary* rather than *behaviour*,
`core` is where it goes; the package that owns the behaviour keeps the half that needs game
state (`render/palette.odin` derives the palette's variables from a Player and a World, and
that is all it does).

Odin forbids cyclic imports between packages, and one directory is exactly one package. The
split is **by level of abstraction, not by game entity** — `player`, `obstacle`, `pattern` and
`world` live together inside `game/` because they reference each other constantly, and
splitting them would force premature interfaces.

### The track is simulation

The floor and the ceiling are not decoration: they are the two lanes the player travels
between, so their shape is simulation and it lives in `core` where everything can see it.

- **The track is two numbers**: a **spine** (where the corridor's centre sits) and a **span**
  (how tall the corridor is). Floor is `spine + span/2`, ceiling is `spine - span/2`, so
  coherence between the two lanes is by construction rather than by a rule someone has to
  remember. Moving the spine makes the world undulate; moving the span is a difficulty knob the
  game never had.
- **The profile is a function of time, not of scrolled pixels.** Screen x becomes world time
  with exactly the mapping obstacles use in reverse. Anchoring it to pixels would slide the
  track against the patterns the moment scroll speed changed, which is the one property the
  whole "obstacles are events in time" architecture exists to protect — and in v2.0 speed
  changes because the *player buys it*. The visible price is that the undulation stretches as a
  run speeds up.
- **A body rests on the highest ground under its whole width**, not on the ground under one
  chosen point. Exact rather than sampled: the profile is linear between its entries, so an
  extreme can only sit at an end or at a boundary inside.
- **A flip resamples both of its endpoints every step**, rather than capturing where the ground
  was when it began. A journey that starts before a change in the ground and ends after it
  therefore always lands on the ground that is actually there, at the cost of a path that curves
  a little while the track slides underneath.
- **The lane-position query is a pure function of a player and a world**, which is why render
  can call it with the world nudged forward by the leftover fraction of a step and get a body
  riding the same interpolated ground the track is drawn on. Without that the character walks
  down a slope at the tick rate while the slope slides smoothly, and the higher the frame rate
  the more visible it is.
- **The flip's duration is constant in time (~0.16 s), never in space.** The corridor changes
  width; the gesture must not. A flip the player has to recalibrate at every curve stops being a
  reflex.

### The player's screen x is game state

The most invasive change in v2.0, done in R2.1. The old `PLAYER_X` was doing two jobs and has
been split into two constants that happen to hold the same number:

- **`core.WORLD_ANCHOR_X`** — the screen x that world time lands on. Constant, and the *only*
  thing any space↔time conversion may read: the terrain sampler and obstacle positions both do.
  A ground that followed the player would slide against the patterns every time they lost or won
  back a stride. Verified by moving the player to x=40 and confirming no obstacle moves.
- **`core.PLAYER_HOME_X`** — where a free-running character settles. They lose x when a cube
  pins them, because the face scrolls away with the world, and win it back at
  `PLAYER_RECOVERY_RATIO` of the scroll speed.

Three things follow, and all three are load-bearing:

- **The distance between the character and the Corruption front is the health bar.** That is why
  there is almost no HUD: the game already draws its own state at full size.
- **Move first, resolve second** (`advance_ground`). Pinning against a face *places* the body
  exactly at it, which is not an overlap — so a resolve-then-move ordering finds nothing on the
  next step, creeps forward, and re-pins on the one after. Measured: `is_blocked` flickered
  every other step while the character was plainly stuck. Moving first makes the contact real,
  and the dragging falls out for free.
- **Depth is `(scroll_speed + player.velocity_x) * dt`**, not the scroll alone. Pinned, the two
  cancel exactly and depth stops; recovering, the character outruns the world and repays the
  loss in score as well as in room. Blocking costs depth with no line of code that says so.

### The three dangers, three verbs

| | says | kills? | built? |
|---|---|---|---|
| **Cube** | *do not be here, or you pay* | no — it **blocks** | ✅ |
| **Gap** | *do not be here* | yes | ✅ |
| **Sentinel** | *do not move right now* | yes | R4.4 |

- **A cube blocks, and that is the design's centre of gravity.** Because it is not lethal, the
  game is finally allowed to threaten **both lanes at once** — a mirrored cube pair is legal,
  and it is the first thing in the project's history that turns "where do I go" into "which
  price do I pay". The v1.x design could never do it: two lethal lanes is an unsolvable pattern.
  What a cube costs is its **width**, because width is how long you stay pinned.
- **The Sentinel is the only danger that asks what you are *doing* rather than where you are.**
  It occupies the middle band of the corridor, so standing on either lane is safe and crossing
  is death. For its duration the flip is forbidden, which means committing to a lane in advance.
- **The floor breaks, the ceiling dissolves.** Hard lit edges and a dark pit on one side; edges
  fading out over tens of pixels and a faint glow on the other. Same cut, opposite reading.
- **The track owns the holes.** `render/` is the only code that knows where its own surface is,
  so it subtracts the void obstacles from the width of the screen and draws what is left one
  span at a time. Drawing a gap as an object is what made it read as a box standing on the floor
  for the whole of the prototype.

### The fairness rule — the only one there is

> **At every instant at least one lane must be non-lethal. While a Sentinel is up, both must
> be.**

That is the entire pattern contract in v2.0, and it replaces a machine of band sets with
subset-containment chaining. Everything else — mirrored cubes, pyramids, fragments in the
awkward place — is legal by construction, because none of it kills.

Two things the old contract taught that are still worth knowing:

- **A contract that guarantees you start safe is a contract that rewards standing still.** That
  is literally what killed v1.x. Any future rule must be checked against "does doing nothing
  survive this".
- **Difficulty is not speed.** Obstacles are events in time, so reaction time *inside* a pattern
  does not move with scroll speed at all — replaying every pattern at 270, 330 and 400 px/s gave
  the same set of surviving answers. Speed changes how long you get to *look*, and pulling the
  other way, how briefly a wide obstacle blocks a lane. In v2.0 speed is therefore not a
  difficulty knob at all: it is something the player buys, and difficulty thresholds are
  measured in **distance**, so buying speed buys score and difficulty together for free.

### The neon stroke

`render/stroke.odin` is the one drawing primitive the art direction is made of: a polyline with
a bright core, an additive halo, round ends and welded joins, which raylib has no equivalent of.
Everything the sketches contain — the track's lit edge, plants, trees, the menus — is that same
mark at a different weight, so it is worth being fussy about. Three things it is fussy about,
all established by reading pixels back:

- **A triangle strip's winding is not free.** Backface culling drops the entire ribbon if the
  vertex pairs come out the other way round, silently and with nothing on screen. The convention:
  for a line running left to right, the first vertex of each pair is the upper one.
- **The halo has to start outside the core**, at `STROKE_HALO_INNER` times its width. Its
  brightest layers are the innermost ones, so starting them at the core's own width spends them
  under the opaque pass that then covers them — measured, the profile fell from 642 to 36 in one
  pixel, which is a line with an outline rather than a line that glows.
- **Joins are mitred and caps are tessellated into the ribbon**, never stamped on as circles.
  Additive geometry that overlaps itself adds twice, so a circle at each vertex is a bright bead
  at each vertex. A circle is used only where a mitre cannot exist.

It is written to know nothing about the game. That matters because of an open question: `ui` may
not import `render`, so the menus cannot reach the stroke as things stand. Either `ui` gains
that import (the graph stays acyclic) or `stroke.odin` and `glow.odin` move into a package of
primitives below both. Keep this file free of `game` imports so that stays a file move.

### The character stands in its box

The figure is authored as fractions of the player's box (`render/player.odin`), and the bottom
of that box is the ground. Two rules follow, and both are the difference between a character
that rests on the floor and one that floats or sinks:

- **The visible figure fills the box, not the joints.** The rim is drawn as a fattened
  silhouette reaching `PLAYER_RIM_THICKNESS` past the body, so a foot joint sits that much plus
  half a limb inside the box — 0.409, not 0.5. A shape whose edge falls exactly on the box's
  bottom lights the pixel row *before* it, which is what contact looks like in a readback.
- **Only the feet touch anything.** Hanging from the ceiling is half a turn plus a mirror, which
  is a vertical flip, so the feet are at the *top* of the box there and whatever grows out of the
  crown points into open air in both worlds. That is why the sprout may overhang the box and the
  feet may not.

The poses are **layers over one figure**, not separate animations: each is a 0..1 weight the
pose so far is lerped toward, in a fixed order. That is what keeps one figure builder and one
place a limb angle comes from. The whip of a flip rides `sin(whip * PI)` — zero at *both* ends of
the turn by construction, so it grows out of the run cycle and settles back into it with no seam.

The sprout's inertia is **measured, not integrated**: everything that moves the head is a pure
function of the world's clock, so "where was it a moment ago" is one more evaluation of the same
functions rather than state kept in the renderer — state that would have to survive the frame
and be reproduced by a replay to mean anything.

One trap when writing that arithmetic: the trail against a *turn* has to have the mirror undone
(`* mirror`), because a turn is measured on screen while the lean is authored in the figure's own
frame. The trail against the head's *rise* must not be, because backward is a direction in the
figure's frame.

A lesson from the flip's first version, worth keeping because it will come up again in the game
feel pass: it shipped with a curve that lingered mid-journey, on the theory that a flip which
visibly slows teaches the player something. Playtest killed it — a flourish placed *on the
player's own motion* is not decoration, it is friction. Teach with the background, the light,
the particles; never by making the character do something it did not ask to do.

### Presentation

The game draws in a fixed 1280x720 coordinate space (`core/screen.odin`) and always will: no
gameplay, layout or render code knows what monitor it is on.

- The render target is allocated at the **real output resolution**, and
  `platform.begin_game_canvas` pushes a `Camera2D` zoom that maps a 1280x720 coordinate onto a
  native pixel. Draw in canvas coordinates; the pixels are native.
- The target is sized to the *scaled canvas*, not to the window. Letterbox bars are the part of
  the window the blit does not cover, and stay outside the target — a bright-pass bloom must not
  see them.
- It is rebuilt only on the frames the output size actually changes (`platform.update_display`).
- Fullscreen means **real fullscreen at the desktop's existing video mode** — the game never
  changes a monitor's resolution. Borderless windowed was tried first and does not work: on KDE a
  screen-sized undecorated window is still a normal window, so the compositor maximizes it into
  the work area and keeps the panel on top of it. The file header of `platform/window.odin`
  records the three raylib behaviours that make this delicate — read it before touching a window
  call, because two of them silently change the player's desktop resolution or drop the window
  out of fullscreen.
- A mode change is a short negotiation, not one call. `platform.apply_display_mode` does **one
  step** and is idempotent; the main loop calls it for `WINDOW_SETTLE_FRAMES` frames after any
  change. Never assume a window call has taken effect on the line after it.
- Presentation may read a wall clock (`display_time` in `main`, accumulated from the same single
  `rl.GetFrameTime()` call) for things that are drawn but not simulated — the menu's drift
  between worlds, the horizon's breathing. It must never reach the simulation, which advances
  only in whole `core.FIXED_TIMESTEP` steps out of the accumulator.
- **Post-processing runs on the finished frame, between the canvas closing and the blit.**
  `fx.apply_bloom` reads the render target and composites back into it in place, so `platform`
  never learns that bloom exists and `fx` never learns that a game does. The order in `main` is:
  `end_game_canvas` → `apply_bloom` → `present_display`.
- **Render textures are stored bottom-up, and the flip happens exactly once**, in
  `present_display`. Every intermediate pass in `fx/` draws with a positive source rect, which
  carries that convention through the chain unchanged. A second flip anywhere in the middle
  silently mirrors the light away from whatever emitted it.
- Drawing rate is a setting; the simulation rate is not.

### Colour has two systems, and they must not collide

Two things change the colour of everything, and they are kept apart by being different *kinds*
of thing rather than by dividing the colour channels between them.

- **Depth** is a level, and it is global. It washes both worlds toward the neutral palette as a
  run gets deeper, with palette and bloom converging together on it — light and colour describe
  one world. It moves the hue.
- **The Corruption is a place**, not a level: the world is gone to the left of an advancing
  front and whole to its right. It takes everything — colour, light, all of it, to full black.

They cannot collide because they never contend for the same pixel: to the right of the front
depth is in charge, and to the left there is nothing left to be in charge of. This is why
`core/palette.odin` has no corruption axis and must not grow one — a whole-screen palette cannot
express a boundary, and the axis it briefly carried was deleted along with the grey.

Three rules the implementation established:

- **It runs after the bloom** (`fx/corruption.odin`, called from `main`). A lit edge's halo is
  part of the picture and has to be eaten along with the edge that threw it. Bloom itself is
  untouched by any of this.
- **The ramp sits behind the front, not across it.** The boundary's lit edge is drawn in the
  world at exactly `front_x` (`render/corruption.odin`), and a ramp centred on the front would
  eat the one mark that says where the front *is*. So the fade runs from `front - softness` up
  to the front: measured, the edge comes back bit-identical and the void deepens behind it.
- **The edge is drawn with primitives, not by the shader.** If the shader ever fails to compile
  the frame keeps its colour and the game still runs — but a lethal front nobody can see would
  be the one thing in this game that kills without showing the blow coming (pillar 3). That
  fallback is the reason it is drawn at all, and the reason it must stay drawn.

It went to black at the R2.6 playtest. The design's first answer was that the Corruption owned
saturation while depth owned hue, and that form and brightness survived; built and looked at,
the dead zone was too faint to read — precisely because the axis that would have made it legible
had been forbidden. Worth remembering as a shape of mistake: a rule invented to keep two systems
apart had made one of them unable to do its job, when what actually kept them apart was that one
is global and the other is a boundary.

The art direction leans on the same split. The chosen style (`sketch_3`) is uniform and soft by
design, so what keeps danger from dissolving into the scenery is **scenery is line, danger is
mass**: hollow lit outlines behind, filled dark silhouettes with a lit rim in front, and
fragments as solid light — the third case. A front that goes to full black is literally line
becoming mass, which makes the visual rule and the mechanic the same rule.

### Save data and determinism

- Save files live in the **OS user data directory**, never in the working directory
  (`platform/paths.odin` resolves it per platform via `os.user_data_dir`).
- The payload is CBOR (`core:encoding/cbor`) sealed with ChaCha20-Poly1305
  (`core:crypto/chacha20poly1305`). A save that fails to authenticate is **rejected and reset to
  defaults**, never trusted and never allowed to crash the game.
- Be honest about what this buys: the key ships inside the binary, so local sealing is a
  **deterrent against casual editing, not security**. Never describe it as protection for a
  leaderboard, in code comments or to the user.
- The real defence is server-side revalidation: the client submits a `RunManifest` (seed, game
  version, tick rate, input log, claimed score) and the server replays it. A locally computed
  score is never evidence of anything.
- Because of that, **determinism is a product feature, not tidiness**: seeded RNG, input as data
  and a fixed timestep together buy leaderboard validation, replays, ghosts and reproducible
  balancing. Do not weaken any of them for convenience.
- Changing `SaveData`'s shape means bumping `SAVE_FORMAT_VERSION`, which makes every existing
  save unreadable — decoding deliberately refuses versions it does not know rather than guessing.
  That is the right default, but it discards the player's data, so **say so before doing it**.
  Phase R1 does exactly this.
- `SaveData` returned by `load_save` owns heap allocations; free it with `destroy_save_data`. A
  `SaveData` built in memory does not own them — its manifest borrows the live recorder's tick
  log — so never destroy one of those.

### Golden rules

- **`game/` never draws.** No `rl.Draw*` call may appear anywhere under `game/`.
- **`render/` never mutates game state.** It takes state by value and produces pixels.
- **`fx/` knows nothing about the game.** It is a parametric particle/post-processing module;
  gameplay may emit into it, but it never imports `game`.
- **A flip is one journey with one clock.** One key, one gesture. A press during a journey is
  *buffered* one deep, never blended: it takes off the instant that journey lands, carrying the
  overshoot so back-to-back flips keep their cadence. One deep and no deeper — measured, five
  presses on five steps give two flips, and a deeper queue would let mashing bank flips the
  player can no longer see coming.
- **Input is passed in, never read inside gameplay.** Gameplay and UI procedures take a
  `core.Input` value. Exactly one procedure polls the keyboard (`platform.read_input`) and
  exactly one reads the clock (`rl.GetFrameTime`, in the main loop). Adding a second of either
  breaks replay.
- **Randomness is seeded and threaded explicitly.** Never call the global `rand.*` procedures;
  every draw goes through the run's own generator so the run is reproducible from its seed.
- **The simulation advances in fixed steps.** `core.FIXED_TIMESTEP`, never a raw frame time. A
  frame may run zero, one, or several steps; input is latched until a step consumes it. Anything
  that must not change a run's outcome — culling, rendering — has to be provably neutral, not
  just probably neutral.
- **No hardcoded colours outside `core/palette.odin`.** Every colour is sampled from the palette
  system. A colour literal anywhere else is a bug, including in `ui/`.
- **The body is dark in both worlds; only the light changes.** Player, obstacles and track all
  take `palette.silhouette`; what tells the worlds apart is the rim and the glow. Inverting a
  silhouette between worlds reads as two different characters.
- **No hardcoded pixel timings in patterns.** Patterns are time offsets; positions are derived at
  runtime from elapsed time and scroll speed.

---

## Code conventions

Taken from the existing code — match them, do not invent new ones.

**File header.** Every file opens with a block comment naming the file and stating its
responsibility, referencing the design doc section where relevant:

```odin
/*
* Player
* Holds the player character state and drives the flip state machine
* (Design Doc, section 3).
*/
package game
```

**Naming**

| Kind | Style | Example |
|---|---|---|
| Types | `PascalCase` | `Player`, `ObstacleType`, `PatternEvent` |
| Procedures | `snake_case` | `update_player`, `get_lane_y` |
| Constants | `SCREAMING_SNAKE` with `::` | `PLAYER_SIZE`, `FLIP_DURATION` |
| Struct fields | `snake_case` | `transition_timer`, `arrival_time` |

**Procedure shapes** — keep the established trio:

```odin
new_player  :: proc() -> Player            // constructor, returns by value
update_player :: proc(player: ^Player, ...) // mutates through a pointer
draw_player :: proc(player: Player)         // takes by value, never mutates
```

Accessors that derive a value follow `get_<thing>_<property>`, e.g. `get_obstacle_size`.

**Formatting**: tabs for indentation, `odinfmt` defaults. Run it if available before finishing a
phase.

**Comments**: explain *why*, not *what*. Keep the habit of citing the design doc section a
decision comes from, and of flagging known simplifications explicitly rather than leaving them
silent.

**Memory**: prefer fixed pre-allocated pools over per-frame allocation, especially in `fx/`.
Where a dynamic array is unavoidable, `defer delete(...)` at the same scope it was created.

---

## Design pillars

Check every proposed feature against these before implementing it. If a feature breaks one,
raise it with the user before writing code.

1. **One key, one gesture.** `SPACE` changes lane. No hold, no second gameplay key, no jump,
   ever. Menus may use arrows/enter/escape — the pillar covers gameplay, not UI.
2. **Readable in two seconds.** Someone watching a video understands the goal without
   explanation. When beauty and readability conflict, readability wins.
3. **Every run is different, every run is fair.** Procedural but never unsolvable and never a
   surprise: every danger has a visible arrival phase before it is dangerous.
4. **The theme is not decoration.** Real and Dream must shape mechanics, visuals and feedback.
5. **One question at every instant: which lane?** Two answers, never more. A **lethal** danger
   may never threaten both lanes at once; a **non-lethal** one may, and that is where most of the
   tension comes from.
6. **Never colour alone.** The two lanes are always distinguishable by position and by type of
   motion as well as by colour. This is an accessibility constraint, not a preference.
7. **A mistake costs ground, not the run.** Only the gap and the Sentinel kill outright.
   Everything else costs distance, and you die when the distance you have left runs out.

---

## Known issues carried forward

Tracked here so they are not rediscovered. Each is scheduled in `ROADMAP.md`.

- **No pattern uses a mirrored cube pair yet**, even though R2.3 made it legal — it is the
  design's centrepiece and it is authored in R4.1. Until then the game has the *rule* that lets
  both lanes be threatened at once and never exercises it.
- **The pool is a placeholder.** Eleven patterns over two obstacle types, authored only so that
  R1 could be verified. The real pool is R5.2, after the cube blocks and the Sentinel exists.
  Measured today: at least one lane is lethal 19.9% of the time, against a Definition of Done
  that asks for over 40%.
- Menus, HUD and the options screen take their colours from the palette but still use raylib's
  default bitmap font. Everything drawn from primitives is crisp at native resolution and only
  the text is not (phase R7).
- There are two glows: the real frame-wide bloom in `fx/bloom.odin`, and the stacked additive
  primitives in `render/glow.odin` that predate it — `render/stroke.odin` builds its halo out of
  the second, sharing `glow_layer_alpha` so a stroke and a plain halo agree. The second was a
  stand-in for the first and now feeds it: a primitive halo is bright, so the bright pass picks
  it up and blooms it again. Particles will go through the same pass. Where a halo looks doubled,
  remove the primitive one rather than lowering the bloom.
- Bloom is LDR: the frame is an RGBA8 texture, so "bright" means "near white", and the thresholds
  in `fx/bloom.odin` are tuned against **what reaches the frame**, not against the palette. A rim
  drawn at 0.7 alpha over a dark background lands near 0.66, not at the 0.91 its colour names.
  The same trap in reverse governs the palette: **a background value must clear the lowest
  threshold it can ever meet, not its own world's.** Bloom settings interpolate on `world_t`, so
  a player halfway through a flip is lit by the neutral threshold (0.30) while the floor is still
  drawn in the Real palette — which is how `real.near` at 0.369 came to bloom at 20% on every
  crossing while sitting comfortably under Real's own 0.50.
- Recorded run manifests are saved but never played back — there is no replay or ghost in the
  game yet, only the data needed for one.
