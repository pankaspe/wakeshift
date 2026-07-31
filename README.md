# Wake Shift

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

## Development Progress

- [x] **Section 0** — Project setup, Odin + raylib window, 60 FPS game loop
- [x] **Section 1** — Player struct, drawn as placeholder rectangle, anchored to floor
- [x] **Section 2** — Flip mechanic (instant lane switch via Space)
- [x] **Section 3** — Player state machine (`Real` / `Dream` / `Transitioning`)
- [x] **Section 4** — Flip animation (ease-out interpolation) + invulnerability window
- [x] **Section 5** — Scrolling world (floor/ceiling tick marks, constant scroll speed)
- [ ] **Section 6** — First obstacle (hardcoded, no collision yet)
- [ ] **Section 7** — AABB collision + game over ("Awakening")
- [ ] **Section 8** — Obstacles as time-based events (refactor)
- [ ] **Section 9** — Patterns + pool
- [ ] **Section 10** — Procedural pattern generator
- [ ] **Section 11** — Multiple obstacle types + Dream World
- [ ] **Section 12** — Score (Dream Depth)
- [ ] **Section 13** — UI: Menu, HUD, Pause
- [ ] **Section 14** — End-run report + local high score persistence
- [ ] **Section 15** — Squash & stretch, base particles
- [ ] **Section 16** — Audio (SFX + music crossfade)
- [ ] **Section 17** — Lucidity streak system
- [ ] **Section 18** — Difficulty tiers
- [ ] **Section 19** — Balancing, polish → Alpha

**Stack**: Odin (`dev-2026-07`) + `vendor:raylib/v55` (raylib 5.5 bindings — v6 bindings currently broken on this system's install, using v55 as workaround)
