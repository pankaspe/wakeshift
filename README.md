# Wake Shift

A minimalist 2D endless runner built with **Odin** and **raylib**, featuring a dual-world flip mechanic between Reality and the Dream.

![Version](https://img.shields.io/badge/Version-v0.1.0--alpha-blue)
![Build](https://img.shields.io/badge/Status-Alpha%20Milestone-green)
![Language](https://img.shields.io/badge/Language-Odin-blue)
![Library](https://img.shields.io/badge/Library-Raylib%20v5.5-green)

---

## 🎮 Game Overview

**Wake Shift** tests timing and risk management across two parallel planes:
- **Reality (Floor)**: Safe baseline scoring (10 pts/s) with static, physical obstacles (*Block*, *Chasm*).
- **Dream (Ceiling)**: High-risk, high-reward scoring (25 pts/s) with dynamic void obstacles (*PulsingShape*, *DreamHole*).

### Key Features
- **Dual-Lane Flipping**: Switch gravity and lane position instantly (`SPACE`).
- **Lucidity Multiplier**: Risk/reward mechanics rewarding late lane switches (near-misses) with up to +100% score bonus.
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
git clone [https://github.com/your-username/wake-shift.git](https://github.com/your-username/wake-shift.git)
cd wake-shift

# Compile and run immediately
odin run .
