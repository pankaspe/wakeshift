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

**Fatte R1, R2, R3 e R4, playtest compresi.** Il gioco adesso *è* quello del documento nel suo
cuore: due corsie, un gesto, il cubo che blocca invece di uccidere in sei forme, la Corruzione
che avanza da sinistra mangiando il terreno che perdi, un corridoio che ondeggia e si strozza, e
la Sentinella — quindi tutti e tre i pericoli e tutti e tre i verbi sono a schermo. Mancano il
pool vero (R5) e l'economia (R6).

**Il 4 settembre 2026 la direzione artistica è cambiata da capo**: via lo stile Ori, dentro
**La Linea** di Cavandoli. La fase che la porta a schermo è la **RL**, ed è in corso: va prima
della R5 perché cambia cos'*è* un pattern.

**Prossima**: la RL.8 — la parallasse. Con la RL.1÷RL.7 fatte **non c'è più niente di pieno a schermo tranne il fondo** e i due fronti
sono entrambi ritagli: a destra la penna scrive, a sinistra la linea si sfilaccia in polvere.
Restano due task di rifinitura (RL.7 curve, RL.8 parallasse) e poi il playtest della fase, la
RL.9 — che adesso ha una domanda in più da rispondere: **lo shader della Corruzione va cancellato
o riacceso** (una riga in `main.odin`).

**Cosa sopravvive intatto e non va toccato**: tutto `platform/` (finestra, display,
salvataggio, cifratura, percorsi); `fx/bloom`; `render/stroke` e `render/glow`; i menu e le
opzioni; il timestep fisso, il recorder e il manifesto.

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

### ✅ Fase R2 — Il tira e molla

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

### 2. Il banding nei gradienti — ✅ **fatta nella RL.1**

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

**La soluzione è il dithering**, non il colore. Anticipata dalla R7 alla RL.1, perché con La
Linea il fondo diventa tutta la superficie dello schermo e un difetto del fondo smette di essere
un difetto di un angolo: `fx/dither.odin`, un livello di rumore sul frame finito, alla
risoluzione vera, dopo il bloom e prima della Corruzione. I numeri e il limite onesto di quel
che compra stanno nella RL.1.

La RL.1 ha anche cambiato il termine del problema: portando i bordi della vignettatura **più
scuri di `deep`** — direzione che il bloom non vincola — la rampa del fondo è passata da 13
livelli a **41**. Metà del banding è sparita così, senza toccare il margine sul bright pass.

### 3. Le collisioni col cubo e con le trappole — ✅ **chiusa con la R4**

Segnalata la sensazione che il contatto col cubo e con gli altri pericoli vada guardato meglio.
Non è ancora un difetto identificato, e ha senso riguardarlo **dopo la R4**, quando il cubo avrà
le sue varianti (pila, piramide, fluttuante, a specchio) e la Sentinella esisterà: rifinire adesso
il contatto con l'unica forma che esiste vorrebbe dire rifarlo fra due fasi. Da tenere d'occhio
nel frattempo: il cubo è un rettangolo pieno e la sagoma del personaggio no, quindi il momento in
cui "tocca" può arrivare prima di quanto l'occhio si aspetti.

**Chiusa il 4 settembre 2026**: la R4 è stata giocata con tutte e sei le forme del cubo e con la
Sentinella, ed è passata senza correzioni richieste. Se il contatto torna a dare fastidio quando
il cubo smette di essere un rettangolo e diventa un gradino nella linea, si riapre nella RL.2.

---

### ✅ Fase R3 — Il tracciato

Il mondo ha smesso di essere una striscia dritta. `core/terrain.odin` è diventato
`core/track.odin`, e il tracciato è **due numeri messi a fotogrammi chiave nel tempo**: la
**spina** (dove sta il centro del corridoio) e lo **spessore** (quanto è alto). Pavimento =
`spina + spessore/2`, soffitto = `spina − spessore/2` — la coerenza fra le due corsie è una
proprietà della rappresentazione, non una regola da ricordarsi.

**Le decisioni che restano vincolanti**

1. **Lineare fra i fotogrammi, e il clamp sta sull'*append*, mai sul campionamento.** La
   linearità serve due volte: è quello che rende `track_support_y` esatto invece che campionato
   (un estremo su un intervallo può stare solo a un capo o su un fotogramma interno), ed è il
   motivo per cui la legalità va imposta quando un punto entra. Ritagliare un fotogramma lascia
   la funzione lineare; ritagliare il campionatore la spezza.
2. **Ogni pattern apre e chiude sul corridoio neutro**, imposto da `validate_pattern_pool`. È
   quello che sostituisce un controllo sulle giunture: in qualunque ordine il generatore li
   incolli, il mondo è continuo e il tratto sopra il gap è piatto, quindi nessuna coppia può
   essere illegale insieme se è legale separata. E **ne cade fuori un ritmo gratis**: il
   tracciato è piatto per tutta l'aria fra due pattern, quindi man mano che i tier stringono
   quell'aria il mondo ondeggia sempre più di continuo, senza una riga che lo voglia.
3. **Un `Track` è un valore semplice** — un array fisso dentro `World`, non un array dinamico
   accanto. Così `interpolated_world` copia il mondo avanti di una frazione di step e legge un
   tracciato che non è di nessuno. Misurato: una run lunga arriva a 20 slot su 64.
4. **Il flip dura sempre uguale, qualunque sia lo spessore.** Il corridoio cambia larghezza, il
   gesto no — altrimenti smette di essere un riflesso.
5. **Il cielo cavalca la spina.** Un cielo inchiodato allo schermo mentre il mondo gli scorre
   sotto si legge come due immagini, con l'orizzonte che taglia la corsia Reale sui tratti alti.

**Misurato** (arnese usa-e-getta sulla simulazione vera, 180 s di generazione, poi cancellato):

| | |
|---|---|
| escursione della spina | **148 px** (il terreno della v1.x si muoveva di 16) |
| escursione dello spessore | **158 px**, fra 254 e 412 |
| cielo residuo | 136 px sotto il pavimento più basso e sopra il soffitto più alto (minimo 70) |
| movimento più rapido della spina | 135 px/s contro un limite autorato di 190 → **nessun salto alle giunture** |
| fotogrammi vivi insieme | picco 20 su 64 → **niente scartato in silenzio** |
| il corpo su una cresta | i piedi atterrano **sulla cresta**, non nel pendio |
| durata del flip | 0.167 s con spessore 250, 340 e 430 (205, 295 e 385 px attraversati) |

**Due pattern nuovi che parlano del mondo invece che di quello che ci sta sopra**: `narrows` (il
corridoio si strozza quasi al minimo con un cubo dentro) e `swell` (il mondo intero sale e
scende di 148 px mentre due voragini chiedono su quale corsia stare). Stanno nel tier
*Drifting* e non in quello d'apertura, così una run comincia su un mondo quasi piatto e scopre
che il suolo si muove **dopo** aver imparato i comandi.

**Una scelta grafica che ho preso contro lo sketch, e il perché.** Nello sketch 3 le piattaforme
sono rettangoli **cavi**. Il terreno qui resta **massa piena scura con il bordo illuminato**,
perché lo sketch non ha voragini letali e noi sì: un buco in una massa scura si legge come un
pozzo in cui si cade, un buco in un contorno cavo è solo una linea che manca. La leggibilità
batte la fedeltà (pilastro 2). Se a schermo dà fastidio si può rivalutare, ma è una decisione,
non una svista.

---

### ✅ Fase R4 — I tre pericoli

Tutta la varietà da tre elementi e tre verbi: *il cubo costa, il buco uccide, la Sentinella
vieta di muoversi*. Il cubo è **una primitiva in sei taglie** (`CubeForm`), e meccanicamente
conta solo la larghezza — pila e piramide costano quanto sono larghe e l'altezza è retorica, il
che è un pregio: si leggono come *peggio* a colpo d'occhio costando uguale. La Sentinella occupa
il 42% dello spessore attorno alla spina ed è disegnata con la palette **neutra**, perché non è
di nessuno dei due mondi. Il buco era già come lo chiede il documento dalla R2.

**Playtest passato il 4 settembre 2026**, senza correzioni richieste. Le due cose che erano state
lasciate al giudizio restano come sono: la coppia a specchio costa 4 px di pista (un contrattempo,
non un prezzo — la manopola è `PLAYER_RECOVERY_RATIO` ed è taratura da R5.3), e il corpo che
attraversa la scatola per uscirne è il prezzo inevitabile della regola "un cubo ti trattiene, non
ti trascina".

Le tre regole che la simulazione rigiocata ha stabilito — il cubo trattiene e non trascina, la
larghezza di un cubo isolato non costa niente, un cubo dentro il raggio della Sentinella è una
trappola e il validatore lo rifiuta — sono in `CLAUDE.md`, sezione "The three dangers, three
verbs", con i numeri. La combinazione Sentinella + cubo si costruisce al contrario: **il raggio
ti tiene sulla corsia che hai scelto e il cubo ti aspetta lì l'istante in cui il divieto cade**.

---

### Fase RL — La Linea

**Obiettivo**: dare un'anima al gioco. La grafica diventa **La Linea** di Osvaldo Cavandoli
(`docs/inspiration/La_Linea.png`): un fondo pieno e un unico tratto continuo che *è* il mondo,
da cui il personaggio si solleva e in cui gli ostacoli rientrano. **La simulazione non cambia di
una riga**: è una fase che tocca solo `render/`, `fx/` e la palette.

**Perché adesso e non nella R7.** Perché la R5.2 autora venti-venticinque pattern, e con questa
grammatica un pattern non è più "una lista di oggetti sopra un fondale": è **una forma della
linea**. Autorare il pool prima vorrebbe dire autorarlo contro una grammatica che stiamo per
buttare.

**Perché il codice è già pronto per riceverla.** `render/stroke.odin` — nucleo luminoso, alone
additivo, giunti saldati, terminali tondi — è esattamente il pennello che serve: è stato scritto
per lo sketch 3 e si scopre che era il file giusto per il progetto sbagliato. Il tracciato è già
due numeri a fotogrammi chiave e `render/terrain.odin` già disegna il pavimento **come una
polilinea**: non si cambia modello, si toglie il riempimento. E il bloom LDR, che oggi è tarato
contro uno schermo pieno di masse scure che sfiorano le soglie, ha finalmente il suo caso
ideale: un tratto sottile e brillante su un fondo scuro.

#### La grammatica nuova

La vecchia regola di leggibilità era *"la scenografia è linea, il pericolo è massa"*, ed è la
regola che protegge il pilastro 2: se tutto diventa linea, sparisce e va sostituita **prima** di
scrivere codice. La sostituta era già scritta in `render/obstacle.odin` senza saperlo — *un cubo
è l'unica cosa nel mondo con angoli retti, e la scenografia è tutta curve*. È una regola
**geometrica, non di riempimento**, quindi sopravvive intatta:

> **Il mondo curva, il pericolo fa angolo.**

E i tre pericoli diventano le tre cose che una linea sa fare, il che è più leggibile di adesso,
non meno:

| | cosa fa la linea |
|---|---|
| **Cubo** | si alza di scatto e ritorna — un gradino con due angoli retti, tutt'uno col pavimento |
| **Buco** | **si interrompe**: è l'unica discontinuità del gioco |
| **Sentinella** | **attraversa** il corridoio da parte a parte |
| **Corruzione** | dietro di te **si sfilaccia in particelle** |

L'ultima riga è un guadagno secco. Oggi la Corruzione è un post-process che uccide il colore del
frame, con tutta la complessità documentata in `CLAUDE.md` ("il colore ha due sistemi e non
devono scontrarsi"). Come linea che si deframmenta quella complessità **sparisce**: non è più un
livello applicato allo schermo, è un posto dove la linea ha smesso di esserci.

#### Le decisioni prese, e che vincolano i task

1. **Cambia il fondo, non il tratto.** I due mondi si distinguono per il colore *dietro*; la
   linea resta sempre lo stesso segno, così legge come "il mondo" e non come "una cosa che
   cambia". Il flip diventa un evento a tutto schermo, che è quello che il gesto centrale del
   gioco merita.
2. **La sfumatura è lenta, e più lenta del flip.** Il flip dura 0.16 s e in un burst se ne fanno
   tre di fila: un fondo che segue `world_t` alla lettera è uno stroboscopio. Il fondo insegue
   con un ritardo suo (ordine di 0.5–0.8 s), quindi durante una raffica resta a metà strada
   invece di sbattere avanti e indietro.
3. **Il fondo non deve dare fastidio.** Sta sotto la linea in tutto: valore, contrasto,
   dettaglio. Nessun elemento del fondo compete con il tratto per l'attenzione, e la
   vignettatura serve a spingere l'occhio verso il centro dove si gioca.
4. **Il glow della linea cresce verso l'Onirico.** È il secondo canale che dice dove stai
   andando, e regge il pilastro 6 insieme alla posizione: mai il colore da solo.
5. **Il mondo si disegna a destra mentre si sfilaccia a sinistra.** Due fronti speculari: uno
   mangia, uno fa. È la gag centrale del cartone e diventa la struttura dello schermo.
6. **Il fronte di disegno non è una manopola di difficoltà.** Sta al bordo destro o quasi. Il
   giocatore vede oggi 1080 px avanti, cioè circa 4 s: spostare il fronte a sinistra ruberebbe
   preavviso, e il pilastro 3 dice che ogni pericolo ha una fase di arrivo visibile.

| Task | Descrizione | Modello |
|---|---|---|
| RL.1 ✅ | **Il fondo diventa il mondo**: due fondi con vignettatura, uno per mondo, e una miscela che *insegue* `world_t` con il suo ritardo invece di seguirlo. Presentazione pura: il valore ritardato vive in `main` accanto a `display_time` e non tocca mai la simulazione | **Opus** |
| RL.2 ✅ | **Il tratto è il mondo**: `render/terrain.odin` ridisegna le due corsie come polilinee continue senza riempimento, e gli ostacoli entrano **dentro** la stessa polilinea invece di essere disegnati sopra. `render/obstacle.odin` si svuota | **Opus** |
| RL.3 ✅ | **Il personaggio è una continuazione della linea**: contorno aperto al posto della sagoma piena, con il tratto più pesante e il nucleo più bianco del mondo attorno. Il sistema di pose resta intero — cambia solo l'ultimo passaggio | **Opus** |
| RL.4 ✅ | **Il glow cresce verso l'Onirico**, e la corsia dormiente si assottiglia. Qui si decide anche se le due linee stanno bene entrambe piene: La Linea ne ha una, noi ne abbiamo due, e due tratti paralleli identici leggono come un tubo invece che come un orizzonte | Sonnet |
| RL.5 ✅ | **Il mondo si disegna a destra**: un fronte di disegno speculare a quello della Corruzione, con il pennino che lo marca. Una volta fatta la RL.2 è **un ritaglio, non un'animazione per ostacolo** — ed è il motivo per cui le due idee stanno nella stessa fase | **Opus** |
| RL.6 ✅ | **La Corruzione diventa un segno**: `fx/particles.odin` anticipato dalla R7, pool fisso pre-allocato, e la linea che si sfilaccia dietro. Poi si decide la sorte di `fx/corruption.odin`: la mia proposta è provare prima con le sole particelle e tenere lo shader spento ma non cancellato, perché la scelta di andare a nero è venuta da un playtest e va disfatta con un altro playtest, non a tavolino | **Opus** |
| RL.7 ✅ | **Le curve**: adottare `core:math/ease` della libreria standard (tutto il set Penner) e cancellare `core/ease.odin`. `ease.ease` è una funzione pura e può stare ovunque; il tween `flux` alloca e va a orologio, quindi **solo presentazione** o salta il determinismo — replay e validazione del punteggio | Sonnet |
| RL.8 | **Parallasse**: linee più sottili, più fioche e più lente dietro. Anticipata dalla R7, e con questa direzione costa un decimo | Sonnet |
| RL.9 ⚑ | Playtest: il mondo si legge in due secondi, il fondo non dà fastidio, il flip si sente come un evento, e il personaggio a 45 px si vede | — |

#### RL.1 ✅ — Il fondo è il mondo (4 settembre 2026)

Il cielo a due metà con l'orizzonte illuminato è sparito. Al suo posto c'è **un campo solo**, il
cui colore *è* il mondo in cui sei, con una vignettatura fissa allo schermo. L'orizzonte se n'è
andato insieme alla divisione, ed è giusto così: con il campo che cambia colore per intero, una
fascia di luce in mezzo allo schermo non ha più niente da dire che il campo non stia già dicendo
più forte.

**Il ritardo.** `render.chase_background_t`, costante di tempo 0.45 s, avanzato in `main` accanto
a `display_time` — presentazione pura, non entra mai in un passo di simulazione. Misurato: un
flip singolo (0.167 s) sposta il campo del **31%** e finisce il lavaggio circa un secondo dopo
l'atterraggio; **sei flip di fila** lo lasciano dentro `[0.21, 0.53]`, cioè fermo a metà strada,
che è esattamente la ragione per cui esiste. Identico a 30, 60 e 240 fps fino alla quinta cifra.

**Due conseguenze che non avevo previsto, e che hanno cambiato altro codice.**

1. **Il vincolo sul bloom è diventato assoluto.** Con il fondo che insegue, qualunque mondo può
   stare a schermo sotto la soglia di qualunque altro: le due cose non sono più nemmeno
   approssimativamente in fase. Quindi *tutti* i `near` della palette stanno adesso sotto la
   soglia più bassa che esiste (0.30, il neutro) e non sotto quella del proprio mondo.
   `neutral.near` era 0.329 e `dream.near` 0.314; entrambi portati a 76/255 = **0.298**, dov'era
   già `real.near`. Verificato spazzando tutto lo spazio (world_t, depth_t): il valore pieno più
   chiaro del gioco è 0.2980.
2. **I bordi possono andare più scuri di `deep`.** Il bloom vincola solo quanto una superficie
   piena può essere *chiara*, quindi la direzione scura è gratis — e spenderla compra livelli: la
   rampa della vignettatura ne ha **41** contro i 13 del vecchio cielo.

**Il banding**, che con un fondo pieno smetteva di essere un dettaglio rimandabile.
`fx/dither.odin`: un livello di rumore sul frame finito, alla risoluzione vera, **dopo il bloom e
prima della Corruzione**. Misurato: il 49.5% dei pixel alzato di esattamente un livello e nessuno
di più, la banda piatta più larga della rampa da 16 px a 8, scarto di media +0.495 di livello.
L'ordine non è un gusto: un pixel di fondo alzato di uno finisce a 0.302, cioè **appena sopra**
la soglia più bassa del bloom, quindi eseguirlo prima gli regalerebbe metà del fondo.

E detto onestamente, perché la parola "dithering" promette più di quanto questo mantenga: il
dithering vero perturba **prima** della quantizzazione, e quando un passaggio riesce a leggere il
frame la quantizzazione è già avvenuta. Questo non toglie il gradino fra due bande, ne seppellisce
la riga dritta sotto un rumore della stessa ampiezza. Se a schermo non basta, la correzione vera è
disegnare il fondo con uno shader che ditherizza prima di scrivere — ed è una decisione da
prendere guardandolo, non qui.

**La vignettatura è fissa allo schermo**, non cavalca la spina come faceva il cielo. Quella regola
esisteva perché un orizzonte inchiodato allo schermo mentre il mondo gli scorreva sotto leggeva
come due immagini; una vignettatura non è geometria del mondo ma dell'obiettivo che lo guarda, e
sta dove sta l'obiettivo. È cotta una volta in una maschera 256x144, perché due gradienti lineari
a mezzo schermo si incontrano con una discontinuità di pendenza, e una piega in una rampa così
poco contrastata è una banda di Mach.

Numeri, mondo Reale, canale blu: centro **76**, bordo laterale 53, bordo alto e basso 36, angoli
29. Il corridoio a spessore neutro (spina ±170) sta fra 68 e 44. Rampa monotona, zero inversioni.

**Cosa tocca a te giudicare**: quanto è forte la vignettatura (`VIGNETTE_DEPTH`, oggi 0.55),
quanto è largo il centro chiaro (`VIGNETTE_X_SCALE`, 0.72), se 0.45 s è il ritardo giusto
(`BACKGROUND_LAG`), e se il banding si vede ancora. Il resto della scena è ancora quello vecchio:
il tratto arriva con la RL.2.

**Ricaduta**: `core.dormant_palette` non aveva più chiamanti ed è stata cancellata — la palette
del mondo dormiente serviva al cielo a due metà e a nient'altro; `render/terrain.odin` e
`render/obstacle.odin` leggono `real_alive`/`dream_alive` per conto loro.
`game.get_track_at_anchor` è rimasta senza chiamanti ma resta: è un accessore legittimo dello
stato del mondo, e la RL.5 lo vorrà.

---

#### RL.2 ✅ — Il tratto è il mondo (4 settembre 2026)

Il riempimento è sparito da tutta la scena tranne il personaggio. Il pavimento e il soffitto sono
**due polilinee sole**, una per corsia, disegnate con `render/stroke.odin`, e i cubi non stanno
più *sopra* la linea: stanno **dentro** di essa. Un cubo è la linea che si alza di scatto, corre
piatta e ritorna — due angoli retti nel terreno, un segno solo, nessuna cucitura che tradisca che
è un oggetto. La piramide è la stessa cosa a gradini, e i gradini escono gratis dalla polilinea,
esattamente come il rilievo del tracciato nella R3.

**Il segno e la hitbox sono la stessa cosa**, per costruzione e non per accordo: il gradino legge
la `get_obstacle_rect` dell'ostacolo, quindi il bordo alto disegnato *è* il bordo alto della
collisione. Le due facce verticali cadono da sole, perché la polilinea mette due punti alla
stessa x.

**Il buco è la linea che si interrompe**, e adesso è letteralmente vero: la sagoma viene costruita
intera su tutto lo schermo e *poi* tagliata ai bordi dei buchi, con i vertici interpolati
esattamente sul taglio. Costruirla già a pezzi avrebbe fatto litigare un cubo a cavallo del bordo
di un buco con il pezzo che lo contiene; costruirla intera rende quel caso un ritaglio.

**I due lati continuano a rompersi in modo diverso**, e senza riempimento la differenza la porta
solo quello che fa il tratto: il pavimento **gira verso il basso** dentro la frattura (altri due
angoli retti — è un taglio, ed è letale), il soffitto **prosegue oltre il labbro e si assottiglia
a zero** con una coda affusolata, e l'apertura si illumina. La regola "il pavimento si rompe, il
soffitto si dissolve" è sopravvissuta al cambio di direzione senza una riga di riempimento.

**La Sentinella perde la massa.** Resta la banda, perché la banda è la meccanica — stare su una
corsia è sicuro, attraversare no — ma è disegnata come **un contorno chiuso** con due estremità
squadrate più l'asse luminoso al centro. Vuota dentro: verificato leggendo i pixel, l'interno è
esattamente 0.

**`render/obstacle.odin` si è svuotato** come previsto. Da 260 righe con sei disegnatori di cubo a
due soli segni, che sono esattamente i due pericoli che non appartengono a una superficie: il
**cubo fluttuante** (l'unico che non poggia su niente, quindi il terreno non può saldarlo) e la
**Sentinella** (che non ha corsia). Tutto il resto è terreno.

**Cosa ho tolto e va guardato**: le cuciture interne dello **Stack**. Erano tre linee orizzontali
dentro la sagoma che dicevano "sono tre cubi"; dentro un contorno vuoto leggerebbero come una
scala a pioli, non come cubi impilati. Adesso lo Stack è un gradino stretto e alto. Meccanicamente
non cambia niente (l'altezza è retorica, il prezzo è la larghezza), ma la retorica era il suo
lavoro: se a schermo non legge più come *peggio* di un cubo standard, si rimette qualcosa.

**Misurato** (armatura usa e getta, cancellata):

- La polilinea del pavimento con quattro cubi sopra e un tracciato che ondeggia e si strozza:
  **24 punti**, x mai all'indietro. Ogni forma di cubo dà **una** faccia verticale a sinistra,
  **una** a destra e un tratto orizzontale alla quota esatta della sua scatola; la piramide dà
  **3 pedate**. Il cubo fluttuante non lascia nessun gradino.
- Un buco nel soffitto taglia la sagoma in **2 pezzi**, che iniziano e finiscono esattamente sui
  bordi del buco, e ogni vertice di entrambi sta sulla superficie che il tracciato descrive
  (scarto < 0.5 px).
- Pixel riletti dal render target: la linea del pavimento c'è (picco 212), il cubo ha il bordo
  alto acceso (212) e l'**interno a 0**, dentro il buco è **0** — la linea non attraversa il
  proprio buco — e a 14 px sotto la superficie ai due labbri c'è **212**, cioè il pavimento gira
  davvero verso il basso.
- I contorni **chiusi** sono nuovi in questa fase ed erano il rischio silenzioso: un triangle
  strip avvolto al contrario sparisce senza errori. Riletti: il cubo fluttuante ha tutti e
  quattro i lati accesi (233), la Sentinella ha bordo alto, bordo basso, asse ed estremità
  squadrata (204/204/224/204).

**Ricadute**:

- `STROKE_MAX_POINTS` da 128 a **256**. Una corsia è adesso la polilinea più lunga del gioco e
  `build_stroke_ribs` tronca in silenzio, che vorrebbe dire una linea che finisce a mezz'aria. Il
  caso peggiore misurato è sulla cinquantina, quindi il margine è abbondante di proposito.
- `palette.silhouette` ha **un solo consumatore rimasto**, il personaggio. Quando la RL.3 lo
  trasforma in contorno, il campo diventa candidato alla cancellazione da `core/palette.odin` — da
  decidere lì, non qui.
- Le manopole nuove stanno tutte in testa a `render/terrain.odin`: `TERRAIN_STROKE_THICKNESS`
  (2.8), `TERRAIN_CORE_LIGHT` (0.30), `TERRAIN_GLOW_STRENGTH` (0.45), `TERRAIN_GLOW_SPREAD` (5.5)
  e soprattutto `TERRAIN_RIM_DORMANT`, alzata da 0.30 a **0.45**: la corsia dormiente non ha più
  una massa dietro, quindi quel numero *è* tutta la sua presenza. Se il mondo dormiente adesso
  urla troppo, la correzione è lì — ma è anche esattamente la domanda che la RL.4 deve decidere
  (la corsia dormiente si assottiglia invece di sbiadire?), quindi conviene guardarle insieme.

**Cosa tocca a te giudicare**: se il gradino legge come *pericolo* invece che come *terreno che si
alza* (è il rischio numero due della fase, ed è una domanda a cui i pixel non rispondono), se la
Sentinella vuota legge ancora come una cosa sola invece che come due corsie in più, se lo Stack
senza cuciture dice ancora "peggio", e quanto pesante deve essere il tratto del mondo — perché la
RL.3 deve fare il personaggio **più pesante di questo**, e quindi questo numero fissa il tetto.

---

#### RL.3 ✅ — Il personaggio è una continuazione della linea (4 settembre 2026)

Il riempimento è finito. Il personaggio si disegnava due volte — una sagoma ingrassata nella luce
del mondo per fare il bordo, poi la stessa sagoma a peso vero nel colore silhouette sopra — e
adesso è **una passata sola**: ogni osso è un tratto, e il bulbo è un tratto chiuso attorno al
profilo dell'unione dei suoi due cerchi. Nove segni e un occhio, e nessuno è pieno.

**La gerarchia dei pesi è aritmetica, non memoria.** Il documento dice che il personaggio è *il
tratto più spesso e il nucleo più bianco dello schermo*, sopra la corsia viva. Quindi i pesi qui
sono **multipli di `TERRAIN_STROKE_THICKNESS`** invece che numeri propri: si tara il tratto del
mondo e il personaggio gli resta sopra per costruzione, e nessuno dei due può scavalcare l'altro
per distrazione. Limbi 1.55, spina 1.90, bulbo 1.85, stelo 1.15, foglie 1.35, nucleo 0.62 contro
lo 0.30 del mondo.

**Il segno non cambia mondo.** Il personaggio è disegnato dalla palette **neutra**, non da quella
corrente: sezione 10, *"il personaggio è lo stesso segno in entrambi i mondi; quello che cambia è
cosa ha dietro e quanto brilla, mai il suo profilo"*. Converge ancora con la profondità, perché
tutte le palette lo fanno. Il vecchio codice invertiva corpo e bordo fra i mondi e leggeva come
due personaggi diversi; un segno che cambia tinta è la versione mite dello stesso errore.

**L'aura è stata cancellata.** Era un disco di 60 px della luce del mondo centrato sull'anca, e
funzionava solo finché un corpo opaco ci stava sopra a coprirne il centro. Tolto il corpo, la
prima misura l'ha trovata a illuminare *l'interno* della figura: bulbo 255 dentro e 255 sul
bordo, cioè nessun contrasto. È il caso dell'alone doppio che `CLAUDE.md` risolve sempre allo
stesso modo — si toglie quello primitivo. Il **flash del flip** non è andato perso: è passato
sull'alone del tratto stesso, quindi adesso è la linea del personaggio a divampare a metà giro
invece di un disco attorno a lui, cavalcando lo stesso `sin(whip * PI)` dello stiramento.

**Il piede torna a terra da solo.** La regola "la figura visibile riempie la scatola" reggeva su
un numero scritto a mano: la sagoma più il bordo arrivavano a 0.091 unità oltre la giuntura del
piede, quindi la giuntura stava a 0.409. Un tratto arriva solo a metà del proprio spessore, cioè
0.042, e la figura sarebbe rimasta **2.2 px in aria**. Invece di riscrivere il numero l'ho reso
derivato: `PLAYER_FOOT_REACH` è 0.5 meno mezzo tratto, `PLAYER_LEG_STRETCH` è quanto va allungata
la gamba per arrivarci (1.15), e **`PLAYER_STRIDE_LENGTH` è allungato dello stesso fattore**,
perché la falcata era tarata sul rapporto fra quanto coprono i piedi e quanto scorre il mondo —
altrimenti il personaggio pattina. Tutto scende da `PLAYER_STROKE_WEIGHT`: si cambia il peso e la
figura resta piantata con la cadenza giusta.

**Il bulbo.** Due contorni di cerchio sovrapposti mostrerebbero gli archi incrociarsi *dentro* la
testa, e l'interno della testa è l'unico posto di un disegno al tratto che non può permettersi un
segno di troppo — sono cinque pixel. Quindi è costruito come il profilo dell'**unione**: gli
estremi dei due archi sono le intersezioni dei cerchi, e quale dei due archi tenere si decide
**sondando il punto medio** invece di ricavarlo da un segno che è facile prendere al contrario e
silenzioso quando lo fai, dato che entrambe le risposte sono un anello chiuso.

**Misurato** (armatura usa e getta, cancellata):

- Il profilo del bulbo, a tre inclinazioni diverse dello stelo: 28 punti, **ogni punto su uno dei
  due cerchi e mai dentro l'altro** (immersione più profonda: 0.000000), passo più lungo 0.059
  contro un raggio di 0.170 — cioè un anello, non una figura con una corda in mezzo.
- Contatto col terreno: fondo della scatola 530, **riga accesa più bassa 530**. Appeso al
  soffitto: cima della scatola 190, riga accesa più alta 189. Entrambi i versi toccano.
- Il personaggio **inchiostra il 21.2%** della propria scatola: è un disegno, non una macchia.
- Colonna verticale attraverso il bulbo **in un frame vero, con fondo e bloom**:
  `123 255×8 198 184 169 186 189 196 255×9` — l'anello satura, il vuoto sta fra 169 e 198, il
  campo accanto è 62. Il buco sopravvive al bloom, ma illuminato: legge come un bulbo che brilla
  con un centro più scuro, non come un anello nero. Se non basta, le manopole sono
  `PLAYER_HEAD_WEIGHT` (anello più sottile = buco più grande) e `PLAYER_STROKE_GLOW`.
- Gerarchia in un frame vero: **personaggio 255, linea del pavimento 239**. Il personaggio è la
  cosa più bianca dello schermo, come chiede il documento.
- Il segno è `[228, 250, 255]` su entrambe le corsie — verificato, non assunto, perché è
  esattamente il posto dove una modifica futura tornerebbe a prendere `palettes.current`.

**Ricadute**:

- Sparite `PLAYER_RIM_THICKNESS`, `PLAYER_TORSO_THICKNESS`, `PLAYER_LIMB_THICKNESS`,
  `PLAYER_SPROUT_THICKNESS`, `PLAYER_SPROUT_TIP_THICKNESS`, `PLAYER_LEAF_THICKNESS`,
  `PLAYER_GLOW_RADIUS`, `PLAYER_GLOW_STRENGTH`. Erano tutte spessori di riempimento.
- `core.Palette.silhouette` **non ha più nessun consumatore** in tutto il gioco. Non l'ho
  cancellato: è una decisione da prendere in `core/palette.odin` guardando se la RL.6 o i
  Frammenti lo rivogliono, e cancellare un campo di palette è più facile che riesumarlo.
- L'occhio resta l'unica cosa del personaggio che prende il colore del mondo corrente
  (`accent`). È un punto solo ed è il secondo canale voluto; se anche quello deve diventare
  neutro è una riga.

**Cosa tocca a te giudicare**: se a 45 px la figura si legge — è **il** rischio della fase e i
pixel non ci rispondono; se il bulbo illuminato dentro va bene o vuole più buco; se il tratto è
troppo pesante o troppo leggero (`PLAYER_STROKE_WEIGHT`, che tira dietro gamba e falcata); e se
il divampare del flip si sente adesso che è sulla linea invece che in un disco. Se non basta, la
correzione che il documento ha già messo in conto è **ingrandire il personaggio**, ed è una
decisione tua, non mia.

---

#### RL.4 ✅ — Il glow cresce verso l'Onirico (4 settembre 2026)

**La domanda aperta della fase ha una risposta: no, le due linee non stanno bene entrambe piene.**
La corsia dormiente adesso è più sottile (`TERRAIN_DORMANT_WEIGHT`, 0.70 del peso vivo) e più
fioca (alpha 0.55 contro 0.85). L'asimmetria **non** è "il soffitto è secondario": segue il
giocatore, quindi quello che si assottiglia è sempre la corsia in cui non sei.

**Il glow è stato misurato prima di essere scritto**, e la misura ha cambiato il numero. Il bloom
dice qualcosa su questo dalla fase 4: l'alone della corsia viva passava già da **5 a 23 righe
accese** fra i due mondi. Ma non dice la stessa frase — `NEUTRAL_BLOOM` è di proposito il punto
più abbagliante dello schermo, quindi la curva del bloom è **una campana** (5 → 26 → 23), e una
campana non sa indicare una direzione. Quindi il guadagno primitivo aggiunto qui è piccolo, ed è
la metà **monotona**: da sola fa 4 → 6 → 10 righe.

Due moltiplicatori invece di uno, perché "più glow" ha due significati e un frame LDR li tratta
in modo molto diverso: più forte spinge l'alone verso il bianco e satura, più largo resta morbido
e copre solo più aria. L'Onirico è quello morbido, quindi la crescita sta soprattutto nella
portata (`GLOW_DREAM_STRENGTH` 0.35, `GLOW_DREAM_SPREAD` 0.50).

**Va su `world_t` diretto, non sul fondo ritardato.** Il fondo insegue con mezzo secondo di
ritardo (RL.1); il glow no. È il canale che dice dove stai **andando**: si muove nell'istante in
cui premi, e il colore arriva un secondo dopo.

**La scoperta che giustifica il canale più di quanto pensassi.** Sia la palette sia il bloom
**convergono verso il neutro con la profondità** (`CONVERGENCE_MAX` 0.72): tardi in una run i due
canali vecchi vengono appiattiti di proposito. Il guadagno di RL.4 è un moltiplicatore su
`world_t` e non converge, quindi è **l'unico che continua a parlare** quando i colori hanno
smesso. Misurato a `depth_t = 1`: **8 righe contro 26** fra Reale e Onirico.

**Misurato** (armatura usa e getta, cancellata):

- Mondo Reale, frame vero con fondo e bloom: corsia viva picco **239** su un campo di 76; corsia
  dormiente picco **185** su un campo di 53. Cioè 54 livelli più fioca ma ancora 132 sopra il
  proprio campo — presente, non sparita.
- **Onesto sull'assottigliamento**: a 2.80 px, il 30% in meno fa 1.96 px, cioè **meno di un
  pixel di differenza**. Nel conteggio delle righe non si vede (2 righe di nucleo in entrambi i
  casi); a schermo la porta l'antialiasing, e il lavoro percettivo lo fa soprattutto l'alpha. Se
  vuoi che il peso conti davvero, la leva è alzare `TERRAIN_STROKE_THICKNESS` — che è anche la
  leva che ingrandisce il personaggio, perché i suoi pesi ne sono multipli.
- Gerarchia in un frame vero: `world_t 0` → personaggio 255, viva 239, dormiente 185.
  `world_t 1` → 255, 255, 193. Nell'Onirico personaggio e corsia viva **saturano entrambi**:
  sopra sta ancora per peso (4.34 px contro 2.80) ma non più per luminosità. La saturazione a
  `world_t 1` c'era già prima di questa fase.

**Ricadute e cose da tenere d'occhio**:

- `render/palette.odin` guadagna `GlowGain` / `glow_gain` / `apply_glow_gain`, e **ogni** segno
  del gioco ci passa: terreno, code dei buchi, aperture oniriche, cubo fluttuante, Sentinella,
  personaggio, occhio. Il canale è una cosa sola, non un'abitudine che ogni file deve ricordarsi.
- `render/terrain.odin` guadagna `LaneLight` (palette + quanto è sveglia + guadagno) perché le
  procedure private stavano arrivando a otto parametri.
- **Un ostacolo non si assottiglia mai con la sua corsia.** Il mondo può ritirarsi dal lato in cui
  non sei; un pericolo no, perché il pilastro 3 gli promette una fase di arrivo visibile e
  l'arrivo avviene mentre la corsia è ancora quella dormiente. L'eccezione è il cubo saldato nella
  linea del terreno, ed è un'eccezione per costruzione e non per scelta: quello *è* il suolo, e si
  legge dai suoi due angoli retti, non dal suo peso. Da guardare al playtest.
- **Se il canale non si legge, quello che lo maschera è `NEUTRAL_BLOOM`**, non questo. È una
  dichiarazione di design della fase 4 ("la soglia fra veglia e sonno è il posto più difficile
  dove guardare fisso") e non l'ho ribaltata a tavolino. Stessa cosa per la convergenza del bloom
  con la profondità.

**Cosa tocca a te giudicare**: se le due corsie hanno smesso di leggersi come un tubo; se la
dormiente è troppo fioca o non abbastanza; se il glow verso l'Onirico si *sente* come "sto
andando di là" o se la campana del bloom se lo mangia; e se l'Onirico satura troppo.

---

#### RL.5 ✅ — Il mondo si disegna a destra (4 settembre 2026)

**È un ritaglio, e la promessa della fase era esatta.** Una volta che ogni ostacolo sta dentro la
polilinea del pavimento (RL.2), "la linea scrive il mondo" è **una x oltre la quale non si
disegna niente**: gli span del terreno si tagliano lì esattamente come si tagliano su un buco,
un ostacolo a cavallo si tronca da solo, e da nessuna parte serve un'animazione di comparsa o uno
stato che ricordi a che punto è arrivata una forma. Gli ostacoli non compaiono: la linea li
raggiunge. Il file nuovo è `render/draw_front.odin` e sono novanta righe di cui la metà è il
commento che spiega perché non ci va un muro.

**Perché a destra non c'è un muro.** La Corruzione è marcata con un bordo verticale illuminato su
tutta l'altezza dello schermo, perché è letale e il pilastro 2 vuole una linea che nessuno possa
mancare. Copiare quel segno qui sarebbe il peggior modo possibile di fare i "due fronti
speculari": una barra luminosa al bordo destro legge come *qualcosa che arriva*, e questo è
l'unico confine del gioco che non minaccia niente. Quindi il fronte di disegno è marcato al
contrario — **per assenza**, perché le linee semplicemente finiscono, più **un pennino** su
ciascuna delle due, dove la penna tocca il foglio. I due fronti sono speculari in *cosa
significano*, e di proposito non in come sono disegnati.

**Il fronte non è una manopola di difficoltà e non deve diventarlo.** `DRAW_FRONT_INSET` è 48 px,
cioè **0.18 s** di preavviso al ritmo di apertura, ed è una costante: niente lo può rendere
funzione del tier, della profondità o del punteggio. Quei 48 px sono spesi per far stare il
pennino a schermo, non per fare tensione.

**Un dettaglio che era facile sbagliare in silenzio.** Il contorno della Sentinella si costruiva
*dal bordo sinistro verso destra*, quindi con il ritaglio i due capi liberi finivano a sinistra:
un raggio scritto a metà sarebbe stato **chiuso sul pennino e aperto sul capo che aveva già
finito**, cioè l'esatto contrario. Adesso il percorso parte dal pennino, va a sinistra lungo il
bordo alto, gira il capo sinistro e torna: i due capi liberi stanno dove sta l'inchiostro.

**Misurato** (armatura usa e getta, cancellata; ogni numero è **inchiostro**, cioè la differenza
contro un frame con il solo fondo — il campo non è piatto, la vignettatura lo rende funzione di
dove guardi, e una soglia assoluta risponde alla domanda sbagliata):

- Inchiostro per colonna attraversando il pennino (x=1232): `-40:187 -30:188 -20:188 -10:194
  +0:209 +10:7 +20:0 +30:0 +40:0`. Il mondo si ferma di netto; l'alone sborda **7 livelli a 10 px**
  e **zero** oltre i 20. Al bordo dello schermo: 0.
- Il pennino: **209** di inchiostro contro i **183** della stessa linea 120 px più indietro — è la
  cosa più luminosa a quell'estremità. Uno per corsia, entrambi presenti.
- Una Sentinella che copre 1138..1326 con il pennino a 1232: **192** di inchiostro 40 px prima del
  pennino, **0** 40 px dopo. Il capo sinistro, che la penna ha finito da un pezzo, è chiuso (192).
- Un cubo fluttuante su 1205..1259: **197** sul tratto alto disegnato, **0** oltre il pennino.
  Percorso di codice diverso dalla Sentinella, quindi vale la pena averlo misurato a parte.
- Un buco su 1162..1264 **sotto** il pennino: il labbro che la penna ha già scritto gira verso il
  basso (**187** a 14 px sotto la superficie) e **non c'è nessun pennino** (0). Giusto: quello che
  la penna sta scrivendo in quell'istante è un'assenza.

**Ricadute e cose da guardare**:

- `solid_spans` prende adesso il fronte come `right`, quindi un buco non ancora raggiunto va
  **limitato** e non sottratto: tagliare su un buco che la penna non ha disegnato metterebbe il
  segno di fine-linea del buco dove sta la penna.
- `draw_obstacle_outline` prende un `closed`, e `drawn_extent` è la funzioncina che risponde
  "fin dove è arrivata la penna su questa forma".
- **Il pennino sparisce quando sotto c'è un buco.** È corretto per costruzione ma a schermo
  potrebbe leggersi come la penna che si spegne. Da guardare al playtest; se dà fastidio,
  l'alternativa è tenere il pennino sulla quota della superficie anche sul vuoto.
- `game.get_track_at_anchor` **non è servita**: la nota della RL.1 diceva che la RL.5 l'avrebbe
  voluta, e non è andata così — il pennino prende il punto vero in cui finisce la polilinea, che
  è più onesto di ricampionare il tracciato. Resta senza chiamanti, e adesso senza nemmeno un
  motivo futuro dichiarato.

**Cosa tocca a te giudicare**: se il mondo che si scrive si *vede* (il fronte è vicino al bordo,
ed è di proposito: era la scelta fra vederlo bene e rubare preavviso, e ho scelto il preavviso);
se il pennino a due punti legge come una penna o come due; e se 48 px bastano o se il pennino
vuole più aria — sapendo che ogni pixel in più è preavviso in meno.

---

#### RL.6 ✅ — La Corruzione diventa un segno (4 settembre 2026)

**I due fronti sono adesso la stessa cosa scritta due volte**: una x con un ritaglio sopra. A
destra la penna scrive il mondo (RL.5), a sinistra la Corruzione lo mangia — e la seconda metà
esisteva solo come filtro sul frame finito. Adesso il terreno è **tagliato al fronte** esattamente
come lo è al pennino, e il segno che fa è **la linea che si sfilaccia in polvere**. Un segno, non
un filtro (documento, sezione 10).

**`fx/particles.odin`, anticipato dalla R7.** Pool fisso da 512, zero allocazioni a qualunque
frame rate e per qualunque numero di emettitori; una particella morta viene riempita scambiandoci
dentro l'ultima viva, quindi niente qui dentro può dipendere dall'ordine. Un'emissione che
sforerebbe viene scartata invece di far crescere il pool: la polvere che non c'è è invisibile, un
frame che alloca è uno scatto che si sente.

**Ha il suo generatore di casualità**, seminato una volta e passato per riferimento come tutti gli
altri del progetto — non il `rand` globale e **di proposito non quello della run**, che deve
restare riproducibile da un seed perché replay e punteggio vogliano dire qualcosa. Polvere che
cambia fra due replay della stessa run è corretto; una run che cambia per via della polvere
sarebbe un bug.

**L'integrazione è esatta, non a passi.** Il drag è un esponenziale, quindi sia la velocità sia la
distanza percorsa hanno forma chiusa. Non è vanità: il pool avanza sull'orologio del frame, e una
moltiplicazione per frame renderebbe la polvere più fitta su una macchina veloce.

**Lo shader è spento, non cancellato**, come chiedeva la proposta. `CORRUPTION_FILTER_ENABLED` in
`main.odin` è la riga che lo riaccende. Il motivo per cui non serve più è preciso: andava a nero
perché dietro il fronte il mondo era ancora **disegnato**; con la linea tagliata lì non resta
niente da drenare se non il campo, e un campo senza disegno sopra *è* l'aspetto di "il mondo qui
non c'è". Ma la scelta di andare a nero era venuta da un playtest (R2.6), quindi si disfa con un
altro playtest: **è una domanda della RL.9**.

**Il bordo illuminato del fronte resta disegnato con le primitive.** Era la ragione per cui
esisteva — un fronte letale che nessuno vede sarebbe l'unica cosa del gioco che uccide senza
mostrare il colpo (pilastro 3) — e adesso quella ragione è più forte, non più debole, perché non
c'è più nessuno shader a fare da rete.

**Misurato** (armatura usa e getta, cancellata):

- Il pool, flusso costante a 110/s con vita 0.8 s (attesi ~88 vivi): **85 / 88 / 88 / 88** a 30,
  60, 144 e 240 fps. Un flusso lento (12/s a 240 fps, cioè 0.05 particelle per frame) si assesta
  a **10** invece di essere arrotondato a zero ogni frame — è a questo che serve il debito
  frazionario. A 100 000/s il picco è **512**, cioè la capacità: si riempie e si ferma. Una
  raffica di 120 un secondo dopo: **0 vive**.
- Indipendenza dal frame rate: la stessa particella dopo 0.5 s di deriva finisce a
  `(-9.6830, 8.3920)` a 60 fps, e a 30/144/240 fps atterra a **0.00000 / 0.00001 / 0.00002 px**
  di distanza.
- Il quadro, inchiostro per colonna attraversando il fronte a x=300:
  `-60:0 -45:0 -30:0 -15:8 +0:195 +15:180 +30:173 +45:173 +60:175`. Dietro il fronte **zero**;
  al fronte il bordo illuminato (195), e regge su **tutta** l'altezza dello schermo (182 vicino
  al bordo alto, 182 vicino a quello basso).
- Una Sentinella che copre 206..394 con il fronte a 300: **166** di inchiostro 40 px davanti al
  fronte, **0** dietro. Si fa mangiare, non sparisce di colpo.
- Dopo un secondo di sfilacciamento: **151** particelle vive, e **185** di inchiostro dietro il
  fronte fuori dal corridoio, cioè dove solo la polvere può essere.

**Ricadute**:

- **`render` importa `fx`.** Il grafo resta aciclico (`fx ← core`), e `fx` continua a non sapere
  niente del gioco: prende posizioni, velocità e colori. Quello che sta in `render` è *come si
  sfilaccia*, che è direzione artistica.
- `draw_terrain` e `draw_obstacle` prendono `front_x`. Il mondo esiste **fra i due fronti** e in
  nessun altro posto, e sono due righe di aritmetica in `draw_terrain_side`.
- `draw_cut_shape` è nuova e possiede la parte che era facile prendere al contrario: una forma
  tagliata a destra ha i capi liberi sul pennino e il capo sinistro chiuso, una tagliata a
  sinistra è lo specchio, **una tagliata da entrambe le parti non è più un anello — sono due
  segni**. `draw_obstacle_outline` è diventata `obstacle_stroke`, perché adesso decide solo il
  colore e il peso.
- La polvere è del **colore della corsia**, non del fronte: è quello che la linea *era*, che si
  disfa. Il bordo è neutro perché il confine non appartiene a nessuno dei due mondi. Sono due
  affermazioni diverse ed è voluto che si vedano diverse.
- La polvere **si ferma in pausa**: emissione e avanzamento girano solo in `.Playing`, non per
  ogni stato che *mostra* una run. Un frame in pausa è un fermo immagine, e della polvere che ci
  deriva sopra sarebbe l'unica cosa a schermo che non si è fermata.
- `emit_fray` non guarda se sotto il fronte c'è un buco. Anche i bordi di un buco vengono
  mangiati, e sbagliare lì non costa niente; dove conterebbe è il pennino, e quello controlla.

**Cosa tocca a te giudicare, e la domanda grossa**: **lo shader va riacceso?** Adesso dietro il
fronte resta il campo con sopra niente — che è esattamente il foglio bianco del cartone, ed è la
ragione per cui secondo me non serve più. Ma è una cosa da guardare, non da decidere qui: se la
zona morta legge come "non c'è ancora niente" invece che come "qui è finito", si riaccende con una
riga. Poi: se la polvere è troppa o troppo poca, se va nella direzione giusta (indietro e *fuori*
dal corridoio, per non attraversare mai la parte di schermo dove si gioca), e se crescere con la
pressione si sente.

---

#### RL.7 ✅ — Le curve (4 settembre 2026)

`core/ease.odin` è cancellato e la libreria standard è adottata — **ma non del tutto, e la
ragione è misurata**.

Due delle tre curve erano identiche a quelle di `core:math/ease`: `ease_out_quad` contro
`quadratic_out` e `ease_in_out_quad` contro `quadratic_in_out` divergono di **1e-7**, cioè rumore
di virgola mobile. Non avevano nemmeno un chiamante. Via.

**La terza no, e sarebbe stato un cambio di feel travestito da pulizia.** `ease_out_back` è
l'easeOutBack di Penner; il `back_out` della libreria è quello di AHEasing, ed è una curva
diversa. Misurato sul mezzo giro del flip:

| | picco | dove | in gradi sul flip |
|---|---|---|---|
| la nostra | 1.100 | t=0.57 | **18°** di sfondamento |
| `ease.back_out` | 1.379 | t=0.47 | **68°** |

Lo scarto più largo fra le due è 0.33 a t=0.38. Cioè non è "un po' più elastica": è uno
sfondamento **in mezzo al viaggio** invece che un impulso alla fine, che è esattamente la versione
che un playtest ha già buttato via — *"un fronzolo messo sul movimento del giocatore non è
decorazione, è attrito"*. Scambiarla è una decisione di game feel, non una pulizia, e non la
prendo io a tavolino.

Quindi la curva del flip **resta**, ma si sposta dove appartiene: dentro `render/player.odin`
accanto al flip che modella, come `whip_ease` con la sua costante. Smette di essere "una curva
condivisa" e diventa quello che è davvero, cioè *la forma del gesto centrale del gioco*, con i
numeri qui sopra scritti nel commento perché la prossima persona non ci riprovi.

**Verificato** (armatura usa e getta, cancellata): guidata la simulazione vera attraverso un flip
completo, **9 passi**, confrontando `get_player_rotation` contro la formula che `core/ease.odin`
conteneva prima di essere cancellata — **0.000000000 radianti** di scarto. E le due cancellate
contro la libreria: 9e-8 e 1.2e-7.

**La regola che resta scritta**: `ease.ease` e le funzioni singole sono pure e `contextless`,
quindi possono stare ovunque, simulazione compresa. **Il tween `flux` no**: alloca (una mappa e un
array dinamico) e gira su un orologio a muro, quindi è solo presentazione — usarlo dentro un passo
di simulazione romperebbe replay e validazione del punteggio.

Nessuno usa ancora `core:math/ease`: il primo chiamante vero sarà la RL.8.

---

#### I rischi che segnalo adesso

- **Il personaggio a 45 px fatto di tratto sottile.** Nel cartone lui riempie il fotogramma; da
  noi è un ottavo dell'altezza dello schermo. È l'unico punto in cui il lavoro si *complica*
  invece di semplificarsi, perché la sagoma piena era una stampella di leggibilità e la
  togliamo. Mitigazioni nella RL.3, ma se non basta la correzione è ingrandire il personaggio,
  ed è una decisione di design.
- **Il gradino può leggersi come terreno.** Un cubo che diventa una gobba nella linea rischia di
  leggersi come "il suolo si alza" (innocuo) invece che come "cosa che costa". È esattamente ciò
  a cui risponde *il mondo curva, il pericolo fa angolo*, e va verificato leggendo i pixel, non
  a occhio.
- **Il banding nei gradienti** (nota 2 del playtest R2.6) smette di essere un difetto minore: un
  fondo pieno con vignettatura è tutta la superficie dello schermo. Va risolto in questa fase e
  non rimandato.
- **Legale, una riga sola**: il personaggio di Cavandoli è protetto. "Uno che lo ricorda" fatto
  del nostro tratto va bene; copiarne il profilo no.

#### Cosa consuma della R7

Particelle (intera), Scenografia (intera), e la parte della UI che riguarda lo stile. Alla R7
restano audio, game feel, il font vero e il Referto Onirico.

#### Cosa va aggiornato in `docs/` — ✅ fatto

La sezione 10 del documento di design (*Identità visiva*) è stata riscritta su La Linea nella
v2.1, e gli sketch non vanno più riletti come vincolanti.

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

**La RL le ha portato via due voci**: le particelle (`fx/particles.odin` nasce lì, per la
Corruzione che si sfilaccia) e la scenografia in parallasse. Quello che resta:
- **Game feel** — screen shake, squash & stretch, camera che reagisce, e la taratura finale di
  tutti i numeri.
- **Audio** — due tracce sincronizzate con crossfade sul flip (mai un cambio di brano); la
  Corruzione che toglie le alte e aggiunge un ronzio avvicinandosi; attrito sul blocco, non
  impatto.
- **UI** — un font vero al posto del bitmap di raylib, e il **Referto Onirico**: profondità,
  record, frammenti, cosa hai comprato, e **di cosa sei morto**.
- **Scenografia** — quello che va *oltre* la parallasse della RL, se dopo il playtest si
  scopre che serve.

---

## La direzione artistica

**Cambiata da capo il 4 settembre 2026: è La Linea** (`docs/inspiration/La_Linea.png`). Un fondo
pieno, un unico tratto continuo che è il mondo, il personaggio che si solleva dal tratto e ci
rientra. Vincolante, non indicativa. La fase che la porta a schermo è la **RL**, dove stanno
la grammatica nuova e le decisioni prese.

Resta vero che tutto è raggiungibile con primitive più palette più bloom: il progetto non ha
asset grafici esterni e non ne avrà. Anzi, adesso ne ha bisogno di meno.

### La direzione precedente — superata, ma non tutta

`docs/sketch/sketch_3` ha governato dal 3 settembre al 4 settembre 2026 e non governa più.
Quello che se ne porta via ha il suo valore e va tenuto:

- **La regola che lo teneva leggibile era geometrica, non di riempimento.** *La scenografia è
  linea, il pericolo è massa* diventa *il mondo curva, il pericolo fa angolo* — stessa regola,
  senza il riempimento (vedi RL).
- **`render/stroke.odin` è nato per lo sketch 3** e con La Linea diventa tutto il renderer
  invece di un dettaglio. È il pezzo di lavoro che il cambio di direzione promuove invece di
  buttare.
- **L'aritmetica del bloom qui sotto resta vera**, anche se i colori cambieranno: un valore di
  fondo deve stare sotto la soglia *più bassa che può incontrare*, non sotto la propria. È la
  cosa da rileggere prima di scegliere i due fondi nuovi.

### La palette ✅ (4 settembre 2026)

Presa **dallo sketch 3 campionando i pixel**, non a memoria. Prima era una cosa diversa: fondi
quasi neri, luce Onirica **arancione** e accento rosa caldo — un mondo caldo contro uno freddo,
che era un'idea ragionevole e non è quello che dice la direzione artistica. Nello sketch la
metà di sopra è lavanda e rosa su viola, e l'arancione era la cosa più rumorosa sullo schermo
che gli sketch non hanno mai contenuto.

| ruolo | Reale (sotto) | Neutra (l'orizzonte) | Onirico (sopra) |
|---|---|---|---|
| `deep` | `#16323F` | `#232B3E` | `#2C1F42` |
| `near` | `#1A3E4C` | `#2E374C` | `#37224C` |
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
La RL.1 ha poi reso quel vincolo **assoluto** invece che prudenziale. Da quando il fondo insegue
la posizione del personaggio con un ritardo suo, i due non sono più nemmeno approssimativamente
in fase: qualunque mondo può essere a schermo sotto la soglia di qualunque altro. Tutti e tre i
`near` stanno adesso sullo stesso valore, 76/255 = **0.298** — `neutral.near` era 0.329 e
`dream.near` 0.314 — e il contributo del fondo al bright pass è zero in ogni punto dello spazio
`world_t` × `depth_t`.

**Le tinte sono sopravvissute al cambio di direzione, i ruoli no.** La Linea non ha rimesso in
discussione quali colori siano i due mondi, ma ha cambiato cosa `deep` e `near` *sono* sullo
schermo: non più il cielo lontano e il cielo vicino alle due corsie, ma il campo al centro
(`near`) e il campo dove la vignettatura prende il sopravvento (`deep`). Stessi valori, altro
mestiere.

**Un asse del colore solo**: la **tinta**, che si muove con la profondità mentre i due mondi
convergono verso il neutro. La Corruzione non ne ha uno e non deve riprenderselo — è un
*posto*, non un livello (nota 1 del playtest R2.6).

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
