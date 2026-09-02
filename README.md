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
threshold between waking and sleeping, where the score runs fastest and you cannot stay
long. One key, two gestures, three places to be.

---

## Status

Playable alpha, and honest about it.

**Working end to end:** the core loop, time-based procedural generation, the Lucidity
streak, difficulty tiers, an encrypted save, and a fully deterministic simulation that can
record and replay a run exactly.

**Not there yet:** audio, particles, bloom, parallax, the Limen, and the world described
in [Where this is going](#where-this-is-going). The game currently looks like what it is —
a prototype on a beige background. Making it look like something is the next milestone.

If you are here to read code rather than to play, the interesting parts are the
deterministic simulation and the package layout. See
[Notes for people learning Odin](#notes-for-people-learning-odin).

---

## Controls

| Key | Action |
| --- | --- |
| `SPACE` | Flip gravity |
| `ESC` | Pause |
| `↑` `↓` | Navigate menus |
| `ENTER` | Confirm / retry |
| `F11` | Toggle fullscreen |

---

## How it plays

**Two lanes, one question.** Obstacles only ever occupy one lane. Being in the other one
is always the answer; the difficulty is entirely in seeing it coming and committing in
time.

**Risk is where the points are.** The Dream lane scores 25 points per second against the
Real lane's 10 — and it is also where the obstacles move on sine curves instead of
standing still.

**Lucidity rewards nerve, not caution.** Settling into the safe lane *late* — within
0.35s of an obstacle arriving — counts as a near miss and builds a streak worth up to
+100% score. Playing it safe scores less than cutting it fine.

**The level is written in time, not pixels.** Obstacles are authored as "arrives 1.8
seconds into this pattern", and their screen position is derived each frame from the
current scroll speed. Speeding the game up never desynchronises a hand-authored pattern.

**Difficulty arrives in tiers.** *Awake* (270 px/s) → *Drifting* at 25s (330 px/s) →
*Deep Dream* at 55s (400 px/s), each unlocking additional pattern types. Scroll speed
eases between tiers rather than jumping, so the change is felt and not seen.

---

## Where this is going

None of this is implemented yet. It is here because the design is settled and drives every
technical decision in the code — the full reasoning is in
[`docs/design_doc.md`](docs/design_doc.md).

**You are descending, not travelling.** The score is called *Dream Depth*, and the world
is built to mean it: forest, then bare scree, then glacier, then somewhere that stops
being a place. Each layer introduces an obstacle behaviour rather than just a palette — a
layer that only changes colour is wallpaper.

**The two worlds converge as you go deeper.** Real and Dream drift toward the same bleached
palette until, at the bottom, the waking world has dream properties. It is the difficulty
curve and the story at once: the colour cue you were leaning on fades exactly when you are
moving fastest, because the character is losing the ability to tell the two apart. Position
and type of movement still separate them, which is also why the game stays playable for
anyone who does not read colour well.

**A third place to be.** Tapping flips you wall to wall. Holding stops you halfway, in the
Limen — highest scoring, and it burns the Lucidity you earned by cutting things fine. The
one gesture that is worth watching is the one you choose to pay for.

**Obstacles that anticipate rather than react.** Chasing the player is the obvious idea and
the wrong one: an obstacle that adapts makes the right answer unstable, which reads as
unfair even when it is solvable. What feels intelligent is an obstacle that anticipates the
*instinctive* answer — one that appears in the lane you are flipping into, one that feints,
one that patrols on a readable cycle.

**Pickups made of light.** With a single button you cannot press to collect, so you collect
by being in the right place — and the pickup sits in the dangerous lane. Obstacles are dark
silhouettes; bonuses are light. Same visual language, opposite meaning, nothing to learn.

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

### Where your save goes

Progress is written to your OS user data directory, never next to the executable:

| OS | Path |
| --- | --- |
| Linux | `$XDG_DATA_HOME/wake-shift/save.dat` (usually `~/.local/share/wake-shift/`) |
| macOS | `~/Library/Application Support/wake-shift/save.dat` |
| Windows | `%LOCALAPPDATA%\wake-shift\save.dat` |

Delete that file to reset your record. It is a CBOR payload sealed with
XChaCha20-Poly1305, so a text editor will not get you a better score — see
[On the save file](#on-the-save-file) for an honest account of what that does and does not
protect.

---

## Project layout

```
src/
├── main.odin      package main — window, game loop, state machine
├── core/          shared vocabulary: lanes, screen geometry, easing, input, time, manifest
├── platform/      the OS: virtual canvas, fullscreen, keyboard, save files
├── game/          the simulation: player, world, obstacles, patterns, scoring, collision
├── render/        drawing only: player, obstacles, terrain
└── ui/            menus, HUD, screens
```

Dependencies run strictly one way, with no cycles:

```
core  ←  platform,  game
game  ←  render,  ui
everything  ←  main
```

Two rules hold the whole thing together:

- **`game/` never draws.** There is no `rl.Draw*` call anywhere under it.
- **`render/` never mutates.** It takes state by value and produces pixels.

Which means the entire simulation runs without a window — that is what makes the
determinism tests below possible.

---

## What "deterministic" means here, and why it was worth it

The same seed and the same key presses produce a bit-identical run. Not approximately:
identically, across different frame rates and different frame pacing.

That rests on three things, all of which had to be true at once:

1. **Seeded generation.** Every random choice — which pattern comes next, how wide a
   chasm is — is drawn from the run's own generator, never a global one.
2. **Input as data.** Gameplay receives a `core.Input` value. Exactly one procedure in the
   project polls the keyboard.
3. **A fixed timestep.** The simulation advances in 1/60s steps regardless of frame rate,
   with input latched until a step consumes it.

Miss any one and the other two are worthless.

The payoff is not tidiness. It is that a run can be recorded as `(seed, [ticks it was
flipped on])` and replayed exactly — which is simultaneously a replay system, a ghost
system, a way to re-run a balance change against the identical run, and the only honest
way to validate a leaderboard score: the server replays the submission and computes the
score itself rather than believing the client.

Every record you set already stores that manifest. Nothing plays it back yet.

---

## On the save file

The save is encrypted and authenticated, and it is worth being precise about what that
buys, because it is easy to oversell:

- It stops someone editing their high score in a text editor. That is real and it is the
  point.
- It is **not** protection for a leaderboard. The key is compiled into the binary, and
  anyone willing to open the executable can extract it. Any design that treats a locally
  computed score as evidence is broken regardless of how it is encrypted.

The actual defence against a forged score is the replay described above. The encryption is
a lock on a door, not a proof of identity.

A save that fails authentication — corrupted, truncated, tampered with, or written by a
different version — is rejected and replaced with defaults. Losing a personal best is
annoying; refusing to start is worse.

---

## Notes for people learning Odin

This is a learning project, and a few things cost real time to work out. Collected here so
they cost you less.

**Split packages by layer, not by entity.** Odin forbids cyclic imports between packages
and one directory is exactly one package. Splitting `player/`, `obstacle/`, `pattern/`
looks tidy and falls apart immediately — scoring reads the player, streaks read the player
*and* obstacles, obstacles read the world. Grouping by level of abstraction (`game/`,
`render/`, `platform/`) gives a graph that actually stays acyclic.

**`make_directory_all` is not idempotent.** It returns `.Exist`, not `nil`, when the
directory is already there. Treating that as an error works perfectly on a fresh install
and fails on every launch after.

**The AEAD routines assert on slice sizes.** `crypto/chacha20poly1305`'s `seal` and `open`
validate their arguments with `ensure()`, which aborts the process. Handing them a
truncated file crashes rather than returning false, so every length check has to happen
before the call.

**A `rand.Generator` holds a pointer to its state.** Store one inside a struct that gets
assigned by value and it keeps pointing at whichever copy it was built from. Store the
state; build the generator on demand.

**Constant folding will refuse a lossy cast.** `u32(1.0 / FIXED_TIMESTEP + 0.5)` fails to
compile because the constant is 60.4999…, not 60.5 — `f32(1.0)/60.0` never held exactly a
sixtieth. The error was right: the integer should be the primary constant and the float
derived from it, not the reverse.

**Import identifiers come from the directory, not the package declaration.**
`import "core:encoding/cbor"` is referenced as `cbor.*` even though the files inside
declare `package encoding_cbor`.

**Some stdlib results must be handled.** `os.write_entire_file` is
`@(require_results)`; ignoring the error is a compile error, not a warning.

---

## Documentation

| File | What it is |
| --- | --- |
| [`docs/design_doc.md`](docs/design_doc.md) | The design: what the game is and why. The binding reference for *what* to build. |
| `ROADMAP.md` | Working plan, phase by phase. Italian — it is the author's notebook, not project documentation. |
| `CLAUDE.md` | Development conventions: architecture rules, naming, invariants. |

---

## Credits

Built by [@pankaspe](https://github.com/pankaspe) as an exercise in learning Odin, with
development assistance from Claude.

Design direction is documented in full in `docs/design_doc.md`, including the visual
identity the project is working toward — silhouette and light, deliberately away from the
neon-geometric look most gravity-flip games share.

Gravity-flip is a well-worn subgenre (G-Switch, Gravity Guy and many others). The mechanic
is not what makes this one different, and the design doc says so on page one; the world, the
third state and the visual identity are expected to do that work.

## License

Not chosen yet. Until one is added, no permissions are granted beyond reading the code.
