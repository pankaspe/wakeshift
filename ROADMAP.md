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

**Fatte R1 e R2.** Il gioco adesso *è* quello del documento nel suo cuore: due corsie, un
gesto, il cubo che blocca invece di uccidere, e la Corruzione che avanza da sinistra mangiando
il terreno che perdi. Mancano il tracciato che curva (R3), la Sentinella e le varianti del cubo
(R4), il pool vero (R5) e l'economia (R6).

**Cosa sopravvive intatto e non va toccato**: tutto `platform/` (finestra, display,
salvataggio, cifratura, percorsi); `fx/bloom`; `render/stroke` e `render/glow`; i menu e le
opzioni; il timestep fisso, il recorder e il manifesto; l'asse saturazione della palette
costruito nella T8.1.

---

## Le fasi

### ✅ Fase R1 — Sfoltire

Tolto tutto ciò che la v2.0 non ha, prima di costruire. Il gioco compila, parte e gira: due
corsie, un gesto, due tipi di ostacolo. Da 7 file di gameplay a 6, e `game/lucidity.odin`
cancellato per intero.

**Cosa è sparito**: lo stato sospeso e la distinzione tap/hold (e con loro `Input.flip_held`,
i tick di rilascio nel manifesto, la posa raccolta e gli anelli nell'occhio); la Lucidity
intera, il near-miss, il moltiplicatore e la barra nell'HUD; quattro tipi di ostacolo
(Feint, Forma pulsante, Pattugliatore, Gradino) più il ritaglio del Gradino nel terreno;
`core.Band`, `core.Bands` e tutta la macchina di concatenamento fra pattern. La palette del
Limine è diventata la palette **neutra** — stesso colore, ruolo diverso: non è più uno stato,
è il punto verso cui i due mondi convergono con la profondità.

**Le tre decisioni che restano vincolanti**

1. **Il contratto è una riga.** *In ogni istante almeno una corsia dev'essere non letale.*
   `validate_pattern_pool` la verifica per aritmetica invece che per attenzione dell'autore:
   calcola la finestra temporale in cui ogni evento rende letale la sua corsia — alla velocità
   più lenta e con la larghezza massima che quel tipo può estrarre, cioè il caso peggiore — e
   controlla che una finestra Reale e una Onirica non si sovrappongano mai. **Controlla anche
   la giuntura**, per ogni coppia ordinata di pattern al `gap` più stretto fra i tier: una
   voragine larga alla fine di un pattern e un cubo all'inizio del successivo sono autorati in
   due momenti diversi e si incontrano solo a runtime.
2. **I pattern non si concatenano più.** Non serve: se una corsia è sempre aperta, in qualunque
   corsia il pattern trovi il giocatore c'è qualcosa che può fare. Ed è proprio il
   concatenamento che aveva ucciso la v1.x — garantiva di entrare in ogni pattern dalla fascia
   sicura, cioè quella in cui la minaccia non è. La lezione sta in `CLAUDE.md`: **un contratto
   che ti garantisce di partire al sicuro è un contratto che premia lo stare fermi.**
3. **Il buffer del tap è profondo uno, di proposito.** Misurato: cinque pressioni su cinque
   step consecutivi producono due flip, non cinque. Una coda più profonda lascerebbe accumulare
   flip che il giocatore non vede più arrivare, e il personaggio continuerebbe a girarsi dopo
   che ha smesso di chiederlo. Una pressione in anticipo è perdono; cinque è il gioco che si
   gioca da solo.

**Misurato** (arnese usa-e-getta sulla simulazione vera, 200 seed × 120 s, poi cancellato):

| | prima (v1.3) | adesso |
|---|---|---|
| run senza mai premere che superano il tier 1 | **161/200** | **0/200** |
| morte mediana senza input | 35.5 s | **3.5 s** |
| almeno una corsia letale | 13.7% | **19.9%** |
| entrambe le corsie letali | 0.0% | 0.000% ✅ (è la regola) |
| durata del flip | 0.24 s | **0.167 s** |

Il numero che conta è il primo: **stare fermi non porta più da nessuna parte.** Il 19.9% è
ancora lontano dal 40% della Definition of Done, ed è giusto così — la densità e il pool vero
sono la R5, e il pool attuale è volutamente minimo (11 pattern, due tipi di ostacolo) perché
autorarlo adesso vorrebbe dire autorarlo contro un cubo che ancora uccide.

**Ricaduta sul salvataggio, fatta**: `SAVE_FORMAT_VERSION` 4 → 5 e `GAME_VERSION` →
`1.0.0-alpha`. **I salvataggi esistenti sono illeggibili e il record personale si è perso**, che
è il comportamento giusto due volte: il formato non ha più i tick di rilascio, e una profondità
segnata nel gioco a tre stati era segnata in un altro gioco.

---

### ✅ Fase R2 — Il tira e molla (manca solo il playtest R2.6 ⚑)

La scommessa centrale del documento, costruita. **Il cubo non uccide più: blocca.** Mentre sei
fermo contro la sua faccia il mondo continua a scorrere, tu vieni trascinato indietro, e la
distanza fra te e il fronte della Corruzione è tutta la salute che hai. La barra della vita è
lo schermo.

**Le quattro decisioni che restano vincolanti**

1. **`PLAYER_X` si è spaccato in due, ed era il punto delicato di tutta la fase.** Adesso c'è
   `core.WORLD_ANCHOR_X` — la x su cui il tempo di mondo atterra, costante — e
   `core.PLAYER_HOME_X` — dove il personaggio si riposa, variabile. Tutte le conversioni fra
   spazio e tempo (il terreno, la posizione degli ostacoli) leggono **solo l'ancora**: un
   terreno che seguisse il giocatore slitterebbe contro i pattern ogni volta che perde o
   riguadagna terreno. Verificato: spostare il giocatore a x=40 non muove un ostacolo di un
   pixel. Le due costanti valgono lo stesso numero (360) perché a riposo il timing di un
   pattern significhi letteralmente quello che dice, ma non devono.
2. **Muovi prima, risolvi dopo.** La disposizione ovvia — cerca un cubo, e se c'è incollati
   alla sua faccia — si autodistrugge: incollarsi mette il personaggio *esattamente* sulla
   faccia, che non è una sovrapposizione, quindi lo step dopo non trova niente, lo lascia
   avanzare, e quello dopo ancora lo riblocca. Misurato, `is_blocked` lampeggiava a step
   alterni mentre il personaggio era palesemente fermo. Muovendo prima il contatto è vero:
   prova ad avanzare, si sovrappone, viene respinto. E il trascinamento viene gratis — la
   faccia scorre a sinistra, quindi essere respinti dietro di essa *è* perdere terreno alla
   velocità del mondo, senza che nessuno debba dirlo.
3. **La profondità è la distanza percorsa dal *personaggio*, non dal mondo.** Una riga:
   `(scroll_speed + player.velocity_x) * dt`. Bloccato, la x del personaggio cala esattamente
   alla velocità di scorrimento, i due si annullano, e la profondità si ferma. **Bloccarsi
   costa punteggio senza che una singola riga glielo dica.** In recupero copre più strada del
   mondo, quindi il terreno perso si ripaga anche in punti.
4. **La regola di equità parla di *letale*, non di *ostacolo*.** Ora che il cubo costa e non
   uccide, `is_lethal` è vero solo per la voragine — e **un cubo su entrambe le corsie è
   diventato legale**, che è il pezzo centrale del design: nessuna via d'uscita, solo la
   scelta di quale prezzo pagare. Non ci sono ancora pattern che lo usano (è la R4.1).

**Come si vede.** Due metà. Il colore che muore è un post-process sul frame finito
(`fx/corruption.odin`), perché la Corruzione non è un livello ma un **posto**: l'unico stadio
che sa a che x sta un pixel è quello che ha i pixel. Gira **dopo il bloom**, così l'alone di un
bordo illuminato ingrigisce insieme al bordo che l'ha emesso. Il **confine** invece è disegnato
nel mondo con le primitive (`render/corruption.odin`), e non è un vezzo: se lo shader non
compilasse resterebbe un killer invisibile, che sarebbe l'unica cosa nel gioco a uccidere senza
far vedere il colpo arrivare (pilastro 3).

**Misurato** (arnese usa-e-getta, poi cancellato — simulazione vera più rilettura dei pixel):

| | |
|---|---|
| 0.5 s bloccato | −135.0 px, cioè **esattamente** lo scorrimento; `is_blocked` fermo 30 step su 30 |
| profondità guadagnata da bloccato | **0.000** |
| il tap che libera | libera sullo **stesso step** in cui è premuto |
| 0.5 s liberi | +89.1 px, il **66%** dello scorrimento, come da `PLAYER_RECOVERY_RATIO` |
| pista disponibile | 360 px (1.33 s bloccato) all'inizio → 150 px (0.56 s) da 14 000 px in poi |
| run senza input, 200 seed | 0/200 sopravvive; **121 prese dalla Corruzione**, 79 in una voragine; morte mediana 4.9 s |
| lettura dei pixel | croma 215 → **0** a sinistra del fronte, 215 intatto a destra, rampa a metà a 0.55; nessun capovolgimento |

Il giallo `(255,220,40)` diventa grigio **214**, che è esattamente la sua luma Rec. 709: lo
shader e `core.desaturate_color` fanno la stessa aritmetica, e devono continuare a farla.

**Da tarare al playtest, in quest'ordine**: `PLAYER_RECOVERY_RATIO` (0.66 — è il numero che
decide se il gioco perdona), `PLAYER_HOME_X` (360 — pista contro visibilità: a 360 si vedono
920 px avanti, cioè 2.9 s a 320 px/s), `CORRUPTION_MIN_RUNWAY` (150) e la campana
2500 → 14 000 px su cui il fronte avanza.

**Un rischio che segnalo e non ho risolto da solo**: il design doc dice che la Corruzione agisce
*solo* sulla saturazione — «forma e luminosità restano». L'ho rispettato alla lettera. Se sullo
schermo la zona morta risulta poco leggibile, la correzione giusta è cambiare quella riga del
documento (aggiungendo un filo di scurimento), non aggiungerlo di nascosto nello shader.

---

## Note dal playtest R2.6 (4 settembre 2026)

Verdetto del committente: **il tira e molla funziona**, si va avanti. Tre cose da portarsi
dietro, in ordine di quanto sono già capite.

### 1. La Corruzione diventa nera, non grigia — ✅ **fatta**

Oggi il fronte scolora verso il grigio (la luma del pixel). Deve invece **mangiare tutto, fino
al nero**: non è un mondo sbiadito, è un vuoto che avanza.

Questo **ribalta una riga del design doc** — sez. 5 diceva «forma e luminosità restano, la tinta
se ne va» — ed è la risposta al rischio segnalato a fine R2: la zona morta era troppo poco
leggibile proprio perché le si era vietato di toccare la luminosità. Il documento è stato
aggiornato di conseguenza.

**Perché non rompe la regola dei due assi.** La regola esiste perché due sistemi che cambiano il
colore di tutto si impastano. La convergenza con la profondità è **globale** e muove la tinta; la
Corruzione è **spaziale** e adesso muove saturazione *e* luminosità insieme, ma solo dietro un
confine. Non si sommano mai sullo stesso pixel in modo ambiguo: a destra del fronte comanda la
profondità, a sinistra non c'è più niente da comandare.

**In più rafforza la regola grafica.** *La scenografia è linea, il pericolo è massa*: un fronte
che porta al nero pieno è letteralmente la linea che diventa massa, che è l'incastro fra
meccanica e grafica che cercavamo.

**Non era una riga sola, e il motivo è istruttivo.** Il bordo illuminato è disegnato nel mondo
*esattamente* su `front_x`, e la rampa com'era — centrata sul fronte — con il nero se lo sarebbe
mangiato: lo schermo si sarebbe scurito senza più niente che dicesse dove fosse arrivato. Adesso
la sfumatura va da `front - softness` **fino al fronte**, quindi il labbro resta intatto e il
vuoto si approfondisce dietro di esso. Rilettura dei pixel: nero puro `[0,0,0]` a sinistra, il
bordo `[228,250,255]` **identico bit per bit** prima e dopo, e il lato pulito intatto.

**Ricaduta**: l'asse scalare della corruzione in `core/palette.odin` è stato **cancellato** —
`desaturate_color`, `desaturate_palette` e `PaletteSet.corruption_t`. Non lo guidava più niente
e non deve: una palette che vale per tutto lo schermo non può esprimere un confine.

### 2. Il banding nei gradienti — **diagnosticato, non ancora risolto**

Le sfumature dello sfondo mostrano bande orizzontali visibili. Non è un caso e non si risolve
ritoccando i colori — **è una conseguenza diretta del vincolo sul bloom**.

Misurato sui valori attuali:

| gradiente | altezza | salti disponibili | larghezza di una banda |
|---|---|---|---|
| Reale, bordo → fondo | 216 px | 13 livelli | **16.6 px** |
| Onirico, bordo → fondo | 216 px | 14 livelli | **15.4 px** |
| verso l'orizzonte | 144 px | 22 livelli | 6.5 px |

La palette tiene i fondi **sotto la soglia più bassa del bright pass** (0.30) apposta, per non
mandare il cielo dentro il bloom. Il prezzo è che un gradiente di fondo ha solo 13-14 livelli a
8 bit da spendere su 216 px, cioè una banda ogni 16 px — e a schermo intero (2560×1440) diventa
una banda ogni **33 px**. Alzare il contrasto dei fondi risolverebbe il banding e romperebbe il
margine sul bloom: sono la stessa decisione vista da due lati.

**La soluzione è il dithering**, non il colore: un rumore ordinato di ±1 livello applicato ai
gradienti rompe le bande senza toccare i valori medi di una virgola, quindi senza spostare un
solo pixel rispetto alla soglia del bright pass. Sta nella **R7**, insieme al resto della resa,
a meno che a schermo dia più fastidio di quanto dia adesso.

### 3. Le collisioni col cubo e con le trappole — **da rivedere**

Segnalata la sensazione che il contatto col cubo e con gli altri pericoli vada guardato meglio.
Non è ancora un difetto identificato, e ha senso riguardarlo **dopo la R4**, quando il cubo avrà
le sue varianti (pila, piramide, fluttuante, a specchio) e la Sentinella esisterà: rifinire adesso
il contatto con l'unica forma che esiste vorrebbe dire rifarlo fra due fasi. Da tenere d'occhio
nel frattempo: il cubo è un rettangolo pieno e la sagoma del personaggio no, quindi il momento in
cui "tocca" può arrivare prima di quanto l'occhio si aspetti.

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

### La palette ✅ (4 settembre 2026)

Presa **dallo sketch 3 campionando i pixel**, non a memoria. Prima era una cosa diversa: fondi
quasi neri, luce Onirica **arancione** e accento rosa caldo — un mondo caldo contro uno freddo,
che era un'idea ragionevole e non è quello che dice la direzione artistica. Nello sketch la
metà di sopra è lavanda e rosa su viola, e l'arancione era la cosa più rumorosa sullo schermo
che gli sketch non hanno mai contenuto.

| ruolo | Reale (sotto) | Neutra (l'orizzonte) | Onirico (sopra) |
|---|---|---|---|
| `deep` | `#16323F` | `#232B3E` | `#2C1F42` |
| `near` | `#1A3E4C` | `#333D54` | `#3A2450` |
| `silhouette` | `#050C11` | `#070810` | `#0A0614` |
| `light` | `#5FE0F0` ciano | `#E4FAFF` bianco-ciano | `#B79BF7` lavanda |
| `accent` | `#8CF5B8` verde | `#F2FDFF` | `#FF9FE2` rosa |

**Sono più scuri dello sketch di proposito, e solo in valore.** Tinta e saturazione sono le sue;
la luminosità no. Lo sketch è un'illustrazione piatta in cui il bagliore è dipinto dentro,
mentre questo frame passa dopo per un bloom vero che prende `max(r,g,b)` contro una soglia fra
0.30 e 0.50 (`fx/bloom.odin`). Il cielo dello sketch sta a **0.68**: adottarlo alla lettera
manderebbe tutto il fondo dentro il bright pass e lo schermo diventerebbe foschia. La
luminosità che lo sketch ha nel cielo qui viene spesa dove serve, cioè in `light` e `accent`,
che sono quello che il bloom deve trovare.

**Il margine è aritmetica, non opinione**, ed è stato verificato con un arnese usa-e-getta che
percorre tutto lo spettro di `world_t` × `depth_t` e calcola il contributo di ogni ruolo al
bright pass. Ha trovato subito un caso che a occhio non si vedrebbe mai: le impostazioni del
bloom si interpolano su `world_t`, quindi **un giocatore a metà flip è illuminato dalla soglia
neutra (0.30) mentre il pavimento in fondo allo schermo è ancora disegnato nella palette
Reale**. La prima versione della tabella aveva `real.near` a 0.369 — tranquillamente sotto lo
0.50 del Reale — e fioriva al 20% ogni volta che il personaggio attraversava il centro. Adesso
ogni fondo sta sotto la soglia *più bassa che può incontrare*, non solo sotto la propria. Il
caso peggiore residuo è `neutral.near` a 0.087, ed è voluto: un soffio sui bordi dello schermo
quando la convergenza prende il sopravvento.

**Cosa manca ancora, e non è la palette.** Lo sketch resta più chiaro di così perché la sua
luminosità è in gran parte *disegnata*: nuvole, aurore, piante, tutto contorno luminoso vuoto.
Quella è scenografia, ed è la **R7**. Nello stesso ordine di idee, nello sketch le piattaforme
sono rettangoli **cavi** con un tratto al neon, mentre da noi il terreno è una massa piena con
il bordo illuminato: è un cambio di disegno, non di colore, e sta nella **R3** insieme al resto
del tracciato.

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
