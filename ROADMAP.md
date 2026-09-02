# WAKE SHIFT — Roadmap verso l'Alpha giocabile

> Documento di lavoro personale, in italiano. Non fa parte della documentazione pubblica del progetto e va rimosso dal repository prima di una eventuale pubblicazione.
>
> Il *cosa e perché* sta in `docs/design_doc.md` (v1.1). Le regole operative di sviluppo stanno in `CLAUDE.md`. Questo file è il *come, in che ordine, e con quale modello*.

---

## Indice

- [Come si legge questa roadmap](#come-si-legge-questa-roadmap)
- [Stato attuale](#stato-attuale)
- [Il sistema a tre mondi](#il-sistema-a-tre-mondi--riferimento-grafico-trasversale)
- [Il salvataggio: cosa resta da sapere](#il-salvataggio-cosa-resta-da-sapere)
- [Struttura del progetto](#struttura-del-progetto)
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

### Quando una fase si chiude

**La sua sezione va compressa**, subito, prima di passare oltre: titolo con ✅, un paragrafo su cosa è stato fatto, e solo le decisioni che restano vincolanti per il lavoro futuro. La tabella dei task sparisce — serviva a eseguirli, non a ricordarli.

Quello che si scopre strada facendo non si butta, si **sposta dove verrà riletto**: una trappola di una libreria va nel commento del file che la contiene, una regola di architettura in `CLAUDE.md`, un dettaglio di gameplay nel design doc. Qui resta il *perché* di una decisione, non il racconto di come ci si è arrivati. Se una nota non ha una casa altrove, la casa va creata prima di cancellarla da qui.

---

## Stato attuale

Verificato sul codice, 2 settembre 2026 — aggiornato a chiusura Fase 5. La Fase 4 (bloom) era stata scavalcata per scelta ed è la prossima.

**Funziona**
- Loop one-button: corsa automatica, `SPACE` inverte la gravità, due corsie
- Ostacoli come **eventi nel tempo** (`arrival_time`), non posizioni in pixel — la scelta architetturale migliore del progetto
- Pattern concatenati con `entry_lane`/`exit_lane`: il generatore non può produrre sequenze irrisolvibili
- Lucidity: risorsa unica che si guadagna dai near-miss e si spende nel Limine, e che è insieme il moltiplicatore di punteggio (fino a +100%)
- 3 tier di difficoltà con pool cumulative
- Coordinate di gioco fisse a 1280×720, letterboxate → nessun codice di gameplay sa che monitor c'è (dalla Fase 2.5 i pixel sono però nativi, non un upscale)
- Menu, pausa, game over, salvataggio record
- **[Fase 1]** Codice riorganizzato nei package (`core/platform/game/render/ui`; `fx` e `audio` non ancora creati) con grafo di dipendenze aciclico; `main.odin` ricablato, `draw_gameplay` estratto
- **[Fase 2]** Salvataggio cifrato (CBOR + XChaCha20-Poly1305) nella directory dati utente, che rifiuta file corrotti o manomessi senza mai far crashare il gioco
- **[Fase 2]** Simulazione deterministica: seed esplicito, input come dato, timestep fisso a 60 Hz. Ogni record salva il `RunManifest` della run che l'ha ottenuto — seed più i tick di ogni flip
- **[Fase 2.5]** Presentazione: parte a schermo pieno senza lampeggiare e senza toccare il modo video del monitor, render target alla risoluzione nativa del monitor (il codice di gioco continua a ragionare in 1280×720), schermata opzioni raggiungibile da menu e pausa, impostazioni salvate dentro il salvataggio cifrato
- **[Fase 3]** Identità visiva avviata: nessun colore scritto a mano fuori da `core/palette.odin`, i due mondi disegnati insieme con l'orizzonte in mezzo, la convergenza che li avvicina col passare della run, il personaggio con un corpo che corre e frusta nel flip, glow additivo da primitive, HUD e menu ricolorati sulla palette
- **[Fase 5]** **Il Limine è giocabile**: tap e hold sullo stesso tasto, il viaggio si ferma a metà e riparte nella direzione in cui stavi andando, Lucidity che si spende invece di accumularsi soltanto, ritmo di punteggio a 40/s al centro, barra della risorsa nell'HUD

**Non funziona / manca**
- Ogni ostacolo pone la stessa domanda: l'unica leva di difficoltà è la velocità (270 → 330 → 400 px/s)
- I 4 tipi di ostacolo sono **un tipo solo con 4 skin**: `Chasm` e `DreamHole` usano la stessa identica collisione di `Block`
- Il "pieno vs vuoto" non esiste: la voragine è disegnata a `y = 720 - 54 = 666`, la linea del pavimento sta a ~690-706 → **sporge dal terreno di 25-40px, è un blocco in piedi, non un buco**
- **Il centro è sicuro**: dalla Fase 5 la fascia centrale è il terzo stato, ma tutti gli ostacoli sono ancora attaccati alle pareti, quindi restarci non rischia niente se non il carburante. Squilibrio previsto, si chiude in T6.6
- Nessuna particella, nessun parallax, nessun audio. Il bloom non è vero bloom: è glow additivo impilato da primitive, non un bright-pass sul frame (Fase 4)
- Nessun replay o ghost visibile in gioco: il `RunManifest` viene registrato e salvato, ma non ancora rigiocato dall'interfaccia
- Menu e opzioni prendono ora i colori dalla palette, ma usano ancora il font bitmap di default di raylib: tutto quello che è disegnato da primitive è nitido alla risoluzione nativa, il testo no (T13.3)

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

## Il salvataggio: cosa resta da sapere

Implementato nella Fase 2. L'analisi che ha portato alle decisioni non serve più; queste tre cose sì.

**Cifrare il salvataggio locale non rende sicura una leaderboard.** La chiave sta dentro il binario, e chiunque sia motivato la estrae. È un *deterrente* contro la modifica col blocco note, non una garanzia. Va detto così nel codice e a voce, mai spacciato per protezione.

**La sicurezza vera è rivalidare lato server** (Design Doc sez. 10): il client manda seed + log degli input, il server rigioca la run e calcola il punteggio da sé. Il punteggio dichiarato dal client non viene mai creduto. Il `RunManifest` che ogni record salva è già quel pacchetto.

**Modello di minaccia, onesto**

| Attacco | Difesa |
|---|---|
| Modifica del file col blocco note | Tag AEAD → salvataggio rifiutato ✅ |
| Estrazione della chiave dal binario | **Nessuna difesa locale possibile.** Solo rivalidazione server |
| Punteggio inventato inviato al server | Il server rigioca il manifesto: niente manifesto valido, niente punteggio ✅ |
| Manifesto fabbricato da un bot che gioca davvero | Rate limiting + flag statistici su punteggi anomali. Fuori scope alpha |

---

## Struttura del progetto

Fatta nella Fase 1; la tabella di migrazione ha esaurito il suo scopo. La struttura viva e le regole d'oro stanno in `CLAUDE.md`, che è il file che governa il codice — qui resta solo il perché.

**Perché non seguiamo la struttura del design doc originale.** La v1.0 prevedeva `player/`, `obstacles/`, `patterns/`, `world/` come package separati. In Odin non funziona: import ciclici vietati, e una cartella è esattamente un package. Quelle entità si guardano continuamente (`score` legge `Player`, `lucidity` legge `Player` *e* `Obstacle`, le collisioni leggono tutto). Il taglio giusto è **per livello di astrazione, non per entità**. Correzione già recepita nel design doc v1.1, sez. 14.

**Ancora da creare**: `fx/` (Fase 9, particelle e bloom — parametrico, non sa niente del gioco) e `audio/` (Fase 12).

---

## Le fasi

> Le fasi concluse sono compresse a un recap: cosa è stato fatto, e dove vive
> adesso la conoscenza che serve a chi riprende. Le tabelle dei task chiusi non
> restano — servivano a eseguirli, non a ricordarli.

### ✅ Fase 0 — Sbloccare la build

Build ripristinata, `docs/` creata, `highscore.txt` tolto da git, design doc alla v1.1, `CLAUDE.md` e `ROADMAP.md` scritti.

---

### ✅ Fase 1 — Struttura del progetto

Codice riorganizzato nei package `core` / `platform` / `game` / `render` / `ui`, con grafo di dipendenze aciclico; `main.odin` ricablato e `draw_gameplay` estratto. Il gioco è rimasto identico a schermo, che era il test.

---

### ✅ Fase 2 — Salvataggio sicuro e determinismo

Salvataggio cifrato (CBOR + XChaCha20-Poly1305) nella directory dati utente, che rifiuta file corrotti o manomessi senza mai far crashare il gioco. Simulazione deterministica: seed esplicito, input come dato, timestep fisso a 60 Hz. Ogni record salva il `RunManifest` della run che l'ha ottenuto.

**Perché conta**: il determinismo è verificato, non solo progettato — stessa sequenza di step, stato bit-identico su profili di frame a 60 Hz, 240 Hz e irregolari; rigiocare un manifesto salvato riproduce il punteggio esatto; spostare un flip di un solo tick lo cambia. Da qui derivano senza altro lavoro di fondo: validazione lato server della leaderboard, replay, ghost, e bilanciamento riproducibile (Fase 11).

**Una correzione alla pianificazione**: `Input` sta in `core`, non in `platform` come diceva la tabella di migrazione. Se stesse in `platform`, `ui` dovrebbe importarlo per il menu — un arco che il grafo non prevede. È vocabolario condiviso, come `Lane`. Stessa logica poi applicata a `Settings` nella Fase 2.5.

Le trappole trovate strada facendo (`make_directory_all` che ritorna `.Exist`, le funzioni AEAD che abortiscono il processo, i tre problemi del timestep fisso, `TICK_RATE` come costante primaria, il culling che non può assumere l'ordinamento) sono commentate nel codice che le riguarda e riassunte nel README.

---

### ✅ Fase 2.5 — Presentazione e finestra

Il gioco parte a schermo pieno alla risoluzione del monitor senza lampeggiare, ha una schermata opzioni raggiungibile da menu e pausa (modalità, dimensione finestra, vsync, limite FPS), e ricorda come lo hai lasciato. Nessun cambiamento al gameplay.

**Le decisioni che restano vincolanti**

- **Le coordinate di gioco restano 1280×720 per sempre.** Quello che è cambiato è dove atterrano: il render target è allocato alla risoluzione reale dell'output e uno zoom di `Camera2D` mappa una coordinata di gioco su un pixel nativo. Niente più upscale raster. Il target è grande quanto il canvas scalato, non quanto la finestra, così le bande nere restano fuori — il bright-pass del bloom (Fase 4) non deve vederle.
- **Fullscreen vero, sempre sul modo video già attivo.** ~~Fullscreen borderless, mai esclusivo.~~ Decisione rivista dopo averla misurata: su KDE una finestra senza decorazioni grande quanto lo schermo resta una finestra *normale*, il compositor la massimizza nell'area di lavoro e ci disegna sopra il pannello. Solo `_NET_WM_STATE_FULLSCREEN` mette una finestra sopra i pannelli. La motivazione originale — non toccare la risoluzione del desktop — resta valida ed è rispettata: si chiede il modo che il desktop sta già usando.
- **Un cambio di modalità è una trattativa, non una chiamata.** Il window manager risponde quando gli pare. `apply_display_mode` fa *un passo* ed è idempotente; `main` lo richiama per 30 frame dopo ogni cambio.

I tre comportamenti di raylib che rendono tutto questo delicato — due dei quali cambiano in silenzio la risoluzione del desktop o fanno uscire la finestra dal fullscreen — stanno nell'intestazione di `platform/window.odin`, che è la prima cosa da leggere prima di toccare una chiamata di finestra.

**Ricaduta sulle fasi successive**: la `T13.3` non è più "costruire la schermata opzioni" ma "ridisegnarla sulla palette definitiva"; alla `T13.4` resta solo lo storico delle ultime run.

---

### ✅ Fase 3 — Palette, corpo, e il primo strato

Il gioco ha smesso di essere disegnato su fondo beige. I due mondi sono ora sempre entrambi a schermo, con l'orizzonte in mezzo; quale dei due è vivo lo decide `world_t`, e quanto si somigliano lo decide `depth_t`. Il personaggio ha un corpo di primitive che corre, fluttua e frusta nel flip. Nessun colore è più scritto a mano fuori dalla palette.

**Le decisioni che restano vincolanti**

- **La palette sta in `core/palette.odin`, non in `render/`.** Anche `ui` disegna con la palette, e `ui` non può importare `render`. È la terza volta che questa cosa succede — `Input` nella Fase 2, `Settings` nella Fase 2.5, la palette qui — ed è ormai una regola, scritta in `CLAUDE.md`: quello che è *vocabolario* va in `core`, il package che possiede il *comportamento* tiene la metà che ha bisogno dello stato di gioco. In `render/palette.odin` resta solo la derivazione di `world_t` e `depth_t` da `Player` e `World`.
- **L'orizzonte cade esattamente sulla fascia del Limine** (216-504, la stessa suddivisione 30/40/30 del gameplay). Non è estetica: quando il Limine diventerà giocabile nella Fase 5, il giocatore starà nel punto dell'immagine che è sempre stato disegnato come soglia.
- **Il ciclo di corsa è agganciato alla distanza percorsa, non al tempo.** Le gambe accelerano da sole a ogni cambio di tier, senza niente da tenere in sincrono.
- **Un mezzo giro lascerebbe il personaggio a correre all'indietro**, quindi la posa specchia anche in orizzontale — e uno specchio non si interpola, cambia il verso del piano. Scatta a metà rotazione, dove la figura è di taglio: un fotogramma dentro 120 ms. Il perché e la via d'uscita (schiacciare la figura in quell'istante, non rallentare la rotazione) stanno nell'intestazione di `render/player.odin`.
- **Il glow non è bloom.** Sono primitive additive impilate: costa poco, non tocca il frame intero, e resta utile anche dopo la Fase 4 per gli aloni locali.

**Le tre manopole da girare se il playtest lo chiede**: `HORIZON_GLOW_*` in `background.odin` se il fondo ruba attenzione agli ostacoli (pilastro 2 batte l'atmosfera), `CONVERGENCE_MAX` (oggi 0.72) se a fondo run i due mondi diventano indistinguibili al punto da non capire dove sei, `PLAYER_STRIDE_LENGTH` se il passo non sembra appoggiato a terra.

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

### ✅ Fase 5 — Il Limine: il terzo stato

Il gesto c'è: tap e hold sullo stesso tasto, il viaggio si ferma a metà e riparte nella direzione in cui stavi andando, la Lucidity si spende invece di accumularsi soltanto. Il centro paga 40/s e costa 30/s di carburante.

**Le decisioni che restano vincolanti**

- **La sospensione è una pausa dell'orologio del viaggio, non un movimento a parte.** Si congela a metà e riparte da lì, ed è per questo che nessuna riga deve ricordare da dove venivi: c'è una sola direzione di marcia e non cambia mai. Qualunque modifica al flip deve preservarlo — nel momento in cui la sospensione diventa un moto suo, la frase che spiega i comandi smette di essere vera.
- **La durata del viaggio è la soglia tra i due gesti.** Il punto in cui ci si ferma è metà viaggio, quindi il tempo per arrivarci *è* il confine tra tap e hold. `FLIP_DURATION` non è una manopola di feel: è anche quanto deve durare una pressione per contare come hold. Sotto ~0.20s la sospensione involontaria torna a rischio.
- **Velocità costante, e non è pigrizia.** Qualunque curva che parta più veloce della media deve restituire il tempo prima di metà strada — aritmetica, non tuning — e restituirlo significa decelerare a mezz'aria. Il primo tentativo lo faceva apposta, per far *vedere* la soglia; al playtest era un intoppo nell'unico gesto del gioco. **Lezione generale per le fasi 9 e 11**: un fronzolo messo sul movimento del giocatore non è decorazione, è attrito. Si insegna con lo sfondo, la luce, le particelle — mai facendo fare al personaggio qualcosa che il giocatore non ha chiesto.
- **Un near-miss è "l'ostacolo è arrivato nella corsia che avevi appena lasciato"**, ancorato alla partenza e non all'atterraggio. La versione precedente guardava solo se il giocatore si fosse sistemato da poco, senza guardare dove fosse l'ostacolo: pagava per schivate immaginarie e non pagava quelle vere colte a mezz'aria. Ancorare alla partenza rende la regola indipendente dallo stato in cui ti trova l'ostacolo, e si difende da sola dentro il Limine perché la finestra si misura da una partenza che si allontana.
- **Una risorsa sola, e si vede quando incassa.** Lucidity è insieme carburante e moltiplicatore: da lì nasce la domanda "banco o brucio?". La barra lampeggia sull'incasso — non era un vezzo, al playtest la risorsa sembrava rotta solo perché non si vedeva guadagnare.
- **Niente invulnerabilità nel Limine**, e la grazia del flip (0.15s) è più corta del viaggio: senza cooldown sul flip, una grazia lunga quanto il viaggio significherebbe invulnerabilità permanente per chi martella il tasto.

**Ricaduta sul salvataggio**: `SAVE_FORMAT_VERSION` 3 → 4 e `GAME_VERSION` → 0.2.0-alpha. Il manifesto registra anche i rilasci del tasto, senza i quali una run col Limine non è riproducibile.

**Squilibrio ancora aperto**: il centro è **sicuro**, tutti gli ostacoli sono attaccati alle pareti. Si chiude in T6.6; fino ad allora il consumo di Lucidity è tarato più duro di quanto dovrà restare.

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

Fasi 0-2.5 completate. Il conteggio qui sotto è **quel che resta**.

| Fase | Sonnet | Opus |
|---|---|---|
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
| **Totale rimanente** | **25** | **32** |

Il rapporto si è spostato verso Opus rispetto al piano iniziale, ed è corretto che sia così: le fasi che restano decidono *come si gioca* (il gesto del Limine, le regole di collisione, gli archetipi anticipatori, il bilanciamento) invece di spostare file. Le fasi economiche da mandare in Sonnet restano la **9** (preset di particelle, molto ripetitivi) e la **13** (UI).

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
