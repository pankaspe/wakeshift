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

## Dove sta il gioco adesso

A schermo non c'è niente di pieno tranne il fondo. Ci sono i **tre ostacoli** (cubo, buco,
tenda), il tracciato che ondeggia e si strozza, la Corruzione che avanza da sinistra, il pennino
che scrive il mondo a destra, e la parallasse.

Manca la **curva di difficoltà costruita sui tre ostacoli** — il pool vero — che è il pezzo che
serve per avere la quadra sul gioco.
