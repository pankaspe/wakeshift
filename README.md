# Wake Shift

A one-button reflex arcade game about being suspended between two worlds — written in
[Odin](https://odin-lang.org/) with [raylib](https://www.raylib.com/), no engine.

![Version](https://img.shields.io/badge/version-0.2.0--alpha-blue)
![Language](https://img.shields.io/badge/Odin-dev--2026--07-blue)
![Library](https://img.shields.io/badge/raylib-5.5-green)
![Status](https://img.shields.io/badge/status-playable%20alpha-orange)

You run forward automatically. One key flips gravity, throwing you between the floor
(**the Real world**) and the ceiling (**the Dream**). Every obstacle lives in exactly one
of them, so the only question you ever have to answer is *where should I be right now?* —
asked faster and faster until you get it wrong.

Hold the key instead of tapping it and you stop halfway, suspended in the **Limen**: the
threshold where the score runs fastest and you cannot stay long. One key, two gestures,
three places to be.

---

## Status

Playable alpha, and honest about it.

**Working:** the core loop and all three states, six obstacle types with genuinely
different readings, time-based procedural generation, Lucidity as a spendable resource,
difficulty tiers, the three-world palette with real bloom, an encrypted save, an options
screen, and a fully deterministic simulation that can record and replay a run exactly.

**Not there yet:** audio, particles, and the parallax scenery — so the world is lit but
empty, and the layered descent the design is built around has not been built. The
difficulty curve also still comes mostly from scroll speed rather than from the obstacles
themselves.

If you are here to read code rather than to play, the interesting parts are the
deterministic simulation, the package layout, and how the palette and the bloom are driven
by the same two numbers.

---

## Controls

| Key | Action |
| --- | --- |
| `SPACE` | Tap to flip · **hold to stop halfway**, suspended in the Limen |
| `ESC` | Pause / back |
| `↑` `↓` | Navigate menus |
| `←` `→` | Change a setting |
| `ENTER` | Confirm / retry |
| `F11` | Toggle fullscreen |

---

## How it plays

**One question, three answers.** *Where should I be right now?* — the floor, the ceiling,
or the threshold between them. Never more than three, and the difficulty is entirely in
seeing the answer coming and committing in time.

**A flip is a journey, and holding stops it halfway.** That single sentence is the whole
control scheme, and the code says it literally: holding freezes the journey's own clock at
its midpoint, releasing resumes it, and the journey always finishes where it was already
going. Nothing anywhere has to remember which wall you came from.

**Risk is where the points are.** 10 points per second on the floor, 25 on the ceiling, 40
in the Limen — which is also the only one that costs something to stay in.

**Lucidity is one resource with two faces.** It is earned by getting out of the way *late*
— when an obstacle arrives in the lane you had just left — and spent staying suspended,
while simultaneously being the score multiplier. So the third state asks a question no
amount of reflex answers: bank the multiplier, or burn it to stand where the score runs
fastest?

**Presence and absence are different rules, not different pictures.** A block kills
whoever touches it. A chasm is the floor failing to be there, so it kills only whoever is
still standing on it — which means being mid-flip, suspended, or on the ceiling all answer it
equally. One asks "move, now"; the other asks "do not be down here for this stretch".

**Obstacles anticipate, they never react.** Nothing reads the player's position: an
obstacle that adapts feels stolen even when it is survivable. What makes one feel
intelligent is being authored to expect the obvious answer — the lane you would flee into
closing half a second later, a threat that is a bluff and retracts before it arrives, a
patroller sweeping the whole column on a cycle you can read but not out-react.

**The level is written in time, not pixels.** Obstacles are authored as "arrives 1.8
seconds into this pattern", and their screen position is derived each frame from the
current scroll speed. Speeding the game up never desynchronises a hand-authored pattern.

**The two worlds converge as you descend.** Palette and bloom both interpolate on the same
two variables — where the player is, and how deep the run has gone — so past about thirty
seconds the Real and the Dream start washing toward the same overexposed threshold. The
colour you were reading the game by fades exactly as the speed peaks. Position and type of
motion are what carry you from there, which is also why they were never allowed to be
redundant with colour.

**The level is written in time, not pixels.** Obstacles are authored as "arrives 1.8
seconds into this pattern", and their screen position is derived each frame from the
current scroll speed. Speeding the game up never desynchronises a hand-authored pattern.

**Difficulty arrives in tiers.** *Awake* (270 px/s) → *Drifting* at 25s (330 px/s) →
*Deep Dream* at 55s (400 px/s), each unlocking additional pattern types, with scroll speed
easing between them rather than jumping.

Where the game is going — the descent through layered worlds, the two palettes converging
as you go deeper, the third playable state, obstacles that anticipate rather than react —
is settled in the design document, which drives every technical decision in the code but
is kept out of this repository (see below).

---

## Building and running

You need the [Odin compiler](https://odin-lang.org/docs/install/) on your `PATH`. raylib
ships with Odin as a vendor library — there is nothing else to install.

```bash
git clone https://github.com/pankaspe/wakeshift.git
cd wakeshift

odin run src            # build and play
odin build src -out:build/wakeshift
odin check src          # type-check only, fast
```

> The build target is the `src` directory, not `.` — `main.odin` lives inside it
> alongside the package directories.

Tested on Linux with Odin `dev-2026-07`. Windows and macOS should work (nothing in the
code is platform-specific) but are currently untested.

Progress and settings are written to your OS user data directory, never next to the
executable: `$XDG_DATA_HOME/wake-shift/save.dat` on Linux,
`~/Library/Application Support/wake-shift/` on macOS, `%LOCALAPPDATA%\wake-shift\` on
Windows. Delete that file to reset.

---

## Project layout

```
src/
├── main.odin      package main — window, game loop, state machine
├── core/          shared vocabulary: lanes, geometry, easing, input, time, settings
├── platform/      the OS: window, render target, keyboard, save files
├── game/          the simulation: player, world, obstacles, patterns, scoring, collision
├── render/        drawing only: player, obstacles, terrain, background, palette
├── fx/            post-processing, knows nothing about the game: bloom
└── ui/            menus, HUD, screens
```

Dependencies run strictly one way, with no cycles: `core` ← `platform`, `game`, `fx`;
`game` ← `render`, `ui`; everything ← `main`. Two rules hold it together — **`game/` never draws**
(no `rl.Draw*` call exists under it) and **`render/` never mutates** (it takes state by
value and produces pixels). Which means the entire simulation runs without a window, and
that is what makes the determinism tests possible.

---

## What "deterministic" means here

The same seed and the same key presses produce a bit-identical run — not approximately,
identically, across different frame rates and different frame pacing. That rests on three
things which all had to be true at once: **seeded generation** (every random choice comes
from the run's own generator), **input as data** (gameplay receives a `core.Input` value;
exactly one procedure polls the keyboard), and **a fixed timestep** (1/60s steps whatever
the frame rate, with input latched until a step consumes it). Miss one and the other two
are worthless.

The payoff is that a run can be recorded as `(seed, [ticks the key went down], [ticks it
came back up])` — the releases matter as much as the presses now that holding is half the
control scheme — and replayed exactly — simultaneously a replay system, a ghost system, a way to re-run a
balance change against the identical run, and the only honest way to validate a
leaderboard score: the server replays the submission and computes the score itself rather
than believing the client. Every record you set already stores that manifest. Nothing
plays it back yet.

Which is also the precise limit of the save file's encryption. It is a CBOR payload sealed
with XChaCha20-Poly1305, and that stops someone editing their high score in a text editor
— real, and the point. It is **not** protection for a leaderboard: the key is compiled
into the binary. A save that fails authentication is rejected and replaced with defaults,
because losing a personal best is annoying and refusing to start is worse.

---

## Notes for people learning Odin

A learning project, and a few things cost real time to work out:

- **Split packages by layer, not by entity.** Odin forbids cyclic imports and one
  directory is exactly one package. `player/`, `obstacle/`, `pattern/` looks tidy and
  falls apart immediately — scoring reads the player, streaks read the player *and*
  obstacles. Grouping by level of abstraction keeps the graph acyclic.
- **`make_directory_all` is not idempotent.** It returns `.Exist`, not `nil`, when the
  directory already exists — so it works on a fresh install and fails on every launch
  after.
- **The AEAD routines assert on slice sizes.** `crypto/chacha20poly1305` validates its
  arguments with `ensure()`, which aborts the process. Every length check has to happen
  before the call, or a truncated file crashes instead of being rejected.
- **A `rand.Generator` holds a pointer to its state.** Stored in a struct that gets
  assigned by value, it keeps pointing at whichever copy it was built from. Store the
  state; build the generator on demand.
- **Constant folding refuses a lossy cast.** `u32(1.0 / FIXED_TIMESTEP + 0.5)` does not
  compile, because `f32(1.0)/60.0` never held exactly a sixtieth. The error was right: the
  integer belongs as the primary constant, with the float derived from it.
- **Import identifiers come from the directory, not the package declaration.**
  `import "core:encoding/cbor"` is referenced as `cbor.*`, though its files declare
  `package encoding_cbor`.
- **Constant folding also refuses a lossy cast you did not know you wrote.**
  `i32(SCREEN_HEIGHT * 0.30)` fails, because 0.30 is not representable and 215.999… cannot
  become an `i32`. Assigning through a typed variable first makes it a runtime cast; better
  still, write the integer arithmetic you actually meant.
- **Render textures are stored bottom-up, and the flip belongs at the very end.** Chaining
  render textures with positive source rects carries that convention through unchanged, so
  the one negative-height blit that presents the frame is still correct. Add a second flip
  in the middle and the post-processing silently mirrors the light away from whatever
  emitted it — with no error, and nothing that reading the code will show you. The way to
  catch it is to read the pixels back and check that the light landed on the row that
  emitted it.

---

## Documentation

| File | What it is |
| --- | --- |
| `CLAUDE.md` | Development conventions: architecture rules, naming, invariants. |
| `ROADMAP.md` | Working plan, phase by phase. Italian — the author's notebook, not project documentation. |
| `docs/` | Design document and art direction sketches. **Not in this repository**: working material kept on the author's disk. The code and `CLAUDE.md` are written to stand on their own without it. |

---

## Credits

Built by [@pankaspe](https://github.com/pankaspe) as an exercise in learning Odin, with
development assistance from Claude.

Gravity-flip is a well-worn subgenre (G-Switch, Gravity Guy and many others). The mechanic
is not what makes this one different, and the design doc says so on page one; the world,
the third state and the visual identity are expected to do that work.

## License

Not chosen yet. Until one is added, no permissions are granted beyond reading the code.
