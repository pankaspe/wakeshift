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

Verificato sul codice, 2 settembre 2026 — aggiornato a chiusura Fase 2.5.

**Funziona**
- Loop one-button: corsa automatica, `SPACE` inverte la gravità, due corsie
- Ostacoli come **eventi nel tempo** (`arrival_time`), non posizioni in pixel — la scelta architetturale migliore del progetto
- Pattern concatenati con `entry_lane`/`exit_lane`: il generatore non può produrre sequenze irrisolvibili
- Lucidity: streak di near-miss → moltiplicatore fino a +100%
- 3 tier di difficoltà con pool cumulative
- Coordinate di gioco fisse a 1280×720, letterboxate → nessun codice di gameplay sa che monitor c'è (dalla Fase 2.5 i pixel sono però nativi, non un upscale)
- Menu, pausa, game over, salvataggio record
- **[Fase 1]** Codice riorganizzato nei package (`core/platform/game/render/ui`; `fx` e `audio` non ancora creati) con grafo di dipendenze aciclico; `main.odin` ricablato, `draw_gameplay` estratto
- **[Fase 2]** Salvataggio cifrato (CBOR + XChaCha20-Poly1305) nella directory dati utente, che rifiuta file corrotti o manomessi senza mai far crashare il gioco
- **[Fase 2]** Simulazione deterministica: seed esplicito, input come dato, timestep fisso a 60 Hz. Ogni record salva il `RunManifest` della run che l'ha ottenuto — seed più i tick di ogni flip
- **[Fase 2.5]** Presentazione: parte a schermo pieno senza lampeggiare e senza toccare il modo video del monitor, render target alla risoluzione nativa del monitor (il codice di gioco continua a ragionare in 1280×720), schermata opzioni raggiungibile da menu e pausa, impostazioni salvate dentro il salvataggio cifrato

**Non funziona / manca**
- Ogni ostacolo pone la stessa domanda: l'unica leva di difficoltà è la velocità (270 → 330 → 400 px/s)
- I 4 tipi di ostacolo sono **un tipo solo con 4 skin**: `Chasm` e `DreamHole` usano la stessa identica collisione di `Block`
- Il "pieno vs vuoto" non esiste: la voragine è disegnata a `y = 720 - 54 = 666`, la linea del pavimento sta a ~690-706 → **sporge dal terreno di 25-40px, è un blocco in piedi, non un buco**
- La Lucidity è un cricchetto: sale e non scende mai
- La fascia centrale (40% dello schermo) è inutilizzata
- Sfondo `rl.ClearBackground(rl.BEIGE)`, contorni neri da 1.8px
- Nessuna particella, nessun bloom, nessun parallax, nessun audio
- Nessun replay o ghost visibile in gioco: il `RunManifest` viene registrato e salvato, ma non ancora rigiocato dall'interfaccia
- Menu e opzioni usano ancora il font bitmap di default di raylib e i colori di sistema: leggibili, ma non hanno identità visiva (Fase 3 / T13.3)

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
| — nuovo — | `src/core/settings.odin` + `src/platform/window.odin` (Fase 2.5) | `core`, `platform` |
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

### Fase 2 — Salvataggio sicuro e determinismo *(T2.1-T2.9 completati)*

**Obiettivo**: le fondamenta invisibili. Nessun cambiamento a schermo, ma senza queste la leaderboard di domani è impossibile e il bilanciamento di dopodomani è cieco.

| Task | Descrizione | Modello |
|---|---|---|
| T2.1 | `platform/paths.odin`: directory dati utente per SO, con creazione della cartella | Sonnet ✅ |
| T2.2 | `SaveData` + serializzazione CBOR, versionata | Sonnet ✅ |
| T2.3 | Cifratura ChaCha20-Poly1305, nonce per salvataggio, gestione del file corrotto/manomesso senza crash | **Opus** ✅ |
| T2.4 | Migrazione trasparente dal vecchio `highscore.txt`, poi rimozione | Sonnet ✅ |
| T2.5 | **Input come struct** `core.Input` passato dall'esterno; via `rl.IsKeyPressed` da dentro la logica | **Opus** ✅ |
| T2.6 | RNG con seed esplicito filtrato nel generatore di pattern | Sonnet ✅ |
| T2.7 | **Timestep fisso** con accumulatore | **Opus** ✅ |
| T2.8 | `RunManifest`: seed, versione, tick rate, log input, punteggio dichiarato — registrato durante la run e salvato per il record | **Opus** ✅ |
| T2.9 | Rimozione degli ostacoli ormai passati dalla lista | Sonnet ✅ |
| T2.10 ⚑ | Verifica finale a mano: giocare qualche run e confermare che nulla è regredito | Sonnet |

**Perché T2.5 e T2.7 erano Opus**: toccano entrambi la macchina a stati del player, e T2.5 è il prerequisito diretto del gesto tap/hold della Fase 5. Il timestep fisso cambia sottilmente il *feel* — andava fatto con attenzione all'interpolazione del rendering.

#### Cosa è emerso strada facendo

Note utili da rileggere, non riassunti dei task:

- **`Input` sta in `core`, non in `platform`** come diceva la tabella. Se stesse in `platform`, `ui` dovrebbe importarlo per il menu — un arco che il grafo delle dipendenze non prevede. È vocabolario condiviso, come `Lane`; a leggere la tastiera è `platform/input.odin`, unico punto del progetto.
- **`make_directory_all` non è idempotente**: su ogni backend ritorna `.Exist` invece di `nil` quando la cartella c'è già. Scoperto solo testando due avvii di fila.
- **Le funzioni AEAD di Odin usano `ensure()`** sulle dimensioni degli slice, che *aborta il processo*. Ogni controllo di lunghezza in `open_bytes` avviene prima di qualsiasi chiamata crittografica: un file troncato deve essere rifiutato, non far chiudere il gioco.
- **Il timestep fisso porta con sé tre problemi, non uno**: l'input che si perde o si duplica (risolto con `pending_input` latched), la spirale della morte (risolta con `MAX_FRAME_TIME`), e il micro-stutter visivo (risolto disegnando da una copia del mondo spinta avanti del resto dell'accumulatore).
- **`TICK_RATE` è la costante primaria, `FIXED_TIMESTEP` deriva da lei.** Il contrario faceva fallire il cast a intero per deriva float — e il manifesto ha bisogno di una frequenza esatta.
- **Il culling degli ostacoli non può assumere l'ordinamento**: la larghezza delle voragini varia da 54 a 118 px, quindi un ostacolo più recente ma stretto può uscire dallo schermo prima di uno precedente ma largo. Compattazione completa, non rimozione del prefisso.

#### Cosa questo sblocca

Il determinismo è verificato, non solo progettato: stessa sequenza di step → stato bit-identico su profili di frame da 60 Hz, 240 Hz e irregolari; rigiocare un manifesto salvato riproduce il punteggio esatto; spostare un solo flip di un tick lo cambia. Da qui derivano, senza altro lavoro di fondo: validazione lato server della leaderboard, replay e ghost, e bilanciamento riproducibile (Fase 10).

---

### ✅ Fase 2.5 — Presentazione e finestra *(completata)*

**Obiettivo**: il gioco si comporta come un gioco vero — parte a schermo pieno alla risoluzione del monitor, ha una schermata opzioni, e ricorda come lo hai lasciato. Nessun cambiamento al gameplay.

**Perché "2.5" e non una rinumerazione**: ci sono 11 riferimenti a fasi e task dentro i commenti del codice (`roadmap T5.1`, `phase 3`, `T12.4`) e decine nei documenti. Rinumerare le fasi da 3 a 13 li renderebbe tutti falsi *in silenzio*, senza un solo errore di compilazione. Inserire mezza fase costa zero.

**Perché prima della Fase 3 e non alla 13, dove stava**

1. **Le opzioni vanno salvate.** Toccare `SaveData` fa scattare il bump di `SAVE_FORMAT_VERSION`, e il decoder rifiuta di proposito le versioni che non conosce: **ogni salvataggio esistente diventa illeggibile**. Farlo adesso costa un highscore di prova. Farlo alla Fase 13 costa lo storico delle run.
2. **È un prerequisito del bloom (Fase 4).** Lo shader di bright-pass e blur lavora sui texel del render target. Decidere la risoluzione del target *dopo* aver scritto lo shader significa rifare la matematica dei texel.
3. **Dalla Fase 3 in poi ogni playtest è un giudizio visivo.** Palette, glow, parallax e particelle vanno giudicati a schermo pieno alla risoluzione vera, non in una finestra 1280×720.

#### Le tre decisioni prese

**Fullscreen vero, ma sempre sul modo video già attivo.** ~~Fullscreen borderless, mai fullscreen esclusivo.~~ *Decisione rivista in corso d'opera, vedi sotto.* La motivazione originale — niente cambio del modo video del monitor, perché non si guadagna né campo visivo né performance e si paga in alt-tab lento, sfarfallio e desktop lasciato alla risoluzione sbagliata — **resta valida**, ma il borderless non è il modo di ottenerla.

Su KDE una finestra senza decorazioni grande quanto lo schermo resta una finestra *normale*: il compositor la massimizza dentro l'area di lavoro (monitor 2560×1440 → finestra 2560×1398) e continua a disegnarci sopra il pannello, anche con `_NET_WM_STATE_ABOVE` e `_STAYS_ON_TOP` impostati — cosa che raylib fa già. L'unico stato che mette una finestra sopra i pannelli è `_NET_WM_STATE_FULLSCREEN`.

Quindi: fullscreen vero, chiedendo però **il modo video che il desktop sta già usando**. Nessun cambio di risoluzione avviene, e con esso nessuno dei costi che avevano fatto scartare l'esclusivo.

**Il canvas passa alla risoluzione nativa.** Oggi il canvas 1280×720 è un upscale *raster*: su un 1080p viene ingrandito ×1.5, su un 4K ×3, e l'immagine è morbida — proprio dove silhouette e rim light dovrebbero essere taglienti. Ma Wake Shift disegna primitive vettoriali, non pixel art: il render target viene allocato alla risoluzione reale dell'output e alle coordinate si applica una scala, così **il codice di gioco continua a ragionare in 1280×720** e non cambia una riga, mentre i pixel sono nativi. Il letterbox resta, per i monitor non 16:9. Da qui esce anche, gratis, la leva per una voce "Qualità" quando arriva il bloom.

**La risoluzione in opzioni è la dimensione della finestra**, non il modo video: si applica in windowed, filtrata su quelle che entrano nel monitor corrente. In fullscreen la voce è disattivata, perché lì la risoluzione è quella del desktop.

| Task | Descrizione | Modello |
|---|---|---|
| T2.5.1 | `platform/display.odin`: render target dimensionato sull'output reale, con le coordinate di gioco che restano 1280×720. Riallocazione al cambio di dimensione | **Opus** ✅ |
| T2.5.2 | `DisplayMode` (Fullscreen / Windowed) e cambio a caldo che non perturba la simulazione — il frame lungo è già tagliato da `MAX_FRAME_TIME`, il render target no | **Opus** ✅ |
| T2.5.3 | Query monitor: lista di risoluzioni finestra valide sul monitor corrente, più una voce "adatta al monitor"; gestione multi-monitor | Sonnet ✅ |
| T2.5.4 | `Settings` (modalità, dimensione finestra, vsync) persistite dentro `SaveData` → `SAVE_FORMAT_VERSION` a 3 | Sonnet ✅ |
| T2.5.5 | Avvio: impostazioni lette **prima** di `InitWindow` (non serve una finestra per leggerle), così la finestra nasce già giusta invece di lampeggiare; primo lancio = fullscreen sul monitor primario | Sonnet ✅ |
| T2.5.6 | `ui/menu.odin` esteso: voce con valore che cicla con ←/→. Due campi nuovi in `core.Input` (`menu_left`, `menu_right`), **meta-input**: fuori dalla simulazione e fuori dal `RunManifest`, come `pause` e `toggle_fullscreen` | **Opus** ✅ |
| T2.5.7 | `GameState.Options`, raggiungibile dal menu principale e dalla pausa, ESC per tornare indietro | Sonnet ✅ |
| T2.5.8 | VSync on/off e limite FPS (60 / monitor / illimitato). La simulazione resta a 60 Hz fissi: cambia solo la frequenza di disegno, e `interpolated_world` in `main.odin` c'è già. Attenzione a non lasciare `SetTargetFPS` e vsync attivi insieme | Sonnet ✅ |
| T2.5.9 ⚑ | Playtest: fullscreen, windowed, cambio a caldo durante una run, riavvio con le impostazioni ricordate | — ✅ |

#### Cosa è emerso strada facendo

- **`Settings` sta in `core`, non in `platform`**, esattamente per il motivo per cui ci sta `Input`: `ui` deve disegnarle e `platform` deve applicarle, e `ui` non ha il permesso di importare `platform`. Il livello che *applica* le impostazioni è `platform/window.odin`; il valore che le descrive è vocabolario condiviso.
- **Il canvas non viene più letterboxato dentro il render target.** Il target è grande esattamente quanto il canvas scalato, e le bande nere sono la parte di finestra che il blit non copre. Costa zero adesso e serve alla Fase 4: il bright-pass del bloom lavorerebbe altrimenti anche sulle bande.
- **CBOR non protegge dagli enum fuori range.** Un `DisplayMode(200)` viene serializzato e rideserializzato senza un solo errore (verificato). Le impostazioni sono l'unica parte del salvataggio che finisce dritta in chiamate di sistema, quindi `decode_save_data` le passa per `validate_settings` prima di restituirle.
- **Il borderless è stato provato, misurato e scartato.** Su KWin 6 (Wayland, quindi XWayland) la finestra borderless esce 2560×1398 con `MAXIMIZED_VERT/HORZ` e senza `FULLSCREEN`, e il pannello resta sopra. È il bug che hai segnalato con lo screenshot. Sostituito da fullscreen vero: `FULLSCREEN` presente, 2560×1440, modo video del monitor intatto prima, durante e dopo.
- **`ToggleFullscreen` di raylib passa a GLFW la dimensione *corrente della finestra* come modo video desiderato.** Chiamato su una finestra 1280×720 non ingrandisce la finestra al monitor: rimpicciolisce il monitor a 1280×720. Misurato — in un test la scrivania è finita a 1024×768. Per questo la finestra fullscreen nasce con `InitWindow(0, 0, ...)`, che raylib legge come "la dimensione del monitor" e applica *mentre* crea la finestra, e per questo il toggle a caldo è protetto da una guardia: si tocca solo quando la dimensione è già quella giusta, altrimenti si richiede il resize e si riprova al frame dopo.
- **`SetWindowState` di raylib agisce su `FLAG_FULLSCREEN_MODE` ogni volta che l'insieme richiesto *differisce* da quello corrente**, a differenza di ogni altro flag che gestisce. Conseguenza: cambiare il vsync faceva uscire la finestra dal fullscreen come effetto collaterale. Si passa il bit della modalità corrente insieme alla richiesta, così il confronto resta pari.
- **Uscire dal fullscreen non basta a riavere la finestra che si voleva.** raylib ripristina la geometria che la finestra aveva *entrando*, che è la dimensione del monitor; KDE massimizza una finestra di quella misura, e una finestra massimizzata ignora il ridimensionamento. Va prima de-massimizzata. Misurato senza: una richiesta di 1600×900 si assestava a 2560×1370 massimizzata.
- **Un cambio di modalità non è una chiamata, è una trattativa.** Il window manager risponde al resize quando gli pare, un frame o due dopo. Per questo `apply_display_mode` fa *un passo* ed è idempotente, e `main` lo richiama per 30 frame dopo ogni cambio. Numero di tentativi limitato di proposito: a un WM che insiste va lasciato vincere.
- **La finestra nasce nascosta.** `.WINDOW_HIDDEN` fra i config flag, modalità applicata, poi `ClearWindowState`: è così che il passaggio a fullscreen non si vede. Senza, il primo avvio mostra per un istante una finestra decorata.
- **`FLAG_FULLSCREEN_MODE` nei config flag non serve e non funziona.** Provato: raylib riporta `IsWindowFullscreen() = true`, ma la finestra che arriva al compositor non porta `_NET_WM_STATE_FULLSCREEN` ed è massimizzata nell'area di lavoro, pannello ancora sopra. Il fullscreen si raggiunge con un toggle dopo la creazione.
- **Il testo non guadagna nitidezza dal target nativo**, perché il font bitmap di default non ha risoluzione da dare. Le primitive vettoriali sì — ed è quello che serviva a silhouette e rim light. Un font vero arriva con l'identità visiva.
- Il salvataggio esistente è stato invalidato dal bump a `SAVE_FORMAT_VERSION = 3`, come previsto: il decoder rifiuta di proposito le versioni che non conosce, quindi il record precedente è andato e si riparte dai default.

**Test di verifica**: superato. Il gioco si apre a schermo pieno alla prima esecuzione senza lampeggiare, le impostazioni sopravvivono al riavvio, un cambio di modalità durante una run non fa saltare né la fisica né il punteggio, `odin check src` resta verde. Confermato dal tuo playtest il 2 settembre 2026.

**Ricaduta sulla Fase 13**: la `T13.3` smette di essere "costruire la schermata opzioni" e diventa "ridisegnarla sulla palette definitiva". La `T13.4` resta, ma le si toglie la parte sulle opzioni: le rimane lo storico delle ultime run.

**Deciso di non fare**: ricordare la dimensione di una finestra ridimensionata a mano trascinandone il bordo. La dimensione salvata è quella scelta nelle opzioni, e basta — leggerla dalla finestra viva ogni frame significa rischiare che un `SetWindowSize` appena richiesto venga sovrascritto dalla vecchia dimensione prima che il window manager l'abbia applicata.

---

### Fase 3 — Palette, corpo, e il primo strato

**Obiettivo**: il salto visivo più grande della roadmap. Riferimento: [Il sistema a tre mondi](#il-sistema-a-tre-mondi--riferimento-grafico-trasversale) e Design Doc sez. 12.

| Task | Descrizione | Modello |
|---|---|---|
| T3.1 | `render/palette.odin`: tre palette, `world_t`, interpolazione continua | **Opus** |
| T3.2 | Interpolazione aggiuntiva per **profondità**: al crescere della profondità le palette dei due mondi virano verso quella del Limine (la convergenza, Design Doc sez. 12) | **Opus** |
| T3.3 | `render/background.odin`: gradiente verticale Onirico→orizzonte→Reale guidato da `world_t` | **Opus** |
| T3.4 | Terreno ricolorato su palette, rim light per mondo | Sonnet |
| T3.5 | Ostacoli ricolorati su palette | Sonnet |
| T3.6 | **Il personaggio prende un corpo**: testa, torso, arti da primitive; ciclo di corsa; la frustata del flip. Corregge anche l'inversione corpo/bordo attuale | **Opus** |
| T3.7 | Glow additivo economico (`BLEND_ADDITIVE`, alpha decrescente) | **Opus** |
| T3.8 | HUD e menu ricolorati, leggibilità su fondo scuro | Sonnet |
| T3.9 ⚑ | Playtest visivo | — |

**Test di verifica**: uno screenshot deve smettere di sembrare un prototipo. Il flip deve *sentirsi* come un attraversamento.

---

### Fase 4 — Bloom reale

| Task | Descrizione | Modello |
|---|---|---|
| T4.1 | Shader GLSL: bright-pass + blur gaussiano separabile | **Opus** |
| T4.2 | Composite additivo, intensità modulata da `world_t`: duro nel Reale, invadente nell'Onirico, sovraesposto nel Limine | **Opus** |
| T4.3 | Verifica 60 FPS stabili con bloom attivo | Sonnet |
| T4.4 ⚑ | Playtest di leggibilità a 400 px/s | — |

**Test di verifica**: se devo scegliere tra bello e leggibile, vince leggibile.

---

### Fase 5 — Il Limine: il terzo stato

**Obiettivo**: il cuore dell'evoluzione. Dipende da T2.5 (input come dato), già fatto.

| Task | Descrizione | Modello |
|---|---|---|
| T5.1 | Riconoscimento tap vs hold sulla barra spaziatrice | **Opus** |
| T5.2 | Fisica della sospensione: arresto a metà viaggio, completamento nella direzione di marcia al rilascio | **Opus** |
| T5.3 | **La posa del galleggiamento**: la rotazione si completa e si assesta, braccia aperte, oscillazione lenta (Design Doc sez. 12) | **Opus** |
| T5.4 | Lucidity come carburante: consumo nel Limine, accumulo dai near-miss, soglia minima | **Opus** |
| T5.5 | Ritmo di punteggio del Limine (40/s) | Sonnet |
| T5.6 | HUD: la Lucidity diventa una barra di risorsa, non un numero | Sonnet |
| T5.7 ⚑ | **Playtest decisivo**: il gesto deve risultare naturale entro 30 secondi senza spiegazioni | — |

**Squilibrio noto e voluto**: a fine fase il centro è **sicuro**, perché tutti gli ostacoli sono attaccati alle pareti. Si chiude in T6.6. Nel frattempo il consumo di Lucidity va tarato aggressivo.

---

### Fase 6 — Ostacoli veri

**Obiettivo**: smettere di avere quattro skin dello stesso ostacolo. Riferimento: Design Doc sez. 5, incluso il principio **anticipatori, non reattivi**.

| Task | Descrizione | Modello |
|---|---|---|
| T6.1 | Terreno interrompibile: il disegno del suolo deve sapere dove sono i vuoti | **Opus** |
| T6.2 | `Chasm` e `DreamHole` diventano **vere assenze**, disegnate come buchi reali | **Opus** |
| T6.3 | Regole di collisione differenziate: il blocco uccide al contatto, la voragine solo se sei nella corsia bassa e appoggiato | **Opus** |
| T6.4 | Fix `PulsingShape`: fase ancorata all'`arrival_time` invece che al tempo globale | Sonnet |
| T6.5 | **Archetipi anticipatori**: Eco, Finta, Pattugliatore (Design Doc sez. 5) | **Opus** |
| T6.6 | **Ostacolo che minaccia il Limine** — chiude lo squilibrio della Fase 5 | **Opus** |
| T6.7 ⚑ | Playtest: due ostacoli diversi devono richiedere due **letture** diverse | — |

---

### Fase 7 — Pattern e curva di difficoltà

| Task | Descrizione | Modello |
|---|---|---|
| T7.1 | Punti di aggancio estesi al Limine | **Opus** |
| T7.2 | 12-16 pattern su tre tier | Sonnet |
| T7.3 | Curva di velocità e cadenza degli switch ribilanciate: la difficoltà non deve più venire solo dalla velocità | **Opus** |
| T7.4 | Validazione automatica delle pool estesa ai nuovi vincoli | Sonnet |
| T7.5 ⚑ | Playtest: una run di 2 minuti non deve ripetere una sensazione già provata nei primi 30 secondi | — |

---

### Fase 8 — I bonus di luce

**Obiettivo**: profondità decisionale senza un secondo input. Dipende dalla Fase 5 (Lucidity come risorsa). Riferimento: Design Doc sez. 8.

| Task | Descrizione | Modello |
|---|---|---|
| T8.1 | Pickup raccolti **per posizione**, non con un tasto; piazzati nella corsia pericolosa | **Opus** |
| T8.2 | Linguaggio visivo: gli ostacoli sono sagome scure, i bonus sono **fatti di luce** | Sonnet |
| T8.3 | Raccogliere luce = guadagnare Lucidity (una sola risorsa, non cinque) | Sonnet |
| T8.4 | **Timeshift** (Onirico): rallentamento del tempo per N secondi | **Opus** |
| T8.5 | **Forza della natura** (Reale): immunità per N secondi | Sonnet |
| T8.6 | Integrazione nei pattern: il generatore piazza i bonus con la stessa logica di aggancio degli ostacoli | **Opus** |
| T8.7 ⚑ | Playtest: la domanda deve diventare "vale il rischio?", non "dove scappo?" | — |

**Nota**: niente malus da raccogliere — decisione presa nel Design Doc sez. 8. Gli elementi avversi vanno nell'ambiente, dove sono prevedibili.

---

### Fase 9 — Sistema particellare

| Task | Descrizione | Modello |
|---|---|---|
| T9.1 | `fx/particles.odin`: pool fisso pre-allocato, emitter parametrico | **Opus** |
| T9.2 | Preset **Reale**: polvere e scintille al contatto, moto lineare | Sonnet |
| T9.3 | Preset **Onirico**: particelle fluttuanti, moto a spirale, scia | Sonnet |
| T9.4 | Preset **Limine**: particelle che orbitano attorno al giocatore sospeso | Sonnet |
| T9.5 | Burst sul flip, colori che sfumano dalla palette di partenza a quella di arrivo | Sonnet |
| T9.6 | Densità e vivacità legate alla Lucidity | Sonnet |
| T9.7 ⚑ | Playtest: nessun calo di framerate a densità massima | — |

---

### Fase 10 — Il primo strato e la sua transizione

**Obiettivo**: validare l'intera idea degli strati su **uno solo**, prima di produrne quattro. Riferimento: Design Doc sez. 3.

| Task | Descrizione | Modello |
|---|---|---|
| T10.1 | Generazione procedurale dei layer di parallax (sagome da rumore, non PNG) | **Opus** |
| T10.2 | Scroll multi-layer a velocità diverse; i layer campionano dalla palette | Sonnet |
| T10.3 | **Sistema di strati**: uno strato è palette + parallax + pool di ostacoli + traccia | **Opus** |
| T10.4 | **La transizione come evento**: 2-3 secondi in cui il parallax si scambia senza fermare il gioco | **Opus** |
| T10.5 | Contenuto di **due** strati soltanto: Foresta e Pietraia | Sonnet |
| T10.6 ⚑ | **Decisione**: se la transizione emoziona, gli altri strati sono lavoro meccanico. Se no, si ridiscute prima di produrli | — |

---

### Fase 11 — Game feel e bilanciamento

| Task | Descrizione | Modello |
|---|---|---|
| T11.1 | Screen shake, hit-stop sulla morte, flash cromatico sul flip | **Opus** |
| T11.2 | Micro-movimenti di camera legati a `world_t` | Sonnet |
| T11.3 | Bilanciamento numerico: punteggi, consumo Lucidity, soglie, finestre di reazione | **Opus** |
| T11.4 ⚑ | Sessioni cronometrate: una run media sui 45-90 secondi | — |

Qui il determinismo della Fase 2 ripaga: si rigioca la stessa run identica dopo ogni modifica ai numeri.

---

### Fase 12 — Audio

| Task | Descrizione | Modello |
|---|---|---|
| T12.1 | Due mix sincronizzati con crossfade sul flip | **Opus** |
| T12.2 | Il Limine come terzo livello di mix: passa-basso e riverbero crescenti | **Opus** |
| T12.3 | Traccia per strato, crossfade sull'evento di transizione (mai sulla fine del file) | **Opus** |
| T12.4 | SFX: flip, collisione, ding di Lucidity, raccolta bonus | Sonnet |
| T12.5 | Volumi separati musica/SFX, persistiti nelle opzioni | Sonnet |
| T12.6 ⚑ | Playtest audio | — |

**Nota di produzione**: due mix × N strati è molto per un solista. Valutare il mix onirico generato a runtime (`AttachAudioStreamProcessor`) o gli stem al posto di tracce complete — Design Doc sez. 13.

---

### Fase 13 — UI, Referto Onirico, rifinitura

| Task | Descrizione | Modello |
|---|---|---|
| T13.1 | HUD definitivo coerente con la palette | Sonnet |
| T13.2 | **Referto Onirico**: profondità, Lucidity massima, tempo per stato, strato raggiunto — screenshottabile | **Opus** |
| T13.3 | Schermata opzioni **ridisegnata** sulla palette definitiva (costruita nella Fase 2.5) | Sonnet |
| T13.4 | Persistenza estesa: storico delle ultime run (le opzioni sono già persistite dalla Fase 2.5) | Sonnet |
| T13.5 | Passata finale di coerenza visiva | **Opus** |
| T13.6 ⚑ | Playtest completo end-to-end | — |

---

## Riepilogo carico per modello

Fasi 0-2 completate. Il conteggio qui sotto è **quel che resta**.

| Fase | Sonnet | Opus |
|---|---|---|
| 2.5 — Presentazione e finestra | 5 | 3 |
| 3 — Palette, corpo, primo strato | 3 | 5 |
| 4 — Bloom | 1 | 2 |
| 5 — Il Limine | 2 | 4 |
| 6 — Ostacoli veri | 1 | 5 |
| 7 — Pattern e difficoltà | 2 | 2 |
| 8 — Bonus di luce | 3 | 3 |
| 9 — Particelle | 5 | 1 |
| 10 — Strati e transizione | 2 | 3 |
| 11 — Game feel | 1 | 2 |
| 12 — Audio | 2 | 3 |
| 13 — UI e rifinitura | 3 | 2 |
| **Totale rimanente** | **30** | **35** |

Il rapporto si è spostato verso Opus rispetto al piano iniziale, ed è corretto che sia così: le fasi che restano decidono *come si gioca* (il gesto del Limine, le regole di collisione, gli archetipi anticipatori, il bilanciamento) invece di spostare file. Le fasi economiche da mandare in Sonnet restano la **9** (preset di particelle, molto ripetitivi), la **13** (UI) e buona parte della **2.5**, dove l'unico lavoro davvero aperto è la pipeline del render target e il widget di menu con valore.

Dove conviene spendere Opus, in ordine: la **5** (il gesto nuovo — se sbagliato lì, tutto il resto poggia male), la **6** (regole di collisione: un errore non dà errore di compilazione, dà un gioco che *sembra* ingiusto) e la **3** (la convergenza delle palette, che è insieme identità visiva e curva di difficoltà).

---

## Definition of Done — Alpha

- [x] Salvataggio cifrato nella directory dati utente, con manifesto della run migliore
- [x] Run riproducibile da seed + log input (base della leaderboard e dei replay)
- [ ] Tre stati giocabili, con costo e ricompensa bilanciati — nessuno è la scelta ovvia sempre
- [ ] Il personaggio ha un corpo e due pose leggibili: la frustata del tap, il galleggiamento dell'hold
- [ ] Sistema visivo a tre palette con blending continuo, bloom, particelle e parallax attivi insieme
- [ ] **La convergenza funziona**: scendendo, i due mondi si somigliano sempre di più, e il gioco resta giocabile perché posizione e movimento reggono da soli
- [ ] Almeno 6 tipi di ostacolo con **letture distinte**, di cui almeno uno che minaccia il Limine e almeno uno anticipatorio (Eco / Finta / Pattugliatore)
- [ ] 12-16 pattern distribuiti su tre tier
- [ ] Bonus di luce raccolti per posizione, piazzati dove costa qualcosa prenderli
- [ ] **Due strati e la transizione fra loro**, come evento che non ferma il gioco
- [ ] Audio: due mix sincronizzati + traccia per strato + i SFX principali
- [ ] Avvio a schermo pieno alla risoluzione del monitor, con modalità finestra e impostazioni ricordate fra un avvio e l'altro
- [ ] Menu, pausa, opzioni, Referto Onirico
- [ ] **60 FPS stabili** con tutti gli effetti attivi
- [ ] Run media 45-90 secondi, curva di difficoltà leggibile
- [ ] Un giocatore nuovo capisce il gesto tap/hold entro 30 secondi senza istruzioni
- [ ] Tre stati distinguibili senza affidarsi al colore
