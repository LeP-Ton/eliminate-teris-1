# README 增加英文支持

## 背景与目标
- 当前根目录 `README.md` 只有中文说明，虽然对中文用户足够友好，但在对外展示、分享仓库或给英文读者阅读时仍有门槛。
- 本次目标是为项目补充完整英文版 README，同时保留现有中文主文档不变，并让中英文文档之间可以快速切换。

## 约束与原则
- 保持中文 README 继续作为默认入口，不改动原有中文信息结构与主叙事。
- 英文支持采用“独立英文文档”而不是在同一个文件内强行双语混排，避免阅读过长、结构混乱。
- 中英文两份 README 都要在顶部提供清晰的语言切换入口。

## 阶段与 TODO
- [x] 检查现有中文 README 结构，确认需要翻译的章节范围。
- [x] 新增完整英文版 `README.en.md`。
- [x] 在 `README.md` 与 `README.en.md` 顶部加入中英文切换链接。
- [x] 更新 `AGENTS.md` 与 `.agentdocs/index.md`，记录 README 英文支持的新认知。
- [x] 执行基础文档自检，确认 diff 与文件状态正常。

## 关键风险
- 如果只在中文 README 顶部加一句 “English coming soon”，并不能真正满足英文支持需求，因此本次必须提供完整英文内容。
- 如果把两种语言塞进同一个 README，会显著拉长页面并降低可读性，所以选择双文档方案更稳妥。

## 当前进展
- 已新增 `README.en.md`，完整覆盖项目介绍、玩法、模式、运行、打包、结构与适用人群。
- 已在 `README.md` 顶部加入 `English` 入口，并在 `README.en.md` 顶部加入返回中文文档的入口。
- 已同步补充项目认知与文档索引，后续可直接按“中英文双 README”方案继续维护。

## 代码变更
- `README.md`
```diff
--- a/README.md
+++ b/README.md
@@ -1,4 +1,6 @@
 # Eliminate Teris 1
+
+简体中文 | [English](README.en.md)
 
 把消除游戏搬进 MacBook Touch Bar 的一次认真尝试。
```

- `README.en.md`
```diff
--- /dev/null
+++ b/README.en.md
@@ -0,0 +1,193 @@
+# Eliminate Teris 1
+
+[简体中文](README.md) | English
+
+A serious attempt to bring a match puzzle game onto the MacBook Touch Bar.
+
+`Eliminate Teris 1` is a lightweight macOS puzzle game designed around the Touch Bar. The battlefield is not the center of your screen, but the narrow strip above your keyboard that people often notice less and use even less. On a one-dimensional board of 16 slots, you swap adjacent tiles, create matches of three or more, chase higher scores, and compress every action into a tighter and more direct rhythm in score attack and speed run modes.
+
+The rules are easy to understand and quick to pick up. But once you actually start playing, you may realize that this small strip of Touch Bar still has enough room for judgment, tempo, tactile feedback, and that irresistible “one more round” feeling.
+
+## Highlights
+
+### 1. The Touch Bar is the main stage
+- The core gameplay happens directly on the Touch Bar instead of using it as a secondary shortcut area.
+- All 16 interactive cells reflect the live board state, while swapping, clearing, refilling, animation, and sound all revolve around this strip.
+- For a MacBook with a Touch Bar, this is not “a game that happens to support Touch Bar.” It is a game that treats the Touch Bar as the game itself.
+
+### 2. One-dimensional matching that stays interesting
+- The board is a horizontal line with `16` columns.
+- You can only swap adjacent tiles.
+- Matching `3` or more tiles of the same kind clears them.
+- Every cleared tile gives `10` points.
+- After a clear, new tiles refill from the left side, creating a new rhythm and new opportunities.
+
+Compared with traditional two-dimensional match games, this one-dimensional structure makes decision-making more focused. There is less visual noise and more instant judgment about whether the next move can extend into a better chain.
+
+### 3. Three modes for practice, score chasing, and speed
+- **Free Mode**: no time limit and no target score; ideal for learning the rules and getting comfortable with the controls.
+- **Score Attack**: score as high as possible within a limited time; currently supports `1 / 2 / 3` minute presets.
+- **Speed Run**: reach a target score as quickly as possible; currently supports `300 / 600 / 900` point targets.
+
+### 4. Local challenge records
+- Records are stored locally by mode and by sub-rule.
+- For example, “Score Attack - 1 minute” and “Score Attack - 3 minutes” are ranked separately, and so are “Speed Run - 300” and “Speed Run - 900”.
+- Each record bucket keeps up to `9` entries so you can keep pushing your best results.
+
+### 5. Audio feedback with a clear rhythm
+- Different modes use different procedural BGM tracks.
+- Swapping, clearing, and refilling each have their own sound effects.
+- Audio is synthesized at runtime, so the project does not rely on external audio assets.
+
+### 6. Multi-language support
+- The game currently supports `Simplified Chinese`, `English`, `Japanese`, `Korean`, and `Russian`.
+- The goal is not only localization, but also making this small and unusual game easier to approach for more players.
+
+## How to Play
+
+### Goal
+Swap adjacent tiles so that at least 3 identical tiles line up, then clear them for points.
+
+### Controls
+- **Touch Bar tap**: select one tile first, then tap an adjacent tile to swap.
+- **Touch Bar drag**: drag from one tile to a neighboring tile to swap directly.
+- **Multi-touch**: multiple fingers are supported, which makes fast and continuous interactions feel much better.
+
+### Scoring
+- Each cleared tile is worth `10` points.
+- Consecutive clears continue to add to your score.
+- Score Attack ranks by final score, while Speed Run ranks by the time required to reach the target.
+
+## Modes
+
+### Free Mode
+Best for your first few rounds. There is no time pressure and no score target. It lets you learn the feel of the one-dimensional board, the Touch Bar interaction, and the general flow of clearing tiles.
+
+### Score Attack
+This is the most straightforward mode for chasing high scores. You need to create as many efficient swaps as possible within limited time. It rewards consistency, quick decisions, and control under pressure.
+
+### Speed Run
+In this mode, the goal is simple: hit the target score as fast as possible. Whether the target is `300`, `600`, or `900`, success depends not only on making correct moves, but also on minimizing hesitation.
+
+## Interface Overview
+
+Besides the Touch Bar board itself, the desktop window provides several supporting panels:
+
+- **Game Settings**: switch mode, sub-rules, language, and start or restart a run.
+- **Time & Score**: shows elapsed time, remaining time when applicable, and score updates.
+- **Challenge Records**: shows local best results for the current mode and current rule bucket.
+- **Mode Briefing**: explains the rules for the currently selected mode.
+
+In other words, this is not just “a Touch Bar strip doing something.” It is a complete play experience made of a Touch Bar battlefield and a desktop information panel.
+
+## Requirements
+
+### For Players
+- macOS `12.0` or later
+- A MacBook Pro with **Touch Bar** for the full intended experience
+
+### For Developers
+- Xcode and a working Swift development environment
+- Command line tools such as `swift`, `codesign`, and `hdiutil`
+
+> The app may still launch on a machine without a Touch Bar, but the core gameplay experience depends heavily on it.
+
+## Quick Start
+
+### 1. Run locally
+The repository includes a launch script:
+
+```bash
+./run.sh
+```
+
+This script rebuilds before launch so you do not accidentally start an outdated binary. In short, it:
+
+1. Resolves the Xcode Developer directory automatically if `DEVELOPER_DIR` is not set manually
+2. Runs `swift build --disable-sandbox`
+3. Resolves the output binary path automatically
+4. Launches `Eliminate Teris 1`
+
+### 2. Package for distribution
+To generate a distributable `.app`, `.dmg`, or `.zip`, run:
+
+```bash
+./package.sh
+```
+
+The packaging script will:
+- Build both `x86_64` and `arm64`
+- Merge them into a universal binary with `lipo`
+- Copy the SwiftPM resource bundle automatically
+- Generate `Info.plist`
+- Apply ad-hoc signing
+- Prefer a `.dmg`, and fall back to `.zip` if DMG creation is unavailable
+
+Artifacts are generated in:
+
+```bash
+dist/
+```
+
+If you only want one architecture, you can override the environment variable:
+
+```bash
+PACKAGE_ARCHS="arm64" ./package.sh
+```
+
+## Project Structure
+
+```text
+.
+├── Sources/
+│   ├── AppDelegate.swift
+│   ├── GameViewController.swift
+│   ├── GameTouchBarView.swift
+│   ├── GameState.swift
+│   ├── GameAudioSystem.swift
+│   ├── ModeRecordStore.swift
+│   └── Resources/
+├── run.sh
+├── package.sh
+└── Package.swift
+```
+
+Key files at a glance:
+
+- `Sources/GameTouchBarView.swift`: Touch Bar board rendering, interaction, and animation
+- `Sources/GameState.swift`: board state, match detection, clearing, and left-side refill logic
+- `Sources/GameViewController.swift`: desktop UI, mode switching, and status presentation
+- `Sources/ModeRecordStore.swift`: local challenge record storage and ranking
+- `Sources/GameAudioSystem.swift`: procedural BGM and sound effects
+- `Sources/Localization.swift`: language switching and resource bundle lookup
+
+## Why This Project Is Interesting
+
+Most Touch Bar software treats the Touch Bar as a shortcut row or a secondary display. `Eliminate Teris 1` asks a different question:
+
+**What happens if the Touch Bar is not a side feature, but the main stage?**
+
+This project suggests that:
+- a real game can live there,
+- feedback and rhythm can still feel satisfying,
+- even a tiny interface area can hold strategy and challenge,
+- and a piece of hardware that is often ignored can become fun again.
+
+## Notes
+
+- The current official Touch Bar path favors the public `window.touchBar` route for better development and packaged-build stability.
+- Available Touch Bar width and system-reserved space may differ slightly across macOS versions and hardware.
+- At this stage, the project is best understood as a distinctive Touch Bar-focused game and experiment rather than a general-purpose casual game for every Mac.
+
+## Who This Is For
+
+You may especially enjoy this project if:
+
+- you still use a MacBook with Touch Bar and want to see it act more like a device and less like an accessory,
+- you like compact games with simple rules and clear pacing,
+- you are interested in macOS native development, Touch Bar interaction, or unconventional UI surfaces,
+- or you want to study a lightweight native project structure built with public APIs, SwiftPM, and manual packaging.
+
+## Closing
+
+`Eliminate Teris 1` is not trying to be a huge content-heavy game. It is a small work with a very clear personality: the satisfaction of match-clearing, the uniqueness of the Touch Bar, and a bit of pixel-arcade flavor compressed into a narrow but surprisingly playful space.
+
+If you like projects that are modest in scale but serious in intent, feel free to run it, tweak it, and keep building on it.
```

- `AGENTS.md`
```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -3,6 +3,7 @@
 - 游戏设置面板已新增“音量”控制项，使用与现有蓝色设置控件一致的主题风格，显示为横向滑杆加百分比读数。
 - 当前音量控制为“总音量”：会同时影响 BGM 与移动/消除/补位音效，不区分背景音乐与音效的独立通道。
 - 音量设置已接入 `GameAudioSystem` 持久化，使用 `UserDefaults` 记忆上次选择；重新启动应用后会自动恢复。
+- README 现已支持中英文双文档：根目录 `README.md` 保持中文主文档，新增 `README.en.md` 作为完整英文说明，并在两个文档顶部互相链接切换。
 
 ## 2026-06-01
 - 仓库已新增面向玩家与开发者的 `README.md`，系统介绍游戏定位、核心玩法、三种模式、Touch Bar 交互方式、本地挑战记录、多语言与程序化音频能力。
```

- `.agentdocs/index.md`
```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,5 +1,6 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260602231628-readme-english-support.md` - 为项目 README 增加英文支持：新增 `README.en.md`，并在中英文文档顶部补充语言切换入口。
 `workflow/20260602225626-settings-audio-volume-control.md` - 在游戏设置中新增总音量滑杆，统一控制 BGM 与音效，并通过 `UserDefaults` 持久化上次音量。
 `workflow/20260601210110-readme-project-introduction.md` - 新增面向玩家与开发者的 README，完整介绍游戏定位、玩法模式、运行打包方式、硬件要求与项目结构。
@@ -50,6 +51,7 @@
 
 ## 读取场景
+- 需要确认“README 是否已有英文版、英文文档放在哪里、如何在中英文之间切换”时，优先读取 `20260602231628` 文档。
 - 需要确认“游戏设置里的音量滑杆接在哪里、是否会记住上次设置、是否同时影响 BGM 与音效”时，优先读取 `20260602225626` 文档。
 - 需要快速了解“这款游戏是什么、怎么玩、如何运行与打包、适合什么设备”时，优先读取 `20260601210110` 文档。
@@ -101,6 +103,7 @@
 
 ## 关键记忆
+- README 当前已支持中英文双文档：`README.md` 为中文主文档，`README.en.md` 为完整英文版，两个文档顶部均提供互链切换。
 - 游戏设置已新增总音量滑杆：UI 位于设置面板内，采用蓝色主题容器 + 百分比显示，当前控制的是“总音量”而非独立 BGM/SFX 分轨。
 - `GameAudioSystem` 现已负责音量持久化：使用 `UserDefaults` 保存 `0...1` 区间的主音量，并在 BGM 播放、音效触发以及运行中调整时统一应用。
 - 仓库现已提供完整 `README.md`：包含项目介绍、玩法说明、模式设计、Touch Bar 交互方式、运行/打包命令、硬件要求与目录结构，可直接作为对外介绍入口。
```

## 测试用例
### TC-001 英文 README 可访问性
- 类型：文档测试
- 优先级：高
- 关联模块：`README.md`、`README.en.md`
- 前置条件：无
- 操作步骤：
1. 打开 `README.md`
2. 点击顶部 `English` 链接
3. 在 `README.en.md` 顶部点击 `简体中文`
- 预期结果：
- 中英文文档可以互相跳转
- 两个入口都可用
- 是否通过：待验证

### TC-002 英文 README 完整性
- 类型：文档测试
- 优先级：高
- 关联模块：`README.en.md`
- 前置条件：无
- 操作步骤：
1. 检查英文文档是否包含项目介绍、玩法、模式、运行、打包、结构与注意事项
- 预期结果：
- 英文读者无需阅读中文 README 也能独立理解项目
- 是否通过：待验证
