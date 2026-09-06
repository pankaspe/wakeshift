# Wake Shift — la lavagna

Il gioco è ripartito da zero il **6 settembre 2026**: labirinto procedurale a scorrimento. Qui c'è
solo cosa è fatto e cosa manca.

Lo **storico non sta più qui**: sta nei messaggi di commit (`git log`), che portano l'argomento per
intero, e il gioco a due corsie è in `docs/archive/`.

Si va a passi piccoli, uno alla volta, e si rivede il piano dopo ognuno.
Stato: ✅ fatto · 🟡 in parte · ⬜ da fare.

| | | Task | Modello | Note |
|---|---|---|---|---|
| ✅ | **L1** | **La griglia e lo scivolamento** → Celle, muri, movimento a quattro direzioni che scivola fino all'ostacolo, la Corruzione. Rispondeva a una domanda sola: **a questa velocità un labirinto si legge e diverte?** | Opus | cella 60, 12 righe, corpo 38. **Sì a entrambe**, in tre playtest. Taratura fine rimandata |
| 🟡 | **L2** | **Il generatore vero** → I parametri (densità, lunghezza dei muri, ramificazione, vicoli) sono continui e **crescono con la distanza**. | Opus | invariante, intreccio e misura ci sono. Mancano la crescita e la riparazione deterministica della trappola 1/1000 |
| ⬜ | **L3** | **I frammenti nel labirinto** → Dove stanno i rombi perché costino qualcosa. Il BFS del generatore dà già il costo di deviazione di ogni cella: si piazzano per misura. | Opus | |
| ⬜ | **L4** | **La barra e la fase Onirica** → Cosa carica la barra, quanto dura l'Onirico, e cosa cambia lassù oltre al colore (pilastro 6). | Opus | attraversamento di un muro + il fronte che arretra |
| ⬜ | **L5** | **Il disegno del labirinto** → I muri come tratto al neon. | Sonnet | il rischio tecnico è chiuso (82 tratti a schermo contro 562). Resta il giudizio estetico |
| ⬜ | **L6** | **Punteggio, HUD, font** → Cosa si segna in un labirinto. Megrim (SIL OFL 1.1) in `assets/fonts/`, caricato dai byte così il binario resta autosufficiente. | Sonnet | |
| ⬜ | **L7** | **Audio** → Tenuto per ultimo per scelta dell'autore. | Sonnet | |
| ⬜ | **L8** | **Livelli e portali** → Il livello è un checkpoint dentro una run continua: il fronte arretra, la barra resta, la difficoltà sale di un gradino, lo scroll non si ferma un frame. | Opus | ritocca l'economia del fronte |
| ⬜ | **L9** | **Allenamento** → Ogni livello raggiunto giocabile da solo, a seed fisso e senza Corruzione. | Sonnet | stesso generatore, seed noto, fronte spento |

L'ordine lo decide l'autore: la tabella dice cosa c'è da fare, non in che sequenza.

---

## Perché quel modello

La regola che divide la colonna è una sola: **Opus dove una risposta sbagliata è invisibile**, Sonnet
dove uno sbaglio si vede subito.

- **Opus** — misure, invarianti, economie. È la classe di lavoro dove il generatore si era
  autoapprovato su ogni chunk mentre il labirinto era murato, e dove i numeri della Corruzione erano
  calibrati contro un'economia già cancellata. Nessuna delle due cose dà errore, dà solo un gioco
  sbagliato.
- **Sonnet** — disegno, HUD, audio, un modo che riusa pezzi che esistono già. Se è storto lo vedi al
  primo avvio.

---

## Da sistemare quando il labirinto è reale

Il `RunManifest` registra solo i tick del flip, quindi con quattro direzioni **non riproduce più una
run** — e il tenere premuto è input di simulazione, quindi nemmeno le sole pressioni basterebbero. Il
record salvato (4998) è di un equilibrio che non esiste più e non sarà comparabile.

---

## Prossimo step consigliato

### **L3 + L4 assieme.**

Non separati, e l'argomento è strutturale: nel design i frammenti caricano la barra ed è **l'Onirico**
che fa arretrare il fronte. Fatto L3 da solo, raccogliere non restituisce un pixel di terreno e la run
resta un conto alla rovescia comunque si tarino i numeri. Sono le due metà di un anello solo:

> raccogli → entri nell'Onirico → recuperi terreno → scade → sei di nuovo sotto pressione

È anche l'unico modo di tarare la Corruzione contro qualcosa invece che contro il vuoto — l'errore
già commesso una volta e già disfatto una volta.
