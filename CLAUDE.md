# CLAUDE.md — Working notes for Wake Shift

Operational rules for developing this project.

- **What and why** → `docs/design_doc.md` (**v2.1**)
- **What it looks like** → **`docs/inspiration/La_Linea.png`**. The art direction changed
  wholesale on 4 September 2026: out goes the Ori-like silhouette-and-light of
  `docs/sketch/sketch_3`, in comes **La Linea** — a filled background, one continuous stroke
  that *is* the world, a character who rises out of that stroke and returns to it. It is
  binding, it is summarised in `ROADMAP.md` under "La direzione artistica", and the phase that
  puts it on screen is **RL**, which also carries the decisions taken. Section 10 of the design doc is
  the binding statement of it. `docs/` is deliberately **not tracked by
  git**: it is the author's working material and lives only on their disk.
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
single pattern. The visual identity is **La Linea**: a filled, vignetted field that *is* the
world you are in, one continuous glowing stroke drawn on it, and nothing else — the field
changes colour with the world, the stroke never does.

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
2. **`docs/design_doc.md` v2.1** — binding on *what* to build, and its **section 10** is binding
   on what it *looks* like: **La Linea** (`docs/inspiration/La_Linea.png`). The sketches under
   `docs/sketch/` governed for one day and no longer bind anything — do not read them as
   references. Everything is reachable with primitives plus palette plus bloom; the project has
   no external art assets and is not getting any, and now it needs fewer.
3. The rest of this file — architecture rules and conventions.

**The art direction is La Linea, and what that changes.** The simulation does not change at
all — RL touches `render/`, `fx/` and the palette and nothing else. What changes is the
grammar, and one rule has to be replaced before any of it is written. The old readability rule
was *scenery is line, danger is mass*; if everything is line, it is gone. Its replacement was
already written in `render/obstacle.odin` without anyone noticing — *a cube is the one thing in
the world with right angles, and the scenery is all curves* — because that rule is
**geometric, not about fill**, so it survives the change intact:

> **The world curves, the danger corners.**

The three dangers become three things a line can do: the cube is a step with two right angles
*in* the surface, the gap is the line **stopping** (the only discontinuity in the game), the
Sentinel **crosses** the corridor. The Corruption stops being a filter on the frame and becomes
a mark — the line fraying into particles behind you — which deletes the whole "colour has two
systems" complication below rather than working around it. Four decisions are already taken and
bind the phase: **the background changes, never the stroke**; the blend **lags** `world_t` by
half a second or so, because a flip is 0.16 s and three in a row would strobe; the background
never competes with the line for attention; and the line's **glow grows toward Dream**, which is
the second channel that says where you are going (pillar 6). All four are built, and so is the
right-hand front: the world **draws itself on the right** as the Corruption eats it on the left.
The draw front may never move far enough left to steal warning time (pillar 3), which is why its
inset is a constant and costs 0.18 s.

**Where the project stands.** The design was rewritten on 4 September 2026 (v1.3 → v2.0, then
v2.1 for the art direction), and **R1 through R4 are built and playtested**: two lanes, one
gesture, a cube that *blocks* rather than kills in six forms, a Corruption front advancing from
the left that eats the ground a mistake costs you, a track whose corridor undulates and pinches,
and the Sentinel — so all three dangers and all three verbs are on screen. **Phase RL is in
progress**: RL.1 through RL.7 are done, so **nothing on screen is filled but the background** — a
field whose colour is the world, two unfilled strokes that are the floor and the ceiling with the
cubes welded into them, a character made of the same mark but heavier and whiter, a dormant lane
that thins and dims behind the one you are in, and two fronts that are both clips: a pen near the
right edge writing the world, and the Corruption fraying it into dust on the left. Still missing:
the real pattern pool (R5), fragments and the Gate (R6).

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

### The track is simulation

`core/track.odin` owns the shape of the world, because the player and the obstacles stand on it.
It is **two numbers keyframed in world time**:

- **spine** — where the corridor's centre sits vertically. Moving it makes the world undulate.
- **span** — how tall the corridor is. Moving it tightens or opens the crossing, and it is a
  difficulty knob the game never had before R3.

Floor is `spine + span/2`, ceiling is `spine - span/2`, so the two lanes cannot disagree —
coherence is a property of the representation rather than a rule someone has to remember.

- **Keyframes in time, not a function of scrolled pixels.** An obstacle is an event in time, and
  a track anchored to pixels would slide against the patterns the moment scroll speed changed —
  which in v2.0 it does, because the player buys it. The visible price is that the undulation
  stretches as a run speeds up.
- **Linear between keyframes, and that is load-bearing twice.** It is what makes
  `track_support_y` exact rather than sampled (an extreme over a range can only sit at an end or
  at a keyframe inside it), and it is why the legality clamp runs **on append, never on sample**:
  clamp a keyframe and the function stays linear; clamp the sampler and it stops being.
- **A `Track` is a plain value** — a fixed `[TRACK_CAPACITY]TrackPoint` inside `World`, not a
  dynamic array beside it. So `interpolated_world` can copy the World forward by a fraction of a
  step and read a track nobody owns. Measured: a long run peaks at 20 of the 64 slots.
- **A body rests on the highest ground under its whole width**, not under one chosen point.
  Verified against a crest straddled by the player's box: the feet land on the crest, not in the
  slope on either side of it.
- **The flip's duration is constant in time whatever the span is.** The corridor changes width;
  the gesture must not, or it stops being a reflex. Measured at 0.167 s across spans of 250, 340
  and 430, crossing 205, 295 and 385 px respectively.
- **The sky used to ride the spine**, and phase RL deleted the sky. The rule it came from is
  still true and still worth knowing, because it will come up again for anything the world
  contains: a *world* element nailed to the screen while the world slides underneath it reads as
  two pictures. What replaced the sky — a vignette — is not a world element but a property of the
  lens looking at it, so it stays screen-fixed on purpose (`render/background.odin`).

**Patterns author the track** (`Pattern.track`), on the same clock and in the same file as the
obstacles: the corridor sagging or pinching *is* content, and authoring it elsewhere would let
the ground and the obstacles disagree about what a moment is for.

The rule that makes that composable is **every pattern opens and closes at the neutral corridor**
(`TRACK_SPINE_DEFAULT`, `TRACK_SPAN_DEFAULT`), enforced by `validate_pattern_pool`. It is what
replaces a seam check: whatever order the generator strings patterns in, the world is continuous
and the stretch across a gap is flat, so no pair can be illegal together that is legal apart.
A rhythm falls out of it for free — the track is flat for the whole gap between patterns, so as
the tiers squeeze that gap the world undulates more and more continuously, with no line of code
intending it.

The validator also enforces `TRACK_MAX_SPINE_RATE` / `TRACK_MAX_SPAN_RATE` on the authored
numbers rather than clamping at runtime. The fix for a track that lurches is to author it
differently; a sampler quietly disagreeing with what was written would also break the linearity
above.

### The player's screen x is game state

The most invasive change in v2.0, done in R2.1. The old `PLAYER_X` was doing two jobs and has
been split into two constants that happen to hold the same number:

- **`core.WORLD_ANCHOR_X`** — the screen x that world time lands on. Constant, and the *only*
  thing any space↔time conversion may read: the track sampler and obstacle positions both do.
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
| **Sentinel** | *do not move right now* | yes | ✅ |

The cube is **one primitive at six sizes** (`CubeForm`): standard, small, wide, stack, pyramid,
and the floating one. Mechanically only the width matters — and, on the floating one, whether
the box is in the body's band at all — so a stack and a pyramid cost exactly what they are wide
and their height is rhetoric. That is the point: they read as *worse* at a glance while costing
the same, which is the cheapest variety in the set.

Three rules the implementation established, all found by replaying the simulation:

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
  nowhere else. Small and Wide are therefore in the set for the eye, not the hand, and that is a
  legitimate job.
- **A pin freezes the character *in the world*, so a cube inside a Sentinel's beam is a trap
  rather than a price.** A pinned body no longer moves relative to anything authored in the
  world, the beam included — so the beam can never pass them, and the flip that would free them
  is the one thing it kills. They stand there until the Corruption arrives, which is the one
  death pillar 7 forbids. `validate_pattern_pool` rejects it: the pinned box is
  `[face - PLAYER_SIZE, face]`, so the beam has to have cleared that box before the face reaches
  it, which is exactly the two event windows not overlapping. The combination the design wants
  is therefore built the other way round — the beam holds you on the lane you chose and the cube
  is waiting on it the instant the ban lifts, which leaves exactly one journey's worth of
  window. Measured: leaving on the release dodges it entirely, leaving a quarter second late
  costs 6 pinned steps and 27 px of runway.

- **A cube blocks, and that is the design's centre of gravity.** Because it is not lethal, the
  game is finally allowed to threaten **both lanes at once** — a mirrored cube pair is legal,
  and it is the first thing in the project's history that turns "where do I go" into "which
  price do I pay". The v1.x design could never do it: two lethal lanes is an unsolvable pattern.
  What a cube costs is its **width**, because width is how long you stay pinned.
- **The Sentinel is the only danger that asks what you are *doing* rather than where you are.**
  It occupies `SENTINEL_BAND` of the span, centred on the spine, so standing on either lane is
  safe and crossing is death. Nothing forbids the press: the flip is simply what it kills, which
  means committing to a lane in advance. A *fraction* of the span rather than a fixed height,
  because the corridor's width changes along the track and what has to stay true at every span
  is that a settled body is clear of it — at the narrowest corridor that leaves 72 px against a
  45 px body. It has no lane, so it is drawn out of the **neutral** palette: it belongs to
  neither world, and the one thing it must never look like is a threat to only one of them.
- **Invulnerability is decided per type, not once at the top of the collision check.** The grace
  period exists to forgive the flip started at the last possible instant against a hole — but
  against a Sentinel the flip *is* the mistake, so forgiving the first tenth of a second of
  every journey would hand a free crossing to exactly the player it is aimed at.
- **The floor breaks, the ceiling dissolves.** It survived the loss of the fill in RL.2, carried
  entirely by what the line does: the floor's stroke **turns down** into the break, which puts
  two more right angles in it, and the ceiling's **runs on past the lip and tapers to nothing**
  while the opening glows. Same cut, opposite reading.
- **The track owns the holes, and since RL.2 it owns the cubes too.** `render/terrain.odin` is
  the only code that knows where its own surface is. It builds each lane as **one polyline across
  the whole screen** — cubes welded in as steps, read off the obstacle's own rectangle so the
  mark and the hitbox are the same thing — and cuts the holes out of it afterwards, interpolating
  a vertex exactly onto each edge. Building it already in pieces would make a cube straddling a
  hole's edge disagree with the piece that contains it; building it whole makes that a clip.
  Drawing a gap as an object is what made it read as a box standing on the floor for the whole of
  the prototype, and drawing a cube as an object is what made it read as something *put there*
  rather than as something the world did.

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
- **`STROKE_MAX_POINTS` is load-bearing, and it truncates in silence.** Since RL.2 a lane is one
  mark spanning the whole screen, so the longest polyline in the game is the world itself; a
  polyline over the cap would be a line that stops in mid air with nothing to say so. Raised to
  256 against a measured worst case around fifty. The same class of silent failure as the winding
  above: check a new kind of stroke by reading the pixels back, not by looking at it.

Since RL.3 it draws the character too, and one shape was worth building properly: the bulb is the
outline of the **union** of two overlapping circles, not two circle outlines on top of each
other, because the arcs would cross inside a head that is five pixels wide. Which half of each
circle to keep is decided by **probing the midpoint**, not by deriving it — the derivation turns
on which intersection point the radical construction produced first, and both answers are a
closed loop, so getting it backwards is silent.

It is written to know nothing about the game. That matters because of an open question: `ui` may
not import `render`, so the menus cannot reach the stroke as things stand. Either `ui` gains
that import (the graph stays acyclic) or `stroke.odin` and `glow.odin` move into a package of
primitives below both. Keep this file free of `game` imports so that stays a file move.

### The character stands in its box

The figure is authored as fractions of the player's box (`render/player.odin`), and the bottom
of that box is the ground. Two rules follow, and both are the difference between a character
that rests on the floor and one that floats or sinks:

- **The visible figure fills the box, not the joints.** How much the drawing reaches past the
  feet joint depends on how it is drawn, so since RL.3 the joint's position *derives* from that
  rather than being a number someone keeps in step: `PLAYER_FOOT_REACH` is half a stroke inside
  the box, `PLAYER_LEG_STRETCH` is what the leg is multiplied by to get there, and
  `PLAYER_STRIDE_LENGTH` is stretched by the same factor because the run cycle is tuned on the
  ratio between what the feet cover and what the ground does — miss that and the character
  skates. It used to be a hand-written 0.409, against a silhouette plus a 2.4 px rim; a stroke
  reaches only half its own width, which would have left the figure 2.2 px in the air. A shape
  whose edge falls exactly on the box's bottom lights the pixel row *before* it, which is what
  contact looks like in a readback.
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
  is the part that is easy to get backwards in silence — before RL.5 the Sentinel's outline was
  built from its left edge rightward, so a half-written beam would have been capped at the pen
  and open at the end it had already finished.
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
- **A shape that can be half-written has to be built from the pen outward.** The Sentinel's
  outline used to run from its left edge rightward, so clipping left both loose ends on the left:
  a half-written beam would have been capped at the pen and open at the end it had already
  finished. The path now starts at the pen, runs away from it and comes back, so the loose ends
  are where the ink stops.

### The glow is a third channel, and it is the one that survives depth

Decision 4 of the art direction: the line's glow grows toward the Dream, so that where you are
*going* is said by something other than colour (pillar 6). It lives in `render/palette.odin` as
`GlowGain` / `glow_gain` / `apply_glow_gain`, and **every stroke in the game goes through it** —
terrain, gap tails, Dream openings, the floating cube, the Sentinel, the character, the eye. One
channel, not a habit each file has to remember.

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
**the world curves, the danger corners** (see the top of this file). What survives untouched is
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
- **The exception is the flip's whip**, and it is not a tidy-up waiting to happen. Our curve is
  Penner's easeOutBack; the library's `back_out` is AHEasing's, and they are different functions:
  measured over the flip's half turn, ours overshoots by 18 degrees peaking at t=0.57 and
  `back_out` by 68 peaking at t=0.47 — an overshoot in the middle of the journey rather than an
  impulse at the end of it, which is exactly the version a playtest already threw out. It lives
  in `render/player.odin` as `whip_ease` because it is not a generic curve, it is the shape of
  this game's central gesture. Swapping it is a game feel decision, not a cleanup.

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
- **Nothing is filled but the background.** Since RL.3 the field is the only filled surface in
  the game and `palette.silhouette` has no consumer left at all (kept for now — deleting a
  palette field is easier than resurrecting one). What tells the worlds apart is the colour
  *behind* the line, never the line: the character is drawn out of the **neutral** palette on
  purpose, because a mark that changes colour between the worlds is the mild version of the
  mistake that inverting body and rim was.
- **The weight hierarchy is a rule, and it lives in the arithmetic.** Character, then the live
  lane, then the dormant lane, then the parallax — thickest and whitest first (Design Doc,
  section 10). `TERRAIN_STROKE_THICKNESS` is the rung everything else is expressed against:
  `render/player.odin`'s weights are multiples of it and `TERRAIN_DORMANT_WEIGHT` is a fraction
  of it, so tuning the world cannot silently invert the order. Do the same for anything new that
  joins the ladder — RL.8's parallax is the last rung.
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
7. **A mistake costs ground, not the run.** Only the gap and the Sentinel kill outright.
   Everything else costs distance, and you die when the distance you have left runs out.

---

## Known issues carried forward

Tracked here so they are not rediscovered. Each is scheduled in `ROADMAP.md`.

- **A mirrored pair costs almost nothing in runway.** Measured: three flips, 0.33 s, 4 px given
  up at the opening speed — a rhythm break rather than a price, because a mashing character is
  mid-flip ten steps out of eleven and mid-flip nothing on a lane can reach them. Whether that
  is enough is a tuning question for R5.3 and the knob is `PLAYER_RECOVERY_RATIO`, not a bug.
- **Working through a mirrored pair draws the body inside a box.** Up to 45 px, which is 83% of
  a standard cube, for about three frames of the encounter. It is the unavoidable price of the
  no-backwards rule above: the character has to end up past the box, and the only way through
  is through. Whether it reads as *wedged* or as *phasing* is the R4.6 playtest's call — and RL.2
  changed the picture without meaning to, because the box is now a hollow step in the ground
  rather than a filled mass, so the body is inside an outline instead of behind one.
- **The pool is still a placeholder**, now nineteen patterns over three obstacle types. The real
  pool is R5.2. The last measurement of the number that condemned v1.3 — how much of the time at
  least one lane is lethal — was 19.9%, against a Definition of Done that asks for over 40%, and
  it has not been re-measured since the Sentinel arrived (R5.4 builds the tool that does).
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
