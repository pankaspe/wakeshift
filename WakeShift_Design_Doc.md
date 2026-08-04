# WAKE SHIFT
### Game Design Document — v1.0

*(già "Hypnagogia" nelle versioni precedenti — rinominato per evitare sovrapposizioni con titoli già pubblicati, vedi sezione 11)*

---

## Indice

1. Concept
2. Il Loop di Gioco
3. I Due Mondi
4. Il Flip: dettagli di design
5. Anatomia degli Ostacoli
6. Spazio di Gioco & Timing
7. Level Design & Generazione Procedurale
8. Metriche e Punteggio
9. Flusso Schermate & UI
10. Persistenza Dati
11. Nome & Identità
12. Identità Visiva
13. Audio Design
14. Stack Tecnico & Note di Architettura
15. Glossario
16. Scope del Primo Prototipo (MVP)
17. Roadmap Post-MVP
18. Domande aperte / da decidere in seguito

---

## 1. Concept

**Genere**: Endless runner / reflex arcade
**Piattaforma target**: Desktop (Windows/Linux/Mac), con possibilità futura di build web (HTML5) grazie alla natura multi-target di Haxe — non sfruttata nell'MVP ma disponibile senza riscrivere il codice
**Engine**: Haxe + HaxeFlixel
**Input**: Un solo tasto — **barra spaziatrice** — per il flip gravità (nessun altro comando)

**Elevator pitch**: Sei sospeso tra il Mondo Reale e il Mondo Onirico. Con un tasto capovolgi la gravità e passi dall'uno all'altro, ognuno con le proprie regole, il proprio ritmo, i propri pericoli. Quanto in profondità riesci a scendere nel sogno prima del Risveglio?

**Canali di distribuzione target**: itch.io / Steam (community indie affine a questo genere), streaming/Twitch (alta skill expression = ottimo da guardare in diretta), clip di "raffiche" di switch perfetti condivisibili come contenuto breve.

**Pilastri di design** (da rispettare in ogni decisione futura, anche in fase di sviluppo assistito da AI):
1. **Un tasto, una regola** — l'intero gioco si controlla con un solo input (barra spaziatrice = flip). Nessuna eccezione, nessun verbo aggiuntivo (niente salto, niente abbassamento separato).
2. **Leggibile in 2 secondi** — chi guarda un video del gioco deve capire l'obiettivo senza spiegazioni.
3. **Ogni run è diversa, ogni run è giusta** — procedurale ma mai ingiusto o irrisolvibile.
4. **Il tema non è decorazione** — reale/onirico deve influenzare meccanica, grafica e feedback, non solo estetica superficiale.
5. **Una sola domanda in ogni istante** — il giocatore si chiede solo "sono nel mondo giusto?". Ogni ostacolo vive in una sola corsia (alta o bassa), mai in entrambe contemporaneamente: lo switch mondi è l'unica risposta possibile a qualsiasi minaccia.

> **Nota per lo sviluppo assistito da AI**: qualsiasi nuova feature proposta in fase di implementazione va prima verificata contro questi 5 pilastri. Se una feature richiede un secondo input o rompe la leggibilità istantanea, va scartata o ridiscussa qui nel doc prima di essere implementata.

---

## 2. Il Loop di Gioco

1. Il personaggio corre automaticamente in orizzontale a velocità crescente.
2. Il giocatore preme la barra spaziatrice per invertire la gravità → il personaggio passa dal pavimento (Mondo Reale) al soffitto (Mondo Onirico), o viceversa.
3. Deve trovarsi nella corsia giusta al momento giusto: ogni ostacolo esiste in una sola corsia (mai in entrambe), quindi lo switch è l'unica azione necessaria per evitarlo (vedi sezione 5, Anatomia degli Ostacoli).
4. La collisione = fine corsa ("Risveglio").
5. Fine partita: riepilogo statistiche ("Referto Onirico") + invito a ritentare immediato.

Durata media di una run: **15–45 secondi** nelle fasi iniziali di gioco, fino a diversi minuti per giocatori esperti.

---

## 3. I Due Mondi

### Mondo Reale (basso / pavimento)
- **Palette**: desaturata, toni freddi (grigi, blu spenti)
- **Fisica ostacoli**: prevedibile, meccanica — velocità costante, pattern regolari e lineari
- **Lettura richiesta al giocatore**: posizione e velocità (skill "spaziale")
- **Audio**: suoni sordi, ovattati, quasi meccanici

### Mondo Onirico (alto / soffitto)
- **Palette**: calda, contrasti forti, quasi psichedelica
- **Fisica ostacoli**: irregolare ma non casuale — movimento su curve sinusoidali, pulsazioni, accelerazioni/decelerazioni morbide
- **Lettura richiesta al giocatore**: ritmo e tempismo (skill "temporale")
- **Audio**: suoni filtrati, eterei, con leggero riverbero

### Perché la dualità funziona
Il giocatore non impara "una skill", ne impara due in parallelo. Il livello di padronanza percepito cresce più velocemente rispetto a un runner classico, senza aggiungere bottoni.

---

## 4. Il Flip: dettagli di design

- Il flip **non è istantaneo**: una micro-transizione di ~0.1–0.15s con distorsione visiva (blur/dissolve) e un suono che cambia pitch (sale passando al sogno, scende tornando al reale)
- Durante la transizione il personaggio è **momentaneamente invulnerabile** (frame di grazia) per evitare la frustrazione da "collisione ingiusta" nel momento del cambio
- Nessun cooldown sul flip: il ritmo lo detta il livello, non un vincolo artificiale
- Vedi sezione 12 per il dettaglio dell'effetto particellare associato al flip

*(Nota: i parametri esatti — durata frame di grazia, curva di easing — andranno definiti e testati in fase di prototipo, non in questo documento. Valori di partenza suggeriti in sezione 6.)*

---

## 5. Anatomia degli Ostacoli

### Il principio visivo di base

Il campo di gioco è composto da **due muri fissi** (soffitto e pavimento) e il personaggio scorre sempre attaccato a uno dei due. Lo switch lo fa "saltare" istantaneamente (con la micro-transizione già descritta) da un muro all'altro. Ogni ostacolo appartiene a **una sola corsia**, mai a entrambe nello stesso momento: la regola che il giocatore interiorizza è semplicissima — *se c'è un ostacolo nella mia corsia, switcho; altrimenti resto dove sono*.

**Regola di leggibilità (fase di arrivo)**: ogni ostacolo, di qualunque tipo, deve avere una fase di "arrivo" riconoscibile prima di diventare pericoloso al 100% — entra dal bordo destro dello schermo con un lieve fade-in, o parte piccolo/incompleto e cresce fino alla forma attiva. Questo garantisce che anche i pattern più fitti (raffiche) restino onesti e mai a sorpresa: il giocatore ha sempre un accenno visivo prima della minaccia piena.

### Principio tematico: pieno vs vuoto

I due mondi non si differenziano solo per palette e ritmo, ma per **il tipo di minaccia che rappresentano**:
- **Mondo Reale → ostacoli "pieni"**: qualcosa che appare, sporge, si materializza. Coerente con un mondo concreto, meccanico, fisico.
- **Mondo Onirico → ostacoli "vuoti/assenti"**: qualcosa che scompare, si dissolve, viene meno. Coerente con un mondo instabile ed evanescente.

Questa asimmetria voluta è ciò che dà identità tematica al gioco, oltre alla semplice differenza estetica.

### Ostacoli — Mondo Reale (basso / pavimento)

Ostacoli "onesti", leggibili a colpo d'occhio, con fisica prevedibile e movimento lineare o a intervalli regolari.

| Ostacolo | Descrizione | Comportamento |
|---|---|---|
| **Blocco/colonna** | L'ostacolo classico, sporge dal pavimento verso l'alto | Statico, posizione e altezza fisse |
| **Voragine** (buco nel pavimento) | Non è qualcosa che appare, ma l'assenza del pavimento stesso | Se il giocatore è in basso quando arriva, deve switchare sopra o cade — inverte la lettura rispetto al blocco |
| **Piattaforma sospesa bassa** | Pende dal soffitto ma abbastanza in basso da colpire chi è nella corsia sbagliata | Statica o con leggera oscillazione verticale minima |
| **Meccanismo a pistone/pressa** | Elemento meccanico che si estende e ritrae dal pavimento | Movimento a intervalli regolari e prevedibili — aggiunge un fattore di timing oltre che di posizione, coerente col tema "meccanico" del Reale |

### Ostacoli — Mondo Onirico (alto / soffitto)

Ostacoli "irregolari" ma mai casuali, letti attraverso il ritmo più che la posizione pura, con movimento su curve morbide (sinusoidali) invece che lineari.

| Ostacolo | Descrizione | Comportamento |
|---|---|---|
| **Forma pulsante** | Cresce e si ritira periodicamente | Curva sinusoidale — a volte blocca la corsia, a volte no, a seconda del momento esatto in cui il giocatore la incrocia |
| **Specchio/ombra fluttuante** | Elemento che si muove lungo la corsia | Moto ondulatorio, non lineare — difficile da "calcolare" a colpo d'occhio, va letto a ritmo |
| **Entità onirica pattugliante** | L'unico vero "nemico" del set — una presenza che pattuglia la sua corsia | Movimento avanti/indietro con pattern regolare ma non banale. Aggiunge presenza narrativa senza introdurre azioni di combattimento: resta comunque un ostacolo da evitare col solo switch |
| **Buco onirico (dissolvenza)** | L'equivalente della voragine, ma nel soffitto | Una porzione di soffitto si dissolve gradualmente e scompare, obbligando il giocatore a scendere |

### Coppie concettuali (Reale ↔ Onirico)

Utile tenerle a mente per il design dei pattern, perché ogni ostacolo del Reale ha un "contraltare" tematico nell'Onirico:

- Blocco (pieno, appare) ↔ Buco onirico (vuoto, scompare)
- Voragine (assenza) ↔ Forma pulsante (presenza intermittente)
- Piattaforma sospesa (statica) ↔ Specchio fluttuante (dinamico)
- Pistone (timing meccanico regolare) ↔ Entità pattugliante (timing organico irregolare)

---

## 6. Spazio di Gioco & Timing

### Principio guida

Lo spazio di gioco va definito **partendo dal tempo di reazione**, non dai pixel. Il tempo è l'esperienza reale del giocatore; i pixel sono solo la sua conseguenza tecnica. Lavorare così permette anche di bilanciare il gioco toccando un solo parametro (la velocità di scroll) senza dover ridisegnare i pattern — vedi nota tecnica in fondo alla sezione.

### Finestre di reazione target

Tempo dal fade-in dell'ostacolo (inizio della fase di "arrivo", sezione 5) al momento in cui deve essere già stato evitato:

| Tier | Finestra di reazione |
|---|---|
| Facile | ~1.2 – 1.5 secondi |
| Medio | ~0.8 – 1.0 secondi |
| Difficile | ~0.5 – 0.7 secondi |
| Estremo | ~0.4 – 0.5 secondi |

Range in linea con lo standard del genere reflex-arcade: abbastanza stretto da generare tensione, mai così stretto da risultare ingiusto nei tier bassi.

### Risoluzione di riferimento

**1280×720** (16:9) come riferimento per il design — si scala in modo pulito su qualsiasi risoluzione desktop comune.

### Suddivisione verticale dello schermo

| Fascia | % altezza schermo | Funzione |
|---|---|---|
| Corsia Onirico (alto) | ~30% | Zona ostacoli Mondo Onirico |
| Zona di transizione centrale | ~40% | Spazio "vuoto" per respiro visivo + attraversamento animato del flip |
| Corsia Reale (basso) | ~30% | Zona ostacoli Mondo Reale |

La zona centrale ampia serve a due scopi: evitare una sensazione claustrofobica e dare margine fisico all'animazione di attraversamento del personaggio durante il flip (il personaggio si sposta fisicamente, non si teletrasporta).

### Velocità di scorrimento

- Dimensione di riferimento del personaggio: **~40–50px**
- Con finestra di reazione tier facile ~1.3s e obiettivo di percorrenza schermo (1280px) in ~4–5 secondi:
  **Velocità di scroll base ≈ 260–280 px/secondo**
- Questa velocità cresce nel tempo secondo la curva di difficoltà (vedi sezione 15, domanda aperta sulla curva esatta)

### Target di performance

Per un arcade a riflessi il frame rate è parte integrante dell'esperienza, non un dettaglio tecnico secondario. **Requisito esplicito**: 60 FPS stabili, da trattare come vincolo di design fin dal prototipo, non come semplice auspicio da verificare a posteriori.

### Nota tecnica per l'implementazione (Haxe/HaxeFlixel)

**Non hardcodare i pixel nei pattern.** I pattern vanno descritti come sequenze di eventi nel tempo (es. *"a 1.5s dall'inizio del pattern → ostacolo in corsia bassa"*), convertiti in posizione X a runtime moltiplicando per la velocità di scroll corrente. Questo rende i pattern indipendenti dal bilanciamento della velocità: se in futuro si cambia la curva di difficoltà, i pattern restano validi senza bisogno di essere ridisegnati.

---

## 7. Level Design & Generazione Procedurale

### Struttura a chunk
- Livello diviso in **pattern/segmenti** pre-disegnati a mano (durata 3–5 secondi di gioco ciascuno)
- Pool separati per Mondo Reale e Mondo Onirico
- Ogni pattern ha **punti di aggancio** (inizio/fine "alto" o "basso") che determinano quali pattern possono susseguirsi, garantendo sempre continuità risolvibile

### Tier di difficoltà
| Tier | Quando compare | Caratteristiche |
|---|---|---|
| Facile | Sempre, dall'inizio | Pattern ampi, margini di errore generosi |
| Medio | Dopo soglia di punteggio/tempo | Pattern più fitti, primi doppi ostacoli |
| Difficile | Dopo soglia più alta | Finestre di reazione strette |
| Estremo | Solo run molto lunghe | Riservato ai giocatori più esperti, valore "trofeo" |

- La velocità di scorrimento globale aumenta gradualmente col progredire della run
- Il pool di pattern disponibili si allarga progressivamente verso i tier più difficili (mai improvvisi salti di difficoltà)

### La cadenza degli switch come motore della difficoltà
Tolto il salto, tutta la varietà ritmica del gioco nasce da **quanto in anticipo si vede arrivare il prossimo switch necessario** e **quanto sono ravvicinati i cambi**:
- **Singolo switch ben distanziato** → respiro, tier facile
- **Doppio switch ravvicinato** → tensione, tier medio
- **Raffica di switch consecutivi** → massima tensione, tier difficile/estremo — è qui che nascono i momenti più "clippabili"

### Numero di pattern stimati per il prototipo
- 15-20 pattern per il Mondo Reale (tier facile/medio)
- 15-20 pattern per il Mondo Onirico (tier facile/medio)
- Estendibili in seguito con tier difficile/estremo

---

## 8. Metriche e Punteggio

Invece di un punteggio anonimo, il tema dà forma alle statistiche mostrate a fine partita:

- **Profondità Onirica** (punteggio principale): cresce nel tempo, più velocemente mentre si è nel Mondo Onirico rispetto al Reale → incentiva il rischio nella zona meccanicamente più instabile
- **Lucidità**: streak di flip consecutivi senza errori → oltre certe soglie, sblocca effetti visivi progressivi, in particolare a livello di sistema particellare (vedi sezione 12)
- **Risveglio**: il game over, narrativamente motivato (non "Game Over" ma "Ti sei svegliato")

A fine run: un piccolo **"Referto Onirico"** riassuntivo (Profondità raggiunta, Lucidità massima, eventuale record personale) — pensato per essere facilmente condivisibile/screenshottabile.

---

## 9. Flusso Schermate & UI

### Principio guida

Il pilastro "un tasto, una regola" (sezione 1) vale per il **loop di gioco**, non per la UI di contorno: nei menu è accettabile e utile usare più tasti (frecce/invio per navigare, ESC per pausa/indietro), senza rompere nessun vincolo di design.

### Main Menu (schermata di avvio)

Voci previste:
- **Inizia Run**
- **Metriche/Statistiche** — record personale, Profondità massima, Lucidità massima, eventuale storico delle ultime run
- **Opzioni** — lingua, volume musica e SFX separati, eventuale regolazione luminosità/contrasto (rilevante dato lo stile Silhouette + Luce, sezione 12)
- **Esci**

### Pausa (ESC durante il gameplay)

Overlay che ferma il gioco (sfondo di gameplay visibile ma sfumato/blur dietro il pannello, per mantenere il contesto), con le voci:
- **Riprendi**
- **Riavvia Run**
- **Torna al Main Menu**
- **Opzioni** (stesso pannello richiamabile dal Main Menu)

### Fine Run → Referto Onirico

- Statistiche della run appena conclusa (Profondità, Lucidità, eventuale nuovo record)
- **Riprova** — l'azione deve essere quanto più rapida possibile, idealmente anche solo ripremendo la barra spaziatrice, per non introdurre attrito nel loop "riprovo subito" che è centrale alla viralità del gioco (sezione 1)
- **Torna al Main Menu**

---

## 10. Persistenza Dati

### Salvataggio locale (offline)

Dati da salvare in locale (formato leggero, es. JSON — nessun database necessario per questo scope):
- Record personale (Profondità massima, Lucidità massima)
- Storico delle run recenti
- Opzioni scelte (lingua, volumi)

**Nota sulla sicurezza**: per il salvataggio puramente locale non è necessaria alcuna protezione anti-manomissione. Modificare manualmente il proprio file di salvataggio non danneggia altri giocatori — è un problema che non esiste in questo contesto, e proteggerlo sarebbe uno sforzo sprecato.

### Leaderboard online (roadmap post-MVP, fuori scope MVP)

A differenza del salvataggio locale, una leaderboard condivisa richiede protezione dalla manomissione, perché un punteggio falsato danneggia l'esperienza di tutti gli altri giocatori. Approccio pianificato, in ordine di robustezza:

- **Livello base (deterrente)**: firma/hash del payload inviato al server con chiave segreta lato client — scoraggia i tentativi più semplici, ma non è una protezione affidabile contro un cheater motivato
- **Livello robusto (standard per gli arcade)**: il client invia **seed della run + log degli input** (ogni pressione della barra spaziatrice con relativo timestamp) invece del punteggio finale. Il server, conoscendo la logica deterministica del gioco (pattern generati da seed, fisica prevedibile — già previsti dall'architettura in sezione 7), **rigioca la run internamente** e calcola autonomamente il punteggio. Se il valore dichiarato dal client non coincide, il punteggio viene scartato
- **Livello aggiuntivo**: rate limiting sulle submission e flag automatici su punteggi statisticamente anomali per revisione manuale, invece di un sistema anti-cheat complesso sproporzionato per un progetto indie/solista

**Nota architetturale importante**: il generatore procedurale deterministico da seed (sezione 7) non serve solo al level design — è anche la base tecnica che renderà possibile, in futuro, la validazione lato server della leaderboard senza dover riprogettare il sistema di generazione.

---

## 11. Nome & Identità

**Titolo**: *Wake Shift*

**Storico naming**: il progetto era inizialmente pensato come *Hypnagogia*, termine reale che indica lo stato di transizione tra veglia e sonno, coerente al 100% col concept. Verificata l'esistenza di più titoli già pubblicati con questo nome esatto (*Hypnagogia: Boundless Dreams* e *Hypnagogia 無限の夢*, entrambi su Steam/itch.io, più *Project Hypnagogia* in sviluppo), il nome è stato scartato per evitare sovrapposizioni. Verificato anche e scartato *Hypnic Jerk* (altro termine medico affine, già usato per un piccolo endless runner su itch.io).

**Wake Shift** è stato verificato non risultare in uso come titolo di alcun videogioco pubblicato al momento della stesura di questo documento. Mantiene comunque il legame concettuale col tema (wake = risveglio, shift = cambio/flip).

Terminologia di gioco coerente col tema:
- Game over → **Risveglio**
- Punteggio → **Profondità Onirica**
- Streak → **Lucidità**

*(Prima di un annuncio pubblico, verificare ulteriormente la disponibilità diretta su Steam e itch.io, oltre a un controllo su eventuali marchi registrati)*

---

## 12. Identità Visiva

### Perché serve un'identità visiva forte

La meccanica di flip-gravità one-button è un sottogenere arcade già molto affermato (es. la serie G-Switch, Gravity Guy e diversi cloni minori). Non essendo la meccanica un elemento di unicità, **l'identità visiva deve fare gran parte del lavoro di differenziazione**, insieme al tema reale/onirico già progettato a livello di ostacoli (sezione 5).

**Direzione da evitare categoricamente**: lo stile sci-fi/neon/geometrico usato dalla quasi totalità dei giochi di flip-gravità esistenti. Uno stile simile farebbe percepire Wake Shift come "un altro clone", vanificando il lavoro fatto sul tema.

### Stile scelto: Silhouette + Luce

Personaggio e ostacoli renderizzati come **sagome piene (silhouette)**, con la caratterizzazione affidata quasi interamente al trattamento della luce piuttosto che al dettaglio delle forme.

**Perché questa scelta**:
- Economica da produrre: poche forme piene, nessuna necessità di dettaglio interno o animazioni complesse — adatta a un progetto in fase di apprendimento di Odin/raylib
- Fortemente leggibile a velocità elevate, requisito chiave per un arcade a riflessi (coerente col pilastro "leggibile in 2 secondi")
- Permette una differenziazione netta tra i due mondi lavorando solo su luce e colore, senza dover disegnare due set di sprite dettagliati

**Mondo Reale**: luce fredda e dura, ombre nette e ben definite, contorni netti sulle silhouette. Sensazione di concretezza fisica.

**Mondo Onirico**: luce calda e diffusa, ombre morbide o quasi assenti, bordi delle silhouette leggermente meno definiti (es. un lieve glow/bloom). Sensazione di instabilità ed eterea leggerezza.

### Sistema Particellare

Le particelle sono l'elemento chiave per dare un "tocco di cura" a uno stile visivo volutamente minimale, e vanno progettate in modo coerente con il principio tematico pieno/vuoto già stabilito in sezione 5.

**Particelle — Mondo Reale**:
- Polvere/scintille al contatto tra personaggio e pavimento
- Piccoli detriti che si staccano dagli ostacoli quando il personaggio passa vicino
- Movimento delle particelle: lineare, gravità dritta verso il basso, coerente con la fisica "onesta" del mondo

**Particelle — Mondo Onirico**:
- Particelle che fluttuano invece di cadere, con leggero movimento a spirale
- Dissolvenza graduale invece di sparizione istantanea
- Una scia leggera ("polvere di sogno") che accompagna il personaggio durante la corsa

**Particelle — Momento del Flip**:
- Breve esplosione di particelle nel punto esatto della transizione
- Colori che sfumano dalla palette del mondo di partenza a quella del mondo di arrivo
- Elemento a basso costo di implementazione (sistema particellare semplice in raylib) ma alto impatto percepito — probabilmente il singolo dettaglio più "condivisibile" del gioco

**Particelle legate alla Lucidità**: al crescere dello streak (sezione 8), la densità e vivacità delle particelle aumenta progressivamente. Questo rende il feedback di "sto giocando bene" percepibile visivamente in tempo reale, non solo tramite un numero a schermo — coerente col pilastro "il tema non è decorazione".

### Palette di riferimento (indicativa, da affinare in fase di prototipo)

| Mondo | Sfondo | Silhouette | Luce/Accento |
|---|---|---|---|
| Reale | Grigio-blu scuro desaturato | Nero/antracite | Bianco freddo / azzurro spento |
| Onirico | Viola-magenta profondo | Nero/antracite (stesso personaggio) | Arancio-oro caldo / rosa acceso |

Mantenere lo **stesso personaggio** (stessa silhouette) in entrambi i mondi è importante: a cambiare deve essere solo l'illuminazione e il contesto, mai l'identità del personaggio — rinforza l'idea che è la stessa persona sospesa tra due stati, non due personaggi diversi.

### Accessibilità cromatica (principio vincolante)

Dato che l'intero stile visivo si basa su luce/colore per distinguere Reale e Onirico, esiste un rischio concreto di svantaggiare giocatori con deficit della visione dei colori. **Principio vincolante**: la distinzione tra i due mondi non deve mai basarsi esclusivamente sul colore. Va sempre rinforzata anche da:
- **Posizione** (alto/basso — già strutturale al gioco)
- **Tipo di movimento** (lineare/regolare nel Reale vs sinusoidale/irregolare nell'Onirico, sezione 5)

Questo garantisce che un giocatore che non percepisce bene la differenza cromatica possa comunque leggere il gioco correttamente basandosi sugli altri due canali sensoriali, senza essere penalizzato per motivi indipendenti dalla skill.

### Animazione con sole primitive

Lo stile Silhouette + Luce permette di ottenere un risultato "curato" senza asset esterni (sprite, illustrazioni), lavorando solo con le primitive geometriche di raylib (rettangoli, cerchi, poligoni). L'elemento chiave è che la sensazione di qualità nasce dalla **matematica del movimento**, non dalla complessità delle forme. Tecniche da adottare fin dal prototipo:

- **Squash & Stretch**: interpolare la scala X/Y delle primitive nei momenti chiave (es. il personaggio si "schiaccia" in orizzontale all'atterraggio e si "stira" in verticale in fase di spinta/salto). Poche righe di interpolazione, ma è il singolo elemento che più dà impressione di peso e reattività.
- **Composizione di forme semplici**: il personaggio non deve essere una sola primitiva — comporre 3-4 forme sovrapposte (es. corpo + testa + un piccolo dettaglio secondario) dà già più carattere rispetto a una forma unica, restando comunque nel dominio delle primitive.
- **Movimento secondario (follow-through)**: un piccolo elemento (scia, dettaglio, secondo cerchio) che insegue la posizione principale con un leggero ritardo nell'interpolazione, per dare morbidezza e peso.
- **Easing invece di movimento lineare**: ogni transizione (flip, entrata ostacoli, cambi di colore) va animata con curve di easing (accelera/rallenta) invece che linearmente. Raylib offre funzioni di easing pronte all'uso; l'impatto percepito è alto a fronte di un costo di implementazione minimo.
- **Oscillazioni matematiche (sinusoidi)**: gli ostacoli del Mondo Onirico che pulsano (sezione 5) si ottengono variando raggio/scala nel tempo con `sin(tempo)` — nessun asset richiesto. La stessa tecnica può dare un leggerissimo "respiro" anche a elementi nominalmente statici, per evitare una sensazione di mondo immobile.
- **Colore e luce come animazione**: oltre alla forma, si può animare il colore/intensità — un lieve pulsare del glow attorno al personaggio, un contorno che si illumina un istante prima del flip, un fondo che cambia gradualmente tonalità al crescere della Profondità Onirica. Economico da implementare, alto impatto su quanto il gioco "sembra vivo".

**Combo di riferimento per il prototipo**: squash & stretch sul personaggio ad ogni atterraggio + easing su tutte le transizioni (specialmente il flip) + oscillazione sinusoidale sugli ostacoli onirici + sistema particellare (vedi sopra). Questa combinazione, pur restando interamente dentro le primitive raylib, punta a un risultato percepito come curato senza richiedere sprite o illustrazioni esterne.

---

## 13. Audio Design

### Perché l'audio non è un dettaglio secondario

In un arcade a riflessi l'audio contribuisce direttamente alla reattività percepita, non solo all'atmosfera. Per Wake Shift ha anche un compito tematico preciso: rinforzare la dualità Reale/Onirico esattamente come fanno grafica e ostacoli (coerente col pilastro "il tema non è decorazione").

### Musica: due tracce sincronizzate, non due tracce alternate

Un cambio musicale netto ad ogni flip rischierebbe di risultare fastidioso, specialmente nei tier alti con raffiche di switch ravvicinati. La soluzione adottata:

- Le due tracce (Reale e Onirico) condividono **lo stesso BPM e la stessa struttura ritmica** — sono trattabili quasi come due "remix" della stessa base, non due canzoni distinte
- Al flip, invece di uno stacco netto, avviene un **crossfade rapido** (100–200ms, in linea con la durata della micro-transizione visiva già definita in sezione 4) tra le due tracce, che restano sempre sincronizzate sullo stesso beat in sottofondo
- Risultato percepito: "lo stesso mondo sonoro visto da due prospettive", coerente col fatto che il personaggio resta lo stesso in entrambi i mondi (stessa silhouette, sezione 12)

**Caratterizzazione Mondo Reale**: strumentazione secca e percussiva — batteria elettronica pulita, bassi netti, poco riverbero. Coerente con "concreto/prevedibile".

**Caratterizzazione Mondo Onirico**: stessi elementi ritmici della traccia Reale ma filtrati — riverbero ampio, synth pad che sfumano, eventuali note leggermente pitch-bent per rinforzare la sensazione di instabilità. Coerente con "evanescente/irregolare".

### SFX per il player

| Evento | Funzione |
|---|---|
| **Flip** | Suono di pitch-shift (sale verso l'Onirico, scende verso il Reale) — è il suono più frequente del gioco, va curato con priorità massima |
| **Collisione / Risveglio** | Suono netto ma non scoraggiante: il giocatore lo sentirà molto spesso nei primi minuti, deve invitare a riprovare subito |
| **Streak / Lucidità** | Un breve "ding"/arpeggio che sale di tono ad ogni switch corretto consecutivo — rinforza sonoramente il senso di flow, in parallelo alla crescita visiva delle particelle (sezione 12) |
| **Respiro/movimento del personaggio** | Leggero whoosh/respiro continuo durante la corsa, con timbro diverso tra i due mondi (più fisico nel Reale, più eterico nell'Onirico) |

### Fonti asset audio per il prototipo

- **Freesound.org** e **OpenGameArt.org** per SFX royalty-free (verificare sempre la licenza prima dell'uso, specialmente in ottica di pubblicazione commerciale)
- In alternativa, generazione procedurale di SFX/pattern semplici via codice (raylib supporta la generazione di onde sonore base) — coerente con l'approccio "il più possibile via codice" già adottato per la grafica in sezione 12

---

## 14. Stack Tecnico & Note di Architettura

**Linguaggio**: Odin
**Libreria grafica/input/audio**: raylib
**Piattaforma di build**: Desktop nativo (Windows/Linux/Mac)

Note architetturali di massima da tenere presenti nello sviluppo (da affinare a inizio prototipo):

- **Rappresentazione dei pattern**: strutture dati a "eventi nel tempo" (timestamp relativo + tipo ostacolo + corsia), non posizioni assolute in pixel (vedi sezione 6)
- **Sistema a stati per il personaggio**: almeno gli stati Corsia-Reale, Corsia-Onirico, In-Transizione (con relativa invulnerabilità temporanea)
- **Generatore procedurale**: selezione pattern da pool con vincolo di compatibilità sui punti di aggancio inizio/fine, pesata per tier di difficoltà sbloccato
- **Sistema particellare**: da progettare come modulo riutilizzabile parametrizzato (colore, direzione, dissolvenza, densità) così da poter servire sia per Reale che Onirico che per il momento del flip, cambiando solo i parametri (vedi sezione 12)
- **Separazione dati/codice**: i pattern (specialmente una volta superato l'MVP) dovrebbero poter essere definiti come dati esterni (es. file di configurazione) piuttosto che hardcoded, per velocizzare l'iterazione di level design

### Struttura del progetto a cartelle

Per garantire che il progetto resti scalabile man mano che cresce (nuovi tier, nuovi ostacoli, più asset audio/particellari), il codice sorgente va organizzato in cartelle per responsabilità fin dall'inizio, invece di partire con tutto in un unico file. Struttura indicativa di riferimento (da adattare in fase di setup pratico del progetto):

```
wake-shift/
├── src/
│   ├── main.odin              # entry point, game loop principale
│   ├── player/                 # stato del personaggio, flip, collisioni
│   ├── world/                  # gestione Corsia Reale/Onirico, scroll, timing
│   ├── obstacles/               # definizione e comportamento dei singoli ostacoli
│   ├── patterns/                 # struttura dati pattern, generatore procedurale, pool
│   ├── particles/                # sistema particellare parametrizzato (sezione 12)
│   ├── audio/                    # gestione musica (crossfade), SFX (sezione 13)
│   ├── ui/                       # HUD, punteggio, Referto Onirico, menu
│   └── core/                     # utility condivise (easing, math, timer)
├── assets/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   └── (eventuali asset grafici futuri, se si esce dalle sole primitive)
└── data/
    └── patterns/                 # definizioni pattern esterne (sezione 7)
```

Questa separazione rispecchia direttamente le sezioni di questo documento (world/obstacles/patterns → sezioni 5-7, particles → sezione 12, audio → sezione 13), così da mantenere corrispondenza diretta tra design doc e codice, utile anche per orientare lo sviluppo assistito da AI in fase di implementazione.

*(Questa sezione verrà espansa e resa più precisa a inizio sviluppo pratico, nell'altra chat dedicata all'implementazione)*

---

## 15. Glossario

Termini di progetto da usare in modo coerente in tutta la documentazione e nel codice, per evitare ambiguità in fase di sviluppo assistito da AI:

| Termine | Significato |
|---|---|
| **Flip** | L'azione di invertire la gravità premendo la barra spaziatrice |
| **Mondo Reale** | Corsia bassa / pavimento |
| **Mondo Onirico** | Corsia alta / soffitto |
| **Switch** | Sinonimo di Flip, usato quando si parla del cambio di corsia nel level design |
| **Corsia** | Una delle due fasce (Reale o Onirico) in cui possono trovarsi personaggio e ostacoli |
| **Pattern** | Segmento di livello pre-disegnato (3-5s) usato dal generatore procedurale |
| **Tier** | Livello di difficoltà (Facile / Medio / Difficile / Estremo) |
| **Raffica** | Sequenza di switch ravvicinati richiesti in rapida successione |
| **Profondità Onirica** | Punteggio principale della run |
| **Lucidità** | Streak di flip corretti consecutivi |
| **Risveglio** | Il game over |
| **Referto Onirico** | Il riepilogo statistiche a fine run |

---

## 16. Scope del Primo Prototipo (MVP)

Per validare il gioco nel modo più rapido possibile, il prototipo minimo dovrebbe includere:

- [ ] Movimento automatico + flip gravità (singolo input, barra spaziatrice)
- [ ] Spazio di gioco secondo le proporzioni e velocità base definite in sezione 6
- [ ] 1 set ridotto di pattern per mondo (5-6 a testa, solo tier facile)
- [ ] Generazione procedurale a chunk con aggancio punti inizio/fine
- [ ] Almeno 2 tipi di ostacolo per mondo (es. Blocco + Voragine per il Reale, Forma pulsante + Buco onirico per l'Onirico)
- [ ] Collisione + Risveglio
- [ ] Punteggio base (Profondità Onirica) senza ancora Lucidità
- [ ] Personaggio e ostacoli in stile silhouette + luce, distinti tra i due mondi (sezione 12)
- [ ] Animazioni base con primitive: squash & stretch sul personaggio, easing sul flip, oscillazione sinusoidale sugli ostacoli onirici (sezione 12)
- [ ] Sistema particellare base: almeno le particelle da contatto/movimento e l'effetto sul flip
- [ ] Audio base: le due tracce musicali sincronizzate con crossfade sul flip, SFX di Flip e Collisione/Risveglio come priorità (sezione 13)
- [ ] Micro-transizione visiva/sonora sul flip + frame di grazia
- [ ] Struttura del progetto organizzata a cartelle fin dall'inizio (sezione 14), non un unico file monolitico
- [ ] Main Menu minimo (Inizia Run, Esci) e overlay di Pausa (ESC) funzionante (sezione 9)
- [ ] Salvataggio locale del record personale (sezione 10)

**Fuori scope per l'MVP** (da aggiungere dopo validazione del "feel"):
- Tier medio/difficile/estremo
- Ostacoli rimanenti (Piattaforma sospesa, Pistone, Specchio fluttuante, Entità pattugliante)
- Sistema Lucidità e relativi effetti particellari progressivi
- Referto Onirico condivisibile
- Skin/estetiche sbloccabili
- Leaderboard online

---

## 17. Roadmap Post-MVP

Ordine suggerito per le fasi successive alla validazione del prototipo minimo:

1. **Validazione del feel** — testare il prototipo MVP, confermare/aggiustare i numeri di sezione 6 (finestre di reazione, velocità). Metodo suggerito per un progetto solista: prima sessioni prolungate giocate/cronometrate in prima persona per calibrare le sensazioni, poi condivisione di una build minima con un piccolo gruppo esterno (3-5 persone, es. amici) per un primo riscontro "a occhio fresco" prima di investire tempo nel polish
2. **Completamento pool ostacoli** — aggiungere gli ostacoli rimanenti (sezione 5) ed espandere il pool di pattern
3. **Tier di difficoltà completi** — introdurre Medio, Difficile, Estremo con relativa curva di sblocco
4. **Sistema Lucidità** — streak, soglie, effetti particellari progressivi (sezione 12)
5. **Referto Onirico condivisibile** — output screenshottabile/esportabile a fine run
6. **Polish audio/visivo** — musica generativa legata al ritmo (vedi domande aperte), affinamento palette e bloom, screen shake calibrato
7. **Distribuzione** — packaging per itch.io/Steam, eventuale sistema di leaderboard online

---

## 18. Domande aperte / da decidere in seguito

- Curva esatta di aumento velocità nel tempo (lineare, a scalini, altro?)
- Durata precisa del frame di grazia sul flip
- Se e come introdurre suoni/musica generativa legata al ritmo dei pattern onirici
- Meccanismo di distribuzione punteggio: lineare o con moltiplicatori legati alla Lucidità
- Monetizzazione (se prevista): solo estetica, nessuna pubblicità invasiva, coerente coi pilastri di design
- Eventuali varianti di modalità (es. modalità a tempo, modalità puzzle a pattern fissi) — da valutare solo dopo la validazione del core loop infinito
- Palette esatta definitiva (quella in sezione 12 è indicativa, da testare visivamente in prototipo)
- Verifica finale disponibilità nome "Wake Shift" su Steam/itch.io prima dell'annuncio pubblico

---

*Documento completo — Versione 1.0. Include: concept, loop di gioco, i due mondi, il flip, anatomia degli ostacoli, spazio di gioco e timing (con target di performance), level design procedurale, metriche e punteggio, flusso schermate e UI, persistenza dati (locale e note anti-cheat per leaderboard futura), nome e identità, identità visiva (con principio di accessibilità cromatica e tecniche di animazione con primitive), audio design, stack tecnico con struttura a cartelle scalabile, glossario, scope MVP, roadmap post-MVP con metodo di playtesting, e domande aperte residue. Da qui in poi lo sviluppo pratico (codice Odin/raylib) proseguirà in una chat dedicata, step by step, usando questo documento come riferimento vincolante.*
