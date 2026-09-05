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

## 6 settembre 2026 — il mondo di mattoncini

**C1 — Via il keyframing** → Spina e apertura sono costanti: pavimento a 555, soffitto a 165.
Cancellati `Pattern.track` e i 76 keyframe autorati, `report_track_faults`, il campionatore e la
sua storia. Resta la mappa fra scroll e tempo, che ora usano anche gli ostacoli. La strozzatura
sono due torri affacciate; `pattern_swell` sparisce con l'ondulazione e `CUBE_MAX_HEIGHT` sale da
7 a 12, perché il corridoio non si stringe più.

**C2 — Il pool costruito a mattoncini** → Il pattern non scrive più le colonne: dichiara una
**forma e i suoi limiti** (muro, salita, discesa, canyon) e il generatore pesca la skyline dal seed
della run. Il pool diventa il vocabolario dello sketch. Via l'aria morta dentro i pattern: il
preavviso è lo schermo, non i loro bordi, e la densità resta con una manopola sola.

**Due regole nuove, entrambe misurate** → Ogni pattern **contiene le proprie finestre**, e questo
rende la giunzione sicura a qualunque gap: sostituisce la vecchia regola del corridoio neutro che
C1 aveva cancellato. E due cubi sulla stessa corsia non possono sovrapporsi in x, perché il
terreno ne scarta uno e la collisione lo terrebbe — un pericolo che non si vede.

**C3 — La curva continua, in distanza** → Via i tre tier: `get_difficulty(scroll_offset)` è tutto.
Due manopole su curve diverse — l'aria fra i pattern si spende presto, la pendenza del sorteggio
morde tardi — più una distanza di sblocco per ogni pattern. Una curva sola satura, ed è quello che
il giocatore chiama "smette di diventare difficile". La velocità smette di essere una manopola: si
scorre sempre a 270 finché non la compra il giocatore.

**Il personaggio diventa un blocco** → Via la figura incappucciata: un quadrato **pieno**, del
colore della corsia in cui sta. Gli ostacoli sono quadrati vuoti, quindi il pieno è tutto ciò che
dice "questo sei tu". Niente rotazione — mezzo giro di un quadrato non si vede, resterebbe solo
l'overshoot, cioè un attrito sul gesto centrale. Restano schiacciamento e allungamento, con
l'atterraggio che molleggia: verificato a 0,0000 px di scivolamento dal terreno.

**Due numeri corretti misurando** → Lo schiacciamento da 0,28 a 0,20: la stoffa può deformarsi di
un terzo, un blocco no, e a 0,28 il quadrato atterrava come 51x32. E il battito da 58 px a 120: il
ciclo di passo della veste erano nove appoggi al secondo, che su un blocco è una vibrazione.

**Via il bordo, e il corpo scende a 38 px** → Senza contorno il blocco è un pezzo della corsia
invece che un oggetto illuminato davanti. Per farlo coincidere serviva anche lo schiarimento del
nucleo, non solo la tinta: senza, stava 22 valori su 255 sotto la linea; con, 4. La rimpicciolita
tocca `PLAYER_SIZE`, non il disegno — un corpo disegnato più piccolo della sua scatola mostrerebbe
un cubo che blocca senza toccare. Densità in calo di circa tre punti per banda, picco al 66,5%.

---

## Dove sta il gioco adesso

A schermo ci sono due sole cose piene: il fondo e il personaggio. Ci sono i **due ostacoli** (quadrato e buco), un
pavimento e un soffitto dritti su cui tutto il rilievo lo fanno le colonne — torri, altopiani,
scale, canyon, creste, strozzature affacciate — la Corruzione che avanza da sinistra, il pennino
che scrive il mondo a destra, e la parallasse.

Il mondo non è più aria e la difficoltà è una curva. Misurato senza giocatore, in bande da 5000 px:
una corsia è minacciata dal **24,7%** della prima banda al **68,7%** della dodicesima, e sale sempre.
Su 200 run che non toccano mai il tasto la morte mediana è a **3,4 s** — contro 35 s e 161 su 200
della v1.3. Un bot avido che guarda una mossa avanti arriva a 23 700 px (depth 2375) e muore sempre
per Corruzione, mai in un buco; in cima alla curva, 40 su 40 sopravvivono un minuto ai soli buchi.

Manca il **feedback** — niente dice al giocatore che è salito di un gradino — e manca l'ingresso.

---

## In corso — il feedback e l'ingresso

Il mondo è costruito e la curva c'è (C1, C2, C3). Quello che resta non è meccanica: è dire al
giocatore cosa sta succedendo, e insegnargli il tasto.

| | Task | Modello |
|---|---|---|
| **C4** | **Il feedback dello scalino** → Ogni tot distanza un burst particellare dice "sei salito di un gradino", senza scriverlo. Da far percepire, non da spiegare. `fx/particles.odin` c'è già: il pool è fisso, ha un generatore di casualità proprio che **non è quello della run** — e non deve diventarlo, o due replay della stessa run divergerebbero. Emesso dal clock del frame, mai dentro uno step. | Sonnet |
| **C5** | **L'intro e il tutorial** → I primi secondi: un testo in fadeIn insegna `SPACE`, poi il gioco entra. **Rischio noto**: l'aria morta è esattamente ciò che ha chiuso la v1.3, e dieci secondi in cui non succede niente sono lunghissimi alla seconda run. Tenere l'intro corta e far arrivare il primo ostacolo presto. | Sonnet |

**Decisioni ancora aperte (C5)**: quanto dura l'intro, e se si ripete a ogni run o solo alla prima.

