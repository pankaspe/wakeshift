# CLAUDE.md — Working notes for Wake Shift

Operational rules for developing this project.

- **What and why** → `docs/archive/design_doc.md` (**v2.1**), which is the last written
  statement of the design and is still binding on *what* to build.
- **What it looks like** → **`docs/inspiration/La_Linea.png`**. The art direction changed
  wholesale on 4 September 2026: out goes the Ori-like silhouette-and-light of
  `docs/archive/sketch/sketch_3`, in comes **La Linea** — a filled background and one continuous
  stroke that *is* the world. It is binding. One clause of it is not: the character no longer
  rises out of that stroke and returns to it, because on 6 September a playtest replaced the
  figure with a filled block. See "The character is a filled block".
- **How the world is built** → **`docs/inspiration/sketch.jpeg`**, the author's own, and binding
  the same way. Flat floor and flat ceiling with all the relief made of **bricks**: staircases,
  isolated towers, plateaus, canyons, facing constrictions, and one detached block that moves.
  C1 built the flat lanes and C2 the relief, both on 6 September (`TIMELINE.md`).
- `docs/` is deliberately **not tracked by git**: it is the author's working material and lives
  only on their disk, and everything under `docs/archive/` — the old design docs, the old roadmap,
  the superseded sketches — is history rather than instruction. Do not read it as binding and do
  not go there looking for the plan. `docs/inspiration/` is the exception: it is current.
- **What has been built, in order** → `TIMELINE.md` (Italian; the user's file). One line per
  piece of work, and **there is no roadmap**: the user decides the next step, one at a time.
- **How we work** → this file

A comment that cites `(roadmap RX.Y)` is a historical tag, not a live reference: that file is
`docs/archive/ROADMAP.md` now. Leave the tags where they are — they say when a decision was
taken — and do not add new ones.

---

## The project in one paragraph

Wake Shift is a one-button reflex arcade game in Odin + raylib. The character runs
automatically while the world scrolls past. `SPACE` flips gravity between the floor (**Real
world**) and the ceiling (**Dream world**) — one key, one gesture, two places to be. The world
is a **track**: two straight lanes a fixed corridor apart, with all the relief made of bricks
standing on them — staircases, towers, plateaus, canyons, facing constrictions. Behind the
player the **Corruption** advances from the left, and the distance between the two is the only
health bar there is. **A mistake costs ground, not the run**: a cube blocks rather than kills,
and while you are pinned the Corruption gains. Obstacles are authored as *events in time*, never
as pixel positions, so scroll speed can change without redrawing a single pattern. The visual identity is **La Linea**: a filled, vignetted field that *is* the
world you are in, one continuous glowing stroke drawn on it, and nothing else — the field
changes colour with the world, the stroke never does.

---

## Language rules — non-negotiable

- **All code is English.** Identifiers, procedures, constants, struct fields, file names.
- **All comments are English.** No exceptions, including quick inline notes.
- **All commit messages are English.**
- **Conversation with the user is Italian.** Explanations, proposals, questions, summaries.
- Markdown docs follow their existing language: `TIMELINE.md` and `docs/` are Italian (the user
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

Most sessions start cold. Read, in this order:

1. **`TIMELINE.md`** — what exists, one line each. It is history, not a plan.
2. **This file** — the architecture rules and the conventions, which are what actually bind.
3. The header comment of whatever file you are about to touch. Every one states its
   responsibility and the decisions behind it, and that is where the *why* lives.

**There is no roadmap and no phase list.** The user decides the next step and says so. If you
finish what was asked and think something else is needed, say what and why — do not start it.

**Where the project stands.** **Two** dangers are on screen and both read: the cube blocks and can
be landed on, the hole stops the line and takes you into it. The world is drawn as La Linea —
nothing filled but the field, obstacles welded into the floor's own polyline, a pen writing the
world on the right and the Corruption fraying it on the left. The character is a **filled block**
in its lane's colour — the third and simplest of three designs, after a stick figure and a robed
one. The earlier note that the final character would be a lemur is superseded by that.

What the obstacle set became in September 2026, in code terms rather than as history — the
timeline has the story. `CUBE_UNIT` is **27**, deliberately narrower than the body (45 px then,
38 now), so a
single brick is a bump and a *shape* is what threatens. A cube's shape is a run of column heights,
and one function (`get_cube_column`) is what the block, the support and the drawing all read.
Since C2 the pattern does not write those heights: it declares a **`Skyline`** — a form and the
bounds around it — and the run's generator draws the columns (`game/skyline.odin`). `floating` is
a flag rather than a form, and a floating cube **orbits** — bob and drift on one clock, a quarter
turn apart. The hole's widths and the mirrored pair's bounds are absolute pixels and deliberately
not multiples of the unit.

**The next piece is decided and written down**: `TIMELINE.md` ends with the remaining tasks and
the model each is tagged for. Read them there rather than re-deriving them.

**C1, C2 and C3 all landed on 6 September**, and between them they are the world of
`docs/inspiration/sketch.jpeg` and the shape of a run through it.

- **C1** made the floor and the ceiling straight and moved every piece of relief into columns.
- **C2** filled it: a pattern declares a *form and its bounds* and the generator draws the
  skyline, the pool is the sketch's vocabulary — bumps, towers, plateaus, staircases, canyons,
  ridges, facing constrictions — and the dead air inside patterns is gone.
- **C3** replaced the three tiers with one continuous function of **distance**, on the same
  measure the Corruption always used. Two knobs on deliberately different curves plus a per
  pattern unlock distance; speed stopped being a difficulty knob at all.

Measured with no player, in 5000 px bands: at least one lane is threatened **24.7%** of the time
over the first band and **68.7%** over the twelfth, rising monotonically. 200 runs that never
touch the key had a median death at 3.4 s against 35 s in v1.x, with none surviving the opening
where 161 of 200 used to.

The remaining pieces are **feedback and onboarding**, not mechanics: C4 makes the curve
perceptible with a particle burst every step of it, C5 is the intro that teaches `SPACE`.

Why the design was rewritten in September 2026, measured rather than guessed: 200 simulated runs
that never touched the key, **161 survived the whole first tier**, median death at 35 s; **86% of
the time** nothing on screen could kill in any position. It was structural, not tuning — the old
pattern contract *guaranteed* you entered every pattern from the safe band, so standing still was
almost always right. Check any new rule against "does doing nothing survive this".

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

**Two traps found the hard way while looking at a 45 px character.** A frame that contains the
world will hand you the world's own line where you expected the thing you are measuring — the
lane's stroke sits exactly on the player's box edge, so a contact check that leaves the terrain
in measures the terrain and calls it the character. And **a bloomed 45 px shape magnified
afterwards is not the shape**: it read as a self-crossing "Σ" until the same figure was drawn
large, clean and without bloom, at which point the contour was fine and the *proportions* were
the bug. Inspect a shape at the size it is drawn, not at the size it is displayed.

**When the thing to verify is pixels, read the pixels back.** `rl.LoadImageFromTexture` on the
render target turns "does the bloom look right" into arithmetic: draw the frame twice, once
with the effect and once without, and compare per-row brightness. That is how phase 4
established that the composite is not upside down and that the Real world's bloom was invisible
before it was retuned. Give a readback test an *asymmetric* subject — the first version used the
game's own frame, whose brightest band was the horizon, which sat exactly where a flip is
undetectable. And say what the number you print actually measures: RL.1's first banding check
reported the widest flat run down the field as 97 px, which turned out to be the vignette's
deliberately flat middle rather than a band at all.

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

1. **One thing at a time, and the user picks it.** There is no plan to read ahead in.
2. **Claude writes code and proposes ideas. The user playtests and gives feedback.**
3. **Claude verifies only that it compiles and launches.**
4. **Report honestly.** If a phase is partially done, say which part and why. If a test fails,
   show the output.
5. Keep `odin check src` green at every intermediate step, especially during file moves.
6. **Add one entry to `TIMELINE.md` when a piece of work lands**: a title and at most seventy
   words on what changed. Nothing else goes there — no rationale, no measurements, no plans.

   What was learned is **moved somewhere it will be read again**, and that is never the timeline:
   a library trap into the comment of the file that hits it, an architecture rule into this file,
   a measurement into the comment of the constant it justifies. The commit message carries the
   argument; the timeline carries the fact.
7. **Spend the user's turns, not their patience.** Batch independent edits into one call, do not
   re-read what you already know, and do not re-run a check nothing has invalidated. When the
   question is how something *looks*, ask the user — they play it, and a rendered readback costs
   a round trip to answer it worse.

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

audio     ← core, game    (phase R7, not created yet)
```

`render` gained its `fx` import in RL.6, when the Corruption became dust rather than a filter.
The graph stays acyclic because `fx` still imports only `core` — and it must stay that way: what
lives in `fx` is *what a particle is*, what lives in `render` is *what fraying looks like*.

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

### The track is two constants, and the relief is columns

`core/track.odin` owns the shape of the world, because the player and the obstacles stand on it.
Since C1 it is **two constants**: `TRACK_SPINE` and `TRACK_SPAN`, from which `TRACK_FLOOR_Y` (555)
and `TRACK_CEILING_Y` (165) are derived so the two lanes cannot disagree with each other.

It was keyframed in world time until then, and patterns authored it: the corridor sagged, lifted,
pinched and opened, and `Pattern.track`, `report_track_faults`, `track_sample`, `track_clamp`,
`track_prune`, `track_support_y` and the whole `[TRACK_CAPACITY]TrackPoint` machine are all gone
with it. That was not a simplification of the world but a change of **material**: the world is
built out of bricks now, so there is one vocabulary for every piece of relief instead of two that
could disagree about what a moment was for. A pinch is two facing columns
(`pattern_narrows`), a plateau is a run of equal ones, a canyon is a zero between two towers.

What survived, and why each one had to:

- **`Ground`, `ground_time_at_x` and `ground_x_at_time`** — the map between scrolled pixels and
  world time, in both directions. It is what makes an obstacle an **event in time** rather than a
  position, so scroll speed can change without redrawing a single pattern. C1 made it
  load-bearing rather than merely surviving: `get_obstacle_position` now goes through
  `ground_x_at_time` instead of holding its own copy of the formula, so there is exactly one
  place the conversion lives. Verified as exact inverses to 1e-6 over 400 samples.
- **A body rests on the highest ground under its whole width.** The track half of it is trivial
  now, but the rule moved wholesale to the columns: a body straddling a staircase rests on the
  higher step (`get_support_y`). It is 38 px and a column is 27, so it always straddles two.
- **A `World` is a plain value**, and it stayed one when the `Track` field left it — so
  `interpolated_world` still copies the world forward by a fraction of a step. The habit is the
  point: anything the presentation copies forward wants to be a value.
- **The gesture never changes with the world.** The flip was a constant 0.167 s across every span
  the corridor could reach; with the span fixed it is now also a constant 390 px. The rule that
  produced the measurement outlives the measurement — and F4 leant its whole weight on it, because
  a flip staying constant in *real* time while the world's clock speeds up is the only thing the
  pace actually costs the player.
- **A *world* element nailed to the screen reads as two pictures.** That is why the old sky rode
  the spine, and it will come up again for anything the world contains. The vignette that
  replaced the sky is not a world element but a property of the lens, so it stays screen-fixed on
  purpose (`render/background.odin`).

Two things C1 changed that a later phase will meet:

- **`CUBE_MAX_HEIGHT` went from 7 to 12.** It is derived from the corridor — a floor column tall
  enough to reach a body on the ceiling would slide through it without blocking it — and it used
  to be derived from `TRACK_SPAN_MIN` because the corridor could pinch to 250. Against a fixed
  390 the arithmetic is `(390 - 45) / 27 = 12.7`. Twelve leaves 21 px of daylight and thirteen
  overlaps by 6, so it is tight rather than comfortable, exactly as seven was. It is what makes
  the sketch's towers legal.
- **A flat lane costs no vertices.** `render/terrain.odin` used to spend one point per track
  keyframe crossing the screen; it now spends points only on the columns standing on the lane.
  Measured over 120 s of the current pool, the worst lane polyline is **16** points against
  `STROKE_MAX_POINTS` of 256.

**The skyline validator is now the only place the world's shape is held to its limits**
(`report_skyline_faults`). It was one of two, the other being the track's rate limits and its
endpoint rule; those are gone along with the thing they constrained, and C2 replaced the endpoint
rule's job with the containment rule below.

### The player's screen x is game state

The most invasive change in v2.0, done in R2.1. The old `PLAYER_X` was doing two jobs and has
been split into two constants that happen to hold the same number:

- **`core.WORLD_ANCHOR_X`** — the screen x that world time lands on. Constant, and the *only*
  thing any space↔time conversion may read: `ground_x_at_time` and `ground_time_at_x` are both
  anchored to it, and every obstacle position goes through the first of them.
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

### A cube is ground you can be above

Since 5 September `game/world.odin` answers "what does a body at this x rest on" with the track
*and* any cube column it is already above (`get_support_y`). One comparison is the whole rule:

> **You rest on a surface your feet were already at or above.**

Coming down onto a cube they are, so a flip onto an occupied lane lands on top of the box.
Walking into one side-on they are not, so it stays a wall and blocks. It needs no physics and no
new state: the body's last position is already state and already deterministic, so a replay
reproduces it.

- **The contact edge belongs to the lane being asked about**, not to the lane the character is
  on. Mid-flip the two endpoints are resolved separately, and testing the ceiling with the
  floor's foot makes a journey start by teleporting.
- **A settled body falls toward a support that dropped away**, at `PLAYER_FALL_SPEED`; rising
  ground is not eased, because a floor coming up under you has already arrived, and a journey is
  never eased because it owns its own path. Without it, riding a cube off its leading edge is a
  whole column's height of teleport in one frame — the game has no gravity to spread it over.
- **It is answered per column**, not per obstacle, so a body straddling a
  staircase rests on the highest step under its width exactly as it rests on the highest ground.
  A column of height zero offers nothing and the track underneath is the answer there.
- What it replaced: a flip onto an occupied lane used to leave the character standing **inside**
  the box, 100% of every cube, for up to 2.5 seconds. Three correct rules met to produce it —
  nothing on a lane may block a crossing character, so a cube scrolls over their x during the
  0.16 s flip; the landing surface came from the track alone; and the pushback is capped at one
  step's scroll, which is exactly what the cube is doing, so the penetration never closed.
  Measured after: 0 px of interpenetration coming down onto a box, and side contact rather than
  enclosure on the tall ones.

### The two dangers, two verbs

| | says | kills? | built? |
|---|---|---|---|
| **Cube** | *do not be here, or you pay* | no — it **blocks** | ✅ |
| **Gap** | *do not be here* | yes | ✅ |

There were three until September 2026, when a Sentinel that fired a curtain across the corridor
was deleted along with the whole idea of a third verb: two elements that combine are a game, three
that each say their own thing are a list. One lesson outlives it — **measure an obstacle of that
class before building it.** Two shapes for it were arithmetically impossible and only arithmetic
found that out, because a flip crosses the corridor at ~2100 px/s and the body still takes
0.167 s to clear any given x.

**The cube's shape is data**: a run of columns, each `CUBE_UNIT` wide, each a whole number of
units tall. `{1,2,3}` is a staircase, `{3,0,0,3}` two towers with a canyon between them, `{1}` the
primitive. One function — `get_cube_column` — is what the block, the support and the drawing all
read, which is what keeps the mark and the hitbox the same thing. Before it, the pyramid was drawn
as steps and collided as its bounding box: it showed a low step it would not let you use.

**Since C2 the pattern declares the shape rather than writing it** (`game/skyline.odin`). A
`Skyline` is a form — `Wall`, `Rise`, `Fall`, `Canyon` — plus an inclusive range for the column
count and one for the height, and `draw_skyline` resolves it into columns from the run's own
generator at the moment the obstacle is created. Three things make that safe, and all three are
load-bearing:

- **The form never survives generation.** That is the whole difference between this enum and the
  `CubeForm` T3 deleted: the old one was re-read by three files that disagreed, this one is gone
  by the time anything can read it, and an obstacle still holds nothing but digits.
- **Everything a validator needs is a bound, never an outcome**, which is what lets the pool be
  checked once at startup against a seed that does not exist yet. `get_max_width` had always done
  this for the hole's rolled width; C2 gave the cube the same property and added `get_min_width`,
  because a facing pair has to be legal on *every* draw and not on the lucky ones.
- **The columns live inline in the `Obstacle`**, a fixed `[CUBE_MAX_COLUMNS]u8` and a count, not a
  slice. An authored profile could be a slice into static pattern data; a drawn one cannot, and an
  `Obstacle` is copied by value into the renderer's steps and into the interpolated world.
  Verified: two runs of one seed produce byte-identical obstacles.

Rules the implementation established, all found by replaying the simulation:

- **A cube holds the character; it never drags them.** The pin clamps forward progress, and the
  clamp is floored at one step's worth of scroll (`advance_ground`). Without the floor, a
  character who lands on a lane that is already occupied is *behind* that face by a whole
  flip's worth of ground and gets yanked backwards in a single step — which is both a visible
  teleport and, because it erases exactly what the flip won, what makes a mirrored pair
  unescapable. Two things fall out of the floor: `velocity_x` can never drop below
  `-scroll_speed`, so the depth arithmetic in `score.odin` never has to clamp; and the pair
  terminates, because each flip advances the character by `flip_clearance` and enough of them
  work past the box.
- **The width of a lone cube costs nothing.** Whatever it is, the answer is one flip to the free
  lane. Width becomes a price only where there is no free lane — which is the mirrored pair and
  nowhere else. A one-column cube and a two-column one are therefore in the set for the eye, not
  the hand, and that is a legitimate job.
- **"The width is the price" is the intent and not the behaviour**, and T2 measured it. Replayed
  at 27, 54 and 108 px, every shape costs the same ground: 40.5 px to a player who answers a lone
  cube in 0.15 s, 4.5 px for a mirrored pair answered at once, 2205 px to one who never presses.
  What is charged is **time spent pinned**, and both ways out of a pin — a flip to the free lane,
  or a landing on top — are width-independent. Pricing that is what R5 is for; until then, do not
  quote a width as a cost.
- **A cube blocks, and that is the design's centre of gravity.** Because it is not lethal, the
  game is finally allowed to threaten **both lanes at once** — a mirrored cube pair is legal,
  and it is the first thing in the project's history that turns "where do I go" into "which
  price do I pay". The v1.x design could never do it: two lethal lanes is an unsolvable pattern.
- **A body is never on one column.** It is 38 px and a column is 27, so it always straddles two
  and rests on the higher — the same "highest ground under its whole width" rule the track obeys.
  Landing on a staircase therefore puts the character on the *upper* of the two steps they cover,
  not the one their leading edge touched. Know this before authoring a skyline.
- **A column of height zero is a place to be, not a wall.** The skyline drops to the lane's own
  surface and comes back, and the body stands on the track there. It is not a hole — the ground
  is still there.
- **`is_lethal_to_both_lanes` is gone, and nothing is lethal to both lanes**, which is the
  simplification that let the fairness rule go back to one sentence. The Sentinel was the only
  thing that ever was.
- **A hole takes you when there is nothing under your *centre*.** Not when your leading edge
  crosses the lip: measured on 5 September, the box test ended the run 18 px — 0.07 s — before
  the body's centre reached the hole, and 8 px before the drawn figure touched it at all, so the
  game was over while the character was plainly still standing on solid ground. The worst kind of
  unfair, because it is not hard, only early. The centre and not the whole body, because a hole
  you are half over is one you have fallen into — and the centre rather than the drawn figure's
  own edge, because what the renderer happens to draw may never decide what the simulation does.
- **A danger that is lethal before it is drawn is the one thing pillar 3 forbids outright.** The
  Sentinel's ray managed 0.17 s of it — drawn only while sweeping, lethal from the instant its
  window touched the character, which is earlier. The fix was to draw it for as long as it
  existed, and the rule outlives the obstacle: check any new danger for a gap between "can kill"
  and "is on screen".
- **Invulnerability is decided per type, not once at the top of the collision check.** It is a
  switch rather than an early return, and it stays one even though only the hole is lethal today:
  the grace period exists to forgive the flip started at the last possible instant against a
  hole, and a danger that punishes the flip itself would need the opposite. Deciding it per type
  is what makes adding such a danger a case rather than a rewrite.
- **A hole breaks both lanes the same way, mirrored.** The stroke **turns out of the corridor**
  at the lip — down off the floor, up off the ceiling — which puts two more right angles in it.
  Nothing is added to the break, ever: **filling a hole with a mark makes it a thing rather than
  an absence**, and that rule has now caught two attempts. Spikes across the break were tried on
  5 September and taken out the same day. The ceiling's old treatment — the stroke tapering to
  nothing past the lip and a halo lighting the opening, on the reading that overhead an absence
  is a way through rather than a fall — lasted until the obstacle set came down to two, and went
  out for the same reason: the halo was mistaken for an emitter standing in the corridor by the
  person who designed it. With only two obstacles left, each has to be one mark meaning one
  thing wherever it appears. A glow is a mark.
- **A hole kills by being an absence, so the character has to be seen going into it.** Until 5
  September a run ended with the figure standing on nothing, which was the only moment in the
  game where the picture said something the rules did not. They now drop through and fade out —
  away from the corridor, so down off the floor and up through the ceiling, because an absence
  overhead is a way out rather than a fall. It is drawn and never simulated: the run is already
  over when it starts, it runs on the frame clock in `main` beside the other presentation state,
  and no step can see it. The Corruption's ending gets none of it — there is nothing to fall
  through.
- **The track owns the holes, and since RL.2 it owns the cubes too.** `render/terrain.odin` is
  the only code that knows where its own surface is. It builds each lane as **one polyline across
  the whole screen** — cubes welded in as steps, read off the obstacle's own rectangle so the
  mark and the hitbox are the same thing — and cuts the holes out of it afterwards, interpolating
  a vertex exactly onto each edge. Building it already in pieces would make a cube straddling a
  hole's edge disagree with the piece that contains it; building it whole makes that a clip.
  Drawing a gap as an object is what made it read as a box standing on the floor for the whole of
  the prototype, and drawing a cube as an object is what made it read as something *put there*
  rather than as something the world did.

### The economy: the front is state, and fragments are what is spent on it

Since F2 (`game/corruption.odin`) the Corruption **always gains** — `CORRUPTION_GAIN` pixels of
front per pixel of world scrolled, on `difficulty.t` — and a fragment buys `CORRUPTION_REFUND`
of it back. Three things about it are load-bearing:

- **`front_x` is no longer a pure function of distance**, and that was given up knowingly: a
  refund cannot be written as one. It is still fully deterministic, so a recorded run validates;
  what is gone is the ability to *ask* where the front is at a given depth without replaying to
  it, and nothing ever asked. The same trade will come up for anything else the player is allowed
  to spend against.
- **The front no longer stops short of the character.** "A player making no mistakes is never in
  danger from the Corruption" was true, was the reason the front was decoration for anyone
  competent, and is now false on purpose.
- **The bank is the screen.** `front_x` clamps at the left edge and any refund still owed there is
  discarded, so a player who out-collects the front is simply safe rather than storing room. A
  hidden surplus behind the left edge would be a meter nobody can see, which is the one thing the
  score and the HUD both refuse. Verified: ten fragments on a full runway leave the front at 8 px
  and nothing owed.
- **The gain is a straight line while the other two knobs are curves**, and that is deliberate:
  the air between patterns is spent early and the draw's lean bites late (`game/difficulty.odin`),
  so a third knob at a constant rate means one of the three is always moving under the player.
  C3's lesson was that one curve saturates; three that saturate together are the same mistake.
- **A refund is a retreat, not a jump.** 60 px in one frame reads as a glitch; 0.23 s of motion
  reads as an event, and a *line* of fragments becomes one continuous slide, which is what the
  run-of-five pattern exists for.

Tuned by replaying 60 runs with a one-move-lookahead bot: fragments unpaid it dies at 8440 px,
paid at 12370, so the economy is worth **+46% of a run**. The front's *average* pressure lands
within 3 px of where the old fixed slide held it (80 against 83) and the **peak** is what moved,
176 to 251 — F2 changes what the front is without quietly changing how hard the game is.

**The gain survived F3 replacing the entire supply it was tuned against**, and that is worth
knowing before touching it: the anchor to re-check is the collecting bot's *mean front* (84 px,
against 83 for the pre-F2 fixed slide), not the run length, which moved from 12370 px to 16150
once the pool started paying properly. Re-measure whenever the supply moves, and re-measure that
number.

### Where a fragment goes, and the one check that keeps it honest

The authoring rule is one sentence, and it lives in `game/pattern.odin` above the pool:

> **A fragment sits on the Dream lane, half a body off the ceiling, just after the pattern's last
> Dream closure — and only in a pattern whose last closure is on the Dream lane.**

It exists because of a measurement, not a taste. A reward on the road the player was taking anyway
is free: before F3 a bot that did not want fragments still collected 16.6 a run, because the
prototype patterns put a cube opposite every diamond. Just after the Dream lane reopens is the one
instant in a pattern where the player is *provably* on the floor, so the trip up is a round trip
nothing else asked for. Measured after: 0.7 a run for that bot, against 12.8 for one that wants
them.

- **A fragment can never cost danger**, only position and tempo — its lane has to be open for the
  diamond to be reachable at all. What is charged is a flip and arriving at the next pattern from
  the ceiling, and the curve raises that price on its own as it closes the air between patterns.
- **The tails those placements need are not the dead air C2 deleted.** C2 cut lead-in and tail that
  contained nothing. These hold the reward — but they do cost density: 4 to 10 points of
  "threatened" per band, peak 71.1% down to 61.0%.
- **`report_fragment_burial` is the check F1 could not write.** A diamond inside a cube or over a
  hole, against the skyline's **declared bounds** and never its drawn columns — widest draw,
  tallest draw, and for a floating cube the reach of its whole orbit. It checks the far lane too,
  because `CUBE_MAX_HEIGHT` crosses 324 px of a 390 px corridor. It runs on the seam as well as
  within a pattern, because a fragment has no containment rule of its own and the thing most
  likely to bury one is the *next* pattern's first cube.
- **It is written on the assumption that a diamond is taken by a body standing on its lane**, which
  is what `FRAGMENT_ON_LANE` being the only authored offset means. A placement further into the
  corridor needs that check revisited, not merely re-run.
- **No diamond sits on top of a floating platform**, and that was measured rather than decided: the
  lift is `LIFT/2 * (1 - cos)`, so the top of the box is at any authored height for one instant and
  nowhere near it across the 200 ms collection window.

### The fairness rule — the only one there is

> **At every instant at least one lane must be non-lethal.**

That is the entire pattern contract in v2.0, and it replaces a machine of band sets with
subset-containment chaining. It had a second sentence about the Sentinel's window until that
obstacle was deleted; only the hole is lethal now, so one sentence covers it. Everything else —
mirrored cubes, staircases, a skyline in the awkward place — is legal by construction, because
none of it kills.

The **skyline** is the other half of the contract, and it is validated the same way rather than by
a closed set of shapes: `report_skyline_faults` rejects a declaration that may draw too many
columns, one taller than `CUBE_MAX_HEIGHT`, an empty range, a canyon too narrow to have a middle,
and a lifted cube that may reach more than one column. The height bound is the one with a failure
behind it — a floor cube tall enough to reach a body on the ceiling would slide through it without
blocking it, since an obstacle only ever tests its own lane.

**A pattern contains its own windows**, and that is the composability rule C2 added
(`report_containment_faults`). Every event's window — the time it can touch a body at the anchor —
lies inside `[0, duration]`, measured at the slowest speed a run uses. Two things follow:

- **the seam cannot conflict at any gap**, whatever order the generator strings patterns in. It is
  the replacement for "every pattern opens and closes at the neutral corridor", which C1 deleted
  along with the corridor. The seam check still runs: a rule worth having is worth verifying.
- **a pattern's own boundaries are not its warning.** The warning is the *screen* — 920 px, 2.5 to
  3.4 seconds of looking at a thing, and the previous pattern is still on screen while the next
  one's obstacles arrive. So a lead-in inside a pattern buys nothing, and measuring that is what
  found the old pool's density problem: it was mostly lead-in and tail. Air between patterns is
  the tier's gap and nothing else, which leaves density with exactly one knob.

**Two cubes on one lane may not overlap in x** (`report_same_lane_overlap`), and this became a
real risk only when C2 made the shapes wide. `render/terrain.odin` welds every cube into the
lane's polyline and **drops** an overlapping one rather than tearing the line — so the collision
would keep a danger the picture does not show, which is the one thing pillar 3 forbids outright.
Checked at the slowest speed, where two events of a given spacing sit closest together in x.

Two things the old contract taught that are still worth knowing:

- **A contract that guarantees you start safe is a contract that rewards standing still.** That
  is literally what killed v1.x. Any future rule must be checked against "does doing nothing
  survive this".
- **Difficulty is not speed**, and since C3 the code says so. Obstacles are events in time, so
  reaction time *inside* a pattern does not move with scroll speed at all — replaying every
  pattern at 270, 330 and 400 px/s gave the same set of surviving answers. Speed changes how long
  you get to *look*, and pulling the other way, how briefly a wide obstacle blocks a lane.
  `INITIAL_SCROLL_SPEED` is still a constant from the first metre to the last, and Slancio
  (roadmap R6.3) is still the only thing that will ever move it; the curve is measured in
  **distance**, so buying speed will buy score and difficulty together for free. What F4 added is
  not a second speed but a **clock** — see below.

### The curve is one function of distance

`game/difficulty.odin`, rewritten by C3. `get_difficulty(scroll_offset)` is the whole of it: a
pure function of how far the run has come, so a replay reaches the same difficulty at the same
point with nothing stored. It replaced three tiers on a clock that each moved a speed, a gap and
a weight table.

- **Distance, because it is what makes buying speed honest.** Depth is the distance travelled
  (`score.odin`), so a faster run earns score and meets difficulty at the same rate, with no line
  of code that knows it does. On a clock the two come apart: speed would buy score for free and
  slowing down would farm an easy world. It also puts the curve on the measure the Corruption
  already used, which was the only part of the game that had it right.
- **Two knobs on deliberately different curves.** `gap` is the air after each pattern and is the
  only density knob there is, since C2 left patterns with no lead-in of their own; `bias` is how
  hard the draw leans, as `bias^demand`, so one number covers "prefers the quiet ones" (under 1)
  through "a burst is sixty-four times likelier than a bump" (4). The air is spent early
  (`quadratic_out`) and the lean bites late (`quadratic_in`), because **one curve saturates and
  a saturated curve is what a player calls "it stops getting harder"** — which is exactly the
  playtest report that produced C3.
- **A third knob is per pattern: `Pattern.min_depth`.** It replaced the tiers' `added_patterns`,
  which unlocked in three jumps; spread across the whole curve, a long run keeps meeting shapes
  it has not met before. Unlocking and being met stay separate — everything unlocked is still
  subject to the lean, which is the mistake the old tier list made.
- **`bias^demand` is a lean, never a threshold.** No pattern is ever excluded, so a deep run
  stays varied instead of collapsing onto the four hardest things in the pool.
- **The pool is validated once, as one pool.** Per-tier validation existed because a tier held a
  different set; with continuous unlocks every pair can meet eventually, so the whole pool is the
  thing to check — simpler and stricter than what it replaced.
- **Zero gap is legal**, and that is C2's containment rule paying off: a pattern holds its own
  windows, so no gap is too small to be fair and the top of the curve can run patterns back to
  back.

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
- **`STROKE_MAX_POINTS` is load-bearing, and it truncates in silence.** Since RL.2 a lane is one
  mark spanning the whole screen, so the longest polyline in the game is the world itself; a
  polyline over the cap would be a line that stops in mid air with nothing to say so. The cap is
  256. C1 made the lane much cheaper — a flat stretch costs nothing, and everything a lane spends
  goes on the columns standing on it, two vertices each plus two per cube — so the worst lane over
  120 s of the current pool is **16** points and a screen tiled with the widest legal cubes is
  about 128. **Re-measured after C2 filled the screen with skylines: 76 points** over 8 seeds x
  120 s of the real pool, with eight-column cubes appearing. Comfortable, and the reason it stayed
  comfortable is C1 — a flat lane spends nothing on itself. Re-measure again if the widest shape
  or the density moves. The same class of silent failure as the winding above: check a new kind of
  stroke by reading the pixels back, not by looking at it.

Since RL.3 it draws the character too, which since 6 September is four points and a closed flag
(`render/player.odin`). One lesson outlives the shapes it was learned on, because it will come up
again for any small compound outline: the stick figure's head was the outline of the **union** of
two overlapping circles rather than two circle outlines on top of each other, since the arcs
would cross inside a head five pixels wide — and which half of each circle to keep had to be
decided by **probing the midpoint**, never by deriving it, because the derivation turns on which
intersection the radical construction produced first and both answers are a closed loop, so
getting it backwards is silent.

It is written to know nothing about the game. That matters because of an open question: `ui` may
not import `render`, so the menus cannot reach the stroke as things stand. Either `ui` gains
that import (the graph stays acyclic) or `stroke.odin` and `glow.odin` move into a package of
primitives below both. Keep this file free of `game` imports so that stays a file move.

### The character is a filled block

A 38 px square, filled, in the colour of the lane it is standing on, with **no outline at all**
(`render/player.odin`). It was a robed figure under a pointed hood until 6 September, and a stick
figure with four limbs before that.

All three redesigns are the same argument taken one step further, and it is the one worth
keeping: **a 45 px shape drawn with a 4 px pen cannot hold detail.** Nine marks in forty-five
pixels read as a knot; one contour read as somebody but still spent its whole budget on being a
somebody. The block spends none, and the interest moves entirely into how it moves — which is
where the design has always said the sense of quality comes from.

Two decisions carry the read, and both are about telling it apart from everything else:

- **It is filled, and it is the second filled thing in the game.** The field is the other. The
  obstacles are *also* squares and they are hollow, welded into the lane's own line — so fill is
  the whole of "this one is you", which is a stronger discriminator than any silhouette at this
  size. This is the deliberate exception to the golden rule below, not an oversight in it.
- **It takes its lane's colour**, and it is the only mark in the game that changes colour between
  the worlds. That reverses a rule the robe kept on purpose: a mark that changes colour is the
  mild version of the mistake inverting body and rim was. A filled block is a different case —
  the fill *is* its identity, so a block wearing the colour of the line it stands on belongs to
  that world instead of visiting it. Mid-flip the colour travels with the body on the journey's
  own clock, not on `world_t`, so it arrives already belonging to where it lands.
- **There is no outline, and the colour match is arithmetic rather than intention.** The first
  version had a neon edge and a playtest took it off: an outline makes the block a lit object
  standing in front of the lane instead of a piece of it. Matching the lane then turned out to
  need the *core lift* as well as the hue — a neon line is not its own colour at the centre, and
  the terrain lifts its core by `TERRAIN_CORE_LIGHT`, so a block drawn from the raw `light` sat
  22 values of 255 under the line it was standing on. Using the terrain's own recipe closes it:
  measured in a real frame, the block and the lane agree to **4 channel values of 255 in the Real
  world and 7 in the Dream**, and 14 px outside the block the frame reads the field exactly.
- **The drawn square is the collision box, to the pixel.** Measured: 38 px lit against a 38 px
  box, where the outlined version measured 47. That is why the size change went into
  `PLAYER_SIZE` and not into a render-side factor — a body drawn smaller than the box that blocks
  it shows a cube stopping the character before touching them, which is the "mark and hitbox
  disagree" failure this project has already paid for twice.
- **It went from 45 px to 38 px by playtest**, and four things derived from `PLAYER_SIZE` were
  re-checked rather than assumed: `MIRROR_MIN_WIDTH` (the facing pair's legal band becomes
  [38, 54] and `SHAPE_FACING` is 54), `CUBE_MAX_HEIGHT` (28 px of daylight now instead of 21),
  the fairness windows (shorter, so a legal pool stays legal — the validator agrees), and "a body
  is never on one column" (38 is still well over `CUBE_UNIT`'s 27). The cost is measurable: every
  threat window is `(width + body) / speed`, so the density curve fell about three points per
  band, peaking at 66.5% instead of 71.1%.

- **The glow is the frame's, not a primitive halo.** With the outline gone the block does not go
  through `render/stroke.odin` at all, so it takes no `glow_gain` and throws no halo of its own —
  it glows because a 38 px surface at 0.85 luma is far over every bloom threshold there is
  (`fx/bloom.odin`). That is the resolution CLAUDE.md already preferred: where a halo looks
  doubled, remove the primitive one rather than lowering the bloom. The flip's glow swell went
  with it.
- **There is no rotation, and that is not an omission.** The flip used to be a half turn with
  Penner's easeOutBack overshoot — the most tuned number in the project. A square's half turn is
  invisible, so all that would survive is the overshoot, which reads as a small unrequested
  tumble on the one gesture the whole game is made of. `whip_ease` went with it. The only
  rotation left is the death fall's, where a tumbling block is the point.
- **The squash and stretch survived untouched**, because the value was in the machinery and not
  in the silhouette: the stretch rides `sin(whip * PI)`, so it is nothing at both ends of the
  turn and everything in the middle, and the landing bounce is a decaying oscillation on
  `settle_timer`. Both scale about the surface being touched rather than about the centre —
  verified at 0.0000 px of drift across the whole bounce in both lanes, because a landing that
  scales about its centre looks like it happened above the ground.
- **`SETTLE_SQUASH_AMOUNT` came down from 0.28 to 0.20 when the robe became a block.** Cloth can
  deform by a third and still read as cloth; measured on the square, 0.28 drew a 45 px box as
  51 x 32 on landing, which is jelly rather than a landing. A block reads its own edges much more
  sharply, so the same motion needs less of it.
- **Pillar 6 still holds, and it had to be re-said for a block.** The two worlds are never told
  apart by colour alone: in the Real world the block compresses on a beat and stays planted, in
  the Dream it lifts off the ceiling and settles back on a long slow period, crossfaded on
  `world_t`. A beat that lifts the block off the *floor* is wrong — on the floor the contact is
  what reads, so the Real world's motion has to be a squash and the Dream's a lift.
- **`PLAYER_STRIDE_LENGTH` is 120 because the robe's 58 was measured and was wrong here.** That
  was a two-step walk cycle, 29 px a step, 0.107 s at the opening speed — nine footfalls a
  second. Under a robe that is a small character walking quickly; on a block it is a 9 Hz
  vibration. One beat per 120 px is 2.3 a second, which is a pulse you can count.
- **A run opens with the landing bounce already playing**, because `settle_timer` starts at zero.
  It is a consequence of the zero value rather than a line of code, and it is kept deliberately:
  the alternative is a block that is simply there on frame one.
- **The fill and the edge are the same square by construction.** The fill goes through raylib's
  `DrawRectanglePro` rather than through two triangles of our own, because a triangle's winding
  is not free — raylib culls back faces, and getting it backwards is a shape that silently does
  not appear. `DrawRectanglePro` builds its corners with exactly the arithmetic `pose_corners`
  does, so the degrees are the only conversion. Verified by reading the frame back: the block's
  interior is lit at 0.84 against a field at 0.30, in both lanes.

What the redesign deleted, and what it cost: the profile anchors, the Cardinal spline and its
0.30 tension, the hat's 0.07 s inertia, the eye, the mirror, the rotation, the run cycle's hem
step and the Dream's undulation. Roughly five hundred lines. The two lessons worth carrying out
of it are the pen-versus-detail one at the top, and this: **the inertia was measured, not
integrated** — everything that moved the head was a pure function of the world's clock, so "where
was it a moment ago" was one more evaluation rather than state kept in the renderer. Any future
follow-through wants building that way.

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
  between worlds, the field's breathing. It must never reach the simulation, which advances
  only in whole `core.FIXED_TIMESTEP` steps out of the accumulator.
- **Presentation may also hold state, and `background_t` is the first of it.** The background is
  one field whose colour *is* the world you are in, and it **chases** `world_t` on a 0.45 s time
  constant rather than following it (`render.chase_background_t`), because a flip is 0.16 s and
  a burst of three would strobe a full-screen colour. It lives in `main` next to `display_time`,
  is advanced from the frame clock, and is not run state — it needs no reset, it simply arrives
  a second after the player does. The rule that keeps this safe is the one above: a presentation
  value may be *derived from* the simulation and may never be *read by* it. Measured: one flip
  moves it 31%, six back to back leave it inside [0.21, 0.53], and 30/60/240 fps agree to five
  decimals.
- **Post-processing runs on the finished frame, between the canvas closing and the blit.**
  `fx.apply_bloom` reads the render target and composites back into it in place, so `platform`
  never learns that bloom exists and `fx` never learns that a game does. The order in `main` is:
  `end_game_canvas` → `apply_bloom` → `present_display`.
- **Render textures are stored bottom-up, and the flip happens exactly once**, in
  `present_display`. Every intermediate pass in `fx/` draws with a positive source rect, which
  carries that convention through the chain unchanged. A second flip anywhere in the middle
  silently mirrors the light away from whatever emitted it.
- Drawing rate is a setting; the simulation rate is not.

### Two fronts, both of them a clip

The world exists **between two x values and nowhere else**: written by the pen on the right
(RL.5, `render/draw_front.odin`), eaten by the Corruption on the left (RL.6,
`render/corruption.odin`). In `draw_terrain_side` that is two lines of arithmetic, and it is the
whole of both ideas — which is what RL.2 bought by putting the obstacles inside the terrain's own
polyline. Neither front needs a per-object animation.

- **A shape cut at one end is open there and closed at the end it finished; cut at both, it is
  not a loop at all but two marks.** `draw_cut_shape` in `render/obstacle.odin` owns that, and it
  is the part that is easy to get backwards in silence — a shape built from its left edge
  rightward would be capped at the pen and left open at the end it had already finished, which is
  exactly backwards.
- **The Corruption's own lit edge is drawn with primitives and must stay drawn.** It was the
  shader-independent fallback when there was a shader; with the shader off it is the only thing
  marking the front, and a lethal front nobody can see is the one thing in this game that would
  kill without showing the blow coming (pillar 3).
- **The filter is off, not deleted.** `CORRUPTION_FILTER_ENABLED` in `main.odin` is the one line
  that brings `fx/corruption.odin` back. It went to black because the world behind the front was
  still *drawn*; with the line clipped there is nothing left there to drain but the field, and a
  field with no drawing on it is what "the world is not here" looks like on paper. Going to black
  came out of a playtest, so it gets undone by another one — RL.9 decides.

### Particles are presentation, and they have their own everything

`fx/particles.odin`, brought forward from R7 by RL.6. A fixed pool of 512, no allocation ever, at
any frame rate, for any number of emitters; a dead particle's slot is filled by swapping the last
live one into it, so nothing may depend on the order they are in. An emission that would overflow
is dropped rather than growing the pool.

- **Its randomness is its own generator**, seeded once — not the global `rand`, and deliberately
  not the run's, which has to stay reproducible from a seed for replay and score validation to
  mean anything. Dust that differs between two replays of one run is correct; a run that differs
  because of dust would be a bug.
- **The integration is exact, not stepped.** Drag is an exponential, so both the velocity and the
  distance it covers are closed forms and a particle lands in the same place at 30 fps as at 240.
  Measured: 0.00002 px apart over half a second. That is not vanity — the pool is advanced from
  the frame clock, and a per-frame multiply would make the dust thicker on a fast machine.
- **A stream keeps a fractional debt.** A rate under one particle per frame still emits; an
  `int(rate * dt)` would round it away every frame forever.
- **Each particle is one additive circle with no halo of its own.** The frame's bloom is what
  makes them glow — the same resolution as everywhere else a primitive halo and a real one would
  do the same job — and it keeps a full pool at 512 draw calls rather than 2 500.
- **The dust is the lane's colour, not the front's.** It is what the line *was*, coming apart;
  the front's edge is neutral because the boundary belongs to neither world. Two different
  statements, and they are meant to look different.
- **It stops when the game is paused.** Emission and update run only in `.Playing`, not for every
  state that *shows* a run: a paused frame is a still, and dust drifting across one would be the
  only thing on screen that had not stopped.

### The world is written, and that is a clip

`render/draw_front.odin`. The world is not already there and scrolling past: it is drawn at a
fixed x near the right edge and scrolls toward the player from under the pen (Design Doc, section
10, decision 5). Four rules, and the first is the reason RL.5 shared a phase with RL.2:

- **It is a clip, never an animation.** Once every obstacle lives inside the floor's own polyline
  (RL.2), "the line writes the world" is one x beyond which nothing is drawn: terrain spans are
  cut at it exactly the way they are cut at a hole, a shape straddling it truncates itself, and
  nothing anywhere needs a per-object reveal or a state remembering how far along it is. Anything
  new that draws itself must truncate the same way rather than fading in.
- **The front is not a difficulty knob and may never become one.** Every pixel it moves left is
  warning time taken from the player, and pillar 3 promises every danger a visible arrival phase.
  `DRAW_FRONT_INSET` is a constant, 48 px, 0.18 s at the opening speed, and it is spent on making
  the nib visible rather than on tension. Nothing may make it a function of tier, depth or score.
- **There is no wall on the right, and copying the Corruption's mark would be the worst possible
  mirroring.** A lit vertical bar at the right edge reads as something approaching, and this is
  the one boundary in the game that threatens nothing. The two fronts are mirrored in what they
  *mean*, deliberately not in how they are drawn: the draw front is marked by absence — the lines
  stop — plus a nib on each of them. When the pen is over a hole there is no nib, because what is
  being drawn is an absence.
- **A shape that can be half-written has to be built from the pen outward.** A shape whose
  outline runs from its left edge rightward leaves both loose ends on the left when it is clipped:
  capped at the pen, open at the end it had already finished. The path has to start at the pen,
  run away from it and come back, so the loose ends are where the ink stops. This cost a silent
  bug once and the only survivor of that class is the floating cube — check any new self-drawn
  shape the same way.

**Nothing in the background may cross the corridor, and that was tested.** A receding grid —
spokes from a vanishing point, rings expanding along them — was built on 5 September at the
faintest alpha on screen, moving on its own axis, and measured at 17 levels of difference between
two moments. Playtest still called it distracting, and it came out the same day. That is the
answer pillar 2 gives every time the background and the play line disagree, and it is worth
knowing before the next background idea: the two bands outside `TRACK_SKY_MARGIN` are not a
limitation to work around, they are the whole licence.

### The glow is a third channel, and it is the one that survives depth

Decision 4 of the art direction: the line's glow grows toward the Dream, so that where you are
*going* is said by something other than colour (pillar 6). It lives in `render/palette.odin` as
`GlowGain` / `glow_gain` / `apply_glow_gain`, and **every stroke in the game goes through it** —
terrain, the floating cube, the character, the eye. One channel, not a habit each file has to
remember.

Four things the implementation established, all found by measuring before writing:

- **The bloom already said something about this, and it is not the same sentence.** Since phase 4
  the live lane's halo grew from 5 lit rows to 23 across the crossing — but `NEUTRAL_BLOOM` is
  deliberately the most dazzling setting there is, so the bloom's curve is a **bell** (5 → 26 →
  23) and a bell cannot state a direction. What RL.4 added is the monotone half (4 → 6 → 10 on
  its own), which is why both its constants are small. If the channel ever fails to read, the
  thing masking it is `NEUTRAL_BLOOM`, not the gain.
- **It rides `world_t` directly, never the lagged `background_t`.** The field chases with half a
  second of lag on purpose (RL.1); the glow must not, because it is meant to *lead* the colour —
  it moves the instant the player commits and the field arrives a second later.
- **It is the only one of the three channels that survives the depth convergence.** Palette and
  bloom both converge toward the neutral as a run deepens (`CONVERGENCE_MAX`, 0.72), so late in a
  run the two older channels are being flattened by design. A plain multiplier on `world_t` is
  not, and at `depth_t = 1` it still separates the two worlds by 8 lit rows against 26.
- **Two multipliers, not one.** "More glow" means two things and an LDR frame treats them very
  differently: brighter drives the halo toward white and saturates, wider keeps it soft and
  covers more air. The Dream is the soft one, so most of the growth is in the reach.

### The player sets the world's clock

F4, `game/world.odin`. The world runs at `WORLD_PACE_DREAM` seconds per real second while the
character is on the ceiling and `WORLD_PACE_REAL` on the floor — 1.35 against 1.0, which is 364
px/s of screen against 270 and 2.52 seconds of look-ahead against 3.41.

- **It is a clock, not a speed, and that is the whole implementation.** Raising `scroll_speed` is
  the obvious build and it is wrong: an obstacle's x is `anchor + (arrival - now) * speed`, so a
  higher speed multiplies the distance to everything not yet arrived. Measured, the naive version
  slides one obstacle 247 px across a single flip and the right edge of the screen 322 px — and it
  is not even faster in the sense that matters, because arrival *times* do not move, so only the
  spacing grows. Leaving `scroll_speed` alone and advancing `elapsed_time` by `pace` instead makes
  the largest single-step move of any obstacle 6.08 px, which is exactly one step at the ceiling's
  rate.
- **`scroll_speed` is now the base rate, not the rate anything moves at.** Everything that means
  "how much world went by this step" goes through `game.get_scroll_rate`. Code written before F4
  read `scroll_speed` for both, so check any use of it that predates this.
- **The pool needed no revalidation**, which is not what F4 was expected to need. Every window the
  fairness check computes is `(body + width) / scroll_speed` *world* seconds and `scroll_speed`
  does not move, so the geometry is pace-invariant by construction. That property is the reason to
  build it this way, not a lucky consequence of it.
- **The pace is a cost, not a purchase.** A run ends when the front reaches the character, the
  front gains per pixel, and depth *is* distance — so a run dies at the same distance and scores
  the same number at any pace. Going fast earns the same sooner, never more. What makes the ceiling
  worth visiting is the fragments F3 put there, and the pace is their price.
- **The difficulty lands entirely on the one clock that does not dilate**: the flip is
  `FLIP_DURATION` of *real* time, because "the gesture never changes with the world" is older than
  this phase, so at pace 1.35 it costs 0.216 world seconds instead of 0.160. Anything else added
  on the player's side has to decide which clock it is on, and the default is real.
- **The pace rides the journey's clock, never the drawn body's height.** `get_player_pace_t` is in
  `game/player.odin` for that reason: `render/palette.odin`'s `world_t` is derived from
  `position.y`, and a body standing on a twelve-unit tower is 324 px up a 390 px corridor while
  still plainly on the floor. Reading that would accelerate the world because the character climbed
  a staircase.

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

- **It ran after the bloom** (`fx/corruption.odin`), because a lit edge's halo is part of the
  picture and had to be eaten along with the edge that threw it. RL.6 switched that pass off:
  with the line clipped at the front there is no halo left behind it to eat. The rule is kept
  here because the file is kept, and reviving it means reviving the ordering too.
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

The art direction leant on the same split, and one half of that has since been replaced.
*Scenery is line, danger is mass* belonged to `sketch_3` and died with it — under La Linea
everything is line, so a rule about fill cannot separate anything. Its replacement is geometric:
**the world curves, the danger corners** (see the top of this file).

**That rule has one exception now, and it is the player.** The character became a filled square on
6 September, so there is a right angle on screen that does not mean "this costs you". It reads
anyway, and the reason is worth knowing before anything else is tempted to break it: the rule is
about the *strokes*, and the player is the one thing that is not a stroke. Fill separates it from
every other square in the corridor, which is the whole reason the block is filled at all — so the
half of the old split that died has come back for exactly one object. Nothing else may use it.

What survives untouched is
the Corruption's own reading, and it gets better rather than worse: a front that eats the line
away is the same mark the mechanic is, and RL.6 turns it from a filter on the frame into the
line fraying into particles.

### Easing curves come from the standard library, with one exception

`core:math/ease` (the whole Penner set). `core/ease.odin` was deleted in RL.7 once two of its
three curves turned out to be the library's to within 1e-7 and to have no callers at all.

- **`ease.ease` and the individual curves are pure and `contextless`**, so they may be used
  anywhere, simulation included.
- **The `flux` tween may not.** It allocates a map and a dynamic array and it runs on a wall
  clock, so it is presentation only — inside a simulation step it would break replay and score
  validation.
- **There is no exception any more.** There was one — `whip_ease`, Penner's easeOutBack, the
  curve the flip's half turn overshot on. It was kept out of the library deliberately, because
  `back_out` is AHEasing's and a different function: measured over the flip's half turn, ours
  overshot by 18 degrees peaking at t=0.57 and `back_out` by 68 peaking at t=0.47, an overshoot
  in the middle of the journey rather than an impulse at the end of it. It went with the
  rotation when the character became a block. The measurement is recorded here because the
  two names still look interchangeable and are not.

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
- **Two things are filled: the field, and the character.** Everything else is line. The field
  has been the only one since RL.3; the character joined it on 6 September and is the deliberate
  exception, because the obstacles are squares too and fill is what says which square is you
  (see "The character is a filled block"). `palette.silhouette` still has no consumer — the
  block takes its lane's `light`, not the silhouette colour — and is kept because deleting a
  palette field is harder than resurrecting one.
  The rule that survives for everything else: what tells the worlds apart is the colour *behind*
  the line, never the line. The character is the one mark allowed to break it, and only because
  a filled block's colour is its identity rather than its decoration.
- **The weight hierarchy is a rule, and it lives in the arithmetic.** `TERRAIN_STROKE_THICKNESS`
  is the rung everything else is expressed against: `render/player.odin`'s weight is a multiple
  of it and `TERRAIN_DORMANT_WEIGHT` a fraction, so tuning the world cannot silently invert the
  order. Do the same for anything new that joins the ladder. Live lane 2.80 px, dormant 1.96,
  parallax 1.18 / 0.95 / 0.78 at alphas 0.30 / 0.22 / 0.15.
- **The character is not on the ladder at all, and the design doc has not caught up.** Section 10
  asks for it to be the thickest stroke on screen. It is not a stroke: since 6 September it is a
  filled block with no outline, so it has no weight to place in the hierarchy. What makes it
  stand out is *fill* — it is the only filled thing in the corridor, everything else is line —
  and brightness: measured in a real frame, block interior 0.85 against a field at 0.30. If
  it stops standing out, raise those before raising the weight.
- **The parallax may never enter the corridor**, and since C1 that is arithmetic rather than a
  clamp: the corridor is fixed, so `core.TRACK_SKY` is exactly 165 px above the ceiling and below
  the floor. `core.TRACK_SKY_MARGIN` is 70, the narrower band the background is actually allowed —
  well clear of the corridor rather than up against it — and every parallax layer lives inside it,
  amplitude and all.
  It is drawn **under** the vignette, because the thinnest mark on screen must not be the one
  thing the lens cannot reach; and it does **not** take the glow gain, because the background is
  the one thing that must not compete harder exactly where everything else is already brightest.
- **An obstacle never thins with its lane.** The world may recede on the side the player is not
  on; a danger may not, because pillar 3 promises it a visible arrival phase and the arrival
  happens while that lane is still the dormant one. The cube welded into the terrain's own line
  is the exception, and it is one by construction rather than by choice: it *is* the ground, and
  it is read by its two right angles rather than by its weight.
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
7. **A mistake costs ground, not the run.** Only the gap kills outright. Everything else costs
   distance, and you die when the distance you have left runs out.

---

## Known issues carried forward

Tracked here so they are not rediscovered. Nothing here is scheduled — the user decides.

- **A block costs almost nothing, and pricing it is unfinished work.** Three findings that are
  really one. Landing on a cube is free: since 5 September a box the character came down onto is
  ground they stand on, so flipping into an occupied lane costs nothing where it used to cost the
  cube's whole width in dragged ground. A mirrored pair therefore collapses to a rhythm break —
  measured in T2 at **one pinned step, 4.5 px**, identical at 27, 54 and 108 px wide. And a lone
  cube costs 40.5 px to a player who answers in 0.15 s, also width-independent. What is charged
  everywhere is **time spent pinned**. The knobs are `PLAYER_RECOVERY_RATIO` and whatever rule
  eventually prices a landing; neither is a bug, and until one of them moves, do not quote a
  width as a cost.
- **A floating cube descending onto a body underneath it drags them backwards.** Found by replay
  in T4 and **not caused by it**: the cube's blocking face is *behind* a character who has run
  under it, so the pin clamps them to a position they have already passed and the one-step floor
  in `advance_ground` walks them back a step at a time. Measured over twenty authored phases, 67
  px at `CUBE_FLOAT_DRIFT = 0` and 66 px with the swing, so the horizontal drift very slightly
  *improves* it. Caught from the side — the case the design is written around — it is 0 px over
  214 pinned steps. The fix is a rule about what a descending surface does to a body below it,
  which the game has never needed before; the pool does not currently author a float that lands
  on the player, so nothing on screen hits it today.
- **A body landing exactly as a tall cube arrives keeps side contact it never sheds** — measured
  at 18 px back when the unit was 54, so re-measure before quoting it. It is the documented
  "move first, resolve second" cap doing its job: whatever overlap the landing frame starts with
  is kept, because the pushback is limited to one step's scroll and the face is moving at exactly
  that. It was invisible while a cube was a filled mass. Closing it
  needs the pushback to exceed the world's speed while penetrating, which would also make
  `velocity_x` drop below `-scroll_speed` and force `score.odin` to clamp.
- **The pool has not been played since F3, and F3 moved its density.** 31 patterns. Measured in
  5000 px bands with no player, at least one lane threatened runs 20.9 / 30.4 / 37.1 / 39.1 /
  41.7 / 44.7 / 47.7 / 52.7 / 59.7 / 55.9 / 56.8 / 61.0%, and lethal 5.4 / 3.9 / 6.0 / 5.8 / 9.4 /
  9.0 / 10.5 / 7.4 / 6.5 / 8.8 / 6.5 / 9.4%. Both are **4 to 10 points below the pre-F3 numbers**,
  which ran 24.7 … 71.1%: the tails that hold the fragments are time when nothing threatens.
  Taking `DIFFICULTY_GAP_OPEN` from 0.90 to 0.70 puts the opening band back at 24.2% but drops the
  collecting bot's median run from 16150 px to 9930 — a difficulty decision rather than a
  compensation, so it is the user's to make at a playtest.
  **The lethal share is the one that is not monotone**, and it is a consequence of the lean rather
  than an oversight: the deep pool holds more high-demand patterns without a hole in them than with
  one, so a very deep run is busier and slightly less deadly than its own middle. Raising
  `pattern_gap_pair` to demand 3 nearly halved the dip; closing it properly means authoring more
  late patterns that carry a hole.
  A greedy one-move-lookahead bot that collects has a median run of **15180 px in 47.6 seconds**
  since F4 put a clock in the player's hand, dying 58 times out of 60 to the Corruption and 2 times
  in a hole — the fragments pulling a locally right answer into a wrong one, which is F6 arriving
  early. The same bot with fragments out of its valuation dies at 8440 px. **The bot understates
  what the pace costs** and any conclusion from it should say so: it reacts in one step and never
  looks ahead, so the 0.9 seconds of warning the ceiling takes away is worth almost nothing to it
  and a great deal to a person. At the top of the curve, pinned there with the Corruption switched off, 40 of 40
  bots survive a full minute: the endgame kills by ground loss, not by being unanswerable.
- **The runway is 360 px and a pin spends it at full scroll speed.** Not new and not C2's doing,
  but C2 made it matter: at 40% density a player who does not answer is pushed off the left edge
  in about 1.3 seconds of continuous pinning, which is why 177 of 200 idle runs end at the
  Corruption rather than in a hole. `PLAYER_RECOVERY_RATIO` is the knob if a playtest says the
  bleed is too fast; `CORRUPTION_MIN_RUNWAY` was the other one and F2 deleted it, because the
  front does not stop short of the player any more.
- Menus, HUD and the options screen take their colours from the palette but still use raylib's
  default bitmap font. Everything drawn from primitives is crisp at native resolution and only
  the text is not (phase R7).
- **A primitive halo under something that used to be opaque is a trap.** The character's aura —
  a 60 px disc of the world's light on the hip — worked only for as long as a filled body covered
  its middle; RL.3 removed the body and the first readback found the inside of the figure lit to
  255 against an outline of 255, which is no drawing at all. Deleted, and the flip's flash moved
  onto the character's own stroke. Expect the same wherever a fill is replaced by a line.
- There are two glows: the real frame-wide bloom in `fx/bloom.odin`, and the stacked additive
  primitives in `render/glow.odin` that predate it — `render/stroke.odin` builds its halo out of
  the second, sharing `glow_layer_alpha` so a stroke and a plain halo agree. The second was a
  stand-in for the first and now feeds it: a primitive halo is bright, so the bright pass picks
  it up and blooms it again. Particles will go through the same pass. Where a halo looks doubled,
  remove the primitive one rather than lowering the bloom.
- Bloom is LDR: the frame is an RGBA8 texture, so "bright" means "near white", and the thresholds
  in `fx/bloom.odin` are tuned against **what reaches the frame**, not against the palette. A rim
  drawn at 0.7 alpha over a dark background lands near 0.66, not at the 0.91 its colour names.
  The same trap in reverse governs the palette, and since RL.1 it is not a precaution but a hard
  ceiling: **no filled surface may exceed 0.298**, the lowest bloom threshold there is minus half
  a level. It used to be phrased as "the lowest threshold it can ever meet", which was already
  subtle — bloom settings interpolate on `world_t`, so a player halfway through a flip is lit by
  the neutral threshold (0.30) while the floor is still drawn in the Real palette, which is how
  `real.near` at 0.369 came to bloom at 20% on every crossing while sitting comfortably under
  Real's own 0.50. Now that the background lags the player by half a second, *any* world's field
  can be on screen under *any* world's threshold, so all three `near` values sit on 76/255. The
  dark direction is unconstrained, and the vignette spends it.
- The dither (`fx/dither.odin`) masks banding, it does not remove it. Real dithering perturbs a
  value before quantisation and no pass that reads the finished frame can do that — the step
  between two bands is still there, buried under noise of the same amplitude. If it is not
  enough on screen, the real fix is drawing the field in a shader that dithers before it writes.
- Recorded run manifests are saved but never played back — there is no replay or ghost in the
  game yet, only the data needed for one.
