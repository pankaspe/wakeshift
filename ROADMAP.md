# WAKE SHIFT — Roadmap verso l'Alpha giocabile

> Documento di lavoro personale, in italiano. Non fa parte della documentazione pubblica del progetto e va rimosso dal repository prima di una eventuale pubblicazione.
>
> Il *cosa e perché* sta in `docs/design_doc.md` (v1.1). Le regole operative di sviluppo stanno in `CLAUDE.md`. Questo file è il *come, in che ordine, e con quale modello*.

---

## Indice

- [Come si legge questa roadmap](#come-si-legge-questa-roadmap)
- [Stato attuale](#stato-attuale)
- [Il sistema a tre mondi](#il-sistema-a-tre-mondi--riferimento-grafico-trasversale)
- [La direzione artistica: gli sketch](#la-direzione-artistica--gli-sketch)
- [La Corruzione](#la-corruzione--la-seconda-metà-della-lucidity)
- [Il terreno a piattaforme](#il-terreno-a-piattaforme--appunti-non-ancora-un-piano)
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

Verificato sul codice, 3 settembre 2026 — aggiornato a chiusura Fase 7.

**Funziona** — una riga per fase, il dettaglio sta nel recap della fase

- **Base** — loop one-button a corsa automatica; ostacoli come **eventi nel tempo**, non posizioni in pixel (la scelta architetturale migliore del progetto); coordinate fisse a 1280×720 così che nessun codice di gameplay sappia su che monitor gira; menu, pausa, game over, record
- **[1]** Package `core/platform/game/render/ui` (più `fx`) con grafo di dipendenze aciclico
- **[2]** Salvataggio cifrato nella directory dati utente, che rifiuta i file manomessi senza crashare; simulazione **deterministica e verificata** — seed esplicito, input come dato, timestep fisso a 60 Hz, e ogni record porta il `RunManifest` che lo riproduce
- **[2.5]** Avvio a schermo pieno senza toccare il modo video del monitor, render target alla risoluzione nativa, opzioni persistite
- **[3]** Nessun colore scritto a mano fuori dalla palette; i due mondi disegnati insieme con l'orizzonte in mezzo; la convergenza che li avvicina col passare della run; il personaggio con un corpo che corre e frusta
- **[4]** Bloom vero su shader, guidato da `world_t` e `depth_t` come la palette. 0.17 ms a frame nel caso peggiore
- **[5]** **Il Limine è giocabile**: tap e hold sullo stesso tasto, il viaggio si ferma a metà e riparte nella direzione in cui stava andando. Lucidity che si *spende* invece di accumularsi soltanto, ed è insieme il moltiplicatore
- **[6]** Sei ostacoli con **sei letture**: presenza contro assenza come regole di collisione diverse, voragini ritagliate davvero nel terreno, e i tre archetipi anticipatori. Il Pattugliatore attraversa il Limine, quindi il centro non è più gratis
- **[7]** Pattern concatenati su **insiemi di fasce**, con l'inclusione al posto dell'uguaglianza: un pattern può avere più di una risposta e dichiararle tutte. 19 pattern, difficoltà a tre manopole (velocità, aria fra i pattern, peso della pesca), e validazione automatica che ha già trovato due difetti da sola

**Non funziona / manca**

- **Niente costringe a essere coraggiosi.** La Lucidity si guadagna col rischio ma non cala mai da sola, quindi giocare pulito non costa niente. È il buco che chiude la Fase 8 con la Corruzione
- **Il terreno è ancora piatto nella sostanza.** La simulazione adesso lo vede — ci si appoggia sopra — ma la sua quota non chiede niente a nessuno: è un'ondulazione, non un interlocutore. È la T7.5.5
- Nessuna particella, nessun parallax, nessun audio
- Nessun replay o ghost in gioco: il `RunManifest` si registra e si salva, ma l'interfaccia non lo rigioca
- Menu e opzioni prendono i colori dalla palette ma usano ancora il font bitmap di raylib (T13.3)

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

## La direzione artistica — gli sketch

Riferimento vincolante quanto la tabella delle tre palette. Gli sketch stanno in `docs/sketch/`, che è **fuori dal repository** (vedi `.gitignore`): restano su disco, non nel clone.

**Scelto lo `sketch_3` per tutto** (3 settembre 2026): non solo il menu ma anche il gioco. Più semplice, più morbido nei colori, più piacevole da giocare. Gli altri due restano come cave da cui estrarre pezzi.

| File | Cosa governa |
|---|---|
| `sketch_3.jpeg` | **Tutto.** Lo stile del gioco e delle schermate |
| `spirito_foresta.jpeg` | **Il personaggio**: il Germoglio, e le sue pose |
| `sketch_1.jpeg` | Cava: il sistema di piattaforme alte e basse, e l'HUD diviso fra i due mondi |
| `sketch_2.jpeg` | Cava: le stalattiti dal soffitto, e i moscerini di luce (Fase 9) |

### Cosa si costruisce, cosa si traduce, cosa si butta

Il vincolo è sempre lo stesso: **niente asset esterni**. Tutto è primitive più palette più bloom, ed è quella proprietà che tiene il gioco in un eseguibile solo e permette a `depth_t` di ricolorare l'intera immagine senza ridisegnare niente.

- **Lo sketch 3 è già codice.** Fondo a gradiente verticale, piante come polilinee, piattaforme come rettangoli con bordo illuminato, orizzonte come fila di cerchi additivi. Non c'è niente da inventare: è `background.odin` più `glow.odin` più il bloom, che ci sono già. È anche l'unico dei tre che non chiede di rinunciare a niente — nessuna pennellata da imitare, nessuna texture da importare.
- **Dello sketch 1 non si prende il disegno, si prende la struttura**: le piattaforme a quote diverse (vedi sotto) e l'HUD diviso.
- **Dello sketch 2 non si prende la pittura.** Il suo valore sta tutto nella pennellata e nella nebbia morbida, cioè in ciò che le primitive non fanno. Restano le stalattiti — una buona forma per un ostacolo onirico appeso — e i moscerini, che sono un preset di particelle della Fase 9.

### Il rischio dello sketch 3, e la sua risposta

Lo sketch 3 è morbido e **uniforme**: piante, piattaforme e personaggio sono tutti tratti al neon dello stesso peso, su un fondo di bassa contrapposizione. È esattamente ciò che lo rende piacevole, ed è anche l'unico modo in cui questo stile può fallire — se gli ostacoli sono disegnati come la scenografia, **si sciolgono dentro di essa**, e il pilastro 2 dice che quando bellezza e leggibilità confliggono vince la leggibilità.

La risposta è l'idea buona dello sketch 1, riusata su un asse diverso. Lì *linea contro massa* separava il sogno dal reale; qui separa **lo sfondo dal pericolo**:

> La scenografia è **linea**: contorni luminosi con l'interno vuoto. Ciò che può ucciderti è **massa**: sagoma piena e scura col bordo illuminato.

Così lo stile resta quello dello sketch 3 e un ostacolo non è mai confondibile con una pianta, nemmeno a colori spenti o per chi non li distingue. Vale anche per i bonus della Fase 8, che sono il terzo caso: né linea né massa, ma **luce piena** (Design Doc sez. 8 — gli ostacoli sono sagome scure, i bonus sono fatti di luce).

### L'HUD diviso, dallo sketch 1

Stato onirico e punteggio in alto, stato reale e distanza in basso: ogni mondo etichettato dove quel mondo sta. Vale per la T13.1.

### Il tratto al neon ✅ (T7.5.2)

Sia lo sketch 1 che il 3 sono fatti di **una cosa sola**: un tratto luminoso di spessore variabile con i cappucci tondi. raylib non ce l'ha — `DrawLineEx` non ha cappucci e due segmenti consecutivi non si saldano. Ora c'è: `render/stroke.odin`, `new_stroke(colore, spessore)` più `draw_stroke` / `draw_stroke_line` / `draw_stroke_dot`, con rastremazione lungo la *lunghezza*, tratti chiusi per i contorni vuoti, alone additivo e nucleo schiarito verso il bianco.

Tre cose imparate costruendola, tutte misurate rileggendo i pixel:

- **Il verso di avvolgimento della strip non è libero.** Il backface culling si mangia l'intero nastro se le coppie di vertici escono nell'ordine sbagliato: niente errore, niente a schermo. La convenzione è quella che `terrain.odin` usava già per caso — per una linea che va da sinistra a destra, il primo vertice della coppia è quello in alto.
- **L'alone deve cominciare *fuori* dal nucleo.** Con lo strato più interno largo quanto il nucleo, la luce viene spesa sotto la passata opaca che poi lo copre: il profilo misurato crollava da 642 a 36 in un pixel, cioè una linea con un contorno, non una linea che brilla. Partendo a 1.6 volte il nucleo la spalla diventa una rampa (81/81/36/36/12/12/2/2 su un tratto da 6 px).
- **Le giunzioni si mitrano, non si timbrano.** Un cerchio sul vertice si sovrappone al nastro e in additivo somma due volte: una perla su ogni punto. Il cerchio resta solo dove la mitra non può esistere (curve strettissime), e i cappucci tondi sono tassellati *dentro* il nastro. È il difetto che il bordo del terreno aveva dalla Fase 3, ed è sparito convertendolo.

**Una domanda architetturale aperta, per la T13.3.** Il grafo dice `ui ← core, game`: `ui` non può importare `render`, quindi oggi il menu **non può** usare il tratto. Quando si arriva alla T13.3 le strade sono due: far importare `render` a `ui` (il grafo resta aciclico), oppure spostare `stroke.odin` e `glow.odin` in un pacchetto di primitive sotto entrambi. La seconda è più pulita e `stroke.odin` è scritto apposta per renderla uno spostamento di file: non importa `game`. Da decidere lì, non adesso.

### Il Germoglio ✅ (T7.5.3)

La scheda personaggio era già conforme alla regola della silhouette unica senza che glielo si fosse chiesto: **corpo scuro, testa che emette**. Il personaggio era già uno scheletro di giunti, quindi diventare il Germoglio è stato un cambio di numeri più un'appendice — non una riscrittura. Testa-bulbo (due cerchi: la sfera più un lobo che la raccorda alle spalle, così la testa finisce in un corpo invece che su un collo), corpo piccolo, un occhio solo, germoglio a due ossa con due foglie.

Le due semplificazioni decise sono state fatte così:

- **Un occhio solo**, più leggibile a 45px e senza un asse di simmetria da mantenere quando la figura specchia a metà rotazione. È disegnato col **punto della primitiva della T7.5.2**: alone additivo nell'accento del mondo e nucleo schiarito verso il bianco, che è esattamente "corpo scuro, testa che emette" scritto in primitive.
- **Il germoglio è un'appendice a due ossa con inerzia**, e l'inerzia è *misurata, non integrata*: tutto ciò che muove la testa (la frustata del flip, il rimbalzo della corsa) è funzione pura dell'orologio, quindi "dov'era un attimo fa" è una valutazione in più invece che uno stato da tenere. Niente stato nel renderer vuol dire niente da riprodurre in un replay. La punta pende più dello stelo, ed è quel singolo numero che fa leggere due ossa come una frusta invece che come un bastone piegato.

**La regola verticale, che non è estetica.** La figura *visibile* — silhouette più bordo illuminato — riempie esattamente la scatola da 45px, perché dalla T7.5.1 il fondo di quella scatola è il suolo. Il bordo sporge di `PLAYER_RIM_THICKNESS` oltre la sagoma, quindi il giunto del piede sta a 0.409 e non a 0.5. Sbagliarla è precisamente ciò che si vede come "il personaggio galleggia" o "il personaggio affonda".

**Solo i piedi toccano qualcosa.** Stare appesi al soffitto è mezzo giro più uno specchio, cioè un ribaltamento verticale: al soffitto i piedi stanno in *alto* nella scatola e il germoglio punta in giù, nell'aria libera. Per questo il germoglio può sporgere dalla scatola (lo fa di 4px) e i piedi no.

**Una cosa che il test ha trovato per conto suo**: un giocatore appena creato ha `settle_timer` a zero, cioè è a metà della molla d'atterraggio — ogni run comincia con il personaggio schiacciato al 72% dell'altezza. Non è un difetto introdotto qui e non è stato toccato, ma qualunque misura presa sul frame zero è sbagliata di 9 pixel.

**Un limite da non superare**: la posa cambia, il *moto* no. La lezione della Fase 5 vale ancora — un fronzolo messo sul movimento del giocatore non è decorazione, è attrito. La capriola è una posa che ruota lentamente mentre il giocatore è sospeso; non deve toccare l'orologio del viaggio né aggiungere un istante che il giocatore non ha chiesto.

---

## La Corruzione — la seconda metà della Lucidity

Indicazione del committente (3 settembre 2026), rielaborata insieme. Va nella **Fase 8**, che cambia nome di conseguenza. Nessun codice finché non si arriva alla fase.

### Il problema che risolve

Oggi il gioco chiede sempre e solo **"dove sto al sicuro?"**, e la risposta sicura è sempre disponibile. Non c'è mai un motivo per essere coraggiosi: la Lucidity si guadagna col rischio, ma niente costringe a guadagnarla — si può giocare pulito, schivare in anticipo, e perdere soltanto moltiplicatore. Manca l'attrito. La Corruzione trasforma la domanda in **"dove devo essere coraggioso?"**, che è la stessa domanda con una posta sopra.

### Cos'è, e cosa non è

**Non è una seconda risorsa.** Il design doc (sez. 8) ha una regola esplicita — una risorsa sola — ed è il motivo per cui la Lucidity fa due mestieri. Due barre in fondo allo schermo la rompono.

Non serve una barra nuova, perché **la Corruzione è la Lucidity letta dal polo opposto**: 100 = lucido, 0 = corrotto. Oggi quel numero cala solo nel Limine; deve calare anche **da solo, di continuo**. Da lì viene tutto il resto senza aggiungere un sistema:

- il moltiplicatore decade se non rischi → bisogna continuare a rischiare per continuare a segnare
- il Limine diventa **guadagnato invece che dato**: ci si può sospendere solo avendo giocato sporco poco prima
- il near-miss smette di essere un bonus e diventa **respirare**

**Ordine di grandezza già controllato**: 14 per near-miss su 100, ostacoli ogni 2-3 secondi. Con un drenaggio intorno ai 3/s un serbatoio pieno dura una trentina di secondi da fermo, quindi serve circa un near-miss ogni 5 secondi per stare in pari. Su una run da 45-90 secondi è un ritmo, non una tortura. Da tarare nella Fase 11 come tutto il resto.

### Cosa succede quando arriva — deciso

**Non uccide.** A zero il Limine si chiude (già succede, `LUCIDITY_SUSPEND_MINIMUM`), il moltiplicatore va a 1, e **il mondo si spegne**: si perde tutto ciò che rende il gioco bello, non la run. Si recupera con un solo near-miss.

Il perché di questa scelta e non della morte: un ostacolo ha sempre una fase d'arrivo visibile prima di essere letale (pilastro 3), e una corruzione letale sarebbe l'unica cosa nel gioco a uccidere senza che si veda arrivare il colpo. Spegnere il mondo punisce abbastanza — toglie il punteggio, il terzo stato e il colore in una volta sola.

### La versione scartata, e perché

**Il muro che insegue da sinistra.** Sembra la cosa ovvia e non lo è: in un gioco con un tasto solo e nessun controllo sulla velocità, un inseguitore **non è una meccanica, è un countdown travestito** — non si può correre più forte, quindi non c'è niente con cui interagisca. E non ci starebbe nemmeno fisicamente: il personaggio è a `PLAYER_X = 200`, dietro di lui ci sono 200 px di pista. Diventa una meccanica solo se sono le azioni del giocatore a muoverlo, che è di nuovo l'idea qui sopra.

### Come si vede

Non con una barra: **col colore che muore da sinistra.** La parte sinistra dello schermo perde il neon e si spegne, e il confine avanza. È leggibile in due secondi (pilastro 2), usa la palette che c'è già, e non aggiunge un tasto.

E qui c'è l'incastro con la direzione artistica. La regola che tiene leggibile lo `sketch_3` è *la scenografia è linea, il pericolo è massa*. Se **la corruzione è ciò che trasforma il mondo da linea a massa**, la regola visiva e la meccanica diventano la stessa regola: terreno corrotto pieno e scuro, terreno sano contorno luminoso. Un colpo d'occhio dice insieme dove sei e come stai andando.

**Il rischio da sorvegliare**: la palette converge già con `depth_t` mentre si scende, e `CLAUDE.md` ha la regola "luce e colore devono descrivere un mondo solo". Due sistemi che cambiano il colore di tutto si impastano. La corruzione deve quindi agire su un asse che la convergenza non usa — la **saturazione**, mentre `depth_t` muove la tinta.

---

## Il terreno a piattaforme — appunti, non ancora un piano

Indicazione del committente (3 settembre 2026): prendere dallo sketch 1 (e dal 2) il **terreno a quote diverse, alto e basso**, perché altrimenti la corsa è troppo lineare — e usarlo per **alzare un po' la difficoltà**, mettendo qualcosa nel terreno. Nessun codice finché non si arriva alla fase.

**Perché è una buona idea e non solo estetica.** Oggi il pavimento è un profilo irregolare ma *piatto nella sostanza*: la sua altezza non significa niente (fino alla T7.5.1 il gioco lo sapeva così poco che il personaggio ci stava dentro fino al ginocchio). Una quota che cambia trasforma il terreno da fondale a interlocutore, e lo fa senza aggiungere un verbo — che è la condizione perché sia ammissibile.

**Il vincolo che decide tutto**: il pilastro 5 dice *una domanda sola, tre risposte*. Il terreno non può chiedere di saltare né di abbassarsi: sarebbe una quarta risposta e un secondo gesto. Quindi tutto quello che il terreno fa deve esprimersi dentro le tre fasce che già ci sono.

**Cosa può fare il terreno, allora**

- **Un gradino che sale è un blocco fatto di paesaggio.** Non essere nel Reale quando arriva la parete. È la stessa domanda di un Block, ma posta dal mondo invece che da un oggetto appoggiato sopra — che è molto più forte tematicamente, e completa l'asse pieno/vuoto del design doc: il vuoto è la voragine, il pieno è il blocco, e il **gradino è il pavimento che si alza**.
- **Un pavimento alto accorcia il viaggio.** Il flip dura sempre `FLIP_DURATION`, quindi su un tratto rialzato copre meno distanza: stessa durata, più velocità apparente. Difficoltà percepita senza toccare una sola costante.
- **Un pavimento alto stringe la fessura.** Una forma pulsante appesa al soffitto sopra un tratto rialzato lascia un varco più stretto, e il Limine diventa scomodo esattamente lì.

**Facce verticali, mai rampe.** Il paragone col terreno non piatto di un platform regge per la forma, non per il comportamento: lì la terra rialzata si percorre, ci si sale sopra. Qui non si può, perché non c'è un salto. Un tratto rialzato quindi non è un gradino da superare, è **un muro da evitare stando altrove**. Una rampa prometterebbe una salita che non avverrà, e il pilastro 3 dice che l'informazione arriva sempre prima dell'impegno.

**Le quattro conseguenze tecniche da non scoprire dopo** (tutte verificate sul codice, non congetture)

1. ✅ **Fatto nella T7.5.1: il profilo è ancorato al tempo.** Vive in `core/terrain.odin`, una voce del profilo dura `TERRAIN_SEGMENT_TIME` secondi, e lo schermo x diventa tempo con la stessa formula che usano gli ostacoli. Conseguenza visiva da tenere d'occhio in playtest: l'ondulazione si allarga con la velocità — una gobba larga 50 px a 270 px/s ne diventa 74 a 400 — quindi il terreno si addolcisce man mano che la run accelera.
2. **Quindi la conclusione naturale: un gradino è un `PatternEvent`.** Autorato nel tempo come tutto il resto, dentro la stessa pool, visibile a `validate_pattern_pool`. Non un sistema parallelo. Il contratto `entry`/`exit` sopravvive intatto, perché stare nel Reale resta stare nel Reale a qualunque quota.
3. **Se invece il profilo diventa procedurale, deve uscire dal seed della run.** Oggi è deterministico per il fatto di essere una costante (`TERRAIN_PROFILE`, sei valori scritti a mano). Un terreno generato che non passi dal generatore della run romperebbe la riproducibilità, cioè leaderboard, replay e ghost insieme.
4. ✅ **Fatto nella T7.5.1 per il Pattugliatore**, che adesso spazza fra le due *pareti* invece che fra i due bordi dello schermo, quindi non entra più nel terreno a nessuna quota. Il Limine invece si è scoperto immobile finché il profilo è condiviso: vedi la domanda decisa qui sopra.

**La domanda aperta è stata decisa nella T7.5.1: si ricampiona a ogni step.** Un flip punta a dov'è il suolo *adesso*, non a dove sarà all'arrivo, quindi l'atterraggio è sempre corretto e la traiettoria si incurva un po' mentre il terreno scorre sotto. Il timore che la accompagnava — che il Limine si mettesse a salire e scendere — non si è avverato e non può avverarsi: pavimento e soffitto portano lo stesso profilo, quindi la sporgenza che abbassa uno alza l'altro di altrettanto e si semplifica nella media. Il punto di mezzo del viaggio resta `(SCREEN_HEIGHT - size) / 2` su qualunque terreno, cioè esattamente l'orizzonte che il fondale disegna. Vale finché le due pareti condividono il profilo: **un gradino su un solo lato romperebbe la proprietà**, ed è la cosa da verificare per prima nella T7.5.5.

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

**Squilibrio chiuso in questa stessa fase**: il centro era sicuro perché ogni ostacolo era attaccato a una parete, e il Pattugliatore lo ha risolto. Resta però il consumo di Lucidity, tarato più duro di quanto dovrà restare — si ritocca quando la Fase 8 le darà anche un drenaggio passivo, e definitivamente nel bilanciamento della Fase 11.

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

### ✅ Fase 7 — Pattern e curva di difficoltà

19 pattern su tre tier, concatenati su **insiemi di fasce** invece che su corsie singole, con una curva di difficoltà che ha smesso di essere solo la velocità. Tre difetti trovati e chiusi lungo la strada, nessuno dei quali era visibile leggendo il codice: `tight_double_switch` dichiarava l'uscita sbagliata e faceva seguire pattern a ingresso Real a un giocatore rimasto sul soffitto; ogni run apriva violando il proprio contratto, perché il generatore pretendeva `.Dream` mentre il giocatore parte in `.Real`; e la pool è diventata insanabile nel momento in cui l'Eco ha smesso di mentire sulla propria uscita.

**Cosa è stato deciso, e perché non è quello che il task diceva.**

La T7.1 chiedeva di insegnare il Limine al contratto dei pattern. Rigiocare ogni pattern contro la simulazione vera ha detto che la domanda era mal posta: **premere una volta e non lasciare mai sopravvive e finisce sospeso in quasi tutti i pattern della pool.** Tenere premuto non chiede il permesso a nessuno, quindi "il giocatore è nel Limine a questa giuntura" non è una cosa che il contratto possa governare — e un contratto che pretendesse di governarla avrebbe dovuto mettere il Limine in ogni insieme, cioè non essere un contratto.

Il difetto vero non era il terzo stato: era che **il contratto dava per scontato che un pattern abbia una risposta sola.** L'Eco ne ha due, e finiscono su pareti opposte. Quindi `entry`/`exit` diventano insiemi e la catena diventa inclusione; il Limine contribuisce a un'uscita **una seconda parete, non una terza fascia**, perché tenere premuto mette in pausa un viaggio invece di iniziarne un altro.

**Le decisioni che restano vincolanti**

- **Nessun pattern può *pretendere* il Limine.** La Lucidity parte da zero a ogni run, quindi un pattern la cui unica risposta è tenere premuto è irrisolvibile per chi non se lo può permettere. Ogni pattern deve avere una risposta fatta di soli tap, e l'arnese di verifica lo controlla direttamente.
- **Un pattern con due risposte ha bisogno di un *convergente* dopo di sé**, cioè di qualcosa che accetti entrambe le pareti. È una classe che non esisteva, e la pool era insanabile senza: `pick_next_pattern` sarebbe ripiegata su `pool[0]` dopo ogni Eco per il resto della run. L'ha trovato il validatore al primo avvio dopo il cambio di contratto, che è esattamente il motivo per cui quel controllo esiste.
- **La velocità non è la curva.** Gli ostacoli sono eventi nel tempo, quindi il tempo di reazione *dentro* un pattern non si muove con la velocità: rigiocando tutto a 270, 330 e 400 px/s l'insieme delle risposte che sopravvivono non cambia. La velocità cambia quanto a lungo *guardi* (1080 px di vista sono 4.0 s a 270 e 2.7 s a 400) e, tirando dalla parte opposta, quanto poco una voragine larga tiene chiusa la corsia. In parte si annulla da sola. Le altre due manopole sono `Tier.gap` (aria vuota fra i pattern, l'unica onestamente monotona) e `Tier.demand_weights` (quali pattern vengono pescati, non quali sono ammessi).
- **Una pool si entra da una parete, e le due pareti hanno scorte separate.** Prima della fase 7 il tier più profondo pesava su demand 3 senza avere un solo pattern di demand 3 da dare a chi stava sul pavimento: metà run prendeva la curva e metà prendeva quello che restava. `validate_tier_balance` controlla proprio questo.

**Perché 19 pattern e non 12-16.** Il bersaglio era stato scritto quando un pattern aveva un'uscita sola. Con le uscite a insieme servono i convergenti, che sono una classe in più, e serve simmetria fra le due pareti: da Dream c'erano tre pattern difficili e da Real uno, e nessun peso può pescare un pattern che non esiste.

**Come si verifica un contratto sui pattern**: rigiocandoli. L'arnese usa-e-getta ha guidato la simulazione vera con ogni linea di input fino a due pressioni, dalle tre fasce, alle tre velocità di tier, su ogni larghezza di voragine, chiedendo a ciascun pattern *quali risposte sopravvivono e dove ti lasciano*. Ha ribaltato l'assunto centrale della prima versione del contratto e ha riconfermato per conto suo un'affermazione della Fase 6 che nessuno aveva mai misurato — che `echo_guarded` tolga davvero la risposta col Limine. La lezione sta in `CLAUDE.md`; le regole del contratto anche.

**Ricaduta sul salvataggio**: `GAME_VERSION` → 0.3.0-alpha. Il formato non cambia e i salvataggi restano leggibili, ma ogni seed genera un livello diverso, quindi i manifesti 0.2.0 non si rigiocano più.

---

### Fase 7.5 — Il suolo e il Germoglio

**Obiettivo**: il personaggio smette di essere affondato nel terreno e diventa il Germoglio. Le due cose sono **un lavoro solo**: posare un personaggio nuovo su un suolo che sta per muoversi vuol dire posarlo due volte. Riferimento: `spirito_foresta.jpeg` e la sezione sulla direzione artistica.

Perché qui e non nella Fase 10, dove il terreno era programmato: il suolo affondato è un bug visibile *adesso*, e finché le corsie sono ancorate al bordo dello schermo qualunque lavoro sul personaggio va rifatto. Anche i bonus della Fase 8 vengono piazzati in corsia, quindi conviene che le corsie abbiano già la loro posizione definitiva.

| Task | Descrizione | Modello |
|---|---|---|
| T7.5.1 ✅ | **Il terreno diventa geometria di gioco, non decorazione** (ex T10.0): il profilo si sposta in `core`, `get_lane_y` lo campiona, e il giocatore corre *sopra* il suolo invece che dentro. Tocca la simulazione — gli estremi del viaggio del flip e `world_t` si muovono col terreno — quindi è un task, non una costante da ritoccare | **Opus** |
| T7.5.2 ✅ | `render/stroke.odin`: la primitiva del **tratto al neon**. Polilinea di spessore dato, cappucci e giunti tondi, nucleo chiaro più alone additivo, colore dalla palette. È la base di tutta la grafica delle fasi 10 e 13 | **Opus** |
| T7.5.3 ✅ | Il **Germoglio**: proporzioni nuove sullo scheletro esistente, testa-bulbo, occhio luminoso singolo, germoglio a due ossa con inerzia. Corpo scuro nei tre mondi, cambia solo la luce | **Opus** |
| T7.5.4 | Le tre pose: corsa, frustata del flip, e la **capriola** raccolta del Limine con l'occhio ad anelli. Solo posa: l'orologio del viaggio non si tocca | Sonnet |
| T7.5.5 | **Il gradino come evento di pattern**: il pavimento a quote diverse, autorato nel tempo, che chiede "non essere quaggiù quando arriva la parete". Vedi [Il terreno a piattaforme](#il-terreno-a-piattaforme--appunti-non-ancora-un-piano) — le quattro conseguenze tecniche sono lì | **Opus** |
| T7.5.6 ⚑ | Playtest: il personaggio appoggia davvero, si legge a 1280×720, i tre stati si distinguono anche a fermo immagine dalla sola posa, e la corsa non è più piatta | — |

**Ricaduta sul salvataggio (T7.5.1, fatta)**: `GAME_VERSION` → 0.4.0-alpha. Le corsie si sono spostate, quindi lo stesso log di input incontra collisioni diverse e i manifesti 0.3.0 non si rigiocano più. Il formato non cambia e i salvataggi restano leggibili. È il secondo bump di fila dopo quello della Fase 7: se a un certo punto i replay devono sopravvivere ai cambi di simulazione, va detto **prima** della prossima modifica alla simulazione, che è la T7.5.5.

**Perché la fase è cresciuta.** Nasceva con quattro task; la scelta dello `sketch_3` e il terreno a piattaforme le hanno aggiunto la T7.5.5. Sta qui e non nella Fase 10 per la stessa ragione per cui ci sta la T7.5.1: il terreno viene toccato una volta sola, e farlo due volte costa il doppio.

---

### Fase 8 — L'economia della Lucidity: cosa la consuma e cosa la riempie

**Obiettivo**: dare al gioco un motivo per essere coraggiosi. Era "i bonus di luce", cioè solo la metà che *riempie*; la Corruzione è la metà che *consuma*, e sono lo stesso lavoro. Dipende dalla Fase 5. Riferimenti: Design Doc sez. 8 e [La Corruzione](#la-corruzione--la-seconda-metà-della-lucidity).

| Task | Descrizione | Modello |
|---|---|---|
| T8.1 | **La Corruzione**: drenaggio passivo della Lucidity, il mondo che si spegne a zero, il recupero con un solo near-miss | **Opus** |
| T8.2 | La corruzione **si vede**: il colore che muore da sinistra, sull'asse della saturazione perché la tinta è già di `depth_t` | **Opus** |
| T8.3 | Pickup raccolti **per posizione**, non con un tasto; piazzati nella corsia pericolosa | **Opus** |
| T8.4 | Linguaggio visivo: gli ostacoli sono sagome scure, i bonus sono **fatti di luce** | Sonnet |
| T8.5 | Raccogliere luce = guadagnare Lucidity (una sola risorsa, non cinque) | Sonnet |
| T8.6 | **Timeshift** (Onirico): rallentamento del tempo per N secondi | **Opus** |
| T8.7 | **Forza della natura** (Reale): immunità per N secondi | Sonnet |
| T8.8 | Integrazione nei pattern: il generatore piazza i bonus con la stessa logica di aggancio degli ostacoli | **Opus** |
| T8.9 ⚑ | Playtest: la domanda deve diventare "vale il rischio?", non "dove scappo?" | — |

**Nota**: niente malus da raccogliere — decisione presa nel Design Doc sez. 8. Gli elementi avversi vanno nell'ambiente, dove sono prevedibili. La Corruzione non fa eccezione: non è un oggetto che si incontra, è una condizione del mondo.

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
| T9.8 | La **scia del Germoglio**: il nastro di luce e le foglie che si staccano, dalla scheda personaggio. Emesso dal corpo, mai attaccato al movimento | Sonnet |
| T9.7 ⚑ | Playtest: nessun calo di framerate a densità massima | — |

---

### Fase 10 — Il primo strato e la sua transizione

**Obiettivo**: validare l'intera idea degli strati su **uno solo**, prima di produrne quattro. Riferimento: Design Doc sez. 3.

**Direzione artistica della Foresta**: il riferimento vincolante è `sketch_1.jpeg`, letto insieme alla sezione [La direzione artistica](#la-direzione-artistica--gli-sketch). Foresta umida e luminescente, funghi giganti, luce che filtra da lontano — e lo sketch dice due cose che una descrizione di atmosfera da sola non diceva:

- **Le due metà non hanno solo colori diversi, hanno linguaggi di tratto diversi.** Sopra, la chioma onirica è *linea*: alberi e funghi come contorni al neon con l'interno vuoto, costruiti col tratto della T7.5.2. Sotto, la foresta reale è *massa*: tronchi come silhouette piene su più piani, con nebbia fra un piano e l'altro e solo qualche bordo illuminato. Sono due modi di disegnare la stessa foresta, ed è la ragione per cui l'immagine si legge a metà schermo senza etichette.
- **La profondità viene dalla nebbia, non dal dettaglio.** Ogni strato più lontano è più chiaro, più desaturato e più lento. Non serve disegnare meglio gli alberi lontani: serve disegnarli più annegati.

Il personaggio non è più un punto aperto: è il **Germoglio**, ed è già fatto nella Fase 7.5. Anche il terreno arriva qui già dentro la simulazione (ex T10.0, ora T7.5.1), quindi questa fase trova il suolo dove deve stare e ci costruisce sopra soltanto scenografia.

| Task | Descrizione | Modello |
|---|---|---|
| T10.1 | Generazione procedurale dei layer di parallax: tronchi come sagome da rumore in basso, chioma come tratti al neon in alto (mai PNG) | **Opus** |
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
| T13.1 | HUD definitivo coerente con la palette, **diviso fra i due mondi** come nello `sketch_1`: stato onirico e punteggio in alto, stato reale e distanza in basso | Sonnet |
| T13.2 | **Referto Onirico**: profondità, Lucidity massima, tempo per stato, strato raggiunto — screenshottabile | **Opus** |
| T13.3 | Menu, pausa e opzioni **ridisegnati sullo `sketch_3`**: fondo a gradiente, piante al neon con la primitiva della T7.5.2, orizzonte punteggiato. Più un font vero al posto del bitmap di default di raylib | Sonnet |
| T13.4 | Persistenza estesa: storico delle ultime run (le opzioni sono già persistite dalla Fase 2.5) | Sonnet |
| T13.5 | Passata finale di coerenza visiva | **Opus** |
| T13.6 ⚑ | Playtest completo end-to-end | — |

---

## Riepilogo carico per modello

Fasi 0-7 completate. Il conteggio qui sotto è **quel che resta**.

| Fase | Sonnet | Opus |
|---|---|---|
| 7.5 — Il suolo, il Germoglio, il gradino | 1 | 4 |
| 8 — Economia della Lucidity | 3 | 5 |
| 9 — Particelle | 6 | 1 |
| 10 — Strati e transizione | 2 | 3 |
| 11 — Game feel | 1 | 2 |
| 12 — Audio | 2 | 3 |
| 13 — UI e rifinitura | 3 | 2 |
| **Totale rimanente** | **18** | **20** |

Il piano è a metà: erano 25 Sonnet e 32 Opus a chiusura della Fase 2.5. Le fasi più pesanti in Opus — il gesto del Limine, le regole di collisione, la convergenza delle palette, la matematica dello shader — sono fatte, ed è per questo che il rapporto si è riequilibrato.

L'arrivo degli sketch ha aggiunto due task Opus veri (il tratto al neon e il Germoglio) e ha spostato il terreno dalla 10 alla 7.5, che è la fase da fare per prima appena la 7 chiude.

Dove conviene spendere Opus da qui, in ordine: la **7.5** (il terreno dentro la simulazione e la primitiva su cui poggia tutta la grafica successiva), la **10** (il sistema degli strati e la transizione come evento, più T10.0 che sposta il terreno dentro la simulazione), la **11** (bilanciamento numerico, dove il determinismo della Fase 2 finalmente ripaga: si rigioca la stessa run identica dopo ogni modifica) e la **8** (il piazzamento dei bonus nella corsia pericolosa, che è una decisione di design non una funzione). Le fasi economiche da mandare in Sonnet restano la **9** (preset di particelle, molto ripetitivi) e la **13** (UI).

---

## Definition of Done — Alpha

`[x]` fatto · `[~]` c'è ma non nella forma finale · `[ ]` non iniziato

- [x] Salvataggio cifrato nella directory dati utente, con manifesto della run migliore
- [x] Run riproducibile da seed + log input (base della leaderboard e dei replay)
- [~] Tre stati giocabili: ci sono e hanno costi diversi, il bilanciamento vero è la Fase 11
- [x] Il personaggio ha un corpo e due pose leggibili: la frustata del tap, il galleggiamento dell'hold
- [ ] Il personaggio è il **Germoglio**, appoggia davvero sul terreno, e i tre stati si distinguono dalla sola posa
- [~] Sistema visivo a tre palette con blending continuo e bloom attivi insieme; mancano particelle e parallax
- [x] **La convergenza funziona**: scendendo, i due mondi si somigliano sempre di più — palette *e* bloom convergono insieme — e posizione e movimento reggono da soli
- [x] Almeno 6 tipi di ostacolo con **letture distinte**, di cui almeno uno che minaccia il Limine e almeno uno anticipatorio (Eco / Finta / Pattugliatore)
- [x] 12-16 pattern distribuiti su tre tier — sono 19, e il perché sta nella Fase 7
- [x] Curva di difficoltà a tre manopole, non solo velocità
- [ ] Bonus di luce raccolti per posizione, piazzati dove costa qualcosa prenderli
- [ ] **La Corruzione**: la Lucidity cala da sola, il mondo si spegne a zero, e un near-miss lo riaccende
- [ ] Il terreno ha quote diverse ed è una domanda, non un fondale
- [ ] **Due strati e la transizione fra loro**, come evento che non ferma il gioco
- [ ] Audio: due mix sincronizzati + traccia per strato + i SFX principali
- [x] Avvio a schermo pieno alla risoluzione del monitor, con modalità finestra e impostazioni ricordate fra un avvio e l'altro
- [~] Menu, pausa e opzioni ci sono; manca il Referto Onirico (T13.2)
- [~] **60 FPS stabili**: misurati 705 con bloom sul frame peggiore, ma particelle e parallax non ci sono ancora
- [ ] Run media 45-90 secondi, curva di difficoltà leggibile
- [~] Un giocatore nuovo capisce il gesto tap/hold entro 30 secondi senza istruzioni — da riverificare con qualcuno che non sia l'autore
- [x] Tre stati distinguibili senza affidarsi al colore: posizione, e tipo di movimento (corsa a terra, deriva nell'onirico, corpo aperto e oscillante nel Limine)
