# Wake Shift

A one-button reflex arcade game about being suspended between two worlds — written in
[Odin](https://odin-lang.org/) with [raylib](https://www.raylib.com/), no engine.

![Version](https://img.shields.io/badge/version-0.3.0--alpha-blue)
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
still standing on it — which means being mid-flip, suspended, or on the ceiling all answer
it equally. One asks "move, now"; the other asks "do not be down here for this stretch".

**Obstacles anticipate, they never react.** Nothing reads the player's position: an
obstacle that adapts feels stolen even when it is survivable. What makes one feel
intelligent is being authored to expect the obvious answer — the lane you would flee into
closing half a second later, a threat that is a bluff and retracts before it arrives, a
patroller sweeping the whole column on a cycle you can read but not out-react.

**The level is written in time, not pixels.** Obstacles are authored as "arrives 1.8
seconds into this pattern", and their screen position is derived each frame from the
current scroll speed. Speeding the game up never desynchronises a hand-authored pattern.

**Patterns chain on what they leave behind.** Each one declares the set of places it is
fair to start from and the set it can leave you in, and the generator only ever picks a
next pattern that accepts all of them — because it has to commit before knowing which
answer you took. Some patterns have two correct answers that end at opposite walls.

**Difficulty is three things, and speed is the smallest.** Since obstacles are events in
time, scroll speed does not change your reaction window at all — it changes how long you
get to *look*. What actually tightens is the empty air between patterns and which patterns
get drawn: at the deepest tier a breather is roughly one in ten rather than eight in
thirteen.

**The two worlds converge as you descend.** Palette and bloom both interpolate on the same
two variables — where you are, and how deep the run has gone — so past about thirty
seconds the Real and the Dream start washing toward the same overexposed threshold. The
colour you were reading the game by fades exactly as the speed peaks. Position and type of
motion carry you from there, which is why they were never allowed to be redundant with
colour.

---

## Building and running

You need the [Odin compiler](https://odin-lang.org/docs/install/) on your `PATH`. raylib
ships with Odin as a vendor library — there is nothing else to install.

```bash
odin run src                        # build and play
odin build src -out:build/wakeshift
odin check src                      # type-check only, fast
```

The build target is the `src` directory, not `.` — `main.odin` lives inside it alongside
the package directories. Tested on Linux; Windows and macOS should work but are untested.

Progress and settings go to your OS user data directory, never next to the executable
(`$XDG_DATA_HOME/wake-shift/save.dat` on Linux). Delete that file to reset.

---

## Credits

Built by [@pankaspe](https://github.com/pankaspe) as an exercise in learning Odin, with
development assistance from Claude.

Gravity-flip is a well-worn subgenre (G-Switch, Gravity Guy and many others). The mechanic
is not what makes this one different; the world, the third state and the visual identity
are expected to do that work.

## License

Not chosen yet. Until one is added, no permissions are granted beyond reading the code.
