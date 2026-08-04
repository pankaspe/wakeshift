# Wake Shift

A minimalist 2D endless runner built with **Odin** and **raylib**, featuring a dual-world flip mechanic between Reality and the Dream.

![Project Status](https://img.shields.io/badge/Status-Alpha%20in%20Progress-orange)
![Language](https://img.shields.io/badge/Language-Odin-blue)
![Library](https://img.shields.io/badge/Library-Raylib%20v5.5-green)

---

## 🎮 Game Overview

**Wake Shift** tests timing and risk management across two parallel planes:
- **Reality (Floor)**: Safe baseline scoring (10 pts/s) with static, physical obstacles (*Block*, *Chasm*).
- **Dream (Ceiling)**: High-risk, high-reward scoring (25 pts/s) with dynamic void obstacles (*PulsingShape*, *DreamHole*).

### Key Features
- **Dual-Lane Flipping**: Switch gravity and lane position instantly (`SPACE`).
- **Lucidity Multiplier**: Risk/reward mechanics that reward late lane switches (near-misses) up to +100% score bonus.
- **Time-Based Procedural Generation**: Obstacles are calculated as time events, guaranteeing smooth speed scaling without positional desync.
- **Adaptive Difficulty Tiers**: Easing scroll speed updates and expanding pattern pools as runs progress.
- **Local Persistence**: Save/load system for tracking high scores across runs.

---

## 🛠️ Stack & Prerequisites

- **Language**: [Odin](https://odin-lang.org/) (`dev-2026-07` or compatible)
- **Framework**: `vendor:raylib/v55` (Raylib 5.5 bindings)

> **Note on Raylib Versioning**: Using `vendor:raylib/v55` as `vendor:raylib/v6` bindings may require specific linker updates on certain Odin toolchains.

---

## 🚀 Getting Started

### Prerequisites
Ensure you have the [Odin compiler](https://odin-lang.org/docs/install/) installed and available in your system path.

### Build and Run

```bash
# Clone the repository
git clone https://github.com/your-username/wake-shift.git
cd wake-shift

# Compile and run immediately
odin run .
```

---

## 🕹️ Controls

| Key | Action |
| :--- | :--- |
| `UP` / `DOWN` | Navigate menu options |
| `ENTER` | Confirm menu selection / Retry after Game Over |
| `SPACE` | Flip between Real (floor) and Dream (ceiling) lanes |
| `ESC` | Pause / Resume run |

---

## 📁 Project Structure

```text
├── main.odin             # Entry point, core game loop (Update & Draw execution)
├── game.odin             # Game state machine (MainMenu, Playing, Paused, GameOver), collisions
├── player.odin           # Player state, flip logic, invulnerability timers
├── player_render.odin    # Player rendering, silhouette shaders/rim light, squash & stretch
├── world.odin            # Scroll state, world elapsed time, spatial speed logic
├── terrain.odin          # Procedural floor/ceiling profile rendering
├── obstacle.odin         # Time-based obstacle data structures & lifecycle
├── obstacle_render.odin  # Custom silhouette rendering for Block, Chasm, PulsingShape, DreamHole
├── pattern.odin          # Pattern pools & procedural lane-graph generator
├── lucidity.odin         # Near-miss detection & score multiplier calculations
├── difficulty.odin       # Difficulty tiers, pattern pool expansion, speed easing
├── score.odin            # Lane-dependent scoring calculations
├── menu.odin             # Reusable UI menu widget
├── ui.odin               # HUD, pause overlays, end-run screens
└── persistence.odin      # Text-based local high score save/load logic
```

---

## 🗺️ Roadmap & Current Status

Current state: **Alpha in Progress** (Section 18 complete).

- [x] **Core Game Loop & Engine**: 60 FPS update/draw decoupling, collision system.
- [x] **Procedural Generation**: Graph-validated pattern pools, time-based event scrolling.
- [x] **Visual Identity Baseline**: Custom vector silhouettes, squash & stretch animations, irregular terrain profiles.
- [x] **Scoring & Risk Engine**: Dream Depth scoring, Lucidity streak multi-system.
- [x] **Progression System**: Difficulty tiers (Awake → Drifting → Deep Dream) with smooth scroll-speed easing.
- [ ] **Alpha Polish (Section 19)**: Balancing obstacle frequency, score scaling, and hitboxes.
- [ ] **Assets & VFX Pass (Section 20)**: Real vector illustrations, particle systems (impact/flip), lighting & audio crossfading.

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for details.
