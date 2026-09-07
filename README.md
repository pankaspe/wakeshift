# Wake Shift

A procedural maze you run through at speed, while the world goes out behind you — written in
[Odin](https://odin-lang.org/) with [raylib](https://www.raylib.com/), no engine.

![Version](https://img.shields.io/badge/version-0.8.0--alpha-blue)
![Language](https://img.shields.io/badge/Odin-dev--2026--07-blue)
![Library](https://img.shields.io/badge/raylib-5.5-green)
![Status](https://img.shields.io/badge/status-maze%20phase-orange)

---

## The game

A maze on a grid, seen from above, scrolling past you. You move with **WASD / arrows** and you
**slide until a wall stops you**, so every input is a commitment rather than a steering correction —
you can only turn where something stops you, and a junction in the middle of a corridor is passed
over, not turned at.

Behind you the **Corruption** advances through the world and ends the run when it reaches you. The
distance between the two is the only health bar there is: run well and you push it clean off the
screen, which buys you the seconds you need to read the maze; hesitate, backtrack badly or stall and
it comes back into view. Its absence *is* the reading — there is no meter.

---

## The loop

**Fragments** lie in the maze off the shortest line. Picking them up charges a bar and does nothing
else; when the bar fills, the world turns **Dream**.

Up there two things change and only two. A slide **goes through the wall that stopped it** and runs
on to the next, so the move is still a commitment and the reading got harder — you have to choose
*which* wall and look two cells further than you were looking. And the Corruption **runs backwards**,
which is what makes the Dream the place ground is bought back rather than a light show. The bar
drains while it lasts; **Lucids**, which exist only up there and sit where the walking maze cannot
reach them, push it back up.

Going through a wall opens it and *leaves it open* — drawn afterwards as a wall with its middle
missing, which is a shape the generator can never make. Fragments vanish and Lucids appear at the
moment the world turns. So with the colour off entirely you can still tell which world you are in by
what the body does, by what the maze is offering, and by the holes behind you. That is the point: the
theme has to change the mechanics, not just the palette.

Levels are designed and not yet built, and the loop's four numbers — how many fragments fill the bar,
how long the Dream lasts, how fast the front retreats, what a Lucid is worth — are first drafts drawn
against a measured income and meant to be played rather than read.
**[TIMELINE.md](TIMELINE.md)** says where each piece stands.

---

## The generator

The corridor is a grid of 12 rows of 60 px with columns running on forever, cut into **chunks of 32
columns**. Each cell owns its north and west wall — two bits, 384 bytes a chunk — so the two sides of
one wall can never drift apart. Walls are edges, never solid cells: only the field and the player are
filled.

A chunk is built and verified **entirely on its own**, in any order:

1. **Seams are hashed, not handed forward.** The holes on a chunk boundary are a function of that
   boundary's column index alone, so neighbouring chunks agree without ever meeting — and a chunk
   evicted from the ring buffer comes back identical.
2. **Carve** a spanning tree with randomised Kruskal, weighting horizontal walls so they survive
   longer. That is what makes corridors run with the scroll instead of across it.
3. **Braid** it: open a fraction of the dead ends so a wrong branch rejoins the maze. A *perfect*
   maze — the tree a plain DFS carve gives you — is exactly wrong here. With no way to turn round
   against the scroll, a dead end does not cost time, it kills.
4. **Measure it on the slide graph**, not on cell adjacency, because a press travels until a wall
   stops it and the player can only stop where something stops them. Dijkstra gives the cheapest
   crossing in cells travelled and in slides taken; a backward reachability pass proves that every
   cell you can get to, you can still get out of.
5. **Accept or re-roll** with another sub-seed until the crossing lands in the band the level asked
   for. The loop is deterministic from the seed, so the run stays reproducible.
6. **Repair rather than re-roll** anything that broke the invariant. Re-rolling is the right tool
   for the difficulty band — a chunk outside it is still a chunk — and the wrong one for a pocket,
   since more attempts can only make *never* rarer. So walls come down one at a time, at the cell
   furthest along that cannot reach a crossing, re-measuring after every single one because opening
   a wall lengthens a slide as well as adding a move.
7. **Place the pickups by measure**, on the chunk that won. The same search prices every cell, so
   "somewhere that costs about half a second of detour" is a question to ask rather than a place to
   guess — and the risk/reward junction the design turns on is selected rather than decorated. The
   price asked for is the cost of a whole crossing that *drives over* the cell, not of stopping on
   it: a pickup is taken by passing over it, and a slide passes over every cell between its ends.

The invariant is deliberately stronger than *a path exists*: the world moves whether the player is
making progress or not, so it is **a path exists that arrives in time**. Measured over 1000 chunks —
0 unsolvable, mean crossing at a third of the time available, 5.8 ms of generation for every 7
seconds of play.

Verified by a solver over the *assembled* world rather than over one chunk, which is the only thing
that can contradict a measurement grading its own homework. It used to say 3.18% of the cells
reachable from the start were cells no route leaves — every chunk reporting green while the world
held dead ends — and it now says **0 over 13533 reachable cells**. What is left for the generator is
making its knobs grow with distance.

---

## The look

**La Linea**, the cartoon by [Osvaldo Cavandoli](https://en.wikipedia.org/wiki/La_Linea_(TV_series)):
a man who walks along a single continuous line that *is* his world, drawn ahead of him and rubbed out
behind. That is not a reference bolted on — it is this game's premise, told by somebody else fifty
years earlier.

Everything on screen is one stroke — a neon polyline with a bright core and an additive halo — on a
filled, vignetted field, with a real frame-wide bloom over the finished frame. The world is
**written** by a pen near the right edge and **unwritten** by the Corruption behind. Collinear walls
are welded into runs before drawing: 82 strokes a screen instead of 562.

Apart from one open-licence font, there are no art assets and there will not be any.

---

## Build

```bash
odin check src                        # type-check, fast
odin build src -out:build/wakeshift   # build
odin run src                          # play
```

Odin `dev-2026-07`, raylib 5.5 via `vendor:raylib/v55`, no other dependencies. Saves are CBOR sealed
with ChaCha20-Poly1305 — a deterrent against editing a save by hand, not security, since the key
ships in the binary. The simulation is deterministic by design: seeded generation, input as data and
a fixed 60 Hz step, which is what makes server-side score validation and replays possible later.

---

## Credits

Built by [@pankaspe](https://github.com/pankaspe) as an exercise in learning Odin, with development
assistance from Claude.

Megrim by Daniel Johnson, under the SIL Open Font License 1.1 (`assets/fonts/OFL.txt`).

*La Linea* and its character are the property of their rights holders. Nothing here copies them: the
debt is to the idea of a world made of one line, and the figure on screen is our own.

**License: not chosen yet** — see [LICENSE](LICENSE). Until that file exists, no permissions are
granted beyond reading the code.
