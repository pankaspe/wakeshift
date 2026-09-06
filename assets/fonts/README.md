# Fonts

**Megrim-Regular.ttf** — Copyright (c) 2009, 2010, 2011 Daniel Johnson, licensed under the
SIL Open Font License 1.1 (`OFL.txt`, which must ship alongside the font).

No Reserved Font Name is declared, so the face may be used, embedded, modified and redistributed
with the game. It may not be sold on its own. Keep `OFL.txt` next to it and keep the copyright
notice wherever the game credits its assets.

It is a **display** face — thin and geometric, which suits La Linea, and which is exactly why its
legibility at HUD sizes has to be looked at rather than assumed (pillar 2).

Load it from bytes rather than from disk (`#load` plus `rl.LoadFontFromMemory`) so the built binary
stays self-contained.
