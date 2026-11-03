# Drive (Audio Game)

Preservation and modern native macOS port of the classic 2002 accessible audio game **Drive**, alongside the original Windows release.

---

## Overview

**Drive** is a pioneering self-voicing audio game developed in 2001–2002 by **Soundsupport.net** (Richard van Tol, Hugo Verweij, and Sander Huiberts).

In Drive, players test-drive an experimental high-speed vehicle called the "Shuttle" inside the Cycom TestLab. The game is played entirely by ear without needing a screen reader:
- Co-pilots Leo and Eve provide real-time audio guidance, navigation cues, and status reports.
- Players listen for track cues, steer across lanes, pick up auditory boosters, and manage a 5-gear transmission.
- Full spoken tutorial, menu navigation, and post-run spoken score readouts.

This repository preserves the complete original game assets while providing a brand-new, standalone, native macOS port written in modern Swift.

---

## Platforms

### macOS (Native Port)
- **Engine**: Modern Swift using AppKit and AVAudioEngine / CoreAudio.
- **Compatibility**: Runs natively on both Apple Silicon (M1/M2/M3/M4) and Intel Macs on macOS 12 (Monterey) or later.
- **Zero External Dependencies**: Standalone application bundle; does not require Adobe/Macromedia Director, Wine, or third-party audio daemons.
- **Accurate Audio Synthesis**: Faithfully reproduces the original Bonneville / CPS (CyberStage Sound Engine) modular synthesis graph in real time, including the 5-harmonic wavetable procedural shuttle motor and dynamic 5-gear sound generation.
- **Native Keyboard Navigation**: Clean key-event routing (Arrow keys, Space, Enter, Escape, high score text entry) with no macOS alert beeps.

### Windows (Original 2002 Release)
- The root directory includes the original `Drive.exe` executable compatible with Windows 98, 2000, ME, and XP (or modern Windows via Wine, PCem, or virtual machines).

---

## How to Build and Run on macOS

### Prerequisites
- macOS 12.0 or newer
- Xcode Command Line Tools (`xcode-select --install`)

### Build Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/vick08/Drive-Audio-Game.git
   cd Drive-Audio-Game
   ```

2. Run the build script:
   ```bash
   ./macos/build_app.sh
   ```

3. Launch the game:
   ```bash
   open Drive.app
   ```

---

## Game Controls

- **Up Arrow**: Accelerate / Shift up / Menu navigation
- **Down Arrow**: Brake / Shift down / Menu navigation
- **Left / Right Arrows**: Steer / Switch track lanes
- **Spacebar**: Activate picked-up booster
- **Enter / Return**: Select menu item / Confirm
- **Escape**: Pause / Return to menu / Quit
- **A–Z & Backspace**: High-score name entry

---

## Repository Structure

```
├── Drive.exe               # Original 2002 Windows game executable
├── macos/
│   ├── Sources/            # Swift engine (AppShell, DirectorRuntime, CPSAudioEngine, VerifySuite)
│   ├── Resources/          # CPS audio graph definitions and patches
│   └── build_app.sh        # Standalone build script compiling Drive.app
├── movies/                 # Original Macromedia Director movie files (.dxr)
├── Xtras/                  # Original audio samples (.hrs RIFF WAV), Director Xtras, and data
├── pics/                   # Original cover and splash artwork
├── IMPLEMENTATION_PLAN.txt # Detailed architectural documentation and reverse-engineering notes
├── readme.txt              # Original 2002 Windows release readme
├── copyright.txt           # Original Soundsupport.net demo copyright notice
└── LICENSE                 # MIT License for the macOS port code
```

---

## Credits and Licensing

- **Original Game, Sound & Music**:
  Created and copyrighted © 2001–2002 by **Soundsupport.net** (Richard van Tol, Hugo Verweij, and Sander Huiberts). Original files are included under the demonstration and evaluation terms specified in `copyright.txt`.
- **macOS Port & Swift Engine**:
  Developed by **Victor Tsaran** (2026), released under the [MIT License](LICENSE).
