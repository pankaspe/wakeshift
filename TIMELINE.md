# TIMELINE — Wake Shift

Una riga per ogni pezzo di lavoro che atterra, in ordine. È storia, non un piano: il prossimo passo
lo decide l'autore, uno alla volta.

---

## 6 settembre 2026 — si riparte: il labirinto

Il gioco a due corsie è archiviato. Ha funzionato come esercizio di stile e ha prodotto un motore
grafico che ci teniamo tutto, ma il playtest ha detto la stessa cosa tre volte in tre modi diversi:
**scorre, non aggancia**. La ragione, misurata: il giocatore pensava un pensiero solo — "quale corsia
è libera" — dal primo metro al cinquemillesimo, e il generatore pescava da trenta frasi scritte a
mano, quindi dopo pochi minuti non c'era più niente da vedere.

La vecchia storia sta in `docs/archive/TIMELINE_v2_mattoncini.md`, le vecchie regole in
`docs/archive/CLAUDE_v2_mattoncini.md`. Si leggono per capire *perché* qualcosa era vero, mai per
sapere cosa costruire.

**La nuova forma.** Il corridoio fra pavimento e soffitto diventa un **labirinto procedurale
infinito** che scorre. Le due corsie non sono più posti dove stare: sono il bordo del labirinto. Si
comanda con **WASD / frecce** e si **scivola finché un muro non ferma**, quindi ogni input è un
impegno e non una correzione. La Corruzione resta e resta l'unica barra della vita. I **frammenti**
la rallentano. Una barra si carica e a pieno il mondo diventa **Onirico** per un tratto — più veloce,
più ricco, più pericoloso — poi torna Reale.

**Cosa teniamo, e non è poco.** Tutto `render/` tranne il terreno: tratto al neon, alone, bloom,
dither, particelle, la palette, la vignettatura, il blocco pieno che è il personaggio, i due fronti
come tagli. Tutto `core`, `platform`, `fx`, `ui`. La Corruzione come fronte e l'economia dei
frammenti. Passo fisso, seed esplicito, input come dato.

**Cosa muore.** `pattern.odin`, `skyline.odin`, quasi tutto `obstacle.odin`, `collision.odin` e
`render/terrain.odin`: circa 2800 righe. E con loro tutta la macchina di equità — finestre,
contenimento, coppie affacciate, il validatore — sostituita da **una sola invariante**: da dove sei,
esiste sempre un cammino verso destra.

**Tre decisioni prese oggi.** Il flip nell'Onirico è una **fase di ricompensa** (barra che si carica,
non verbo di navigazione). I frammenti fanno **un mestiere solo**: rallentano il fronte. Il movimento
è **scivolamento fino al muro**, non steering libero.

---

## In corso — la fase L

Si va a passi piccoli, uno alla volta, e si rivede il piano dopo ognuno.

| | Task | Note |
|---|---|---|
| **L1** | **La griglia e lo scivolamento** → Prototipo grezzo su un ramo: celle, muri, movimento a quattro direzioni che scivola fino all'ostacolo, la Corruzione che già c'è. Labirinto anche solo abbozzato. Serve a rispondere a una domanda sola: **a questa velocità un labirinto si legge e diverte?** | prima decisione: dimensione della cella e del corpo |
| **L2** | **Il generatore vero** → L'invariante del cammino garantito, poi rami e vicoli ciechi attorno. I parametri (densità, lunghezza dei muri, ramificazione, vicoli) sono continui e crescono con la distanza. | qui vive tutta la difficoltà |
| **L3** | **Frammenti e Corruzione nel labirinto** → L'economia riadattata: dove stanno i rombi in un labirinto perché costino qualcosa, e quanto rallentano il fronte. | |
| **L4** | **La barra e la fase Onirica** → Cosa carica la barra, quanto dura l'Onirico, e cosa cambia lassù oltre al colore (pilastro 6). | |
| **L5** | **Il disegno del labirinto** → I muri come tratto al neon. `STROKE_MAX_POINTS` e il costo delle draw call vanno **misurati**, non supposti: uno schermo di labirinto sono centinaia di segmenti corti invece di una polilinea lunga. | rischio tecnico noto |
| **L6** | **Punteggio, HUD, font** → Cosa si segna in un labirinto. Megrim (SIL OFL 1.1, nessun Reserved Font Name) in `assets/fonts/`, caricato dai byte così il binario resta autosufficiente. | |
| **L7** | **Audio** → Tenuto per ultimo per scelta dell'autore, che intanto prova il gioco con musiche diverse in sottofondo. | |

**Da sistemare quando il labirinto è reale**: il `RunManifest` registra solo i tick del flip, quindi
con quattro direzioni non riproduce più una run. Il record salvato (4998) è di un equilibrio che non
esiste più e non sarà comparabile.
