# Eliminate Teris 1

[简体中文](README.md) | English

A serious attempt to bring a match puzzle game onto the MacBook Touch Bar.

`Eliminate Teris 1` is a lightweight macOS puzzle game designed around the Touch Bar. The battlefield is not the center of your screen, but the narrow strip above your keyboard that people often notice less and use even less. On a one-dimensional board of 16 slots, you swap adjacent tiles, create matches of three or more, chase higher scores, and compress every action into a tighter and more direct rhythm in score attack and speed run modes.

The rules are easy to understand and quick to pick up. But once you actually start playing, you may realize that this small strip of Touch Bar still has enough room for judgment, tempo, tactile feedback, and that irresistible “one more round” feeling.

## Highlights

### 1. The Touch Bar is the main stage
- The core gameplay happens directly on the Touch Bar instead of using it as a secondary shortcut area.
- All 16 interactive cells reflect the live board state, while swapping, clearing, refilling, animation, and sound all revolve around this strip.
- For a MacBook with a Touch Bar, this is not “a game that happens to support Touch Bar.” It is a game that treats the Touch Bar as the game itself.

### 2. One-dimensional matching that stays interesting
- The board is a horizontal line with `16` columns.
- You can only swap adjacent tiles.
- Matching `3` or more tiles of the same kind clears them.
- Every cleared tile gives `10` points.
- After a clear, new tiles refill from the left side, creating a new rhythm and new opportunities.

Compared with traditional two-dimensional match games, this one-dimensional structure makes decision-making more focused. There is less visual noise and more instant judgment about whether the next move can extend into a better chain.

### 3. Three modes for practice, score chasing, and speed
- **Free Mode**: no time limit and no target score; ideal for learning the rules and getting comfortable with the controls.
- **Score Attack**: score as high as possible within a limited time; currently supports `1 / 2 / 3` minute presets.
- **Speed Run**: reach a target score as quickly as possible; currently supports `300 / 600 / 900` point targets.

### 4. Local challenge records
- Records are stored locally by mode and by sub-rule.
- For example, “Score Attack - 1 minute” and “Score Attack - 3 minutes” are ranked separately, and so are “Speed Run - 300” and “Speed Run - 900”.
- Each record bucket keeps up to `9` entries so you can keep pushing your best results.

### 5. Audio feedback with a clear rhythm
- Different modes use different procedural BGM tracks.
- Swapping, clearing, and refilling each have their own sound effects.
- Audio is synthesized at runtime, so the project does not rely on external audio assets.

### 6. Multi-language support
- The game currently supports `Simplified Chinese`, `English`, `Japanese`, `Korean`, and `Russian`.
- The goal is not only localization, but also making this small and unusual game easier to approach for more players.

## How to Play

### Goal
Swap adjacent tiles so that at least 3 identical tiles line up, then clear them for points.

### Controls
- **Touch Bar tap**: select one tile first, then tap an adjacent tile to swap.
- **Touch Bar drag**: drag from one tile to a neighboring tile to swap directly.
- **Multi-touch**: multiple fingers are supported, which makes fast and continuous interactions feel much better.

### Scoring
- Each cleared tile is worth `10` points.
- Consecutive clears continue to add to your score.
- Score Attack ranks by final score, while Speed Run ranks by the time required to reach the target.

## Modes

### Free Mode
Best for your first few rounds. There is no time pressure and no score target. It lets you learn the feel of the one-dimensional board, the Touch Bar interaction, and the general flow of clearing tiles.

### Score Attack
This is the most straightforward mode for chasing high scores. You need to create as many efficient swaps as possible within limited time. It rewards consistency, quick decisions, and control under pressure.

### Speed Run
In this mode, the goal is simple: hit the target score as fast as possible. Whether the target is `300`, `600`, or `900`, success depends not only on making correct moves, but also on minimizing hesitation.

## Interface Overview

Besides the Touch Bar board itself, the desktop window provides several supporting panels:

- **Game Settings**: switch mode, sub-rules, language, and start or restart a run.
- **Time & Score**: shows elapsed time, remaining time when applicable, and score updates.
- **Challenge Records**: shows local best results for the current mode and current rule bucket.
- **Mode Briefing**: explains the rules for the currently selected mode.

In other words, this is not just “a Touch Bar strip doing something.” It is a complete play experience made of a Touch Bar battlefield and a desktop information panel.

## Requirements

### For Players
- macOS `12.0` or later
- A MacBook Pro with **Touch Bar** for the full intended experience

### For Developers
- Xcode and a working Swift development environment
- Command line tools such as `swift`, `codesign`, and `hdiutil`

> The app may still launch on a machine without a Touch Bar, but the core gameplay experience depends heavily on it.

## Quick Start

### 1. Run locally
The repository includes a launch script:

```bash
./run.sh
```

This script rebuilds before launch so you do not accidentally start an outdated binary. In short, it:

1. Resolves the Xcode Developer directory automatically if `DEVELOPER_DIR` is not set manually
2. Runs `swift build --disable-sandbox`
3. Resolves the output binary path automatically
4. Launches `Eliminate Teris 1`

### 2. Package for distribution
To generate a distributable `.app`, `.dmg`, or `.zip`, run:

```bash
./package.sh
```

The packaging script will:
- Build both `x86_64` and `arm64`
- Merge them into a universal binary with `lipo`
- Copy the SwiftPM resource bundle automatically
- Generate `Info.plist`
- Apply ad-hoc signing
- Prefer a `.dmg`, and fall back to `.zip` if DMG creation is unavailable

Artifacts are generated in:

```bash
dist/
```

If you only want one architecture, you can override the environment variable:

```bash
PACKAGE_ARCHS="arm64" ./package.sh
```

## Project Structure

```text
.
├── Sources/
│   ├── AppDelegate.swift
│   ├── GameViewController.swift
│   ├── GameTouchBarView.swift
│   ├── GameState.swift
│   ├── GameAudioSystem.swift
│   ├── ModeRecordStore.swift
│   └── Resources/
├── run.sh
├── package.sh
└── Package.swift
```

Key files at a glance:

- `Sources/GameTouchBarView.swift`: Touch Bar board rendering, interaction, and animation
- `Sources/GameState.swift`: board state, match detection, clearing, and left-side refill logic
- `Sources/GameViewController.swift`: desktop UI, mode switching, and status presentation
- `Sources/ModeRecordStore.swift`: local challenge record storage and ranking
- `Sources/GameAudioSystem.swift`: procedural BGM and sound effects
- `Sources/Localization.swift`: language switching and resource bundle lookup

## Why This Project Is Interesting

Most Touch Bar software treats the Touch Bar as a shortcut row or a secondary display. `Eliminate Teris 1` asks a different question:

**What happens if the Touch Bar is not a side feature, but the main stage?**

This project suggests that:
- a real game can live there,
- feedback and rhythm can still feel satisfying,
- even a tiny interface area can hold strategy and challenge,
- and a piece of hardware that is often ignored can become fun again.

## Notes

- The current official Touch Bar path favors the public `window.touchBar` route for better development and packaged-build stability.
- Available Touch Bar width and system-reserved space may differ slightly across macOS versions and hardware.
- At this stage, the project is best understood as a distinctive Touch Bar-focused game and experiment rather than a general-purpose casual game for every Mac.

## Who This Is For

You may especially enjoy this project if:

- you still use a MacBook with Touch Bar and want to see it act more like a device and less like an accessory,
- you like compact games with simple rules and clear pacing,
- you are interested in macOS native development, Touch Bar interaction, or unconventional UI surfaces,
- or you want to study a lightweight native project structure built with public APIs, SwiftPM, and manual packaging.

## Closing

`Eliminate Teris 1` is not trying to be a huge content-heavy game. It is a small work with a very clear personality: the satisfaction of match-clearing, the uniqueness of the Touch Bar, and a bit of pixel-arcade flavor compressed into a narrow but surprisingly playful space.

If you like projects that are modest in scale but serious in intent, feel free to run it, tweak it, and keep building on it.
