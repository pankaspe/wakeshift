# WAKE SHIFT — Roadmap di Sviluppo
### Fase 2: Refactor architetturale + Boost grafico (stile Ori) — Odin + raylib

---

## Come funziona questa roadmap

- Sostituisce la roadmap precedente (Sezioni 0-N, "da zero all'Alpha"), ormai completata: l'Alpha è finita, con Lucidity, tier di difficoltà e persistenza già implementati.
- Copre due filoni paralleli decisi insieme: **rifattorizzare il codice in package separati** (il progetto è cresciuto oltre un singolo `package main`) e **alzare il livello grafico** verso uno stile atmosferico ispirato a *Ori and the Blind Forest*, partendo dalla base "Silhouette + Luce" già definita nel Design Doc (sez. 12).
- Ogni fase ha un obiettivo, cosa introduce, eventuali rischi/note tecniche, e un test di verifica prima di passare alla successiva.
- Riferimento vincolante per *cosa* costruire resta il Design Doc v1.0 (sez. 12 Identità Visiva, sez. 14 Stack Tecnico). Questa roadmap è il *come* e *in che ordine*, aggiornato alla luce delle nuove decisioni.

---

## Fase 0 — Housekeeping

**Obiettivo**: ripartire da uno stato pulito prima di toccare architettura o grafica.

**Cosa include**:
- Questo file sostituisce la vecchia roadmap.
- Il Design Doc (`WakeShift_Design_Doc.md`) resta il riferimento di design; se e quando serve aggiornarlo (es. la direzione "Silhouette + Luce senza sprite esterni" della sez. 12 evolve per includere fondali dipinti), lo si tratta come modifica a parte.

**Test di verifica**: repo pulita, questa roadmap committata.

---

## Fase 1 — Refactor in package Odin

**Obiettivo**: passare da 17 file in un unico `package main` a package separati per responsabilità, secondo la struttura abbozzata nel Design Doc (sez. 14): `player`, `world`, `obstacle`, `pattern`, `ui`, `core`...

**Cosa include**:
- Mappare le dipendenze reali tra i file attuali (chi chiama chi) **prima** di spostare qualsiasi file.
- Estrarre in un package `core` i tipi/costanti condivisi trasversalmente (es. `Lane`, `GameState`, costanti schermo, funzioni di easing) — in Odin **non sono ammessi import ciclici tra package**, a differenza di ora dove tutti i file nello stesso package si vedono liberamente tra loro. Senza questo passaggio, spostare player/obstacle/pattern nei rispettivi package genera cicli quasi subito.
- Ordine di estrazione suggerito, dal meno dipendente al più dipendente: `core` → `display` → `world` → `player` → `obstacle` → `pattern` → `difficulty`/`score`/`lucidity` → `ui`/`menu` → `persistence` → `main` (resta root, orchestratore).
- Spostare un package alla volta, verificando `odin build` dopo ciascuno spostamento — mai tutto in un colpo solo.

**Rischi/note**: questo è il passo con più rischio di rottura silenziosa (stato condiviso che smette di essere condiviso). Va fatto con il gioco funzionante ad ogni step intermedio, non solo alla fine.

**Test di verifica**: `odin build` pulito ad ogni package spostato; il gioco gira identico a prima (nessuna regressione di gameplay) a refactor completato.

---

## Fase 2 — Bloom/glow shader

**Obiettivo**: primo assaggio della direzione "Ori" senza bisogno di asset grafici.

**Cosa include**:
- Un secondo render pass con shader GLSL custom (`rl.LoadShader`) applicato sulla texture del canvas virtuale già gestito in `display.odin`.
- I rim-light già presenti su player e ostacoli (Design Doc sez. 12, "outer glow economico") diventano bagliori reali invece di bordi netti.

**Rischi/note**: rischio basso, reversibile, non tocca la logica di gioco — buon primo esperimento per validare la direzione prima di investire in asset.

**Test di verifica**: confronto visivo prima/dopo su una run reale; il glow non deve compromettere la leggibilità a velocità elevate (pilastro "leggibile in 2 secondi", Design Doc sez. 6).

---

## Fase 3 — Sistema particellare

**Obiettivo**: implementare quanto già previsto ma mai realizzato nel Design Doc (sez. 12).

**Cosa include**:
- Modulo riutilizzabile e parametrizzato (colore, direzione, dissolvenza, densità).
- Usi previsti: polvere/scintille nel Mondo Reale, particelle fluttuanti nel Mondo Onirico, esplosione colorata al momento del flip, densità/vivacità crescente legata allo streak di Lucidity.

**Rischi/note**: con lo shader di bloom della Fase 2 già attivo, le particelle luminose sono probabilmente il singolo elemento a miglior rapporto impatto percepito/costo di implementazione di tutta la roadmap.

**Test di verifica**: le particelle rispettano il principio pieno/vuoto e lineare/fluttuante già stabilito per Reale/Onirico (Design Doc sez. 5, 12); nessun calo di framerate percepibile a densità massima.

---

## Fase 4 — Sfondi a parallax

**Obiettivo**: introdurre profondità atmosferica via texture — qui entrano i primi asset PNG del progetto.

**Cosa include**:
- Pipeline di caricamento texture (`rl.LoadTexture`) e scroll multi-layer (2-4 livelli a velocità diverse).
- Fase di partenza con asset gratuiti (itch.io, OpenGameArt — pacchetti "parallax background"/"atmospheric forest") per validare la pipeline e il mood prima di investire in arte custom o commissionata.

**Rischi/note**: vincolo del Design Doc da rispettare — la distinzione Reale/Onirico non deve mai dipendere solo dal colore (oggi già rinforzata da posizione + tipo di movimento, sez. 12 "Accessibilità cromatica"). I nuovi fondali devono aggiungersi a quel linguaggio visivo, non sostituirlo.

**Test di verifica**: il gioco resta leggibile e accessibile con i nuovi fondali attivi; nessuna texture compete visivamente con player/ostacoli in primo piano.

---

## Fase 5 — Polish visivo

**Obiettivo**: rifinire coerenza ed eleganza dopo le fasi strutturali.

**Cosa include**:
- Palette definitiva per i due mondi (Design Doc sez. 12 ha una palette indicativa da affinare).
- Eventuale evoluzione del player da rettangolo singolo a composizione di 3-4 forme per dargli più carattere (già suggerito in Design Doc sez. 12, mai fatto).

**Test di verifica**: revisione visiva complessiva, confronto con la direzione "Ori" di riferimento.

---

## Fase 6 — Post-MVP non grafico (ancora aperto dal Design Doc originale)

Elementi già previsti in Design Doc sez. 17 e non ancora affrontati, indipendenti dal lavoro grafico sopra:
- Completamento pool ostacoli e pattern.
- Referto Onirico condivisibile (schermata fine run esportabile).
- Audio: musica e SFX — nessun file audio presente nel progetto ad oggi.
- Distribuzione (itch.io/Steam, eventuale leaderboard online).

---

## Ordine consigliato

**Fase 1 prima di tutto**: più codice/asset si accumulano sopra una struttura piatta (shader, particelle, texture), più il refactor architetturale dopo diventa costoso. Le Fasi 2-5 sono in gran parte indipendenti tra loro e possono essere riordinate in base a cosa dà più soddisfazione vedere prima; la Fase 6 non ha dipendenze dalle altre e può procedere in parallelo quando serve una pausa dal lavoro grafico/architetturale.
