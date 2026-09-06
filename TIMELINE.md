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

**C5 — Il prompt del tasto** → Un testo solo, `PRESS SPACE TO SHIFT`, in dissolvenza al centro
del corridoio all'inizio di ogni run. Non è un tutorial e non è una pausa: il gioco gira sotto e
il primo ostacolo sta già arrivando. Sfuma via al primo flip del giocatore, o dopo tre secondi se
non preme. Stato di presentazione in `main`, sul clock del frame, mai dentro uno step.

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

Il tasto ora si insegna (C5). Manca il **feedback**: niente dice al giocatore che è salito di un
gradino.

---

## 6 settembre 2026 — fase F, la ragione per flippare

Un playtest ha detto che il gioco scorre ma non aggancia: si schiva e basta, non c'è una vera
scelta e non c'è un motivo per andare nell'Onirico. Le misure lo confermavano già — un bot che
guarda una mossa avanti arriva a 23 700 px e muore **60 volte su 60 per Corruzione, mai in un
buco**, e in cima alla curva 40 bot su 40 sopravvivono un minuto ai soli ostacoli. La Corruzione
decide già ogni partita ed è l'unica cosa passiva del gioco.

**F1 — Il frammento** → Un rombo vuoto, sospeso, il primo **premio** del gioco. Non è un terzo
ostacolo e non sta in `ObstacleType`: la regola dei "due elementi" parla di pericoli, e un
frammento non blocca, non uccide e non si risponde. Lista propria, stream proprio sul `Pattern`,
stesso orologio degli eventi. Alla presa esplode in particelle. Per ora conta e basta: l'economia
è F2.

**Una rappresentazione, tre collocazioni** → Corsia più scostamento dentro il corridoio. A metà
corpo è "lo prendi correndo lì"; a metà corridoio nessun corpo fermo ci arriva — **misurato a
145 px fuori portata da entrambe le corsie** — quindi si prende solo a mezzo flip, e la finestra
è di **233 ms**, che è `(24 + 38) / 270`: la tolleranza è la dimensione del rombo diviso la
velocità. È la prima volta che i 0,167 s che il flip passa nel corridoio contengono qualcosa.

**Il playtest sceglie il soffitto** → Via la collocazione a mezz'aria: era quella intelligente, ma
a mano risultava pignola invece che abile. Resta il rombo sulla corsia Onirica, che è poi la forma
che serve a F2. Rimpicciolito da 24 a 16 px e **riempito**: sotto i 20 px un contorno è quasi tutto
pennino, quindi "più piccolo" e "pieno" sono la stessa richiesta. Alone primitivo giù da 0,42 a
0,15 — a riempirlo ci pensa il bloom, che è la risposta che CLAUDE.md dà già ogni volta.

**Il blocco risponde** → Alla presa il quadrato fa un pop **uniforme** su entrambi gli assi, 0,20 s
di sola discesa. Tutto il resto che il blocco fa è anticorrelato — battito, atterraggio, flip
schiacciano un asse mentre allungano l'altro — quindi crescere su tutti e due è l'unico movimento
che gli altri non sanno produrre, e si legge come un evento diverso invece che come un atterraggio
più forte. Moltiplica la scala esistente, non la sostituisce.

**Terza eccezione al pieno, consapevole** → Le cose piene erano due, il campo e il personaggio, e
il pieno è ciò che dice "questo sei tu". Il discriminante si sposta da *pieno* a **quadrato
pieno**: il rombo è ruotato, è meno di metà del corpo, ed è l'unico che usa il colore `accent`.

---

## In corso — la fase F

Due pattern (`pattern_fragment_pair`, `_run`) esistono **per essere buttati**: F3 sparge i
frammenti sul pool vero. Misurato: sulla corsia la finestra di raccolta è **200 ms** esatti,
`(16+38)/270`, ed è l'unica manopola che ha. E un rombo messo dove il giocatore già si trova è
**gratis** — una run che non tocca mai il tasto lo raccoglie — quindi collocarli è tutto il lavoro
che resta da fare per dargli un senso.

| | Task | Modello |
|---|---|---|
| **F2** | **L'economia** → La Corruzione guadagna sempre, con un ritmo che cresce con la curva; i frammenti la ricacciano indietro. Qui il gioco cambia natura. Va **dopo** F1 e non prima: un fronte che avanza senza niente da spendergli contro è un conto alla rovescia, che è l'obiezione che `corruption.odin` fa già agli inseguitori. Si accetta consapevolmente che `front_x` smetta di essere una funzione pura della distanza e che "chi non sbaglia non è mai in pericolo" decada. | Opus |
| **F3** | **Il pool si riempie** → I frammenti nella collocazione vincente su tutto il pool, i tre prototipi via, più piattaforme fluttuanti. Qui serve anche il controllo che oggi manca: un rombo dentro un cubo, da scrivere contro i **limiti** dichiarati della skyline e non contro l'esito, come fa già `get_max_width`. | Sonnet |
| **F4** | **Onirico = veloce** → Il mondo accelera quando sei sul soffitto: il giocatore fa il tempo del gioco con un tasto. Richiede di ridefinire la banda di velocità e **rivalidare il pool**, che è controllato alla velocità più lenta di una run. | Opus |
| **F5** | **Le due lane** → Reale pulito e ad alto contrasto, Onirico ricco e più difficile da leggere, così la differenza visiva *è* la differenza di difficoltà. Modifica la regola "il campo cambia colore col mondo, il tratto mai". | Sonnet |
| **F6** | **Far fallire il bot avido** → Pattern dove la mossa localmente giusta frega due secondi dopo. Bersaglio misurabile col bot che esiste già. | Sonnet |
| **C4** | **Il feedback dello scalino** → **Accantonato dall'autore il 6 settembre**, da rivalutare. Il burst particellare che serviva è nato comunque, come feedback della presa di un frammento. | Sonnet |

