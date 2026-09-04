# Wake Shift

A one-button reflex arcade game about running through a dream that is going out behind you —
written in [Odin](https://odin-lang.org/) with [raylib](https://www.raylib.com/), no engine.

![Version](https://img.shields.io/badge/version-0.6.0--alpha-blue)
![Design](https://img.shields.io/badge/design-v2.0-purple)
![Language](https://img.shields.io/badge/Odin-dev--2026--07-blue)
![Library](https://img.shields.io/badge/raylib-5.5-green)
![Status](https://img.shields.io/badge/status-rewrite%20in%20progress-orange)

You run forward automatically. One key flips gravity, throwing you between the floor
(**the Real world**) and the ceiling (**the Dream**). Behind you, from the left, the
**Corruption** eats the colour out of the world and keeps coming.

The twist is what happens when you get it wrong. A cube does not kill you — it **stops** you,
and while you are pinned against it the Corruption closes the distance. **A mistake costs
ground, not the run.** The gap in the floor kills, and the Sentinel that hangs in the corridor
kills anyone crossing it; everything else just makes you pay. You die when the payments add up.

---

> ### Status: mid-rewrite
>
> The design was rewritten from scratch on 4 September 2026 after the previous version was
> measured and found wanting: across 200 simulated runs that **never touched the key**, 161
> survived the whole first difficulty tier, and for **86% of the time** there was nothing on
> screen that could kill you in any position. It was structural, not a tuning problem — the
> level generator's own fairness contract guaranteed you started each pattern in the safe lane,
> so standing still was almost always the right answer.
>
> What is described below is the design being built toward. The playable build still contains
> the previous version's three-state gameplay; the rewrite is tracked in `ROADMAP.md`.

---

## Controls

| Key | Action |
| --- | --- |
| `SPACE` | Change lane |
| `ESC` | Pause / back |
| `↑` `↓` | Navigate menus |
| `←` `→` | Change a setting |
| `ENTER` | Confirm / retry |
| `F11` | Toggle fullscreen |

One key, one gesture. There is no jump, no second action, and there never will be.

---

## How it plays

**One question, two answers.** *Which lane?* — the floor or the ceiling. The difficulty is
entirely in seeing the answer coming and committing in time.

**A mistake costs ground, not the run.** This is the whole design in one line. Only two things
kill outright; everything else takes distance from you, and distance is all you have. It also
means the game is finally allowed to threaten **both** lanes at once — a mirrored pair of cubes
has no escape, only a choice about which price to pay. A design where every obstacle is lethal
can never do that, because two lethal lanes is an unsolvable pattern.

**The health bar is the screen.** The Corruption is a front advancing from the left, and the
gap between it and your character is exactly how much room you have left to make mistakes in.
No bar, no number, nothing to learn — you can read the state of the run from a thumbnail.

**Three dangers, three verbs.** The cube says *do not be here, or you pay*. The gap says *do
not be here*. The Sentinel — a beam across the middle of the corridor, harmless to anyone
standing on a lane — says *do not move right now*, which is the only question in the game that
is about what you are doing rather than where you are. Every pair of them makes a different
dilemma.

**The world is a track, not a backdrop.** Two lanes described by a spine and a span: move the
spine and the world undulates, move the span and the corridor tightens around you. The lanes
are derived from those two numbers, so they can never disagree with each other.

**The level is written in time, not pixels.** Obstacles are authored as "arrives 1.8 seconds
into this pattern", and screen position is derived each frame from the current scroll speed.
Speeding the game up never desynchronises a hand-authored pattern — which matters more than
usual here, because speed is something the *player* buys mid-run.

**Speed is a purchase, not a curve.** Since obstacles are events in time, scroll speed does not
change your reaction window at all — it changes how long you get to *look*. So it is not the
difficulty curve. Instead you spend collected fragments on it at a **Gate**: two doors, one per
lane, bought by choosing which one to run through. Faster means more depth per second, and it
also means every mistake costs more and the hard patterns arrive sooner.

**Colour has two systems and they never collide.** Depth moves the hue — the two worlds
converge toward one washed-out palette as a run gets deeper, so the colour you were reading the
game by fades exactly as it gets hardest. Corruption moves the saturation, and it moves through
space rather than time: the colour dies from the left, behind the front. Position and type of
motion carry you from there, which is why they were never allowed to be redundant with colour.

---

## Building and running

You need the [Odin compiler](https://odin-lang.org/docs/install/) on your `PATH`. raylib ships
with Odin as a vendor library — there is nothing else to install.

```bash
odin run src                        # build and play
odin build src -out:build/wakeshift
odin check src                      # type-check only, fast
```

The build target is the `src` directory, not `.` — `main.odin` lives inside it alongside the
package directories. Tested on Linux; Windows and macOS should work but are untested.

Progress and settings go to your OS user data directory, never next to the executable
(`$XDG_DATA_HOME/wake-shift/save.dat` on Linux). Delete that file to reset.

---

## Under the hood

**The simulation is deterministic, and that is a product feature rather than tidiness.** Seeded
generation, input recorded as data, and a fixed 60 Hz timestep mean a run is reproducible from
its seed and its input log alone. Every personal best is stored with the manifest that
reproduces it, which is what makes server-side leaderboard validation, replays and ghosts
possible later without changing anything.

**Saves are sealed, and the README will not oversell it.** The payload is CBOR sealed with
ChaCha20-Poly1305, and a file that fails to authenticate is rejected and reset rather than
trusted. But the key ships inside the binary, so this is a deterrent against editing a save in
a text editor — not security. The real defence is replaying the manifest on a server.

**Everything is drawn from primitives.** There are no art assets in this repository and there
will not be any. The whole look is one drawing primitive — a neon polyline with a bright core
and an additive halo — plus a palette and a real frame-wide bloom pass.

---

## Credits

Built by [@pankaspe](https://github.com/pankaspe) as an exercise in learning Odin, with
development assistance from Claude.

Gravity-flip is a well-worn subgenre (G-Switch, Gravity Guy and many others). The mechanic is
not what makes this one different; the Corruption at your back, and the fact that a mistake
takes ground instead of ending the run, are expected to do that work.

## License

Not chosen yet. Until one is added, no permissions are granted beyond reading the code.
