# Wake Shift

A one-button reflex arcade game about being suspended between two worlds — written in
[Odin](https://odin-lang.org/) with [raylib](https://www.raylib.com/), no engine.

![Version](https://img.shields.io/badge/version-0.1.0--alpha-blue)
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

**Working:** the core loop, time-based procedural generation, the Lucidity streak,
difficulty tiers, an encrypted save, an options screen, and a fully deterministic
simulation that can record and replay a run exactly.

**Not there yet:** audio, particles, bloom, parallax, and the Limen itself. The game
currently looks like what it is — a prototype on a beige background. Making it look like
something is the next milestone.

If you are here to read code rather than to play, the interesting parts are the
deterministic simulation and the package layout.

---

## Controls

| Key | Action |
| --- | --- |
| `SPACE` | Flip gravity |
| `ESC` | Pause / back |
| `↑` `↓` | Navigate menus |
| `←` `→` | Change a setting |
| `ENTER` | Confirm / retry |
| `F11` | Toggle fullscreen |

---

## How it plays

**Two lanes, one question.** Obstacles only ever occupy one lane. Being in the other one
is always the answer; the difficulty is entirely in seeing it coming and committing in
time.

**Risk is where the points are.** The Dream lane scores 25 points per second against the
Real lane's 10 — and it is also where obstacles move on sine curves instead of standing
still.

**Lucidity rewards nerve, not caution.** Settling into the safe lane *late* — within 0.35s
of an obstacle arriving — counts as a near miss and builds a streak worth up to +100%
score. Playing it safe scores less than cutting it fine.

**The level is written in time, not pixels.** Obstacles are authored as "arrives 1.8
seconds into this pattern", and their screen position is derived each frame from the
current scroll speed. Speeding the game up never desynchronises a hand-authored pattern.

**Difficulty arrives in tiers.** *Awake* (270 px/s) → *Drifting* at 25s (330 px/s) →
*Deep Dream* at 55s (400 px/s), each unlocking additional pattern types, with scroll speed
easing between them rather than jumping.

Where the game is going — the descent through layered worlds, the two palettes converging
as you go deeper, the third playable state, obstacles that anticipate rather than react —
is settled in [`docs/design_doc.md`](docs/design_doc.md), which drives every technical
decision in the code.

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
├── render/        drawing only: player, obstacles, terrain
└── ui/            menus, HUD, screens
```

Dependencies run strictly one way, with no cycles: `core` ← `platform`, `game`; `game` ←
`render`, `ui`; everything ← `main`. Two rules hold it together — **`game/` never draws**
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

The payoff is that a run can be recorded as `(seed, [ticks it was flipped on])` and
replayed exactly — simultaneously a replay system, a ghost system, a way to re-run a
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

---

## Documentation

| File | What it is |
| --- | --- |
| [`docs/design_doc.md`](docs/design_doc.md) | The design: what the game is and why. Binding on *what* to build. |
| `ROADMAP.md` | Working plan, phase by phase. Italian — the author's notebook, not project documentation. |
| `CLAUDE.md` | Development conventions: architecture rules, naming, invariants. |

---

## Credits

Built by [@pankaspe](https://github.com/pankaspe) as an exercise in learning Odin, with
development assistance from Claude.

Gravity-flip is a well-worn subgenre (G-Switch, Gravity Guy and many others). The mechanic
is not what makes this one different, and the design doc says so on page one; the world,
the third state and the visual identity are expected to do that work.

## License

Not chosen yet. Until one is added, no permissions are granted beyond reading the code.
