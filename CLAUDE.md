# CLAUDE.md — Working notes for Wake Shift

Operational rules for developing this project.

**The game was rewritten on 6 September 2026.** The two-lane dodging game was replaced, by the
author's decision, with a **procedural maze** run at speed, and the first step of that rewrite has
landed: the grid, the sliding, the generator and the Corruption all run. Everything about the old
gameplay — the pattern pool, the skylines, the cubes and holes, the fairness rule, the difficulty
curve, the economy tuning — is archived in `docs/archive/CLAUDE_v2_mattoncini.md` and
`docs/archive/TIMELINE_v2_mattoncini.md`. **Do not read those as instructions.** They are history,
and the reason they are kept is that they record measurements and traps that cost real work to find:
go there to learn *why* something was once true, never to learn what to build.

The fragments, the Dream phase and the generator's deterministic repair have landed since; **the
levels are still designed and not built**, and so is the growth of the generator's knobs with
distance. `TIMELINE.md` says where each one stands.

What still binds:

- **What it looks like** → `docs/inspiration/La_Linea.png`. A filled, vignetted field and one
  continuous glowing stroke that *is* the world. The maze is drawn in exactly that stroke.
- **What is done and what is left** → `TIMELINE.md` (Italian; the author's file). It is a **board,
  not a history**: one row per step, its status, and which model should take it. The history lives in
  `git log`, where the commit messages carry the argument. There is still no roadmap in the sense
  that matters — the board says what, never when, and the author picks the next one.
- **How we work** → this file.

`docs/` is deliberately **not tracked by git**: it is the author's working material and lives only
on their disk.

---

## The project in one paragraph

Wake Shift is a **procedural maze runner** in Odin + raylib. The corridor between the floor and the
ceiling is an endless maze that scrolls past; the two lanes are no longer places to be, they are the
maze's boundary. The player moves with **WASD / arrows** and **slides until a wall stops them**, so
every input is a commitment rather than a steering correction. Behind them the **Corruption**
advances from the left, and the distance between the two is the only health bar there is.
**Fragments** picked up in the maze charge a bar and do nothing else — they do not touch the front,
because what moves the front is the *state of the world* and fragments are the only way to change it.
At full the world turns **Dream**: a slide goes through the wall that stopped it and runs on to the
next, and the Corruption runs backwards. The bar drains while it lasts, **Lucids** found only up
there extend it, and at empty the world falls back to Real. The visual identity is **La Linea**: a filled, vignetted field, one continuous glowing stroke,
and nothing else.

---

## Language rules — non-negotiable

- **All code is English.** Identifiers, procedures, constants, struct fields, file names.
- **All comments are English.** No exceptions, including quick inline notes.
- **All commit messages are English.**
- **Conversation with the author is Italian.** Explanations, proposals, questions, summaries.
- Markdown docs follow their existing language: `TIMELINE.md` and `docs/` are Italian (the author
  reads them); `CLAUDE.md` and `README.md` are English (they govern the code and face outward).

---

## Build and run

```bash
odin check src            # type-check only, fast — run this after every edit
odin build src -out:build/wakeshift
odin run src              # what the author runs to playtest
```

Toolchain: Odin `dev-2026-07`, raylib bindings `vendor:raylib/v55` (imported as `rl`). Always import
raylib as `import rl "vendor:raylib/v55"` — never `v6`, the linker expectations differ.

---

## Picking up in a new session

1. **`TIMELINE.md`** — the board: what is done, what is left, which model each step wants, and the
   author's next recommended step. Read `git log` for why any of it is the way it is.
2. **This file** — the architecture rules and conventions, which are what actually bind.
3. The header comment of whatever file you are about to touch. Every one states its responsibility
   and the decisions behind it, and that is where the *why* lives.

**There is no roadmap and no phase list.** The author decides the next step and says so. If you
finish what was asked and think something else is needed, say what and why — do not start it.

---

## How verification works here

`odin check src` after every edit; `odin build src` and a short launch before reporting a task done.
**Never claim anything about how the game looks or feels** — the author is the only one who can
judge that. Say "compiles, launches, no crash in N seconds", nothing more.

For anything with real logic, write a throwaway program that exercises the module directly and run
it. That habit has caught bugs type-checking could not, repeatedly.

Build a throwaway as a package *inside* `src/` — `src/scratch_check/`,
`odin build src/scratch_check -out:<scratchpad>/sc` — not in the scratchpad, because the relative
imports (`../core`) only resolve from there. It is invisible to `odin build src`, which compiles only
what `main.odin` imports, so it cannot break the game. **Delete the directory before committing.**

Five traps, all learned the hard way and all still live:

- **When the thing to verify is a rule about play, replay it.** Drive the real simulation with
  scripted input and ask what actually survives. A claim about play is cheap to check and expensive
  to be wrong about.
- **Measure the thing, not a proxy for it, and watch what your harness confounds.** "Is it too easy"
  only became answerable when it became "what fraction of the time is at least one lane lethal". And
  a first pass measured obstacle lethality using a player who never pressed, so the run ended at the
  first threat and every later one scored zero — it looked exactly like a collision bug.
- **Check the bot before trusting the bot.** The greedy bot sat inside a mirrored pair until it died,
  because it valued both lanes equally and never pressed; that silently invalidated every run-length
  number measured in a pool where such pairs were common. Instrument the *death mode* before quoting
  a median. The maze bot repeated it twice over: it discarded every seam-crossing slide because the
  destination fell outside its search window, and then it walked into the pockets above and died in
  all 24 runs. **A model of a player who cannot read the maze is not a benchmark for an economy** —
  give the bot the lookahead a competent player has, or the number measures the bot.
- **When the thing to verify is pixels, read the pixels back.** `rl.LoadImageFromTexture` on the
  render target turns "does the bloom look right" into arithmetic: draw the frame twice, once with
  the effect and once without, and compare per-row brightness. Give a readback test an *asymmetric*
  subject, and say what the number you print actually measures.
- **When a check involves the window, do not trust what raylib reports about itself.** Read the live
  window's state from the outside (`wmctrl -lG`, `xprop -id <id> _NET_WM_STATE`). raylib claimed
  `IsWindowFullscreen() = true` for a window the compositor had merely maximized.
- **A model that grades its own homework will pass.** The maze generator checked every chunk it made
  and every check came out green, while the live maze was walled shut three chunks in: the model and
  the world disagreed at the chunk boundaries, and only a real solver run over the real, assembled
  world could say so. Whenever a check is per-piece, write the whole-thing check too — and when the
  two disagree, do not reason about which is right, print both and diff them.

---

## Workflow

1. **One thing at a time, and the author picks it.** There is no plan to read ahead in.
2. **Claude writes code and proposes ideas. The author playtests and gives feedback.**
3. **Claude verifies only that it compiles and launches.**
4. **Report honestly.** If a phase is partially done, say which part and why. If a test fails, show
   the output.
5. Keep `odin check src` green at every intermediate step, especially during file moves.
6. **Update the board in `TIMELINE.md` when a piece of work lands**: move the row's status, and say
   in its Note what is still missing. Keep it lean — it is the file the author opens first, and a
   row that grows into a paragraph stops being readable at a glance. Nothing else goes there: no
   rationale, no measurements, no narrative. Those go in the commit message and in the comment of
   the constant they justify.

   What was learned is **moved somewhere it will be read again**, and that is never the timeline: a
   library trap into the comment of the file that hits it, an architecture rule into this file, a
   measurement into the comment of the constant it justifies. The commit message carries the
   argument; the timeline carries the fact.
7. **Spend the author's turns, not their patience.** Batch independent edits into one call, do not
   re-read what you already know, and do not re-run a check nothing has invalidated. When the
   question is how something *looks*, ask — they play it.

---

## Architecture

### Package graph — strictly acyclic

```
core      ← imports nothing from the project
platform  ← core
game      ← core
fx        ← core          (bloom, dither, particles)
render    ← core, game, fx
ui        ← core, game
main      ← everything

audio     ← core, game    (not created yet)
```

`game` does not import `platform`: input arrives as a `core.Input` value, so gameplay needs nothing
from the platform layer at all. Keep it that way — it is what makes the simulation testable without
a window.

Four things live in `core` that look like they belong elsewhere — `Input`, `Direction`, `Settings`
and `Palette` — all for the same reason: two packages that may not import each other both need them.
When something is *vocabulary* rather than *behaviour*, `core` is where it goes; the package that
owns the behaviour keeps the half that needs game state.

Odin forbids cyclic imports between packages, and one directory is exactly one package. The split is
**by level of abstraction, not by game entity**.

### Golden rules

- **`game/` never draws.** No `rl.Draw*` call may appear anywhere under `game/`.
- **`render/` never mutates game state.** It takes state by value and produces pixels.
- **`fx/` knows nothing about the game.** It is a parametric particle/post-processing module;
  gameplay may emit into it, but it never imports `game`.
- **Input is passed in, never read inside gameplay.** Gameplay and UI procedures take a `core.Input`
  value. Exactly one procedure polls the keyboard (`platform.read_input`) and exactly one reads the
  clock (`rl.GetFrameTime`, in the main loop). Adding a second of either breaks replay.
- **Randomness is seeded and threaded explicitly.** Never call the global `rand.*` procedures; every
  draw goes through the run's own generator so the run is reproducible from its seed.
- **The simulation advances in fixed steps.** `core.FIXED_TIMESTEP`, never a raw frame time. A frame
  may run zero, one, or several steps; input is latched until a step consumes it. Anything that must
  not change a run's outcome — culling, rendering — has to be provably neutral, not just probably
  neutral.
- **No hardcoded colours outside `core/palette.odin`.** A colour literal anywhere else is a bug,
  including in `ui/`.
- **A pickup is taken by passing over it**, not by stopping on it, so everything about one — where it
  is placed, what it costs, when it is collected — is asked of the cells a slide *crosses*. Pricing
  the stop instead put fragments on the optimal route's own straight runs at a price they did not
  cost.
- **Fill means actor, line means world.** The field and the body were the only filled things until
  the fragments landed; the rule moved rather than broke. What makes it safe is that the palette has
  **three families** now and hue carries the distinction: `light` is the world, `accent` is what is
  worth going for, `figure` is you. Before this the player and the fragments both sampled `accent`,
  so the two things a player actually looks at were the same colour. Nothing else may become filled
  without earning a family of its own.
- **The world converges with depth and the actors do not.** Washing both worlds toward the neutral
  palette is right for a *place*; doing it to the body and the fragments would take them away exactly
  when the maze is densest. The actors are also sampled straight Real → Dream rather than through the
  neutral palette, because neutral is *what the world converges to* and something that does not
  converge has no business passing through it — that is also what stopped the body going white in
  the middle of every crossing.
- **A small bright filled shape under the bloom is not a shape, it is a blob.** Fill dim, outline
  bright: the fill says "actor", the outline carries the silhouette. And anything that pulses does it
  on **scale and alpha, never brightness** — brightness crosses the bloom threshold and back, so the
  halo pops and the mark reads as flicker instead of breathing.
- **The weight hierarchy lives in the arithmetic.** Every stroke weight is a multiple or a fraction
  of one rung, so tuning the world cannot silently invert the order.
- **A *world* element nailed to the screen reads as two pictures.** The vignette is screen-fixed on
  purpose because it is a property of the lens; anything the world contains must ride the world. The
  dust gets away with screen coordinates because it lives at a front that barely moves on screen; the
  pierce ring does not, because it marks a *wall*, so it stores a world x and `fx.draw_rings` takes
  the offset. Handing fx an offset is arithmetic, not game knowledge.
- **Nothing happening is not an event.** The pierce worked from the day it landed and read as a
  glitch, because one wall quietly ceasing to exist is indistinguishable from the wall never having
  been there — which is what the maze is full of. What was missing was not a better effect but *any*
  statement that something happened at a place. The flash is warm and belongs to you; the wake is the
  world's light, dimmed and broken, because it is what the world was left like. An act and a
  consequence, told apart the way the palette tells anything apart.

### The maze

Twelve rows of 60 px fill the 720 px canvas exactly, and the columns run on forever. Vertically the
division has to be whole or the corridor would not close against the floor; horizontally it never
has to be, because the world scrolls and the fraction is only where the camera is.

- **Walls are edges, not blocks.** A maze of solid cells would be a third filled thing and it would
  stop being La Linea. Each cell owns its **north** and **west** wall and nothing else, so the two
  sides of one wall cannot drift apart, and a single procedure answers for all four directions.
- **A pierced wall is open, and it is not the same as a wall that was never carved.** Two more bits
  per cell say so. Nothing about collision reads them — they exist because the difference *is* the
  wake, and the wake is pillar 6's third channel: with the colour off you can still tell which world
  you are in by the holes behind you. Only the player's pierce sets them; the carve, the braid and
  the repair all open walls that were never there.
- **An instant cannot be read off a level.** A pierce, a pickup: the simulation counts them and
  presentation compares the count across a frame's steps. That is the allowed direction — derived
  from the simulation, never read by it — and it is the only way a frame can be told that something
  *happened* rather than what is currently true.
- **Collision is a question to the grid, never an overlap of rectangles.** The block sits centred in
  its cell and is smaller than it, so the air around it is presentation and costs nothing: there is
  no pixel at which it can catch on a corner, because no pixel is ever consulted.
- **A chunk is generated alone, and that is the point.** The holes in a seam are a function of the
  boundary's column index alone, so the two chunks that touch it agree without ever meeting. That
  buys three things at once: an evicted chunk comes back identical, a chunk can be verified on its
  own in a test, and nothing has to be generated in order. **Never hand a seam forward.**
- **The invariant is a budget, not a connection.** "A path exists" is too weak here: the camera
  advances whether the player is making progress or not, so a route costing three cells of climbing
  per column gained is a route that kills. Measure the cheapest crossing, re-roll the chunk when it
  falls outside the band the level asked for, and keep the loop deterministic from the seed so the
  run stays reproducible. Difficulty is *measured*, never hoped for.
- **Measure on the slide graph, not on cell adjacency.** A press travels until a wall stops it, so
  the player can only stop where something stops them, and a junction in the middle of a straight
  run is passed over rather than turned at. Slide-connectivity is strictly weaker than
  cell-connectivity; measuring the wrong one is measuring a game nobody is playing.
- **Braid, never a perfect maze.** The tree a DFS carve produces is exactly wrong: with no way to
  turn round against the scroll, a dead end does not cost time, it kills.
- **Both edges of a chunk lie, and they lie in opposite directions.** A chunk-local search is blind
  past its own columns, so at each edge it reports a standstill where the live maze reports a
  journey continuing — and in both cases it is a row whose seam is open. The right edge is the
  *crossing*, so that state is absorbing and may never be a stepping stone; the left edge leads back
  into a chunk this measurement cannot see, so that move is struck out entirely. Conservative is the
  correct direction: a chunk wrongly called hard is re-rolled, a chunk wrongly called easy is
  shipped. Left in, the search stands still at an edge and climbs through those phantom stops into
  rows the player can never stop in — every per-chunk number came out green while the live maze was
  walled shut three chunks in.
- **The pickups are placed by the same measurement, once, on the chunk that won.** Not on every
  attempt: measuring the twenty-three that lost is paying twenty-four times for an answer about a
  maze nobody plays. The band is stated in *cells of detour*, and a cell is 60 px against a 900 px/s
  slide, so **15 cells is one second** and the band reads as time.
- **The Dream's pierce is the one thing that writes to a chunk after it was generated**, so a chunk
  is a pure function of its seed only until it is played through. The holes are behind the body and
  the slot is reused long after the Corruption has eaten that ground, which is why it is safe — say
  so, do not rely on it silently, and do not add a second writer.
- **Generation belongs to a simulation step, never to a draw.** It is pure and idempotent, so a
  draw that triggered it would still get the right walls — and would pay several milliseconds for
  them mid-frame, at a moment chosen by the camera rather than by the simulation.
- **Merge collinear walls before drawing them.** Measured: 82 strokes a screen instead of 562.
- **A check that stops early is blind past where it stopped.** `trap_free` used to examine only the
  cells the crossing search had reached, and that search returns at the first exit it pops — so
  everything dearer than the crossing was never looked at, and a solver over the assembled world
  found **3.18% of reachable cells terminal** while every chunk reported green. It tests every cell
  now. Same lesson as the seams, different costume.
- **Pillar 5 is repaired, not re-rolled.** Re-rolling is right for the difficulty band, because a
  chunk outside it is still a chunk; it is wrong for a pocket, because twenty-four attempts can make
  "never" rarer and cannot promise it. So the pockets are opened, one wall at a time, at the cell
  furthest along that still has a wall to take down. Measured: 73.8% of chunks want a repair, mean
  2.05 walls, and the assembled world goes from 3.18% pockets to **0 over 13533 reachable cells**.
- **Safety is not monotone in openings**, which is the one thing about the repair that is not
  obvious. Taking a wall down does not only add a move, it *lengthens a slide* — a cell that used to
  stop on safe ground can run past it and end somewhere worse. A batch of openings cannot be reasoned
  about, only a sequence of them, each one measured. Never rewrite that loop into a single pass.
- **A horizontal slide reads only west walls and a vertical one only north walls**, so one opened
  wall can only change one row's Left/Right or one column's Up/Down. Patching the slide table instead
  of rebuilding it is what lets the repair fit in a step: 10.7 ms a chunk down to 5.5, with output
  identical to the digit, which is also how you know the patch is equivalent.

### Presentation

The game draws in a fixed 1280x720 coordinate space (`core/screen.odin`) and always will: no
gameplay, layout or render code knows what monitor it is on.

- The render target is allocated at the **real output resolution**, and `platform.begin_game_canvas`
  pushes a `Camera2D` zoom that maps a 1280x720 coordinate onto a native pixel.
- The target is sized to the *scaled canvas*, not to the window. Letterbox bars stay outside it — a
  bright-pass bloom must not see them.
- Fullscreen means **real fullscreen at the desktop's existing video mode**. The header of
  `platform/window.odin` records the three raylib behaviours that make this delicate — read it before
  touching a window call, because two of them silently change the player's desktop resolution.
- **A mode change is a short negotiation, not one call.** `platform.apply_display_mode` does one step
  and is idempotent; the main loop calls it for `WINDOW_SETTLE_FRAMES` frames after any change.
- Presentation may read a wall clock (`display_time` in `main`) for things that are drawn but not
  simulated. It must never reach the simulation.
- **Presentation may hold state**, and `background_t` is the example: the field's colour *chases* the
  world on a 0.45 s time constant rather than following it, because a burst of flips would strobe a
  full-screen colour. The rule that keeps this safe: a presentation value may be *derived from* the
  simulation and may never be *read by* it.
- **Post-processing runs on the finished frame**, between the canvas closing and the blit:
  `end_game_canvas` → `apply_bloom` → `present_display`.
- **Render textures are stored bottom-up, and the flip happens exactly once**, in `present_display`.
  Every intermediate pass draws with a positive source rect. A second flip anywhere in the middle
  silently mirrors the light away from whatever emitted it.

### The neon stroke

`render/stroke.odin` is the one drawing primitive the art direction is made of: a polyline with a
bright core, an additive halo, round ends and welded joins, which raylib has no equivalent of.
Everything is that same mark at a different weight. Four things it is fussy about, all established by
reading pixels back:

- **A triangle strip's winding is not free.** Backface culling drops the entire ribbon if the vertex
  pairs come out the other way round, silently and with nothing on screen. The convention: for a line
  running left to right, the first vertex of each pair is the upper one.
- **Neither is a triangle fan's, and it wants the opposite order to the stroke.** The same shape that
  outlines correctly fills *nothing* — measured, 0 lit pixels against the 2r² the area works out to,
  and 7200 with the points reversed. Keep one point order for the shape and reverse it in the one
  place that fills, so the two passes can never disagree about what the shape is.
- **The halo has to start outside the core**, at `STROKE_HALO_INNER` times its width. Starting it at
  the core's own width spends its brightest layers under the opaque pass — measured, the profile fell
  from 642 to 36 in one pixel, which is a line with an outline rather than a line that glows.
- **Joins are mitred and caps are tessellated into the ribbon**, never stamped on as circles.
  Additive geometry that overlaps itself adds twice, so a circle at each vertex is a bright bead.
- **`STROKE_MAX_POINTS` is load-bearing and it truncates in silence.** A polyline over the cap is a
  line that stops in mid air with nothing to say so. The maze was expected to push on this and does
  not: welding collinear wall edges into runs takes a screen from 562 segments to **82 strokes,
  measured**, and a merged run is two points, so the cap is not in play. It comes back the day a
  wall curves.

Two other lessons that will come up again:

- **A bloomed small shape magnified afterwards is not the shape.** A 45 px figure read as a
  self-crossing "Σ" until the same figure was drawn large, clean and without bloom, at which point
  the contour was fine and the *proportions* were the bug. Inspect a shape at the size it is drawn.
- **A primitive halo under something that used to be opaque is a trap.** Where a halo looks doubled,
  remove the primitive one rather than lowering the bloom — the frame's bloom already picks up
  anything bright.

### Two fronts, both of them a clip

The world exists **between two x values and nowhere else**: written by the pen on the right
(`render/draw_front.odin`), eaten by the Corruption on the left (`render/corruption.odin`). That is
two lines of arithmetic and it is the whole of both ideas — neither front needs a per-object
animation, and anything new that draws itself must truncate the same way rather than fading in.

- **The front is not a difficulty knob and may never become one.** Every pixel it moves left is
  warning time taken from the player. `DRAW_FRONT_INSET` is a constant, spent on making the nib
  visible rather than on tension.
- **There is no wall on the right, and copying the Corruption's mark would be the worst possible
  mirroring.** A lit vertical bar at the right edge reads as something approaching, and this is the
  one boundary that threatens nothing. The draw front is marked by *absence* plus a nib.
- **The Corruption's own lit edge is drawn with primitives and must stay drawn.** A lethal front
  nobody can see is the one thing that would kill without showing the blow coming.
- **The left front lives in the world, and the camera follows the body.** It was a screen x with the
  camera running past it at a constant speed until the first maze playtest, and measured, that made
  the camera the game's real threat: 96% of the ground a player lost was the camera and 4% was the
  thing with a name on it. Reading a maze takes time a runner never needed, so a camera that charges
  for standing still prices out the only way the game can be played. Two rules come out of the swap
  and both are load-bearing:
  - **Death compares two world positions, never two screen ones.** That is what lets the camera lag,
    chase, and be as pretty as it likes without any of it reaching the thing that decides a run.
  - **A front off the picture is not a missing front.** Being far enough ahead that there is nothing
    to see is the reward, and it is the clearest health bar the game has. Do not draw a marker, a
    meter or an arrow for it — the empty edge *is* the reading.
- **A shape cut at one end is open there and closed at the end it finished**, so anything that can be
  half-written has to be built from the pen outward. A shape whose outline runs from its left edge
  rightward leaves both loose ends on the left when clipped — capped at the pen and open at the end
  it had already finished, which is exactly backwards. This cost a silent bug once.

### Particles are presentation, and they have their own everything

`fx/particles.odin`: a fixed pool of 512, no allocation ever, at any frame rate. A dead particle's
slot is filled by swapping the last live one into it, so nothing may depend on the order.

- **Its randomness is its own generator**, seeded once — not the run's, which has to stay
  reproducible. Dust that differs between two replays of one run is correct; a run that differs
  because of dust would be a bug.
- **The integration is exact, not stepped.** Drag is an exponential, so both the velocity and the
  distance it covers are closed forms and a particle lands in the same place at 30 fps as at 240.
  The pool is advanced from the frame clock, so a per-frame multiply would make the dust thicker on a
  fast machine.
- **A stream keeps a fractional debt.** A rate under one particle per frame still emits.
- **Each particle is one additive circle with no halo of its own**; the frame's bloom makes it glow.
- **It stops when the game is paused.** A paused frame is a still, and dust drifting across one would
  be the only thing on screen that had not stopped.

### Colour, light and the Corruption

Two things change the colour of everything and they are kept apart by being different *kinds* of
thing: **depth** is a level and it is global; **the Corruption is a place**, whole to the right of a
front and gone to the left. They can never contend for the same pixel. `core/palette.odin` has no
corruption axis and must not grow one — a whole-screen palette cannot express a boundary.

- **The ramp sits behind the front, not across it**, or it eats the one mark that says where the
  front *is*.
- Bloom is LDR: the frame is an RGBA8 texture, so "bright" means "near white" and the thresholds are
  tuned against **what reaches the frame**, not against the palette. **No filled surface may exceed
  0.298**, the lowest bloom threshold minus half a level. The dark direction is unconstrained.
- The dither masks banding, it does not remove it. No pass that reads a finished frame can dither
  before quantisation; the real fix is drawing the field in a shader that does.

### Easing curves come from the standard library

`core:math/ease` (the whole Penner set). `ease.ease` and the individual curves are pure and
`contextless`, so they may be used anywhere, simulation included. **The `flux` tween may not** — it
allocates and runs on a wall clock, so inside a simulation step it would break replay.

### Save data and determinism

- Save files live in the **OS user data directory**, never in the working directory.
- The payload is CBOR sealed with ChaCha20-Poly1305. A save that fails to authenticate is **rejected
  and reset to defaults**, never trusted and never allowed to crash the game.
- Be honest about what this buys: the key ships inside the binary, so local sealing is a **deterrent
  against casual editing, not security**. Never describe it as protection for a leaderboard.
- The real defence is server-side revalidation: the client submits a `RunManifest` and the server
  replays it. A locally computed score is never evidence of anything.
- Because of that, **determinism is a product feature, not tidiness**: seeded RNG, input as data and
  a fixed timestep together buy leaderboard validation, replays, ghosts and reproducible balancing.
- Changing `SaveData`'s shape means bumping `SAVE_FORMAT_VERSION`, which makes every existing save
  unreadable. That is the right default, but it discards the player's data, so **say so before doing
  it**.
- **The manifest records flip ticks only, and there are no flips any more.** It does not reproduce
  a run, confirmed: the control scheme is four directions, and a held key is simulation input too,
  so recording the presses alone would not be enough either. Extending it is part of making the maze
  real rather than an optional tidy-up.

---

## Code conventions

**File header.** Every file opens with a block comment naming the file and stating its
responsibility:

```odin
/*
* Maze
* Generates the corridor's walls and answers what is solid where.
*/
package game
```

**Naming**

| Kind | Style | Example |
|---|---|---|
| Types | `PascalCase` | `Player`, `MazeCell` |
| Procedures | `snake_case` | `update_player`, `get_cell` |
| Constants | `SCREAMING_SNAKE` with `::` | `PLAYER_SIZE`, `CELL_SIZE` |
| Struct fields | `snake_case` | `transition_timer`, `arrival_time` |

**Procedure shapes** — keep the established trio:

```odin
new_player  :: proc() -> Player             // constructor, returns by value
update_player :: proc(player: ^Player, ...)  // mutates through a pointer
draw_player :: proc(player: Player)          // takes by value, never mutates
```

Accessors that derive a value follow `get_<thing>_<property>`.

**Formatting**: tabs for indentation, `odinfmt` defaults.

**Comments**: explain *why*, not *what*. Flag known simplifications explicitly rather than leaving
them silent.

**Memory**: prefer fixed pre-allocated pools over per-frame allocation, especially in `fx/`. Where a
dynamic array is unavoidable, `defer delete(...)` at the same scope it was created.

---

## Design pillars

Check every proposed feature against these before implementing it. If a feature breaks one, raise it
with the author before writing code.

1. **Every move is a commitment.** The player gives a direction and travels until a wall stops them;
   the input is a decision with a visible outcome, never a steering correction. Nothing may turn
   movement into continuous nudging.
2. **Readable in two seconds.** Someone watching a video understands the goal without explanation.
   When beauty and readability conflict, readability wins.
3. **Every run is different, every run is fair.** Procedural but never unsolvable and never a
   surprise: every danger has a visible arrival phase before it is dangerous.
4. **The theme is not decoration.** Real and Dream must shape mechanics, visuals and feedback.
5. **The generator can never trap you, and it can never merely *just* let you through.** From
   wherever the player is there is a path onward, and it arrives in time — the world scrolls whether
   they are progressing or not, so a solvable maze that cannot be crossed fast enough is an
   unsolvable one wearing a disguise. Being stuck is always the consequence of a route they chose.
6. **Never colour alone.** Real and Dream are distinguishable by layout and by motion as well as by
   colour. This is an accessibility constraint, not a preference.
7. **A mistake costs ground, not the run.** You die when the ground you have left runs out.
