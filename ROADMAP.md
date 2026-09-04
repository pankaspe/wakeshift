# WAKE SHIFT — Roadmap v2.0

Piano operativo della riscrittura decisa il 4 settembre 2026. Il *cosa* e il *perché* stanno
in `docs/design_doc.md` **v2.0**; le regole di sviluppo in `CLAUDE.md`; qui c'è il *come e in
che ordine*.

---

## Come si legge

Ogni fase è un blocco di lavoro diviso in **task numerati** (`R<fase>.<n>`). Io scrivo il
codice, tu giochi e dai il giudizio, si itera, si passa avanti.
**Una fase alla volta, mai iniziare la successiva senza il tuo via.**

`⚑` = task che richiede un tuo playtest prima di chiudere la fase.

| Modello | Quando |
|---|---|
| **Sonnet** | Lavoro meccanico e già specificato: spostamenti file, cancellazioni, applicazione di uno schema definito, boilerplate, contenuto ripetitivo |
| **Opus** | Decisioni ancora aperte, architettura, macchine a stati, determinismo, matematica, regole di collisione, tuning |

Regola pratica: se il task si descrive in tre righe senza lasciare scelte aperte, è Sonnet.

**Quando una fase chiude**, la sua sezione si comprime subito: ✅ nel titolo, un paragrafo su
cosa è stato fatto, e solo le decisioni ancora vincolanti. La tabella dei task sparisce.
Quello che si è imparato non si butta, si **sposta dove verrà riletto**: una trappola di
libreria nel commento del file che la contiene, una regola di architettura in `CLAUDE.md`, un
dettaglio di gameplay nel design doc.

---

## Il passato — v1.x, chiuso

Nove fasi costruite fra il 2 e il 4 settembre 2026, tutte completate. Una riga a testa; il
codice che resta vivo è documentato in `CLAUDE.md`, il resto è in `git log`.

| | |
|---|---|
| **0** | Build sbloccata, `docs/` creata, roadmap e `CLAUDE.md` scritti |
| **1** | Package `core` / `platform` / `game` / `render` / `ui` con grafo aciclico |
| **2** | Salvataggio cifrato nella directory dati utente; simulazione deterministica e verificata (seed, input come dato, timestep fisso, `RunManifest`) |
| **2.5** | Fullscreen reale senza toccare il modo video, render target alla risoluzione nativa, opzioni persistite |
| **3** | Palette a tre mondi, nessun colore scritto a mano fuori da `core/palette.odin`, i due mondi disegnati insieme con l'orizzonte |
| **4** | Bloom vero su shader, 0.17 ms a frame nel caso peggiore |
| **5** | Il Limine giocabile e la Lucidity spendibile — **entrambi rimossi dalla v2.0** |
| **6** | Sette tipi di ostacolo con regole di collisione diverse — **ridotti a tre nella v2.0** |
| **7 / 7.5** | Contratto fra pattern a insiemi di fasce, difficoltà a tre manopole, il suolo come geometria, il tratto al neon, il Germoglio e le sue tre pose |
| **8.1** | La Corruzione come drenaggio passivo — **l'asse saturazione della palette sopravvive, il resto no** |

**Perché è stato riscritto.** Misurato, non stimato: su 200 run simulate senza mai toccare il
tasto, **161 sopravvivevano a tutto il primo tier** e la morte mediana arrivava a 35 secondi;
per l'**86% del tempo** niente sullo schermo poteva uccidere in nessuna posizione; **mai una
volta** su 24 000 secondi entrambe le corsie erano minacciate insieme. Non era taratura: era il
contratto fra i pattern che *garantiva* di entrare in ogni pattern dalla fascia sicura, quindi
non muoversi era la risposta giusta quasi sempre.

---

## Stato attuale

**Il codice a schermo è ancora la v1.3**: tre stati, Lucidity, sette ostacoli. La v2.0 esiste
solo come documento. Le fasi qui sotto sono la strada per allineare il codice al documento.

**Cosa sopravvive intatto e non va toccato**: tutto `platform/` (finestra, display,
salvataggio, cifratura, percorsi); `fx/bloom`; `render/stroke` e `render/glow`; i menu e le
opzioni; il timestep fisso, il recorder e il manifesto; l'asse saturazione della palette
costruito nella T8.1.

---

## Le fasi

### Fase R1 — Sfoltire

**Obiettivo**: togliere tutto ciò che la v2.0 non ha, prima di costruire. Si demolisce per
primo perché ogni fase successiva costa meno su una base più piccola, e perché il rischio è
basso: alla fine il gioco deve ancora compilare e girare, solo con meno cose dentro.

| Task | Descrizione | Modello |
|---|---|---|
| R1.1 | **Via il Limine**: `PlayerState.Suspended`, la distinzione tap/hold, `advance_suspension`, `input.flip_held`. Il flip diventa un viaggio e basta, `FLIP_DURATION` scende a ~0.16 s. Tocca la macchina a stati e il recorder (niente più `record_release`) | **Opus** |
| R1.2 | **Via la Lucidity**: cancellare `game/lucidity.odin`, il near-miss, il moltiplicatore, la soglia di sospensione, la barra nell'HUD. Il punteggio resta la sola distanza | Sonnet |
| R1.3 | **Via quattro ostacoli**: Feint, Forma pulsante, Pattugliatore, Gradino. `Block` → `Cube`, `Chasm` e `DreamHole` → `Gap`. Il pool di pattern si riduce a quelli che restano esprimibili | Sonnet |
| R1.4 | **Il contratto collassa**: da insiemi di fasce a una riga — *in ogni istante almeno una corsia dev'essere non letale*. `core.Bands` sparisce, `validate_pattern_pool` si riscrive attorno alla regola nuova | **Opus** |
| R1.5 ⚑ | Playtest: il gioco gira, due corsie, un gesto, e non è peggiorato rispetto a prima di iniziare | — |

**Ricaduta sul salvataggio**: `SAVE_FORMAT_VERSION` va alzata — sparisce la Lucidity dai dati
salvati. **I salvataggi esistenti diventano illeggibili e il record personale si perde.** È il
comportamento giusto (meglio azzerare che indovinare) ma va fatto sapendo cosa costa.
`GAME_VERSION` → `1.0.0-alpha`: qui la simulazione cambia tanto che la numerazione a 0.x non
significa più niente.

---

### Fase R2 — Il tira e molla

**Obiettivo**: la scommessa centrale del documento, costruita prima di tutto il resto. Il cubo
non uccide, blocca; mentre sei bloccato la Corruzione ti mangia terreno; la distanza fra te e
il fronte è tutta la salute che hai.

**Va per prima perché è l'unica affermazione del design doc che non si può verificare
leggendola.** O quel tira e molla è divertente, e allora ha senso costruirci sopra un
tracciato e un'economia, o non lo è, e allora è molto meglio scoprirlo adesso.

| Task | Descrizione | Modello |
|---|---|---|
| R2.1 | **La x del personaggio diventa variabile di gioco**. `core.PLAYER_X` da costante a posizione di riposo; il personaggio la insegue quando corre libero. Tocca tutto ciò che converte x in tempo di mondo (`ground_time_at_x`, `get_obstacle_position`), che è il punto delicato dell'intera fase | **Opus** |
| R2.2 | **Il fronte della Corruzione**: una posizione sullo schermo che avanza con la profondità fino a un margine minimo, e che uccide al contatto. `game/corruption.odin` | **Opus** |
| R2.3 | **Il blocco**: il cubo ferma il personaggio contro la sua faccia, che scorre col mondo, quindi si perde terreno alla velocità di scorrimento. Il tap libera. Recupero a ~2/3 della perdita | **Opus** |
| R2.4 | La Corruzione **si vede**: il colore che muore da sinistra, sull'asse saturazione già costruito nella T8.1, ora spaziale invece che globale | **Opus** |
| R2.5 | L'HUD sparisce: resta la Profondità e basta. La barra della vita è la distanza sullo schermo | Sonnet |
| R2.6 ⚑ | **Playtest, il più importante del progetto**: il tira e molla è divertente? Il blocco si legge? Il fronte fa paura senza essere ingiusto? Da qui escono i numeri di perdita/recupero e la posizione di riposo | — |

---

### Fase R3 — Il tracciato

**Obiettivo**: il mondo smette di essere una striscia dritta. Due corsie descritte da **spina**
(dov'è il centro del corridoio) e **spessore** (quanto è alto), autorate nel tempo come tutto
il resto.

| Task | Descrizione | Modello |
|---|---|---|
| R3.1 | `core/terrain.odin` → `core/track.odin`: spina e spessore, campionati nel tempo. Le due corsie derivano da loro, quindi la coerenza è per costruzione | **Opus** |
| R3.2 | `render/terrain.odin` segue: le due linee disegnate col tratto al neon, i buchi ritagliati dentro | Sonnet |
| R3.3 | Il tracciato diventa **parte del pattern**: un pattern dice dove passa il mondo per tutta la sua durata, non solo cosa ci sta sopra | **Opus** |
| R3.4 ⚑ | Playtest: la corsa non è più piatta, e il corridoio che si stringe si sente nei comandi senza confonderli | — |

**Vincoli da rispettare**: spessore fra ~240 e ~460 px; la spina resta abbastanza dentro lo
schermo da lasciare aria per lo sfondo; il flip dura sempre ~0.16 s **qualunque sia lo
spessore** — costante nel tempo, non nello spazio.

---

### Fase R4 — I tre pericoli

**Obiettivo**: tutta la varietà da tre elementi e tre verbi. *Il cubo costa, il buco uccide, la
Sentinella vieta di muoversi.*

| Task | Descrizione | Modello |
|---|---|---|
| R4.1 | Le varianti del cubo: singolo di lato n, pila, piramide, **cubo a specchio** (su entrambe le corsie — legale, perché non uccide) | Sonnet |
| R4.2 | Il cubo fluttuante dell'Onirico: sale e scende, a volte blocca e a volte ci passi sotto. L'unico ostacolo di tempismo del set | **Opus** |
| R4.3 | Il **buco**, largo, con bordi netti e pozzo scuro sul pavimento e bordi sfumati con bagliore sul soffitto | Sonnet |
| R4.4 | La **Sentinella**: raggio nella fascia centrale del corridoio, letale per chi attraversa e innocuo per chi sta fermo su una corsia | **Opus** |
| R4.5 | La validazione automatica della regola di equità: nessun istante con entrambe le corsie letali, nessuna Sentinella sopra un buco | **Opus** |
| R4.6 ⚑ | Playtest: i tre elementi si combinano in domande diverse, e il cubo a specchio si legge come una scelta e non come un bug | — |

---

### Fase R5 — I pattern e la difficoltà

**Obiettivo**: riempire il gioco. Un pool nuovo, e una curva di difficoltà che **non usa la
velocità**.

| Task | Descrizione | Modello |
|---|---|---|
| R5.1 | Il vocabolario dei pattern riscritto sulla v2.0: tracciato più eventi, contratto a una riga | **Opus** |
| R5.2 | Il pool: puntare a 20-25 pattern che sfruttino davvero le combinazioni dei tre pericoli | Sonnet |
| R5.3 | **La difficoltà avanza con la distanza, non col tempo** — così comprare Slancio compra punteggio e difficoltà insieme, gratis. Manopole: fronte della Corruzione, densità, complessità, spessore del corridoio, larghezza dei buchi | **Opus** |
| R5.4 | Un arnese usa-e-getta che rigioca il pool e misura *quanto tempo almeno una corsia è minacciata* — il numero che ha condannato la v1.3, da tenere sotto controllo da qui in avanti | **Opus** |
| R5.5 ⚑ | Playtest: la curva si sente, e restare fermi non porta da nessuna parte | — |

---

### Fase R6 — Frammenti e Varco

**Obiettivo**: la piccola economia dentro la run, spesa senza mai fermarsi e senza un secondo
tasto.

| Task | Descrizione | Modello |
|---|---|---|
| R6.1 | I **Frammenti**: luce piena, raccolti per posizione, piazzati dove costano qualcosa | Sonnet |
| R6.2 | Il **Varco**: due porte, una per corsia, con icona e prezzo disegnati nel mondo. Si compra passandoci dentro; porta spenta se non puoi permettertela; mai letale, mai un menu | **Opus** |
| R6.3 | I quattro potenziamenti — **Slancio**, **Respiro**, **Ariete**, **Richiamo** — validi solo per la run in corso | **Opus** |
| R6.4 | Piazzamento: ogni quanto arriva un Varco, e come il generatore mette i Frammenti sulla corsia scomoda | **Opus** |
| R6.5 ⚑ | Playtest: la domanda diventa "vale il rischio?", e Slancio è una scelta che si può rimpiangere | — |

---

### Fase R7 — Rifinitura

Quello che rende il gioco finito, in ordine di impatto. Da spacchettare in task quando ci si
arriva: farlo adesso sarebbe pianificare contro un gioco che non abbiamo ancora giocato.

- **Particelle** — `fx/particles.odin`, pool fisso pre-allocato, emitter parametrico. Preset
  Reale (polvere lineare) e Onirico (fluttuanti a spirale). Il blocco e la raccolta di un
  frammento sono i due momenti che le chiedono di più.
- **Game feel** — screen shake, squash & stretch, camera che reagisce, e la taratura finale di
  tutti i numeri.
- **Audio** — due tracce sincronizzate con crossfade sul flip (mai un cambio di brano); la
  Corruzione che toglie le alte e aggiunge un ronzio avvicinandosi; attrito sul blocco, non
  impatto.
- **UI** — un font vero al posto del bitmap di raylib, e il **Referto Onirico**: profondità,
  record, frammenti, cosa hai comprato, e **di cosa sei morto**.
- **Scenografia** — il primo strato disegnato col tratto al neon, in parallasse. *La
  scenografia è linea, il pericolo è massa.*

---

## La direzione artistica

Vincolante, non indicativa. `docs/sketch/sketch_3` **governa tutto**, gioco e schermate
(scelto il 3 settembre 2026), e `spirito_foresta` il personaggio. `sketch_1` e `sketch_2` sono
cave da cui prendere, non riferimenti. Tutto è raggiungibile con primitive più palette più
bloom: il progetto non ha asset grafici esterni e non ne avrà.

L'unico modo in cui questo stile può fallire è che sia **uniforme** — tutto morbido, tutto
dello stesso peso di linea. La regola che lo tiene leggibile:

- **la scenografia è linea** — contorni luminosi vuoti, sullo sfondo;
- **il pericolo è massa** — sagome scure piene con un bordo illuminato;
- **i Frammenti sono luce piena** — né l'una né l'altra: sono la sola cosa che si vuole toccare.

E l'incastro che tiene insieme grafica e meccanica: **la Corruzione è ciò che trasforma il
mondo da linea a massa.** Scenografia corrotta piena e scura, scenografia sana contorno
luminoso — così la regola visiva e la regola di gioco sono la stessa regola.

**Due assi del colore, da non far collidere mai**: la **tinta** si muove con la profondità (i
due mondi convergono), la **saturazione** con la Corruzione (e si muove nello spazio, da
sinistra).

---

## Il salvataggio: cosa resta da sapere

**Cifrare il salvataggio locale non rende sicura una leaderboard.** La chiave sta dentro il
binario e chiunque sia motivato la estrae. È un *deterrente* contro la modifica col blocco
note, non una garanzia: va detto così nel codice e a voce, mai spacciato per protezione.

**La sicurezza vera è rivalidare lato server**: il client manda seed e log degli input, il
server rigioca la run e calcola il punteggio da sé. Il punteggio dichiarato dal client non
viene mai creduto. Il `RunManifest` che ogni record salva è già quel pacchetto.

| Attacco | Difesa |
|---|---|
| Modifica del file col blocco note | Tag AEAD → salvataggio rifiutato ✅ |
| Estrazione della chiave dal binario | **Nessuna difesa locale possibile.** Solo rivalidazione server |
| Punteggio inventato inviato al server | Il server rigioca il manifesto ✅ |
| Manifesto fabbricato da un bot che gioca davvero | Rate limiting e flag statistici. Fuori scope alpha |

Per questo il determinismo è una **feature di prodotto** e non pulizia: compra la validazione
delle classifiche, i replay, i ghost e il bilanciamento riproducibile. Non va indebolito per
comodità.

---

## Definition of Done — Alpha v2.0

- [ ] Un tasto, un gesto, due corsie
- [ ] Il tracciato curva e il corridoio si stringe
- [ ] Cubo, buco e Sentinella, con le loro varianti
- [ ] La Corruzione insegue, si vede, e un errore costa terreno invece della run
- [ ] Frammenti e Varco funzionanti, quattro potenziamenti
- [ ] Difficoltà che cresce con la distanza, senza che la velocità cresca da sola
- [ ] Almeno una corsia minacciata per **oltre il 40% del tempo** (il numero che la v1.3
      falliva con l'86% di aria morta)
- [ ] Restare fermi non porta da nessuna parte
- [ ] Particelle, audio, font vero, Referto Onirico
- [ ] Determinismo intatto e verificato
