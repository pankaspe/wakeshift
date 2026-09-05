# Wake Shift

A one-button reflex arcade game about running through a dream that is going out behind you —
written in [Odin](https://odin-lang.org/) with [raylib](https://www.raylib.com/), no engine.

![Version](https://img.shields.io/badge/version-0.7.0--alpha-blue)
![Language](https://img.shields.io/badge/Odin-dev--2026--07-blue)
![Library](https://img.shields.io/badge/raylib-5.5-green)
![Status](https://img.shields.io/badge/status-in%20development-orange)

You run forward automatically. `SPACE` flips gravity, throwing you between the floor — **the Real
world** — and the ceiling, **the Dream**. Behind you, from the left, the **Corruption** eats the
world and keeps coming. The distance between you and it is the only health bar there is, and it is
drawn at full size in the picture you are already looking at.

The twist is what happens when you get it wrong: **a mistake costs ground, not the run.**

---

## What is in it

**The corridor.** Two lanes that curve together and whose width opens and pinches. It is not
scenery: the floor and the ceiling are two keyframed numbers, so they can never contradict each
other, and a pattern authors the shape of the world along with the things standing on it.

**The cube** — *do not be here, or you pay.* It does not kill; it **blocks**. You are stopped
against its face and you lose ground for as long as you stay. Its shape is **data, not code**: a
pattern writes a skyline of columns — `{1,2,3}` is a staircase, `{3,0,3}` two towers with a canyon
between them — and the same numbers are what blocks you, what holds you up, and what gets drawn, so
a step you can see is a step you can stand on. Welded into the floor's own line, read by its right
angles. Because it is not lethal, it is the only danger allowed on both lanes at once, and a
mirrored pair is a choice about which price to pay. Land on top of one and you ride it.

**The hole** — *do not be here.* The line simply stops: the only discontinuity in the game. The
lane turns out of the corridor at the lip and the stroke ends — down off the floor, up off the
ceiling, the same mark mirrored. It takes you when there is nothing under your centre, and you see
yourself go in.

**The Corruption.** A front advancing from the left, faster the deeper you go. It is not a timer —
it stops short of a clean runner — it is how expensive your mistakes have become. The world's line
frays into dust as it arrives.

**The pen.** Near the right edge, the world is being *written*: one x beyond which nothing is
drawn, so obstacles do not appear, the line reaches them. Two mirrored fronts, one making and one
unmaking.

---

## Controls

| | |
|---|---|
| `SPACE` | flip between floor and ceiling — the only gameplay key there is, and there will never be a second |
| `ESC` | pause |
| `F11` | fullscreen |

---

## The look

The art direction is **La Linea**, the cartoon by [Osvaldo
Cavandoli](https://en.wikipedia.org/wiki/La_Linea_(TV_series)) — a man who walks along a single
continuous line that *is* his world, drawn ahead of him and rubbed out behind. That is not a
reference bolted on: it is this game's premise, told by somebody else fifty years earlier.

So there is one filled surface on the screen — the field — and everything else is a stroke. The
field's colour *is* which world you are in, and it lags behind you by half a second so a burst of
flips washes instead of strobing. The character rises out of the floor's own line and returns to
it. And one rule keeps it readable now that everything is line:

> **The world curves, the danger corners.**

The corridor bends, the hood and the robe bend, the horizons bend. A right angle means *this costs
you*, and nothing else on screen has one.

Everything is drawn from primitives — one neon polyline with a bright core and an additive halo,
a palette, and a real frame-wide bloom pass. **There are no art assets in this repository and
there will not be any.**

---

## Stack

| | |
|---|---|
| Language | [Odin](https://odin-lang.org/) `dev-2026-07` |
| Graphics | [raylib](https://www.raylib.com/) 5.5, via `vendor:raylib/v55` |
| Encoding | `core:encoding/cbor` |
| Crypto | `core:crypto/chacha20poly1305` |
| Easing | `core:math/ease` |
| Engine | none |

```bash
odin check src                        # type-check, fast
odin build src -out:build/wakeshift   # build
odin run src                          # play
```

---

## Under the hood

**The simulation is deterministic, and that is a product feature rather than tidiness.** Seeded
generation, input recorded as data, and a fixed 60 Hz timestep mean a run is reproducible from its
seed and its input log alone. Every personal best is stored with the manifest that reproduces it,
which is what makes server-side leaderboard validation, replays and ghosts possible later without
changing anything.

**Saves are sealed, and this README will not oversell it.** The payload is CBOR sealed with
ChaCha20-Poly1305, and a file that fails to authenticate is rejected and reset rather than trusted.
But the key ships inside the binary, so it is a deterrent against editing a save in a text editor —
not security. The real defence is replaying the manifest on a server.

**Obstacles are events in time, never pixel positions.** Their place on screen is derived every
frame from the world's clock and its speed, so scroll speed can change without a single authored
pattern moving. Difficulty is measured in distance, so buying speed buys score and difficulty
together.

---

## Timeline

What has been built, in order, one line each: **[TIMELINE.md](TIMELINE.md)**.

There is no roadmap. The next step is decided one at a time.

---

## Credits

Built by [@pankaspe](https://github.com/pankaspe) as an exercise in learning Odin, with
development assistance from Claude.

Gravity-flip is a well-worn subgenre (G-Switch, Gravity Guy and many others). The mechanic is not
what makes this one different; the Corruption at your back, and the fact that a mistake takes
ground instead of ending the run, are expected to do that work.

*La Linea* and its character are the property of their rights holders. Nothing here copies them:
the debt is to the idea of a world made of one line, and the figure on screen is our own.

---

## License

**Not chosen yet** — see [LICENSE](LICENSE). Until that file exists, no permissions are granted
beyond reading the code.
