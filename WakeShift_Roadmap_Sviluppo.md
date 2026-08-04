# WAKE SHIFT — Roadmap di Sviluppo
### Da zero alla versione Alpha/Beta — Odin + raylib

---

## Come funziona questa roadmap

- Ogni **sezione = una lezione**. Ha un obiettivo chiaro, introduce codice nuovo (un pezzo alla volta, non tutto insieme), e finisce con un **test di verifica**: qualcosa che deve funzionare a schermo prima di passare alla sezione successiva.
- Non si passa alla sezione N+1 finché il test della sezione N non è verificato. Se qualcosa non torna, si aggiusta lì, non si va avanti "sperando che si sistemi dopo".
- Ogni sezione dichiara anche **quali concetti Odin** vengono toccati, così sai cosa stai imparando mentre lo scrivi (utile visto che vieni da Zig e la base c'è già, ma la sintassi/idiomi Odin sono loro).
- Il riferimento vincolante per *cosa* costruire resta il Design Doc v1.0. Questa roadmap è il *come* e *in che ordine*.
- Struttura a cartelle di riferimento (dal Design Doc, sez. 14): la seguiamo fin dalla Sezione 0, non alla fine.

---

## Sezione 0 — Setup progetto e finestra vuota

**Obiettivo**: avere un progetto Odin che compila, con raylib collegata, e una finestra che si apre a 60 FPS.

**Cosa introduciamo**:
- Struttura cartelle iniziale (`src/main.odin`, resto delle cartelle vuote per ora)
- Import del package raylib
- Game loop minimo: `InitWindow`, ciclo `for !WindowShouldClose()`, `BeginDrawing`/`EndDrawing`, `CloseWindow`
- `SetTargetFPS(60)` — il vincolo dei 60 FPS è di design (sez. 6 del Design Doc), lo mettiamo fin da subito

**Concetti Odin**: package, import, procedure `main`, ciclo `for` come `while`

**Test di verifica**: si apre una finestra 1280×720 con sfondo di un colore a scelta, si chiude con ESC o click sulla X, senza crash.

---

## Sezione 1 — Il personaggio, statico

**Obiettivo**: disegnare il player come rettangolo (silhouette provvisoria) fermo nella Corsia Reale (pavimento).

**Cosa introduciamo**:
- `struct Player` con posizione, dimensioni
- Divisione verticale dello schermo secondo le percentuali del Design Doc (sez. 6): 30% Onirico / 40% zona centrale / 30% Reale
- Disegno del player con `DrawRectangleRec` o simile, ancorato al "pavimento" (bordo inferiore della corsia Reale)

**Concetti Odin**: struct, inizializzazione di struct, costanti (`::`) per le proporzioni schermo

**Test di verifica**: rettangolo fermo visibile nella fascia bassa dello schermo, nella posizione corretta rispetto alle proporzioni definite.

---

## Sezione 2 — Il Flip (senza transizione, solo lo switch)

**Obiettivo**: premendo Spazio il player salta istantaneamente da corsia Reale a corsia Onirico e viceversa. Nessuna animazione ancora — solo la meccanica pura, per validare l'input prima di vestirlo.

**Cosa introduciamo**:
- `enum Corsia { Reale, Onirico }`
- Campo `corsia: Corsia` nel `Player`
- `IsKeyPressed(.SPACE)` per invertire il valore
- Riposizionamento immediato del player in base alla corsia corrente

**Concetti Odin**: enum, `switch`/`if` su enum, gestione input raylib

**Test di verifica**: Spazio fa saltare il rettangolo tra pavimento e soffitto, istantaneamente, in modo affidabile (nessun doppio input accidentale, nessun input perso).

---

## Sezione 3 — Macchina a stati del personaggio

**Obiettivo**: introdurre lo stato "In-Transizione" già prima di avere l'animazione vera, così la struttura è pronta quando aggiungiamo il micro-delay del flip.

**Cosa introduciamo**:
- `enum StatoPlayer { Reale, Onirico, Transizione }`
- Il player ora ha `stato` invece di (o oltre a) `corsia`
- Logica: alla pressione di Spazio, se non si è già in transizione, si entra in `Transizione`; un timer decide quando si esce nello stato opposto

**Concetti Odin**: enum più articolato, gestione del tempo con `rl.GetFrameTime()`, pattern "timer accumulator"

**Test di verifica**: il flip ora ha un breve ritardo prima di completarsi (anche se visivamente ancora "di scatto" — l'animazione vera arriva in Sezione 4). Durante la transizione, un secondo flip non deve rompere lo stato.

---

## Sezione 4 — Animazione del flip: easing + frame di grazia

**Obiettivo**: il flip diventa quello descritto nel Design Doc (sez. 4): micro-transizione ~0.1–0.15s con movimento interpolato (non teletrasporto), più un breve frame di invulnerabilità.

**Cosa introduciamo**:
- Interpolazione della posizione Y del player durante `Transizione` con una funzione di easing (raylib ne offre già pronte, oppure una semplice `lerp` con curva)
- Flag `invulnerabile: bool` legato alla durata dello stato `Transizione`
- Costanti separate per durata transizione e durata frame di grazia (già nel Design Doc si nota che potrebbero differire — teniamole come due costanti distinte fin da subito)

**Concetti Odin**: procedure che ritornano valori (funzione di easing), costanti float, passaggio di puntatori (`^Player`) per modificare lo stato dentro una procedura dedicata `update_player`

**Test di verifica**: il personaggio si sposta visibilmente (non a scatto) tra le due corsie; durante il movimento è "intoccabile" (lo verificheremo bene in Sezione 7, quando esisteranno le collisioni — per ora basta che il flag esista e si azzeri correttamente a fine transizione).

---

## Sezione 5 — Il mondo che scorre

**Obiettivo**: dare la sensazione di corsa automatica orizzontale, anche senza ostacoli ancora.

**Cosa introduciamo**:
- Una variabile globale (o in uno `struct World`) `velocita_scroll`
- Elementi di sfondo/pavimento/soffitto che si muovono verso sinistra a `velocita_scroll * GetFrameTime()`
- Velocità iniziale secondo i numeri del Design Doc (sez. 6: ~260–280 px/s)

**Concetti Odin**: primo vero `struct World`, procedura `update_world`, iniziamo a separare la logica in file diversi (`src/world/world.odin`)

**Test di verifica**: il pavimento (o una linea/texture segnaposto) scorre visibilmente a velocità costante e credibile.

---

## Sezione 6 — Primo ostacolo, hardcoded

**Obiettivo**: un singolo ostacolo statico (Blocco, Mondo Reale) che appare, scorre verso il player, e per ora lo attraversa senza conseguenze — serve solo a validare spawn e movimento relativo.

**Cosa introduciamo**:
- `struct Obstacle` con posizione, dimensioni, tipo (per ora un solo tipo)
- Spawn manuale in un punto fisso, con movimento legato a `velocita_scroll`
- Cartella `src/obstacles/`

**Concetti Odin**: primo array/slice di struct (`[dynamic]Obstacle` o array fisso), iterazione con `for`

**Test di verifica**: il blocco appare da destra, scorre verso sinistra alla velocità corretta, esce di scena senza crash.

---

## Sezione 7 — Collisione e Risveglio (game over base)

**Obiettivo**: se il player tocca l'ostacolo (ed è nella corsia sbagliata, e non invulnerabile), la run finisce.

**Cosa introduciamo**:
- Collisione AABB (`CheckCollisionRecs` di raylib o funzione custom)
- `enum StatoGioco { InCorso, GameOver }` a livello di gioco generale (non del player)
- Al game over: freeze della simulazione, testo a schermo, tasto per riavviare (reset di player/world/ostacoli)

**Concetti Odin**: primo vero controllo condizionale complesso (corsia + invulnerabilità + collisione), reset dello stato (utile capire qui la differenza fra ri-creare uno struct da zero vs resettare i campi)

**Test di verifica**: collisione = game over, il frame di grazia della Sezione 4 protegge davvero durante la transizione, e si può riavviare la run.

---

## Sezione 8 — Ostacoli come eventi nel tempo (refactor)

**Obiettivo**: prima di aggiungere altri ostacoli, sistemiamo la fondazione secondo il principio del Design Doc (sez. 6): pattern descritti in **tempo relativo**, non pixel assoluti.

**Cosa introduciamo**:
- `struct ObstacleEvent { tempo: f32, tipo: TipoOstacolo, corsia: Corsia }`
- Conversione da "evento nel tempo" a posizione X reale a runtime, moltiplicando per `velocita_scroll`
- Refactor dello spawn della Sezione 6/7 per passare da questo nuovo sistema

**Concetti Odin**: refactor consapevole (si tocca codice già scritto, si capisce perché), forse prima introduzione a `enum` con più varianti (`TipoOstacolo`)

**Test di verifica**: stesso comportamento a schermo di prima, ma ora il timing è guidato da eventi temporali — se cambiamo `velocita_scroll` a mano, l'ostacolo deve ancora apparire "al momento giusto" percepito, non a un pixel fisso.

---

## Sezione 9 — Pattern e pool

**Obiettivo**: passare da un singolo ostacolo hardcoded a un vero **pattern** (sequenza di 3–5s, sez. 7 Design Doc), e da un pattern a un piccolo **pool** di pattern.

**Cosa introduciamo**:
- `struct Pattern { eventi: []ObstacleEvent, aggancio_inizio, aggancio_fine: Corsia }`
- 2-3 pattern scritti a mano per il Mondo Reale
- Concatenazione manuale (ancora non casuale) di più pattern in sequenza

**Concetti Odin**: slice di struct dentro struct, organizzazione dati statici (array di `Pattern` definiti a livello di package), cartella `src/patterns/`

**Test di verifica**: più pattern si susseguono senza interruzioni o salti innaturali, i punti di aggancio inizio/fine coincidono correttamente tra un pattern e il successivo.

---

## Sezione 10 — Generatore procedurale

**Obiettivo**: selezione casuale (ma vincolata) del prossimo pattern dal pool, rispettando gli aggangi.

**Cosa introduciamo**:
- Funzione `pick_next_pattern` che filtra il pool per compatibilità di aggancio e sceglie casualmente tra i candidati
- Gestione dei numeri casuali in Odin (`rand` package)

**Concetti Odin**: package `core:math/rand`, filtri su slice, prima vera "logica di gioco" non banale

**Test di verifica**: run ripetute generano sequenze diverse di pattern, mai una sequenza irrisolvibile o con salti bruschi di aggancio.

---

## Sezione 11 — Ostacoli multipli e Mondo Onirico

**Obiettivo**: aggiungere gli altri tipi di ostacolo minimi per l'MVP (Design Doc sez. 16): Voragine per il Reale, Forma pulsante e Buco onirico per l'Onirico.

**Cosa introduciamo**:
- Estensione di `TipoOstacolo` (enum) e della logica di disegno/collisione per gestire comportamenti diversi (statico vs sinusoidale vs "assenza")
- Pattern dedicati al Mondo Onirico (pool separato, come da sez. 7 Design Doc)
- Prima vera oscillazione sinusoidale (`sin(tempo)`) per la Forma pulsante

**Concetti Odin**: `switch` su enum per comportamenti diversi, funzioni matematiche (`math.sin`), gestione di "assenza" come ostacolo (Voragine/Buco: la collisione qui è concettualmente invertita)

**Test di verifica**: entrambi i mondi hanno almeno 2 tipi di ostacolo funzionanti e leggibili, con la fase di "arrivo" (fade-in/crescita, sez. 5 Design Doc) visibile prima della minaccia piena.

---

## Sezione 12 — Punteggio: Profondità Onirica

**Obiettivo**: punteggio che cresce nel tempo, più velocemente nel Mondo Onirico che nel Reale (Design Doc sez. 8).

**Cosa introduciamo**:
- Variabile punteggio in `struct GameState`
- Incremento differenziato in base a `player.corsia`/`stato`
- Visualizzazione a schermo (testo semplice per ora, l'HUD vero arriva in Sezione 13)

**Concetti Odin**: formattazione stringhe per il testo a schermo (`fmt.tprintf` o simile), prima introduzione a uno `struct GameState` centrale che raccoglie i dati della run

**Test di verifica**: il numero cresce in modo visibile e coerente, più veloce quando si sta nell'Onirico.

---

## Sezione 13 — UI: Menu, HUD, Pausa

**Obiettivo**: il gioco smette di essere "solo simulazione" e diventa navigabile: Main Menu, HUD in gioco, overlay di Pausa (Design Doc sez. 9).

**Cosa introduciamo**:
- `enum SchermataAttuale { MainMenu, InGioco, Pausa, GameOver }` a livello globale (macchina a stati dell'applicazione, distinta da quella del player)
- Disegno condizionale in base alla schermata attuale
- Cartella `src/ui/`

**Concetti Odin**: gestione di più "stati applicativi" annidati (schermata generale + stato player + stato gioco), organizzazione del codice per evitare un `main` gigante

**Test di verifica**: si parte dal menu, si entra in gioco, ESC mette in pausa e riprende correttamente, game over porta a una schermata dedicata.

---

## Sezione 14 — Referto Onirico (fine run) + persistenza record

**Obiettivo**: schermata di fine run con statistiche (Design Doc sez. 8-9) e salvataggio locale del record personale (sez. 10).

**Cosa introduciamo**:
- Raccolta di statistiche minime a fine run (punteggio finale, forse tempo di sopravvivenza)
- Lettura/scrittura di un file locale semplice (testo o binario minimale) per il record
- Cartella dati fuori da `src/` (o accanto all'eseguibile, da decidere in pratica)

**Concetti Odin**: I/O su file (package `os`), gestione errori Odin (valori multipli di ritorno, `ok` pattern — utile visto che vieni da Zig, qui non c'è `try`/`catch` ma il pattern è concettualmente simile)

**Test di verifica**: chiudendo e riaprendo il gioco, il record precedente è ancora lì; un punteggio più alto lo aggiorna correttamente.

---

## Sezione 15 — Squash & Stretch e particelle base

**Obiettivo**: primo passo di "polish" secondo lo stile Silhouette + Luce (Design Doc sez. 12): il personaggio non è più un rettangolo rigido, e ci sono le prime particelle.

**Cosa introduciamo**:
- Interpolazione di scala X/Y del player nei momenti chiave (atterraggio dopo flip)
- `struct Particle` minimale + pool riutilizzabile (array fisso, non allocazioni continue)
- Particelle da contatto (Reale, lineari) ed esplosione al momento del flip

**Concetti Odin**: pool di oggetti riutilizzabili (pattern comune in game dev per evitare allocazioni ogni frame — rilevante anche perché in Odin la gestione memoria è esplicita), cartella `src/particles/`

**Test di verifica**: il personaggio ha un minimo di "peso" percepito nei movimenti, le particelle appaiono nei momenti giusti senza impatto visibile sulle prestazioni.

---

## Sezione 16 — Audio base

**Obiettivo**: SFX di Flip e Collisione/Risveglio (priorità secondo Design Doc sez. 13), poi le due tracce musicali con crossfade.

**Cosa introduciamo**:
- Caricamento e riproduzione SFX con raylib audio
- Le due tracce musicali sincronizzate, crossfade legato allo stato `Transizione` del player
- Cartella `src/audio/` + `assets/audio/`

**Concetti Odin**: gestione risorse (caricamento/scaricamento audio, tipico problema di lifetime — di nuovo, terreno familiare venendo da Zig), interpolazione del volume nel tempo per il crossfade

**Test di verifica**: flip e collisione hanno feedback sonoro immediato; le due tracce si sentono come "la stessa base vista da due prospettive", non come due canzoni che si accavallano goffamente.

---

## Sezione 17 — Sistema Lucidità

**Obiettivo**: streak di flip corretti consecutivi (Design Doc sez. 8), con feedback visivo/sonoro crescente (particelle più dense, sez. 12, e "ding" che sale di tono, sez. 13).

**Cosa introduciamo**:
- Contatore streak nel `GameState`, si azzera all'errore (se applicabile — da definire con "flip corretto" cosa intende esattamente)
- Collegamento streak → densità particelle e → pitch del suono di streak

**Concetti Odin**: niente di nuovo strutturalmente, è più che altro collegare sistemi già esistenti tra loro — buon momento per consolidare

**Test di verifica**: la streak cresce e si vede/sente crescere in tempo reale, si azzera in modo comprensibile per il giocatore.

---

## Sezione 18 — Tier di difficoltà

**Obiettivo**: curva di difficoltà vera (Design Doc sez. 7): velocità crescente nel tempo, sblocco progressivo di pattern Medio/Difficile.

**Cosa introduciamo**:
- Funzione di crescita della `velocita_scroll` nel tempo (qui si decide finalmente la curva aperta in sez. 18 del Design Doc — lineare o a scalini, la testiamo qui)
- Pool di pattern aggiuntivi per i tier superiori, sblocco per soglia di punteggio/tempo

**Concetti Odin**: nessun concetto nuovo importante, ma prima vera sessione di **bilanciamento numerico** — qui il ruolo di "architetto" tuo diventa centrale, io scrivo i numeri che decidi tu

**Test di verifica**: la run diventa percepibilmente più difficile nel tempo in modo graduale, mai con un salto improvviso e ingiusto.

---

## Sezione 19 — Bilanciamento, rifinitura, Alpha

**Obiettivo**: non è una sezione di nuovo codice, ma di playtest mirato (Design Doc sez. 17: prima sessioni prolungate in prima persona, poi build condivisa con un piccolo gruppo esterno).

**Cosa facciamo**:
- Passiamo in rassegna ogni numero rimasto "indicativo" nel Design Doc (frame di grazia, finestre di reazione, curva di velocità) e li fissiamo sulla base del test reale
- Fix di bug emersi durante il playtest
- A questo punto hai una **Alpha giocabile**: tutto lo scope MVP del Design Doc (sez. 16) è coperto

**Test di verifica**: qualcuno che non ha mai visto il gioco lo capisce in meno di 2 secondi (pilastro #2) e riesce a giocare una run senza sentirsi trattato ingiustamente.

---

## Oltre la Sezione 19

Da qui si entra nella Roadmap Post-MVP del Design Doc (sez. 17): pool ostacoli completo, tier Estremo, Referto Onirico condivisibile, polish audio/visivo avanzato, packaging per distribuzione. La affronteremo come estensione di questa roadmap una volta che l'Alpha è stabile e testata — non ha senso pianificarla nel dettaglio adesso, i numeri e le priorità potrebbero cambiare in base a cosa impariamo dal playtest della Sezione 19.

---

*Roadmap v1.0 — compagna del Design Doc v1.0. Procediamo una sezione alla volta, in ordine, senza saltare: ogni sezione presuppone che quella precedente sia testata e funzionante.*
