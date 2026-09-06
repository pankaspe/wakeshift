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

**F2 — L'economia** → Il fronte **accumula** invece di essere una funzione della distanza:
guadagna 0,030 px per ogni px di mondo all'apertura, sale con la curva, e non si ferma più a
150 px dal personaggio. Ogni frammento ne ricompra 60, restituiti come arretramento e non come
salto. Il surplus non si banca: la stanza è quella che si vede, e dieci frammenti su un corridoio
pieno lasciano il fronte a 8 px con niente in sospeso.

**Misurato in replay, 60 run** → Con un bot che schiva una mossa avanti: se i frammenti non pagano
muore a 8440 px (31 s), se pagano a 12 370 (46 s). L'economia vale il **+46% di run**. La pressione
media sul giocatore resta dov'era col vecchio fronte fisso — 80 px contro 83 — ed è il **picco** a
muoversi, da 176 a 251. Muoiono tutti di Corruzione, nessuno in un buco.

**Due cose che F3 deve sistemare** → La pendenza del sorteggio decide anche l'offerta del premio:
i due prototipi hanno demand bassa, quindi i frammenti crollano da 1,40 per 1000 px a zero oltre i
45 000. E il bot ne raccoglie 16,6 a run **anche quando non li vuole**, run identiche allo step,
perché il cubo sta sulla corsia opposta ai rombi: il premio è sulla strada che stava già facendo.

**Via il contatore dall'HUD** → Lo chiedeva già F1: quanto vale un frammento lo dice il fronte che
arretra, non un numero in un angolo. Il totale della run finisce nel Dream Report.

**F3 — Il pool si riempie** → Una regola sola: il rombo sta sulla corsia **Onirica**, subito dopo
l'ultima chiusura onirica del pattern, e solo nei pattern che chiudono l'Onirico per ultimi. È
l'unico istante in cui il giocatore è dimostrabilmente sul pavimento, quindi salire è un viaggio
di andata e ritorno che nessun altro motivo giustifica. Sedici pattern su trentuno lo portano; i
due prototipi di F1 sono spariti.

**Il premio smette di essere gratis** → Misurato con lo stesso bot di F2: uno che schiva e basta
ne raccoglieva **16,6 a run**, adesso **0,7**, contro 12,8 di uno che li vuole. E l'offerta non
crolla più con la profondità — da 0,95→0,00 per 1000 px a **1,15–1,60 piatta su dodici bande** —
perché non dipende più da due pattern a domanda bassa che la pendenza del sorteggio spegneva.

**Il controllo che mancava** → `report_fragment_burial`: un rombo dentro un cubo o sopra un buco,
scritto contro i **limiti dichiarati** della skyline e non contro l'esito — larghezza massima,
altezza massima, e per un cubo fluttuante tutta l'orbita. Controlla anche la corsia opposta,
perché una torre da 12 unità attraversa 324 px di corridoio su 390. Gira sul pattern e sulla
giunzione, perché un frammento non ha una regola di contenimento sua.

**Piattaforme fluttuanti** → Due pattern nuovi: il blocco sospeso arriva anche sul pavimento, e
una coppia sfasata sulle due pareti fa da cancello. **Niente rombo sopra una piattaforma**, e non
per scelta: il sollevamento è `LIFT/2 * (1 - cos)`, quindi la cima della scatola sta all'altezza
autorata per un istante e non per i 200 ms della finestra di raccolta.

**Cosa è cambiato senza che lo chiedessi** → La densità scende di 4–10 punti per banda (picco dal
71,1% al 61,0%): le code che reggono i premi sono tempo in cui nessuna corsia è minacciata.
Riportando `DIFFICULTY_GAP_OPEN` da 0,90 a 0,70 la banda d'apertura torna a 24,2% ma la run
mediana del bot crolla da 16 100 px a 9 900 — è una scelta di difficoltà, non una compensazione,
e la lascio a te. Le costanti della Corruzione non si sono mosse: la pressione media sul bot è
84 px dove F2 ne misurava 84.

**F4 — Onirico = veloce** → Sul soffitto il mondo corre a **1,35**: 364 px/s contro 270, e il
preavviso scende da 3,41 a 2,52 secondi. Il pavimento resta il tempo che il gioco ha sempre avuto,
perché "più veloce" dev'essere una cosa che il giocatore *fa*, non una linea di base da notare.

**È un orologio, non una velocità, ed è tutta l'implementazione** → La strada ovvia — alzare
`scroll_speed` sull'Onirico — è sbagliata: la x di un ostacolo è `ancora + (arrivo - adesso) *
velocità`, quindi alzarla moltiplica la *distanza* da tutto ciò che non è ancora arrivato. Il
mondo scivolerebbe a destra a ogni flip, e non sarebbe nemmeno più veloce nel senso che serve: gli
orari d'arrivo non si muovono, cresce solo la spaziatura. Quindi `scroll_speed` resta ferma e
**`elapsed_time` avanza di `pace` secondi per secondo reale**.

**Misurato** → Seguendo un ostacolo attraverso un flip, il movimento più grande in uno step è
**6,08 px** — esattamente uno step al ritmo del soffitto — e su uno step in cui il ritmo cambia
davvero, 6,07. Alzando `scroll_speed` lo stesso ostacolo sarebbe scivolato di **247 px** e il bordo
destro dello schermo di **322**. Il pool **non ha avuto bisogno di rivalidazione**: ogni finestra
è `(corpo + larghezza) / scroll_speed` secondi di *mondo*, e `scroll_speed` non si muove più.

**Il ritmo è un costo, non un acquisto** → La run finisce quando il fronte ti raggiunge, il fronte
guadagna per pixel, e il punteggio *è* distanza: si muore alla stessa distanza e si segna lo stesso
numero a qualunque ritmo. Andare veloce non fa guadagnare di più, fa guadagnare lo stesso **prima**.
Quello che rende il soffitto sensato sono i frammenti di F3, e il ritmo è il loro prezzo. Su 60 run
il bot passa da 16 150 px in 60 s a 15 180 px in **47,6 s**, a 319 px/s medi con il 47% degli step
in alto; e ne raccoglie 10,6 invece di 12,8, perché la finestra di raccolta è 0,2 s di mondo, cioè
0,148 reali lassù.

**Quello che il flip non fa** → Resta 0,160 s di tempo **reale**: "il gesto non cambia mai col
mondo" è più vecchio di questa fase. Quindi al soffitto costa 0,216 secondi di mondo invece di
0,160, ed è lì che va a finire tutta la difficoltà. Il bot sottostima il costo — reagisce in uno
step e non guarda avanti — quindi il preavviso perso vale quasi niente per lui e molto per te.

---

## In corso — la fase F

Il pool ha **trentuno** pattern e sedici portano un frammento. La finestra di raccolta sulla
corsia è **200 ms** esatti, `(16+38)/270`, ed è l'unica manopola che il rombo ha; il resto lo
decide dove sta. Un bot avido che raccoglie arriva a 16 100 px (60 s) e muore tre volte su
sessanta in un buco — il premio che tira una risposta localmente giusta dentro una sbagliata,
che è F6 in miniatura.

| | Task | Modello |
|---|---|---|
| **F5** | **Le due lane** → Reale pulito e ad alto contrasto, Onirico ricco e più difficile da leggere, così la differenza visiva *è* la differenza di difficoltà. Modifica la regola "il campo cambia colore col mondo, il tratto mai". | Sonnet |
| **F6** | **Far fallire il bot avido** → Pattern dove la mossa localmente giusta frega due secondi dopo. Bersaglio misurabile col bot che esiste già. | Sonnet |
| **C4** | **Il feedback dello scalino** → **Accantonato dall'autore il 6 settembre**, da rivalutare. Il burst particellare che serviva è nato comunque, come feedback della presa di un frammento. | Sonnet |

