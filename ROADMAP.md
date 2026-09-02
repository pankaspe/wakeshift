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

Verificato sul codice, 2 settembre 2026 — aggiornato a chiusura Fase 6.

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
- **[Fase 4]** Bloom vero: bright-pass + blur gaussiano separabile su shader, intensità e soglia guidate da `world_t` e `depth_t` come la palette. 0.17 ms a frame nel caso peggiore
- **[Fase 6]** Sei ostacoli con **sei letture**: presenza vs assenza come regole di collisione diverse, voragini ritagliate davvero nel terreno, e i tre archetipi anticipatori (Eco, Finta, Pattugliatore). Il Pattugliatore attraversa il Limine, quindi il centro ha smesso di essere gratis
- **[Fase 5]** **Il Limine è giocabile**: tap e hold sullo stesso tasto, il viaggio si ferma a metà e riparte nella direzione in cui stavi andando, Lucidity che si spende invece di accumularsi soltanto, ritmo di punteggio a 40/s al centro, barra della risorsa nell'HUD

**Non funziona / manca**
- La curva di difficoltà viene ancora quasi solo dalla velocità (270 → 330 → 400 px/s): le letture ora sono sei, ma la tabella dei tier cambia solo quanto in fretta arrivano (T7.3)
- Il contratto `entry_lane`/`exit_lane` dei pattern non sa che esiste il Limine: un pattern risolto sospendendosi esce nella corsia opposta a quello risolto con i flip (T7.1)
- Pochi pattern: 11 in tutto su tre tier, contro i 12-16 previsti (T7.2)
- **Il giocatore e gli ostacoli sono affondati nel terreno.** `get_lane_y` ancora la corsia Reale al bordo dello schermo (y=675, piedi a 720), ma la superficie del terreno sta a y=690-706: **da 14 a 30px di un personaggio alto 45 stanno sotto il suolo su cui dovrebbe correre**, e lo stesso al soffitto. Viene da quando il terreno ha preso un profilo irregolare e nessuno ha aggiornato le corsie. Vedi la nota nella Fase 10
- Nessuna particella, nessun parallax, nessun audio
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

**Creato nella Fase 4**: `fx/` — parametrico, non sa niente del gioco. Oggi contiene il bloom; le particelle ci si aggiungono nella Fase 9. **Ancora da creare**: `audio/` (Fase 12).

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

### ✅ Fase 4 — Bloom reale

Nasce `fx/`, il package parametrico che non sa niente del gioco: prende una render texture e dei numeri. Dentro c'è il bloom vero — bright-pass con soglia morbida, blur gaussiano separabile a 9 tap su due iterazioni a offset crescenti, composite additivo di ritorno sul frame. Costo misurato nel caso peggiore (2560×1440, 51 ostacoli, 400 px/s, giocatore sospeso, due passate di composite): **0.17 ms di bloom su 1.42 ms di frame, il 9% del budget dei 60 FPS.**

**Le decisioni che restano vincolanti**

- **Il post-processing gira sul frame finito**, tra la chiusura del canvas e il blit: `end_game_canvas` → `apply_bloom` → `present_display`. `apply_bloom` ricompone dentro la texture che ha letto, così `platform` non sa che il bloom esiste e `fx` non sa che esiste un gioco.
- **Le render texture sono memorizzate dal basso verso l'alto, e il flip avviene una volta sola** in `present_display`. Tutte le passate intermedie disegnano con source rect positivo, che porta avanti la convenzione invariata. Un secondo flip in mezzo specchia la luce lontano da ciò che l'ha emessa, in silenzio.
- **Il bloom è LDR**: il frame è RGBA8, quindi "luminoso" vuol dire "vicino al bianco", e **le soglie vanno tarate su quello che arriva al frame, non sulla palette**. Un bordo disegnato al 70% di alpha su fondo scuro atterra a ~0.66, non allo 0.91 che il suo colore dichiara. Tarato sulla palette, il bloom del Reale era invisibile.
- **Luce e colore devono descrivere un mondo solo**: `bloom_for_world` interpola sugli stessi due segmenti di `sample_palette` e converge verso il Limine della stessa quantità (`core.CONVERGENCE_MAX`). Se i due sistemi divergono, l'immagine smette di essere d'accordo con sé stessa.
- **Gli shader stanno dentro il binario**, non su disco: il gioco resta un eseguibile solo, e un `.fs` mancante sarebbe un crash all'avvio in cambio di niente. Uno shader che non compila **disabilita il bloom** invece di far cadere il gioco — stessa regola del salvataggio.
- **I due glow si sommano.** Quello da primitive (`render/glow.odin`) era il sostituto del bloom e ora lo alimenta: un alone disegnato è luminoso, quindi il bright-pass lo riprende e lo rifiora. Da tenere presente nella Fase 9 — anche le particelle passeranno di lì. Dove un alone sembra doppio si toglie quello da primitive, non si abbassa il bloom.

**Come si verifica un effetto GPU**: rileggendo i pixel. `rl.LoadImageFromTexture` sul render target trasforma "il bloom si vede giusto?" in aritmetica — stesso frame due volte, con e senza, confronto della luminosità riga per riga. Ha stabilito che il composite non è capovolto (la luce cade sulla riga che l'ha emessa, non sul suo specchio) e ha trovato il bloom invisibile del Reale. Il soggetto del test deve essere **asimmetrico**: la prima versione usava il frame del gioco, la cui banda più luminosa è l'orizzonte, che sta al centro esatto — dove un capovolgimento è indistinguibile. La lezione è in `CLAUDE.md`.

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

### ✅ Fase 6 — Ostacoli veri

Sei tipi, e finalmente sei letture invece di una regola con sei pelli. Le voragini sono ritagliate davvero nel terreno, la fase delle animazioni è ancorata e autorata, e il Pattugliatore attraversa il Limine — che è il momento in cui il centro smette di essere gratis.

**Le decisioni che restano vincolanti**

- **Pieno contro vuoto sono due *regole*, non due disegni.** Una presenza uccide chi la tocca; un'assenza uccide solo chi ci sta appoggiato sopra. Una voragine quindi non fa niente a chi è a mezz'aria, sospeso o al soffitto, ed essendo larga fino a 2.6 volte un blocco chiede "non stare quaggiù per questo tratto" dove il blocco chiede "spostati, ora". È da lì che nascono due letture diverse, non dalla grafica.
- **Il terreno ritaglia i propri buchi.** È l'unico codice che sa dov'è la propria superficie, quindi la campiona come funzione di x, sottrae i vuoti dalla larghezza dello schermo e disegna quel che resta una campata alla volta. `draw_obstacle` esce subito per `Chasm` e `DreamHole`. Disegnarli come oggetti è ciò che li ha fatti sembrare scatole in piedi sul pavimento per tutto il prototipo.
- **Un ostacolo non legge mai il giocatore.** Ciò che fa sembrare intelligente un ostacolo è *anticipare* la risposta ovvia, non reagire a quella vera: un ostacolo che si adatta si percepisce come rubato anche quando è risolvibile (pilastro 3). Eco e Finta sono interamente autorati, e la spazzata del Pattugliatore è funzione del proprio `arrival_time` e di nient'altro.
- **La fase di un'animazione è ancorata all'`arrival_time` e autorata nel pattern.** Il tempo globale fa presentare allo stesso pattern una faccia diversa ogni run — né l'autore né il giocatore possono impararla — e estrarla a caso sposta il problema nel seed invece di risolverlo. È la differenza tra "una forma che pulsa" e "una forma che sarà un muro quando ti raggiunge".
- **Il pavimento si rompe, il soffitto si dissolve.** Stesso taglio, lettura opposta: bordi netti e fossa buia da una parte, bordi che sfumano e bagliore dietro dall'altra.

**Come si verifica un ostacolo**: rigiocandolo. Il programma usa-e-getta guida la simulazione vera con input scriptati e chiede *se un pattern si può sopravvivere e come*. Ha stabilito che l'Eco punisce il flip di panico e si risolve sia con due flip stretti sia con una sospensione, e che l'Eco guardato si risolve ancora con i flip ma **non più sospendendosi**. Un test che verifica una regola di collisione non basta: quello che conta è se la domanda che l'ostacolo pone ha una risposta.

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

**Direzione artistica della Foresta** — indicazione del committente, da approfondire quando ci arriviamo:

> Il *mood* è quello di **Zangarmarsh** (WoW, Terrallenword): foresta umida e luminescente, funghi giganti, luce che filtra, atmosfera satura. Una foresta che da **reale** diventa **onirica** giocando sui colori — palette blu/viola — con il bloom a fare gran parte del lavoro. Il personaggio non resta una figura astratta: **uno scoiattolo, uno spiritello, qualcosa che appartiene alla foresta**.

Due note tecniche da tenere presenti quando si progetta:
- È **compatibile con l'identità già costruita**, non un cambio di rotta: la palette Onirico è già viola/magenta e il Reale già blu freddo, e "silhouette + luce" con bloom è esattamente il linguaggio di una foresta luminescente. Non servono asset esterni.
- Il personaggio è già uno **scheletro di giunti** (`render/player.odin`): dargli proporzioni da scoiattolo e una coda è un cambio di costanti più un osso in più, non una riscrittura. La regola della silhouette unica resta — corpo scuro, cambia solo la luce.

| Task | Descrizione | Modello |
|---|---|---|
| T10.0 | **Il terreno diventa geometria di gioco, non decorazione**: il profilo si sposta in `core`, `get_lane_y` lo campiona, e il giocatore corre *sopra* il suolo invece che dentro. Tocca la simulazione — gli estremi del viaggio del flip e `world_t` si muovono col terreno — quindi è un task, non una costante da ritoccare | **Opus** |
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

Fasi 0-6 completate. Il conteggio qui sotto è **quel che resta**.

| Fase | Sonnet | Opus |
|---|---|---|
| 7 — Pattern e difficoltà | 2 | 2 |
| 8 — Bonus di luce | 3 | 3 |
| 9 — Particelle | 5 | 1 |
| 10 — Strati e transizione (+ T10.0) | 2 | 4 |
| 11 — Game feel | 1 | 2 |
| 12 — Audio | 2 | 3 |
| 13 — UI e rifinitura | 3 | 2 |
| **Totale rimanente** | **18** | **17** |

Il piano è a metà: erano 25 Sonnet e 32 Opus a chiusura della Fase 2.5. Le fasi più pesanti in Opus — il gesto del Limine, le regole di collisione, la convergenza delle palette, la matematica dello shader — sono fatte, ed è per questo che il rapporto si è riequilibrato.

Dove conviene spendere Opus da qui, in ordine: la **10** (il sistema degli strati e la transizione come evento, più T10.0 che sposta il terreno dentro la simulazione), la **11** (bilanciamento numerico, dove il determinismo della Fase 2 finalmente ripaga: si rigioca la stessa run identica dopo ogni modifica) e la **8** (il piazzamento dei bonus nella corsia pericolosa, che è una decisione di design non una funzione). Le fasi economiche da mandare in Sonnet restano la **9** (preset di particelle, molto ripetitivi) e la **13** (UI).

---

## Definition of Done — Alpha

`[x]` fatto · `[~]` c'è ma non nella forma finale · `[ ]` non iniziato

- [x] Salvataggio cifrato nella directory dati utente, con manifesto della run migliore
- [x] Run riproducibile da seed + log input (base della leaderboard e dei replay)
- [~] Tre stati giocabili: ci sono e hanno costi diversi, il bilanciamento vero è la Fase 11
- [x] Il personaggio ha un corpo e due pose leggibili: la frustata del tap, il galleggiamento dell'hold
- [~] Sistema visivo a tre palette con blending continuo e bloom attivi insieme; mancano particelle e parallax
- [x] **La convergenza funziona**: scendendo, i due mondi si somigliano sempre di più — palette *e* bloom convergono insieme — e posizione e movimento reggono da soli
- [x] Almeno 6 tipi di ostacolo con **letture distinte**, di cui almeno uno che minaccia il Limine e almeno uno anticipatorio (Eco / Finta / Pattugliatore)
- [ ] 12-16 pattern distribuiti su tre tier
- [ ] Bonus di luce raccolti per posizione, piazzati dove costa qualcosa prenderli
- [ ] **Due strati e la transizione fra loro**, come evento che non ferma il gioco
- [ ] Audio: due mix sincronizzati + traccia per strato + i SFX principali
- [x] Avvio a schermo pieno alla risoluzione del monitor, con modalità finestra e impostazioni ricordate fra un avvio e l'altro
- [~] Menu, pausa e opzioni ci sono; manca il Referto Onirico (T13.2)
- [~] **60 FPS stabili**: misurati 705 con bloom sul frame peggiore, ma particelle e parallax non ci sono ancora
- [ ] Run media 45-90 secondi, curva di difficoltà leggibile
- [~] Un giocatore nuovo capisce il gesto tap/hold entro 30 secondi senza istruzioni — da riverificare con qualcuno che non sia l'autore
- [x] Tre stati distinguibili senza affidarsi al colore: posizione, e tipo di movimento (corsa a terra, deriva nell'onirico, corpo aperto e oscillante nel Limine)
