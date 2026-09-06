# Wake Shift

A procedural maze you run through at speed, while the world goes out behind you — written in
[Odin](https://odin-lang.org/) with [raylib](https://www.raylib.com/), no engine.

![Version](https://img.shields.io/badge/version-0.8.0--alpha-blue)
![Language](https://img.shields.io/badge/Odin-dev--2026--07-blue)
![Library](https://img.shields.io/badge/raylib-5.5-green)
![Status](https://img.shields.io/badge/status-maze%20phase-orange)

> **Rewritten, and mid-build.** Wake Shift spent its first months as a one-button gravity-flip
> runner. It was pretty and it did not hook anyone, for a reason that turned out to be measurable:
> the player was asked the same single question — *which lane is free* — from the first metre to the
> last, and the level generator drew from thirty hand-written patterns, so within minutes there was
> nothing left to see. On 6 September 2026 the gameplay was replaced with a maze. The renderer, the
> Corruption and the whole engineering spine carried over; the old game is preserved in the git
> history and its notes in `docs/archive/`.
>
> **What runs today**: the grid, the sliding, the generator, the Corruption. **What does not yet**:
> fragments, the Dream phase, levels. See [TIMELINE.md](TIMELINE.md) for where each one stands.

---

## What it is

The corridor between a floor and a ceiling is an **endless procedural maze** that scrolls past you.
The two lanes are no longer places to stand: they are the maze's boundary.

You move with **WASD / arrows**, and you **slide until a wall stops you** — every input is a
commitment with an outcome you can see before you make it, never a steering correction.

The camera runs at a constant speed whether you are making progress or not, and never comes back
for you: standing still is not a neutral act, it is ground given away, and a step backwards is paid
for twice. Nothing has to punish hesitation, because the arithmetic already does.

Behind you, from the left, the **Corruption** eats the world and keeps coming. The distance between
you and it is the only health bar there is, drawn at full size in the picture you are already
looking at.

*Planned, not yet built:* **fragments** picked up along the way charge a meter, and at full the
world turns **Dream** for a while — you cross one wall per slide, the Corruption retreats — before
falling back to Real.

---

## The look

The art direction is **La Linea**, the cartoon by [Osvaldo
Cavandoli](https://en.wikipedia.org/wiki/La_Linea_(TV_series)) — a man who walks along a single
continuous line that *is* his world, drawn ahead of him and rubbed out behind. That is not a
reference bolted on: it is this game's premise, told by somebody else fifty years earlier.

Everything on screen is one stroke — a neon polyline with a bright core and an additive halo — on a
filled, vignetted field, with a real frame-wide bloom pass over the finished frame. Exactly two
things are filled: the field, and you. The world is **written** by a pen near the right edge and
**unwritten** by the Corruption on the left, and both of those are a clip rather than an animation.

Apart from one open-licence font (`assets/fonts/`), there are no art assets and there will not be
any.

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
generation, input recorded as data and a fixed 60 Hz timestep mean a run is reproducible from its
seed and its input log alone — which is what makes server-side leaderboard validation, replays and
ghosts possible later without changing anything. *(The input log still records the old game's
one-button events, so it does not reproduce a run today. Extending it is part of finishing the
maze, not an optional tidy-up.)*

**Saves are sealed, and this README will not oversell it.** The payload is CBOR sealed with
ChaCha20-Poly1305, and a file that fails to authenticate is rejected and reset rather than trusted.
But the key ships inside the binary, so it is a deterrent against editing a save in a text editor —
not security. The real defence is replaying the manifest on a server.

**The generator does not hope, it measures.** It replaces a whole machine of hand-checked pattern
fairness rules with one invariant — and a stronger one than it first looks: not *a path exists*, but
*a path exists that arrives in time*. The world scrolls whether you are moving or not, so a route
costing three cells of climbing per column gained is a route that kills.

Every chunk of maze is therefore measured on the **slide** graph — what a press actually does, not
cell adjacency — and re-rolled with another sub-seed until the cheapest crossing lands in the band
the level asked for. Over 1000 chunks that is 0 unsolvable, a mean crossing at 45% of the time
available, and 4 ms of generation for every 7 seconds of play. Seam holes are a function of the
boundary's column index alone, so a chunk is generated, verified and regenerated entirely on its
own, in any order, and an evicted one comes back identical.

---

## Timeline

What has been built, in order, one line each: **[TIMELINE.md](TIMELINE.md)**.

There is no roadmap. The next step is decided one at a time.

---

## Credits

Built by [@pankaspe](https://github.com/pankaspe) as an exercise in learning Odin, with development
assistance from Claude.

Megrim by Daniel Johnson, under the SIL Open Font License 1.1 (`assets/fonts/OFL.txt`).

*La Linea* and its character are the property of their rights holders. Nothing here copies them:
the debt is to the idea of a world made of one line, and the figure on screen is our own.

---

## License

**Not chosen yet** — see [LICENSE](LICENSE). Until that file exists, no permissions are granted
beyond reading the code.
