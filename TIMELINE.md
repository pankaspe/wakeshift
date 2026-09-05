# Wake Shift — Timeline

Cosa è stato fatto, in ordine. Una riga per lavoro: **titolo → cosa cambia**, mai più di settanta
parole. Il *perché* sta nei commenti del codice, che è l'unico posto dove non invecchia.

Non è un piano. I prossimi passi li decide l'autore uno alla volta.

---

## 2–4 settembre 2026 — v1.x

**Fondamenta** → Grafo di package aciclico (`core`, `platform`, `game`, `render`, `ui`).
Salvataggio CBOR cifrato nella directory dati utente. Fullscreen reale senza mai cambiare il modo
video del monitor, render target alla risoluzione nativa. Simulazione deterministica dal primo
giorno: seed, input come dato, timestep fisso a 60 Hz, manifesto di run registrato.

**Palette e bloom** → Tre mondi — Reale, neutro, Onirico — e nessun colore scritto a mano fuori da
`core/palette.odin`. Bloom vero su shader, 0.17 ms a frame nel caso peggiore, tarato contro quello
che arriva davvero al frame e non contro i nomi dei colori.

**Il primo pool** → Sette tipi di ostacolo, contratto fra pattern a insiemi di fasce, il Limine e
la Lucidity. Quasi tutto rimosso o ridotto nella riscrittura.

**La misura che ha chiuso la v1.3** → 200 run simulate senza mai premere il tasto: 161
sopravvivevano a tutto il primo tier, morte mediana a 35 s, e per l'**86% del tempo** niente a
schermo poteva uccidere in nessuna posizione. Non era taratura: il contratto *garantiva* di
entrare in ogni pattern dalla fascia sicura, quindi non muoversi era quasi sempre la risposta
giusta.

---

## 4 settembre 2026 — v2.0, la riscrittura

**R1 — Il cubo blocca invece di uccidere** → Un cubo ferma il personaggio contro la sua faccia e
gli costa terreno finché resta lì. Da qui il gioco può minacciare **entrambe le corsie insieme**,
cosa che un design dove tutto uccide non può fare: una coppia speculare diventa "quale prezzo
paghi", non "sei morto".

**R2 — La x del personaggio è stato di gioco** → `PLAYER_X` si spacca in due costanti:
`WORLD_ANCHOR_X`, dove il tempo di mondo atterra, e `PLAYER_HOME_X`, dove un corridore libero si
assesta. La distanza fra personaggio e Corruzione diventa l'unica barra della vita, disegnata a
schermo pieno.

**R2.6 — La Corruzione va a nero** → Il primo tentativo drenava verso il grigio e la zona morta
risultava illeggibile. Un playtest l'ha mandata a nero pieno: dietro il fronte non c'è una
versione slavata del mondo, non c'è niente.

**R3 — Il tracciato è simulazione** → Il corridoio diventa due numeri a fotogrammi chiave nel
tempo — spina e apertura — dentro `core/track.odin`. Pavimento e soffitto non possono più
contraddirsi perché sono la stessa coppia di numeri. I pattern autorano il tracciato insieme agli
ostacoli.

**R4 — I tre pericoli, i tre verbi** → Cubo (costa), buco (uccide chi ci sta sopra), Sentinella
(uccide chi si muove). Il cubo è una primitiva sola in sei taglie: mecanicamente conta solo la
larghezza, l'altezza è retorica.

---

## 4 settembre 2026 — fase RL, *La Linea*

Cambio di direzione artistica: via lo stile silhouette-e-luce, dentro **La Linea** di Cavandoli.
Un fondo pieno, un tratto continuo che *è* il mondo, e niente altro.

**RL.1 — Il fondo diventa il mondo** → Il cielo a due metà sparisce. Al suo posto un campo solo
il cui colore è il mondo in cui sei, con vignettatura cotta in una maschera. Il campo **insegue**
la posizione del personaggio con 0.45 s di ritardo, perché un flip dura 0.16 s e una raffica di
tre sarebbe uno stroboscopio.

**RL.2 — Il tratto è il mondo** → Sparisce il riempimento. Le due corsie sono due polilinee, e i
cubi non stanno più *sopra* la linea: sono un gradino **dentro** di essa, letto dal rettangolo di
collisione, quindi segno e hitbox sono la stessa cosa. Il buco è la linea che si interrompe.

**RL.3 — Il personaggio è una continuazione della linea** → Da sagoma piena a contorno. Il peso
del tratto e la posizione dei piedi diventano derivati l'uno dall'altra, così tarare il pennino
non lascia il personaggio in aria.

**RL.4 — Il glow cresce verso l'Onirico** → Terzo canale oltre a posizione e movimento, e l'unico
che sopravvive alla convergenza di profondità. La corsia dormiente si assottiglia e sbiadisce.

**RL.5 — Il mondo si disegna a destra** → Un pennino vicino al bordo destro oltre il quale non si
disegna niente. Non è un'animazione: è un ritaglio, comprato dalla RL.2 mettendo gli ostacoli
dentro la polilinea. Costa 0.18 s di preavviso e non sarà mai una manopola di difficoltà.

**RL.6 — La Corruzione diventa un segno** → Da filtro sul frame a linea che si sfilaccia.
`fx/particles.odin`: pool fisso da 512, zero allocazioni, integrazione esatta sotto attrito
esponenziale, generatore di casualità proprio. Lo shader resta compilato ma spento.

**RL.7 — Le curve** → Adottata `core:math/ease`, cancellata la nostra. Tranne la curva del flip:
misurata, quella della libreria sfonda di 68° contro i nostri 18, ed è la versione che un playtest
aveva già buttato.

**RL.8 — La parallasse** → Tre orizzonti per banda, nelle due fasce che il mondo non può mai
raggiungere. Verificato spazzando tutte le coppie spina/apertura legali: 9.2 px di franco.

---

## 5 settembre 2026 — il personaggio e la quadra sul gameplay

**Il mago** → La figura a stecchi a 45 px leggeva come un groviglio: nove segni in quarantacinque
pixel non hanno dove stare. Diventa **un contorno solo** — cappuccio, strozzatura, campana — al
peso della corsia viva, aperto ai piedi, così il pavimento chiude la figura e il personaggio legge
come il terreno che si alza. Provvisorio: la figura finale sarà un lemure.

**Il personaggio atterra sopra il cubo** → Un flip su una corsia occupata lasciava il corpo
**dentro** la scatola, al 100% di ogni forma, per due secondi e mezzo. Ora poggi su una superficie
su cui i tuoi piedi erano già: scendendoci sopra ci sali, arrivandoci contro di fianco resta un
muro. Effetto collaterale da ritarare: atterrare su un cubo è gratis.

**Due morti ingiuste** → Il buco uccideva 18 px prima che il centro del corpo ci arrivasse, con la
figura ancora visibilmente sul solido: ora ti prende quando non c'è niente sotto il tuo centro. Il
raggio era letale 0.17 s prima di essere disegnato: ora è disegnato per tutto il tempo che esiste.

**Il buco si prende il personaggio** → Cade dentro e si dissolve, lontano dal corridoio. Prima la
run finiva con la figura in piedi sul nulla, l'unico momento in cui il disegno diceva una cosa
diversa dalle regole.

**La Sentinella diventa una tenda, e l'ostacolo è la coppia** → Un emettitore su una corsia spara
una tenda di luce che si ferma un corpo prima dell'altra. Due affacciate e sfalsate sono **un flip
forzato e a tempo**: finestra di 0.18 s. È l'unica cosa nel gioco che stando fermi non si
sopravvive, ed è tenuta all'ultimo tier.

**Due forme scartate misurandole** → Un raggio che attraversa tutto il corridoio: zero pressioni
su duecento sopravvivono, perché due cose che si avvicinano da capi opposti si incontrano sempre.
La feritoia fra due raggi affacciati: il corpo ci sta dentro 0.054 s ma il suo attraversamento in
x ne dura 0.167, per un raggio di larghezza qualsiasi, zero compreso.

---

## 5 settembre 2026 — gli ostacoli si riducono a due

**T1 — Via la Sentinella** → Cancellata da sei file: il tipo, le costanti, i tre pattern e i loro
riferimenti nei tier, `draw_sentinel`, le clausole del validatore. Con lei se ne va
`is_lethal_to_both_lanes`, e la regola di equità torna a una frase sola.

**T2 — Il quadrato dimezzato, il buco slegato** → Buchi a 65/103/140 px assoluti, poi l'unità da
54 a **27**. Assoluti anche i limiti della coppia specchiata: erano scritti come multipli
dell'unità, e dimezzandola la banda legale diventava vuota. Misurato: dimezzare la larghezza non
dimezza il prezzo, perché a essere pagato è il tempo passato bloccati.

**Il buco è un buco anche in alto** → Il soffitto non si dissolve più: si spezza come il
pavimento, stesso segno specchiato. Via la coda sfumata e l'alone, scambiato a schermo per un
emettitore. Con due ostacoli soli ognuno deve dire una cosa sola.

**T3 — La forma diventa dato** → `CubeForm` non esiste più: il pattern scrive la skyline in
colonne, e le stesse cifre sono ciò che blocca, ciò che regge e ciò che viene disegnato. Prima la
piramide era disegnata a gradini e collideva come scatola piena. Il fluttuante diventa un flag.

**T4 — Il fluttuante orbita** → Deriva orizzontale sfasata di un quarto di giro dal bob: due assi
così sono un'ellisse. Le finestre di equità crescono dell'ampiezza, perché un ostacolo che si
muove in x cambia quando ti raggiunge.

---

## 5 settembre 2026 — il corridoio si allarga

Le due corsie erano troppo vicine per leggersi come due posti. Apertura di default da 340 a
**390**, massimo a 470, e tutti i 76 `span` autorati traslati di +50 invece che scalati: una
strozzatura riguarda quanto spazio resta al corpo, e il corpo è 45 px assoluti.

---

## Dove sta il gioco adesso

A schermo non c'è niente di pieno tranne il fondo. Ci sono i **due ostacoli** (quadrato e buco), il
tracciato che ondeggia e si strozza, la Corruzione che avanza da sinistra, il pennino che scrive il
mondo a destra, e la parallasse.

Manca il gioco. Le venti pattern sono tutte scritte per il vecchio enum: **nessuna usa il
vocabolario che T3 ha costruito** — niente skyline oltre le tre colonne, nessuna colonna a zero. E
si vede nella misura: una corsia è minacciata il **13,1%** del tempo, letale il 3,7%, contro un
obiettivo di oltre il 40%. Il mondo è per lo più aria.

---

## In corso — il mondo di mattoncini e la curva di difficoltà

**Riferimento visivo: `sketch.jpeg` in root.** Il mondo si costruisce con i quadrati, che sono i
mattoncini di gioco: **pavimento e soffitto diventano dritti** e tutto il rilievo lo fanno le
colonne — scale, torri isolate, altopiani, canyon, strozzature affacciate. Il blocco staccato che
si muove è il fluttuante, che c'è già.

La forma dei pattern resta autorata, la forma dei blocchi no: il pattern autora il **ritmo**
(quando, quale corsia, cosa chiede) e il generatore pesca la **skyline** dentro limiti che il
pattern dichiara. È nella grana del progetto — `get_max_width` esiste già apposta per far ragionare
il validatore su un evento prima che le sue scelte casuali siano fatte, ed è così che il buco tira
a sorte la propria larghezza.

| | Task | Modello |
|---|---|---|
| **C1** | **Il pavimento diventa dritto** → Spina e apertura diventano costanti: via `Pattern.track`, via `report_track_faults`, via l'ondulazione. La strozzatura non è più un'apertura che si stringe ma due colonne affacciate, cioè si autora con lo stesso vocabolario di tutto il resto. **Attenzione**: quello che se ne va è il *keyframing*, non `Ground` né `ground_time_at_x` — la mappa fra scroll e tempo è ciò che rende gli ostacoli eventi nel tempo e deve restare intatta. Da controllare chi legge il tracciato per l'orizzonte e la parallasse. | Opus |
| **C2** | **Il pool vero, costruito a mattoncini** → Il contenuto: le skyline dello sketch, profili pescati dentro limiti dichiarati dall'evento e verificati staticamente come già si fa per la larghezza del buco. Densità molto su. Obiettivo misurato: **oltre il 40%** di tempo con almeno una corsia minacciata, contro il 13,1% di oggi. Ogni regola nuova va controllata contro "stare fermi sopravvive a questo?", che è la misura che ha chiuso la v1.3. | Opus |
| **C3** | **La curva continua, in distanza** → Via i tre tier discreti, dentro una funzione continua. **La variabile è la distanza, non il tempo**: così comprare velocità compra punteggio e difficoltà insieme, e rallentare non è una strategia. Cresce la densità (l'aria fra i pattern) e cresce la parzialità del sorteggio verso i pattern che chiedono di più. La velocità smette di essere una manopola del tier. | Opus |
| **C4** | **Il feedback dello scalino** → Ogni tot distanza un burst particellare dice "sei salito di un gradino", senza scriverlo. Da far percepire, non da spiegare. `fx/particles.odin` c'è già: il pool è fisso, ha un generatore di casualità proprio che **non è quello della run** — e non deve diventarlo, o due replay della stessa run divergerebbero. Emesso dal clock del frame, mai dentro uno step. | Sonnet |
| **C5** | **L'intro e il tutorial** → I primi secondi: un testo in fadeIn insegna `SPACE`, poi il gioco entra. **Rischio noto**: l'aria morta è esattamente ciò che ha chiuso la v1.3, e dieci secondi in cui non succede niente sono lunghissimi alla seconda run. Tenere l'intro corta e far arrivare il primo ostacolo presto. | Sonnet |

**Decisioni ancora aperte (C5)**: quanto dura l'intro, e se si ripete a ogni run o solo alla prima.

**Nota per C1**: l'allargamento di ieri ha traslato 76 `span` autorati che C1 cancellerà insieme al
resto del keyframing. Non è lavoro buttato — la costante che conta, l'apertura del corridoio, resta.
