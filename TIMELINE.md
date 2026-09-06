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

## 6 settembre 2026 — L1: la griglia, lo scivolamento, il generatore

Il gioco a due corsie esce dal codice: 11 file cancellati. Al suo posto una griglia di 12 righe da 60
px, il corpo che scivola in quattro direzioni finché un muro non lo ferma, e un generatore a chunk
che **misura** ogni chunk sul grafo delle scivolate e lo ritira se il costo di attraversamento cade
fuori banda. La telecamera corre da sola e non torna mai indietro. I muri sono spigoli, fusi in
polilinee prima di essere disegnati.

---

## In corso — la fase L

Si va a passi piccoli, uno alla volta, e si rivede il piano dopo ognuno. Lo stato si aggiorna a ogni
passo che atterra: ✅ fatto · 🟡 in parte · ⬜ da fare.

| | | Task | Note |
|---|---|---|---|
| ✅ | **L1** | **La griglia e lo scivolamento** → Celle, muri, movimento a quattro direzioni che scivola fino all'ostacolo, la Corruzione che già c'è. Serve a rispondere a una domanda sola: **a questa velocità un labirinto si legge e diverte?** | cella 60, 12 righe, corpo 38. Il codice c'è; **la domanda la risponde il playtest**, non il commit |
| 🟡 | **L2** | **Il generatore vero** → L'invariante del cammino garantito, poi rami e vicoli ciechi attorno. I parametri (densità, lunghezza dei muri, ramificazione, vicoli) sono continui e crescono con la distanza. | invariante, intreccio e misura ci sono. Mancano: i parametri che **crescono** con la distanza, e la riparazione deterministica della trappola 1/1000 |
| ⬜ | **L3** | **Frammenti e Corruzione nel labirinto** → Dove stanno i rombi in un labirinto perché costino qualcosa. Il BFS del generatore dà già il costo di deviazione di ogni cella: si piazzano per misura. | |
| ⬜ | **L4** | **La barra e la fase Onirica** → Cosa carica la barra, quanto dura l'Onirico, e cosa cambia lassù oltre al colore (pilastro 6). | attraversamento di un muro + il fronte che arretra |
| 🟡 | **L5** | **Il disegno del labirinto** → I muri come tratto al neon. `STROKE_MAX_POINTS` e il costo delle draw call vanno **misurati**, non supposti. | misurato: **82 tratti a schermo contro 562**, frame a 13,35 ms. Il rischio tecnico è chiuso; il giudizio estetico no |
| ⬜ | **L6** | **Punteggio, HUD, font** → Cosa si segna in un labirinto. Megrim (SIL OFL 1.1, nessun Reserved Font Name) in `assets/fonts/`, caricato dai byte così il binario resta autosufficiente. | |
| ⬜ | **L7** | **Audio** → Tenuto per ultimo per scelta dell'autore, che intanto prova il gioco con musiche diverse in sottofondo. | |
| ⬜ | **L8** | **Livelli e portali** → Il livello è un checkpoint dentro una run continua: il fronte arretra, la barra resta, la difficoltà sale di un gradino, lo scroll non si ferma un frame. | deciso il 6 settembre |
| ⬜ | **L9** | **Allenamento** → Ogni livello raggiunto giocabile da solo, a seed fisso e senza Corruzione. Stesso generatore, seed noto, fronte spento. | deciso il 6 settembre |

L'ordine dopo L1 lo decide l'autore: la tabella dice cosa c'è da fare, non in che sequenza.

**Da sistemare quando il labirinto è reale**: il `RunManifest` registra solo i tick del flip, quindi
con quattro direzioni **non riproduce più una run** — confermato con L1, e il tenere premuto è input
di simulazione che nemmeno le pressioni da sole basterebbero a ricostruire. Il record salvato (4998)
è di un equilibrio che non esiste più e non sarà comparabile.
