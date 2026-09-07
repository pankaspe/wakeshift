# Wake Shift — la lavagna

Il gioco è ripartito da zero il **6 settembre 2026**: labirinto procedurale a scorrimento. Qui c'è
solo cosa è fatto e cosa manca.

Lo **storico non sta più qui**: sta nei messaggi di commit (`git log`), che portano l'argomento per
intero, e il gioco a due corsie è in `docs/archive/`.

Si va a passi piccoli, uno alla volta, e si rivede il piano dopo ognuno.
Stato: ✅ fatto · 🟡 in parte · ⬜ da fare.

---

## Da fare, in ordine di criticità

L'ordine dice **quanto fa male adesso**, non in che sequenza si è obbligati a lavorare. L'autore
sceglie comunque.

| | | Task | Modello | Note |
|---|---|---|---|---|
| ⬜ | **L10** | **Mai obbligati a tornare indietro** → Da dove ti fermi, almeno una fra su / giù / destra deve portare avanti. Mai la sola sinistra. | Opus | **è quello che rovina il gioco adesso.** Prima misurare quanto è grave, poi invariante + metrica (vedi sotto) |
| 🟡 | **L4** | **La barra e la fase Onirica** → Cosa carica la barra, quanto dura l'Onirico, cosa cambia lassù. | Opus | attraversamento, arretramento, anello, colori: ci sono. **Non paga**: raccogliere è in perdita finché il Reale è in attivo. Serve una decisione tua |
| 🟡 | **L2** | **Il generatore vero** → I parametri crescono con la distanza. | Opus | invariante, intreccio, misura e riparazione ci sono. Manca **solo la crescita** — e senza, L4 e L8 non hanno contro cosa tararsi |
| ⬜ | **L13** | **La disintegrazione lungo il fronte** → La Corruzione mangia i muri dove li incontra, non solo pavimento e soffitto. | Sonnet | residuo del gioco a due corsie: `emit_fray` conosce ancora due corsie sole |
| ⬜ | **L12** | **L'evento di transizione Reale ↔ Onirico** → Il mondo che gira deve essere un avvenimento, non 0,35 s di colore. | Sonnet | la meccanica lassù è già grossa, non viene annunciata |
| ⬜ | **L5** | **Il disegno del labirinto** → I muri come tratto al neon. | Sonnet | il rischio tecnico è chiuso (82 tratti contro 562). Resta il giudizio estetico |
| ⬜ | **L11** | **I quattro muri candidati** → Nell'Onirico, da fermo, marcare i muri che bucheresti. | Sonnet | trasforma il bonus da «vado e vedo» a «scelgo quale». È anche il più a rischio di fare confusione a schermo |
| ⬜ | **L8** | **Livelli e portali** → Il livello è un checkpoint dentro una run continua: il fronte arretra, la barra resta, la difficoltà sale di un gradino, lo scroll non si ferma un frame. | Opus | intrecciato con l'economia di L4: è qui che il fronte va ridisegnato |
| ⬜ | **L6** | **Punteggio, HUD, font** → Cosa si segna in un labirinto. Megrim (SIL OFL 1.1) in `assets/fonts/`, caricato dai byte così il binario resta autosufficiente. | Sonnet | |
| ⬜ | **L14** | **La mappa** → Una striscia con due marker: dove sei tu, dove è la Corruzione. | Sonnet | **condizionale**: si fa solo se dopo l'economia il fronte ancora non si legge. Celle da 55 px, 12 righe, 60 px di striscia — nessuna misura da rifare |
| ⬜ | **L9** | **Allenamento** → Ogni livello raggiunto giocabile da solo, a seed fisso e senza Corruzione. | Sonnet | stesso generatore, seed noto, fronte spento |
| ⬜ | **L7** | **Audio** → Tenuto per ultimo per scelta dell'autore. | Sonnet | |

---

## Fatto

| | | Task | Note |
|---|---|---|---|
| ✅ | **L1** | **La griglia e lo scivolamento** | cella 60, 12 righe, corpo 38. **A questa velocità un labirinto si legge e diverte: sì**, in tre playtest |
| ✅ | **L2a** | **Invariante, intreccio, misura** | fascia misurata sul grafo delle scivolate, non sull'adiacenza fra celle |
| ✅ | **L2b** | **La riparazione deterministica** | si aprono muri invece di ritirare il chunk: sacche **3,18% → 0 su 13533 celle** (40 semi) |
| ✅ | **L3** | **I frammenti nel labirinto** | piazzati per misura sul costo di **copertura** (ci passi sopra), non di sosta. Fascia 3–18 celle |
| ✅ | **L4a** | **L'anello meccanico** | barra, attraversamento di un muro, arretramento del fronte, Lucidi |
| ✅ | **L4b** | **Il lampo e la scia** | anello che si espande sul muro bucato, e il muro che resta aperto disegnato spezzato |
| ✅ | **L4c** | **Tre famiglie di colore** | mondo `light` / frammenti `accent` / corpo `figure`, e gli attori non convergono con la profondità |

---

## Perché quel modello

La regola che divide la colonna è una sola: **Opus dove una risposta sbagliata è invisibile**, Sonnet
dove uno sbaglio si vede subito.

- **Opus** — misure, invarianti, economie. È la classe di lavoro dove il generatore si era
  autoapprovato su ogni chunk mentre il labirinto era murato, dove il test delle trappole dichiarava
  verde un mondo col 3,18% di celle terminali, e dove i numeri della Corruzione erano calibrati
  contro un'economia già cancellata. Nessuna delle tre cose dà errore, dà solo un gioco sbagliato.
- **Sonnet** — disegno, HUD, audio, un modo che riusa pezzi che esistono già. Se è storto lo vedi al
  primo avvio.

---

## L10 — l'argomento per intero

Sotto la sensazione di incastro ci sono **due problemi diversi**, e la cura è diversa.

**Il primo è strutturale.** Il generatore misura l'attraversamento in **celle percorse** e conta una
cella verso sinistra come una verso destra. Nel gioco non è lo stesso: a destra paghi solo tempo, a
sinistra paghi il tempo **e** il terreno, perché il fronte intanto avanza. Una cella all'indietro
vale grosso modo il doppio. Quindi il generatore approva labirinti che chiedono di tornare indietro,
perché nella sua aritmetica costano poco: sta misurando una cosa che non è quella che paghi.

**Il secondo è informativo.** Il fronte sta 2000–3400 px dietro e non è a schermo. Tornare indietro
di cinque celle sono 300 px, il 10% del vantaggio — praticamente niente. Ma non lo si sa, quindi
*ogni* passo indietro si sente come flirtare con la morte anche quando è gratis.

### Il cambio di invariante

> Oggi: **esiste un cammino che ti fa arrivare in tempo.**
> Da domani: **esiste un cammino che ti fa arrivare in tempo e non ti chiede mai di tornare indietro.**

Perché è quella giusta:

- **Tornare indietro passa da tassa a scelta.** È letteralmente il pilastro 5 — *essere bloccato è
  sempre la conseguenza di un percorso che hai scelto*. Oggi non lo è: è la conseguenza di un
  corridoio che non ti ha dato alternative.
- **Non tocca niente.** Scivoli sempre fino al muro, nessuna meccanica nuova, niente in più a
  schermo.
- **La macchina esiste già.** È la riparazione di L2b con una domanda diversa: *«ogni cella
  raggiunge un attraversamento senza mosse a sinistra?»*, e dove no si apre un muro.
- **Dà una manopola di difficoltà migliore di quella che toglie.** Da «quanto spesso il labirinto ti
  frega», che è punitiva e non si legge, a **quanti cambi di corsia servono per attraversare** —
  continua, leggibile, tarabile.

Insieme: **prezzare una cella verso sinistra per quello che costa** (circa il doppio). L'invariante
fa sì che indietro non sia mai *obbligatorio*, la metrica fa sì che non sia nemmeno la strada più
conveniente. Sono due cose diverse e servono tutte e due.

### Prima di scrivere una riga, misurare

**Su quante celle di sosta raggiungibili l'unica mossa che porta avanti è sinistra?** È il solutore
sul mondo assemblato con le mosse a sinistra tolte.

- se viene fuori il 20–30% → l'invariante è la risposta, e il numero dopo deve essere zero;
- se viene fuori il 3% → quello che si sente non è la struttura ma **il non vedere quanto costa**, e
  la cura è L4 (economia) o L14 (mappa), non il generatore.

Indovinare quale dei due è, è precisamente l'errore già commesso una volta: il fronte *sembrava*
velocissimo e misurandolo prendeva il 4% del terreno perso.

---

## Leve grosse, discusse e non prese

Tenute qui perché non si perdano, non perché siano previste.

- **Girare ai bivi.** Mentre scivoli premi Su e il corpo gira alla prima apertura utile invece che al
  muro. Eliminerebbe il problema di L10 del tutto, e riscrive cos'è il gioco: *«i bivi in mezzo a una
  scivolata non ti vengono offerti»* è la regola che rende la lunghezza dei rettilinei una manopola
  invece che un ornamento. Da usare solo se L10 non basta.
- **Spendere un pezzo di barra per bucare un muro nel Reale.** Darebbe sempre una via d'uscita e
  renderebbe il frammento utile *subito*. Rischio serio: se la barra si spende a rate non si accumula
  mai e **l'Onirico non scatta più** — la fase diventa un pulsante.
- **Rimbalzo** e **diagonali**: scartati dal design doc §7. Il primo toglie il controllo al giocatore
  (pilastro 1), il secondo è un secondo schema di controllo da imparare sotto pressione in una fase
  che dura sei secondi.

---

## Decisioni in sospeso, da prendere giocando

Nessuna di queste è lavoro: sono giudizi che solo l'autore può dare.

| Cosa | Dove si cambia |
|---|---|
| L'ambra del corpo è troppo su un campo verde-azzurro? | `core/palette.odin`, tabella unica |
| Menta contro ciano basta a separare rombi e muri, ora che i rombi sono pieni? | idem |
| Anello e rombi sono lo stesso colore di proposito — legge come «i frammenti che ho preso» o come confusione? | idem |
| La scia: ~20 monconi spezzati a schermata durante un Onirico. Rumorosa? | `WAKE_ALPHA` in `render/maze.odin` |
| I quattro numeri dell'anello (quanti frammenti, quanto dura, quanto arretra, quanto vale un Lucido) | `game/dream.odin` e `game/corruption.odin` |

---

## Da sistemare quando il labirinto è reale

Il `RunManifest` registra solo i tick del flip, quindi con quattro direzioni **non riproduce più una
run** — e il tenere premuto è input di simulazione, quindi nemmeno le sole pressioni basterebbero. Il
record salvato (4998) è di un equilibrio che non esiste più e non sarà comparabile.

---

## Prossimo step consigliato

### **L10, e si comincia misurando.**

È l'unica cosa in lista che non è un miglioramento ma un **difetto che si sente giocando**. E la
misura viene prima perché decide quale delle due cure serve: il generatore, oppure il far vedere
quanto costa davvero un passo indietro.
