# WAKE SHIFT — Roadmap verso l'Alpha giocabile

> Documento di lavoro personale, in italiano. Non fa parte della documentazione pubblica del progetto e va rimosso dal repository prima di una eventuale pubblicazione.
>
> Il *cosa e perché* sta in `docs/design_doc.md` (v1.1). Le regole operative di sviluppo stanno in `CLAUDE.md`. Questo file è il *come, in che ordine, e con quale modello*.

---

## Indice

- [Come si legge questa roadmap](#come-si-legge-questa-roadmap)
- [Stato attuale](#stato-attuale)
- [Il sistema a tre mondi](#il-sistema-a-tre-mondi--riferimento-grafico-trasversale)
- [Il salvataggio: analisi](#il-salvataggio-analisi-e-decisioni)
- [Struttura del progetto](#struttura-del-progetto-da-qui-a-lì)
- [Le fasi](#le-fasi)
- [Riepilogo carico per modello](#riepilogo-carico-per-modello)
- [Definition of Done — Alpha](#definition-of-done--alpha)

---

## Come si legge questa roadmap

Ogni fase è un blocco di lavoro; ogni fase è divisa in **task numerati** (`T<fase>.<n>`).
Il flusso è sempre lo stesso: io scrivo il codice, tu testi a schermo, iteriamo, poi si passa avanti.
**Una fase alla volta, mai iniziare la successiva senza il tuo via.**

### Assegnazione dei modelli

Ogni task porta il modello consigliato, per ottimizzare il piano Pro.

| Modello | Quando |
|---|---|
| **Sonnet** | Lavoro meccanico e già specificato: spostamenti file, applicazione di un pattern definito, ricolorazione contro una tabella data, boilerplate, funzioni pure con spec chiara, contenuto ripetitivo (pattern, preset di particelle) |
| **Opus** | Decisioni ancora aperte, architettura, macchine a stati, determinismo, matematica di shader, regole di collisione, tuning del game feel — tutto ciò dove *cosa* costruire non è del tutto fissato, o dove un bug sottile sarebbe difficile da individuare a occhio |

Regola pratica: se il task si può descrivere completamente in tre righe senza lasciare scelte aperte, è **Sonnet**. Se richiede di decidere qualcosa mentre lo si costruisce, è **Opus**.

`⚑` segnala i task che richiedono un tuo playtest prima di poter chiudere la fase.

---

## Stato attuale

Verificato sul codice, 2 settembre 2026 — aggiornato a chiusura Fase 1.

**Funziona**
- Loop one-button: corsa automatica, `SPACE` inverte la gravità, due corsie
- Ostacoli come **eventi nel tempo** (`arrival_time`), non posizioni in pixel — la scelta architetturale migliore del progetto
- Pattern concatenati con `entry_lane`/`exit_lane`: il generatore non può produrre sequenze irrisolvibili
- Lucidity: streak di near-miss → moltiplicatore fino a +100%
- 3 tier di difficoltà con pool cumulative
- Canvas virtuale 1280×720 letterboxato → fullscreen pulito su qualsiasi monitor
- Menu, pausa, game over, salvataggio record
- **[Fase 1]** Codice riorganizzato nei sette package (`core/platform/fx/game/render/ui/audio`, `fx` e `audio` ancora vuoti) con grafo di dipendenze aciclico; `main.odin` ricablato, `draw_gameplay` estratto

**Non funziona / manca**
- Ogni ostacolo pone la stessa domanda: l'unica leva di difficoltà è la velocità (270 → 330 → 400 px/s)
- I 4 tipi di ostacolo sono **un tipo solo con 4 skin**: `Chasm` e `DreamHole` usano la stessa identica collisione di `Block`
- Il "pieno vs vuoto" non esiste: la voragine è disegnata a `y = 720 - 54 = 666`, la linea del pavimento sta a ~690-706 → **sporge dal terreno di 25-40px, è un blocco in piedi, non un buco**
- La Lucidity è un cricchetto: sale e non scende mai
- La fascia centrale (40% dello schermo) è inutilizzata
- Sfondo `rl.ClearBackground(rl.BEIGE)`, contorni neri da 1.8px
- Nessuna particella, nessun bloom, nessun parallax, nessun audio
- Salvataggio in chiaro (`highscore.txt`) nella cartella di lavoro

---

## Il sistema a tre mondi — riferimento grafico trasversale

Riferimento vincolante per tutto il lavoro grafico. Le fasi 3, 4, 5, 8, 9 lo citano.

### Il principio

I due mondi sono **sempre entrambi visibili** — Onirico in alto, Reale in basso, che si incontrano in una fascia di orizzonte al centro. Quello che cambia con la posizione del giocatore non è *quale* mondo si vede, ma **quale dei due è vivo e quale sta sbiadendo**. Salendo, l'onirico fiorisce (satura, si illumina, respira) e il reale si spegne. E viceversa. Nel mezzo entrambi sono presenti a metà intensità e la palette si sbianca: è il momento di soglia.

### La variabile che guida tutto

```
world_t = 1 - (player_center_y / SCREEN_HEIGHT)
```

`0.0` = pavimento (Reale puro) · `0.5` = centro (Limine puro) · `1.0` = soffitto (Onirico puro)

È **continua, non a scatti**. Non esiste nessun momento di "switch" della palette: è questo che rende il flip un'esperienza visiva invece di un cambio di stato.

### Le tre palette (valori di partenza, da affinare a schermo)

| Ruolo | **Reale** (freddo, duro) | **Limine** (slavato, sovraesposto) | **Onirico** (caldo, diffuso) |
|---|---|---|---|
| Fondo profondo | `#0B0F17` | `#1A1B26` | `#2A0D33` |
| Fondo vicino | `#182231` | `#3A3550` | `#4E1B5C` |
| Silhouette | `#05070B` | `#0A0910` | `#0B0410` |
| Luce / rim | `#8FB8E8` azzurro freddo | `#F0E6D2` bianco caldo pallido | `#FFAE5C` oro caldo |
| Accento | `#D8E8FF` | `#FFF6E0` | `#FF6FBE` rosa acceso |

Con `world_t ≤ 0.5` si interpola Reale→Limine su `world_t * 2`; con `world_t > 0.5` si interpola Limine→Onirico su `(world_t - 0.5) * 2`. **Nessun colore scritto a mano fuori da `render/palette.odin`.**

### Due vincoli non negoziabili

- **Silhouette unica**: il personaggio è la stessa sagoma scura nei tre stati; cambia solo la luce (rim e glow prendono il colore del mondo corrente). Oggi il codice fa il contrario e va corretto.
- **Mai il colore da solo**: i tre stati devono restare distinguibili anche da **posizione** e **tipo di movimento** (lineare nel Reale, fluttuante nell'Onirico, sospeso e ondeggiante nel Limine), oltre che dalla densità e dal comportamento delle particelle.

---

## Il salvataggio: analisi e decisioni

Hai chiesto di studiare il tema in ottica leaderboard online. Ecco cosa ho trovato e cosa propongo.

### I tre problemi di oggi

1. `highscore.txt` è **testo in chiaro**: si modifica col blocco note.
2. Sta nella **cartella di lavoro**: cambia a seconda di dove lanci il gioco, si perde, si duplica.
3. Era **versionato in git** (risolto: ora è in `.gitignore` e rimosso dall'indice).

### Cosa offre Odin

La standard library è messa bene, ho verificato: `core:crypto` include `hmac`, `sha2`, `chacha20poly1305`, `ed25519`, `argon2id`; `core:encoding` include `cbor` per un formato binario compatto. Non serve nessuna dipendenza esterna.

### La cosa importante da dire chiaramente

**Cifrare il salvataggio locale non rende sicura una leaderboard.** La chiave deve stare dentro il binario, e chiunque sia motivato la estrae. È un *deterrente*, non una garanzia: ferma la modifica casuale, non un cheater vero. È giusto farlo — è sbagliato considerarlo protezione.

La sicurezza vera è **rivalidare lato server**, ed è già descritta correttamente nel design doc (sez. 10): il client manda **seed + log degli input**, il server rigioca la run internamente e calcola il punteggio da sé. Il punteggio dichiarato dal client non viene mai creduto.

Perché questo funzioni servono tre cose, tutte da mettere in piedi **prima** che il codice cresca:

1. **RNG con seed esplicito** — mai `rand.*` globale
2. **Input come dato** — la logica riceve uno stato di input, non interroga la tastiera al suo interno
3. **Timestep fisso** — a passo variabile la stessa sequenza di input non produce la stessa run

Un investimento, quattro ritorni: **validazione leaderboard, replay, ghost delle run migliori, bilanciamento riproducibile** (rigiochi la stessa run identica dopo aver cambiato un numero). Per questo la Fase 2 viene prima di tutto il lavoro grafico.

### Decisioni proposte

| Aspetto | Decisione | Perché |
|---|---|---|
| Posizione | Directory dati utente del SO: `$XDG_DATA_HOME/wake-shift/` (Linux), `%APPDATA%\wake-shift\` (Windows), `~/Library/Application Support/wake-shift/` (macOS) | Convenzione corretta; non dipende dalla cartella di lancio |
| Formato | CBOR (`core:encoding/cbor`) | Compatto, versionabile, già nella stdlib |
| Protezione | **ChaCha20-Poly1305** (`core:crypto`), chiave incorporata + nonce casuale per salvataggio | Cifratura *e* integrità in una primitiva sola. Soddisfa la richiesta di "criptato" e dà tamper-evidence nello stesso passo |
| Salvataggio corrotto | Rifiutato → si riparte dai default, con avviso | Un file manomesso non deve mai far crashare il gioco |
| Manifesto della run | Salvato per la run migliore: `seed`, `game_version`, `tick_rate`, log degli input, `claimed_depth` | È il pacchetto che un domani si manda al server. Gratis: ti dà anche i replay/ghost |

**Alternativa considerata e scartata**: solo HMAC-SHA256 senza cifratura. Dà la stessa tamper-evidence e lascia il file leggibile per il debug — più semplice, tecnicamente sufficiente. L'ho scartata perché hai chiesto esplicitamente il file criptato, e AEAD costa lo stesso sforzo dandoti entrambe le cose. Se in fase di sviluppo il file opaco ti dà fastidio da ispezionare, si torna a HMAC in mezz'ora.

### Modello di minaccia, onesto

| Attacco | Difesa |
|---|---|
| Modifica del file col blocco note | Tag AEAD → salvataggio rifiutato ✅ |
| Estrazione della chiave dal binario | **Nessuna difesa locale possibile.** Solo rivalidazione server |
| Punteggio inventato inviato al server | Il server rigioca il manifesto: niente manifesto valido, niente punteggio ✅ |
| Manifesto fabbricato da un bot che gioca davvero | Rate limiting + flag statistici su punteggi anomali. Fuori scope alpha |

---

## Struttura del progetto: da qui a lì

### Perché non seguiamo la struttura del design doc originale

La v1.0 prevedeva `player/`, `obstacles/`, `patterns/`, `world/` come package separati. **In Odin non funziona**: import ciclici vietati, e una cartella è esattamente un package. Quelle entità si guardano continuamente (`score` legge `Player`, `lucidity` legge `Player` *e* `Obstacle`, `obstacle` legge `World`, le collisioni leggono tutto). Il taglio giusto è **per livello di astrazione, non per entità**. La correzione è già recepita nel design doc v1.1, sez. 14.

### Struttura di destinazione

```
wake-shift/
├── CLAUDE.md          ROADMAP.md          README.md          .gitignore
├── docs/
│   ├── design_doc.md              # v1.1
│   └── archive/                   # roadmap superate
├── assets/                        # (dalla Fase 11: audio)
└── src/
    ├── main.odin      # package main — finestra, loop, macchina a stati
    ├── core/          # Lane, costanti schermo, easing, math, timer
    ├── platform/      # canvas virtuale, fullscreen, input, persistenza
    ├── fx/            # particelle, bloom — parametrico, ignora il gioco
    ├── game/          # player, world, obstacle, pattern, difficulty,
    │                  #   score, lucidity, collisioni — MAI un disegno
    ├── render/        # palette, sfondo, terreno, player, ostacoli, parallax
    ├── ui/            # menu, HUD, schermate
    └── audio/         # musica con crossfade, SFX
```

### Grafo delle dipendenze — rigorosamente aciclico

```
core      ← non importa nulla del progetto
platform  ← core
fx        ← core
game      ← core, platform, fx
render    ← core, game, fx
ui        ← core, game
audio     ← core, game
main      ← tutti
```

**Regole d'oro**: `game/` non disegna mai; `render/` non muta mai stato; `fx/` non sa niente del gioco.

### Tabella di migrazione

| Oggi | Domani | Package |
|---|---|---|
| `src/main.odin` | `src/main.odin` | `main` |
| `src/core/core.odin` | `src/core/lane.odin`, `screen.odin`, `ease.odin` | `core` |
| `src/display/display.odin` | `src/platform/display.odin` | `platform` |
| `src/persistence.odin` | `src/platform/save.odin` | `platform` |
| — nuovo — | `src/platform/input.odin`, `src/platform/paths.odin` | `platform` |
| `src/world.odin` | `src/game/world.odin` | `game` |
| `src/player.odin` | `src/game/player.odin` | `game` |
| `src/obstacle.odin` | `src/game/obstacle.odin` | `game` |
| `src/pattern.odin` | `src/game/pattern.odin` | `game` |
| `src/difficulty.odin` | `src/game/difficulty.odin` | `game` |
| `src/score.odin` | `src/game/score.odin` | `game` |
| `src/lucidity.odin` | `src/game/lucidity.odin` | `game` |
| `src/game.odin` | `src/game/collision.odin` + `src/game/run.odin` | `game` |
| `src/player_render.odin` | `src/render/player.odin` | `render` |
| `src/obstacle_render.odin` | `src/render/obstacle.odin` | `render` |
| `src/terrain.odin` | `src/render/terrain.odin` | `render` |
| — nuovo — | `src/render/palette.odin`, `src/render/background.odin` | `render` |
| `src/menu.odin` | `src/ui/menu.odin` | `ui` |
| `src/ui.odin` | `src/ui/screens.odin` | `ui` |
| — nuovo — | `src/fx/particles.odin`, `src/fx/bloom.odin` | `fx` |

---

## Le fasi

### ✅ Fase 0 — Sbloccare la build *(completata)*

| Task | Descrizione | Modello |
|---|---|---|
| T0.1 | `world` riportato in `package main`, `odin check` verde, gioco avviabile | Opus ✅ |
| T0.2 | `docs/`, `.gitignore`, `highscore.txt` rimosso dall'indice git | Sonnet ✅ |
| T0.3 | Design doc aggiornato alla v1.1, `CLAUDE.md` e `ROADMAP.md` creati | Opus ✅ |

---

### ✅ Fase 1 — Struttura del progetto *(completata)*

**Obiettivo**: mettere la casa in ordine prima che ci si accumulino sopra shader, particelle e parallax. Più codice grafico si stratifica su una struttura piatta, più il refactor dopo costa.

| Task | Descrizione | Modello |
|---|---|---|
| T1.1 | `core/` diviso in `lane.odin`, `screen.odin`, `ease.odin` | Sonnet ✅ |
| T1.2 | `platform/`: sposta `display.odin` e `persistence.odin` | Sonnet ✅ |
| T1.3 | **`game/`**: sposta world, player, obstacle, pattern, difficulty, score, lucidity; dividi `game.odin` in `collision.odin` + `run.odin` | **Opus** ✅ |
| T1.4 | `render/`: sposta i tre file di disegno | Sonnet ✅ |
| T1.5 | `ui/`: sposta menu e schermate | Sonnet ✅ |
| T1.6 | `main.odin` ricablato sui nuovi package; `draw_gameplay` estratto (oggi il blocco DRAW ripete lo stesso disegno tre volte) | Sonnet ✅ |
| T1.7 ⚑ | Verifica di non-regressione: il gioco gira **identico** a prima | Sonnet ✅ |

**Perché T1.3 è Opus**: è il task con la più alta probabilità di rottura silenziosa. Nove file che oggi si vedono liberamente dentro `package main` diventano un package con confini veri; stato condiviso che smette di essere condiviso non dà errore di compilazione, dà un bug.

**Test di verifica**: `odin check src` verde dopo *ogni* task, e il gioco percepibilmente identico a fine fase. Se noti una differenza, è un bug.

---

### Fase 2 — Salvataggio sicuro e determinismo

**Obiettivo**: le fondamenta invisibili. Nessun cambiamento a schermo, ma senza queste la leaderboard di domani è impossibile e il bilanciamento di dopodomani è cieco.

| Task | Descrizione | Modello |
|---|---|---|
| T2.1 | `platform/paths.odin`: directory dati utente per SO, con creazione della cartella | Sonnet |
| T2.2 | `SaveData` + serializzazione CBOR, versionata | Sonnet |
| T2.3 | Cifratura ChaCha20-Poly1305, nonce per salvataggio, gestione del file corrotto/manomesso senza crash | **Opus** |
| T2.4 | Migrazione trasparente dal vecchio `highscore.txt`, poi rimozione | Sonnet |
| T2.5 | **Input come struct** `platform.Input` passato dall'esterno; via `rl.IsKeyPressed` da dentro la logica | **Opus** |
| T2.6 | RNG con seed esplicito filtrato nel generatore di pattern | Sonnet |
| T2.7 | **Timestep fisso** con accumulatore | **Opus** |
| T2.8 | `RunManifest`: seed, versione, tick rate, log input, punteggio dichiarato — registrato durante la run e salvato per il record | **Opus** |
| T2.9 | Rimozione degli ostacoli ormai passati dalla lista (oggi non vengono mai eliminati: dopo 5 minuti ne cicli ~300 a frame) | Sonnet |
| T2.10 ⚑ | Verifica: due run con lo stesso seed e lo stesso log input producono lo stesso punteggio | Sonnet |

**Perché T2.5 e T2.7 sono Opus**: toccano entrambi la macchina a stati del player, e T2.5 è il prerequisito diretto del gesto tap/hold della Fase 5. Il timestep fisso cambia sottilmente il *feel* — va fatto con attenzione all'interpolazione del rendering.

---

### Fase 3 — Palette e fondamenta visive

**Obiettivo**: il salto visivo più grande della roadmap, prima di qualsiasi shader. Riferimento: [Il sistema a tre mondi](#il-sistema-a-tre-mondi--riferimento-grafico-trasversale).

| Task | Descrizione | Modello |
|---|---|---|
| T3.1 | `render/palette.odin`: tre palette, `world_t`, interpolazione continua | **Opus** |
| T3.2 | `render/background.odin`: gradiente verticale Onirico→orizzonte→Reale, intensità e saturazione guidate da `world_t` | **Opus** |
| T3.3 | Terreno ricolorato su palette, rim light per mondo | Sonnet |
| T3.4 | Ostacoli ricolorati su palette | Sonnet |
| T3.5 | Player: silhouette unica nei tre stati, rim light del mondo corrente (corregge l'inversione corpo/bordo attuale) | Sonnet |
| T3.6 | Glow additivo economico: 3-4 draw sovrapposti in `BLEND_ADDITIVE` con alpha decrescente | **Opus** |
| T3.7 | HUD e menu ricolorati, leggibilità su fondo scuro | Sonnet |
| T3.8 ⚑ | Playtest visivo | — |

**Nota**: `world_t` a questo punto varia solo durante i 0.12s del flip. Il sistema è già completo e continuo, ma brillerà davvero alla Fase 5, quando il giocatore potrà fermarsi nel mezzo.

**Test di verifica**: uno screenshot deve smettere di sembrare un prototipo. Il flip deve *sentirsi* come un attraversamento, non come uno scatto.

---

### Fase 4 — Bloom reale

**Obiettivo**: la direzione "Ori" vera, sul render target che già esiste in `platform/display.odin`.

| Task | Descrizione | Modello |
|---|---|---|
| T4.1 | Shader GLSL: bright-pass + blur gaussiano separabile | **Opus** |
| T4.2 | Composite additivo, intensità modulata da `world_t`: duro e contenuto nel Reale, morbido e invadente nell'Onirico, sovraesposto nel Limine | **Opus** |
| T4.3 | Verifica 60 FPS stabili con bloom attivo | Sonnet |
| T4.4 ⚑ | Playtest di leggibilità a 400 px/s | — |

**Test di verifica**: il glow non deve compromettere la leggibilità alla massima velocità. Se devo scegliere tra bello e leggibile, vince leggibile.

---

### Fase 5 — Il Limine: il terzo stato

**Obiettivo**: il cuore dell'evoluzione. Qui il gioco smette di essere un clone di flip-gravity. Dipende da T2.5 (input come struct).

| Task | Descrizione | Modello |
|---|---|---|
| T5.1 | Riconoscimento tap vs hold sulla barra spaziatrice | **Opus** |
| T5.2 | Fisica della sospensione: arresto a metà viaggio, ondeggio, completamento alla direzione di marcia al rilascio | **Opus** |
| T5.3 | Lucidity come carburante: consumo nel Limine, accumulo dai near-miss, soglia minima | **Opus** |
| T5.4 | Ritmo di punteggio del Limine (40/s) | Sonnet |
| T5.5 | HUD: la Lucidity diventa una barra di risorsa, non un numero | Sonnet |
| T5.6 | Feedback visivo della sospensione (luce, ondeggio, scia) | Sonnet |
| T5.7 ⚑ | **Playtest decisivo**: il gesto deve risultare naturale entro 30 secondi senza spiegazioni | — |

**Squilibrio noto e voluto**: a fine fase il centro è **sicuro**, perché tutti gli ostacoli attuali sono alti 54px e attaccati alle pareti. Il Limine sarà temporaneamente troppo forte; si chiude alla Fase 6 (T6.5). Nel frattempo il consumo di Lucidity va tarato aggressivo.

**Se T5.7 non passa**, si ridiscute il gesto prima di costruirci sopra qualsiasi altra cosa.

---

### Fase 6 — Ostacoli veri: pieno vs vuoto

**Obiettivo**: smettere di avere quattro skin dello stesso ostacolo, e recuperare l'idea tematica centrale del design doc.

| Task | Descrizione | Modello |
|---|---|---|
| T6.1 | Terreno interrompibile: il disegno del suolo deve sapere dove sono i vuoti | **Opus** |
| T6.2 | `Chasm` e `DreamHole` diventano **vere assenze**, disegnate come buchi reali | **Opus** |
| T6.3 | Regole di collisione differenziate: il blocco uccide al contatto, la voragine solo se sei nella corsia bassa e appoggiato | **Opus** |
| T6.4 | Fix `PulsingShape`: fase ancorata all'`arrival_time` invece che al tempo globale (oggi lo stesso pattern è a volte un muro da 55px, a volte uno stub da 8px ignorabile) | Sonnet |
| T6.5 | **Ostacolo che minaccia il Limine** — chiude lo squilibrio della Fase 5. Candidati: spira che attraversa tutta l'altezza lasciando passaggio solo alto o basso; entità che pattuglia il centro | **Opus** |
| T6.6 | Ostacoli rimanenti dal design doc: piattaforma sospesa, pistone, specchio fluttuante | Sonnet |
| T6.7 ⚑ | Playtest: due ostacoli diversi devono richiedere due **letture** diverse | — |

---

### Fase 7 — Pattern e curva di difficoltà

| Task | Descrizione | Modello |
|---|---|---|
| T7.1 | Punti di aggancio estesi al Limine (un pattern può richiedere entrata/uscita dal centro) | **Opus** |
| T7.2 | 12-16 pattern su tre tier | Sonnet |
| T7.3 | Curva di velocità e cadenza degli switch ribilanciate: la difficoltà non deve più venire solo dalla velocità | **Opus** |
| T7.4 | Validazione automatica delle pool estesa ai nuovi vincoli | Sonnet |
| T7.5 ⚑ | Playtest: una run di 2 minuti non deve ripetere una sensazione già provata nei primi 30 secondi | — |

---

### Fase 8 — Sistema particellare

**Obiettivo**: quello che il design doc prevede da sempre e non è mai stato fatto. Con il bloom già attivo è l'elemento a miglior rapporto impatto/costo di tutta la roadmap.

| Task | Descrizione | Modello |
|---|---|---|
| T8.1 | `fx/particles.odin`: pool fisso pre-allocato, emitter parametrico (colore start/end, velocità, gravità, spread, lifetime, drag) | **Opus** |
| T8.2 | Preset **Reale**: polvere e scintille al contatto col pavimento, moto lineare, gravità verso il basso | Sonnet |
| T8.3 | Preset **Onirico**: particelle che fluttuano, moto a spirale, dissolvenza graduale, scia di "polvere di sogno" | Sonnet |
| T8.4 | Preset **Limine**: particelle che orbitano attorno al giocatore sospeso, quasi ferme — lì dentro il tempo sembra diverso | Sonnet |
| T8.5 | Burst sul flip, con colori che sfumano dalla palette di partenza a quella di arrivo | Sonnet |
| T8.6 | Densità e vivacità legate alla Lucidity | Sonnet |
| T8.7 ⚑ | Playtest: nessun calo di framerate a densità massima | — |

---

### Fase 9 — Profondità: parallax procedurale

| Task | Descrizione | Modello |
|---|---|---|
| T9.1 | Generazione procedurale dei layer: sagome di alberi, rocce, forme oniriche costruite con rumore | **Opus** |
| T9.2 | Scroll multi-layer a velocità diverse (3-4 livelli) | Sonnet |
| T9.3 | I layer campionano dalla palette: salendo, i fondali reali sbiadiscono e quelli onirici emergono | Sonnet |
| T9.4 ⚑ | Playtest: nessun fondale deve competere con player e ostacoli in primo piano | — |

**Perché procedurale e non PNG gratuiti**: mescolare fondali dipinti da terzi con primitive geometriche disegnate da te dà quasi sempre un risultato incoerente, e ti lega a uno stile che non hai scelto. Restare "tutto via codice" è coerente con silhouette+luce e non richiede un'illustratrice.

---

### Fase 10 — Game feel e bilanciamento

| Task | Descrizione | Modello |
|---|---|---|
| T10.1 | Screen shake calibrato, hit-stop (2-3 frame di freeze sulla morte), flash cromatico sul flip | **Opus** |
| T10.2 | Micro-movimenti di camera legati a `world_t` | Sonnet |
| T10.3 | Bilanciamento numerico: ritmi di punteggio, consumo di Lucidity, soglie dei tier, finestre di reazione per tier | **Opus** |
| T10.4 ⚑ | Sessioni cronometrate: una run media deve stare sui 45-90 secondi | — |

Qui il determinismo della Fase 2 ripaga: si rigioca la stessa run identica dopo ogni modifica ai numeri.

---

### Fase 11 — Audio

| Task | Descrizione | Modello |
|---|---|---|
| T11.1 | Due tracce sullo stesso BPM e struttura ritmica, con crossfade sul flip | **Opus** |
| T11.2 | Il Limine come terzo livello di mix: passa-basso e riverbero crescenti, come sentire i due mondi da sott'acqua | **Opus** |
| T11.3 | SFX: flip (pitch che sale verso l'Onirico e scende verso il Reale), collisione, ding di Lucidity, respiro del personaggio | Sonnet |
| T11.4 | Volumi separati musica/SFX, persistiti nelle opzioni | Sonnet |
| T11.5 ⚑ | Playtest audio | — |

---

### Fase 12 — UI, Referto Onirico, rifinitura

| Task | Descrizione | Modello |
|---|---|---|
| T12.1 | HUD definitivo coerente con la palette | Sonnet |
| T12.2 | **Referto Onirico**: profondità, Lucidity massima, tempo per stato, record — pensato per essere screenshottabile | **Opus** |
| T12.3 | Schermata opzioni (volumi, luminosità, lingua) | Sonnet |
| T12.4 | Persistenza estesa: opzioni e storico delle ultime run | Sonnet |
| T12.5 | Passata finale di coerenza visiva | **Opus** |
| T12.6 ⚑ | Playtest completo end-to-end | — |

---

## Riepilogo carico per modello

| Fase | Sonnet | Opus |
|---|---|---|
| 1 — Struttura | 6 | 1 |
| 2 — Salvataggio e determinismo | 6 | 4 |
| 3 — Palette | 4 | 3 |
| 4 — Bloom | 1 | 2 |
| 5 — Limine | 3 | 3 |
| 6 — Ostacoli | 2 | 4 |
| 7 — Pattern | 2 | 2 |
| 8 — Particelle | 5 | 1 |
| 9 — Parallax | 2 | 1 |
| 10 — Game feel | 1 | 2 |
| 11 — Audio | 2 | 2 |
| 12 — UI | 3 | 2 |
| **Totale** | **37** | **27** |

Le fasi più economiche da mandare avanti in Sonnet sono la **1** (spostamenti), la **8** (preset di particelle, molto ripetitivi) e la **12** (UI). Le fasi dove conviene spendere Opus sono la **2** (determinismo: un errore qui si paga per tutto il resto del progetto), la **5** (il gesto nuovo) e la **6** (regole di collisione, dove un bug non dà errore di compilazione ma un gioco che sembra ingiusto).

---

## Definition of Done — Alpha

- [ ] Tre stati giocabili, con costo e ricompensa bilanciati — nessuno è la scelta ovvia sempre
- [ ] Sistema visivo a tre palette con blending continuo, bloom, particelle e parallax attivi insieme
- [ ] Almeno 6 tipi di ostacolo con **letture distinte**, di cui almeno uno che minaccia il Limine
- [ ] 12-16 pattern distribuiti su tre tier
- [ ] Audio: due tracce sincronizzate + i tre SFX principali
- [ ] Menu, pausa, opzioni, Referto Onirico
- [ ] Salvataggio cifrato nella directory dati utente, con manifesto della run migliore
- [ ] Run riproducibile da seed + log input (base della leaderboard e dei replay)
- [ ] **60 FPS stabili** con tutti gli effetti attivi
- [ ] Run media 45-90 secondi, curva di difficoltà leggibile
- [ ] Un giocatore nuovo capisce il gesto tap/hold entro 30 secondi senza istruzioni
- [ ] Tre stati distinguibili senza affidarsi al colore
