# README 顶部补充徽章、目录与截图预览区

## 背景与目标
- 当前中英文 README 已具备完整正文内容，但首页首屏仍偏“纯文本说明”，缺少项目徽章、快速导航与截图展示入口。
- 本次目标是在不改动正文结构的前提下，增强 `README.md` 与 `README.en.md` 顶部信息密度，让仓库首页更像一个完整的项目介绍页。

## 约束与原则
- 不引入不存在的截图资源；截图区先做稳定占位，等后续正式图片准备好后再补充。
- 中文与英文 README 需要保持同等级的信息结构，避免一边有 TOC、另一边没有。
- 不改动现有玩法、运行、打包等正文内容，只增强顶部导航与首屏展示。

## 阶段与 TODO
- [x] 检查中英文 README 当前顶部结构与可复用信息。
- [x] 为 `README.md` 增加静态徽章、目录与截图预览占位区。
- [x] 为 `README.en.md` 同步增加对应的英文版结构。
- [x] 更新 `.agentdocs/index.md` 与 `AGENTS.md`，记录新的 README 认知。
- [x] 执行文档自检，确认顶部结构与 diff 留痕完整。

## 关键风险
- 如果直接插入不存在的本地截图链接，会让 README 出现空图或坏链，所以本次明确使用“截图预览占位”而不是伪造图片资源。
- 如果只改中文 README，英文 README 的首屏体验会明显落后，因此本次必须双语同步。

## 当前进展
- `README.md` 与 `README.en.md` 顶部都已新增四枚静态徽章，用于快速展示平台、Swift 版本、Touch Bar 适配与当前可玩状态。
- 两份 README 都已新增 TOC，读者进入仓库后可以直接跳转到截图区、玩法、运行方式和项目结构等核心章节。
- 截图区当前为占位说明，已经明确后续应优先补入“桌面主界面 / Touch Bar 棋盘 / 打包产物”三类图片。

## 代码变更
- `README.md`
```diff
--- a/README.md
+++ b/README.md
@@ -2,12 +2,37 @@
 
 简体中文 | [English](README.en.md)
 
+![Platform](https://img.shields.io/badge/Platform-macOS%2012%2B-1f6feb)
+![Swift](https://img.shields.io/badge/Swift-5.7%2B-f05138)
+![Touch%20Bar](https://img.shields.io/badge/Touch%20Bar-Optimized-111111)
+![Status](https://img.shields.io/badge/Status-Playable-2ea043)
+
 把消除游戏搬进 MacBook Touch Bar 的一次认真尝试。
 
 `Eliminate Teris 1` 是一款为 macOS 与 Touch Bar 场景设计的轻量消除游戏：战场不在大屏幕中央，而是在键盘上方那条熟悉又常被忽视的细长区域里。你会在 16 格的一维棋盘上交换相邻方块、制造三连消除、追逐更高分数，也会在竞速与限时模式里，把每一次操作都压缩成更紧凑、更直接的节奏。
 
 它的规则很直白，上手很快；但真正玩起来时，你会发现这一条窄窄的 Touch Bar，依然能装下判断、节奏、手感和一点点“再来一把”的执念。
 
+## 目录
+
+- [截图预览](#截图预览)
+- [游戏特色](#游戏特色)
+- [怎么玩](#怎么玩)
+- [模式说明](#模式说明)
+- [游戏界面说明](#游戏界面说明)
+- [运行环境](#运行环境)
+- [快速开始](#快速开始)
+- [项目结构](#项目结构)
+- [为什么这个项目值得一玩](#为什么这个项目值得一玩)
+
+## 截图预览
+
+> 当前仓库还没有正式截图资源，这里先保留预览区占位；后续补图时，建议优先展示桌面主界面、Touch Bar 棋盘和打包后的应用外观。
+
+- **主界面预览**：展示桌面窗口中的设置、时间与得分、挑战记录、玩法说明四大模块。
+- **Touch Bar 棋盘预览**：展示 16 格主战场、交换动作、消除反馈与补位节奏。
+- **打包产物预览**：展示 `.app`、`.dmg` 或 `.zip` 的最终分发形态，方便玩家快速理解如何安装体验。
+
 ## 游戏特色
```

- `README.en.md`
```diff
--- a/README.en.md
+++ b/README.en.md
@@ -2,12 +2,37 @@
 
 [简体中文](README.md) | English
 
+![Platform](https://img.shields.io/badge/Platform-macOS%2012%2B-1f6feb)
+![Swift](https://img.shields.io/badge/Swift-5.7%2B-f05138)
+![Touch%20Bar](https://img.shields.io/badge/Touch%20Bar-Optimized-111111)
+![Status](https://img.shields.io/badge/Status-Playable-2ea043)
+
 A serious attempt to bring a match puzzle game onto the MacBook Touch Bar.
 
 `Eliminate Teris 1` is a lightweight macOS puzzle game designed around the Touch Bar. The battlefield is not the center of your screen, but the narrow strip above your keyboard that people often notice less and use even less. On a one-dimensional board of 16 slots, you swap adjacent tiles, create matches of three or more, chase higher scores, and compress every action into a tighter and more direct rhythm in score attack and speed run modes.
 
 The rules are easy to understand and quick to pick up. But once you actually start playing, you may realize that this small strip of Touch Bar still has enough room for judgment, tempo, tactile feedback, and that irresistible “one more round” feeling.
 
+## Table of Contents
+
+- [Screenshot Preview](#screenshot-preview)
+- [Highlights](#highlights)
+- [How to Play](#how-to-play)
+- [Modes](#modes)
+- [Interface Overview](#interface-overview)
+- [Requirements](#requirements)
+- [Quick Start](#quick-start)
+- [Project Structure](#project-structure)
+- [Why This Project Is Interesting](#why-this-project-is-interesting)
+
+## Screenshot Preview
+
+> The repository does not include final screenshots yet. This section is kept as a placeholder so we can later add the desktop UI, the Touch Bar board, and the packaged app preview in a stable place near the top.
+
+- **Desktop Window Preview**: show the settings panel, time and score panel, challenge records, and mode briefing together.
+- **Touch Bar Board Preview**: show the 16-cell battlefield, tile swapping, clear feedback, and refill rhythm.
+- **Packaged App Preview**: show the final `.app`, `.dmg`, or `.zip` presentation so players can quickly understand the distribution format.
+
 ## Highlights
```

- `.agentdocs/index.md`
```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260610231349-readme-top-badges-toc-screenshot-preview.md` - 为中英文 README 顶部新增项目徽章、目录与截图预览占位区，强化仓库首页展示与导航。
 `workflow/20260608230301-record-seeds-dev-only.md` - 挑战记录测试数据改为仅开发模式注入：`run.sh` 显式开启开发模式，非开发模式启动时会自动清理旧 seed。
 `workflow/20260608223729-custom-model-private-modal-sync.md` - 放弃继续发散版本后，直接把 `custom-model` 分支的私有 modal Touch Bar 方案同步回主线，同时保留现有 README 与音量功能。
 `workflow/20260602231628-readme-english-support.md` - 为项目 README 增加英文支持：新增 `README.en.md`，并在中英文文档顶部补充语言切换入口。
@@ -53,6 +54,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要确认“README 顶部是否已有徽章、目录与截图预览区，以及后续应该把正式截图补到哪里”时，优先读取 `20260610231349` 文档。
 - 需要确认“README 是否已有英文版、英文文档放在哪里、如何在中英文之间切换”时，优先读取 `20260602231628` 文档。
 - 需要确认“游戏设置里的音量滑杆接在哪里、是否会记住上次设置、是否同时影响 BGM 与音效”时，优先读取 `20260602225626` 文档。
 - 需要快速了解“这款游戏是什么、怎么玩、如何运行与打包、适合什么设备”时，优先读取 `20260601210110` 文档。
@@ -106,6 +108,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- README 顶部现已补充静态徽章、目录与截图预览占位区：`README.md` 与 `README.en.md` 都能在首屏快速展示平台/Swift/Touch Bar/状态信息，并为后续正式截图预留固定位置。
 - README 当前已支持中英文双文档：`README.md` 为中文主文档，`README.en.md` 为完整英文版，两个文档顶部均提供互链切换。
 - 游戏设置已新增总音量滑杆：UI 位于设置面板内，采用蓝色主题容器 + 百分比显示，当前控制的是“总音量”而非独立 BGM/SFX 分轨。
 - `GameAudioSystem` 现已负责音量持久化：使用 `UserDefaults` 保存 `0...1` 区间的主音量，并在 BGM 播放、音效触发以及运行中调整时统一应用。
```

- `AGENTS.md`
```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -1,5 +1,9 @@
 # 项目认知记录
 
+## 2026-06-10
+- README 顶部现已增强为“项目首页入口”形态：`README.md` 与 `README.en.md` 都新增了静态徽章，首屏即可看到平台、Swift 版本、Touch Bar 适配与当前可玩状态。
+- 中英文 README 顶部都已加入目录（TOC）与“截图预览”占位区；当前仓库还没有正式截图资源，后续补图时应优先填充该区域，而不是把截图分散插入正文各处。
+
 ## 2026-06-02
 - 游戏设置面板已新增“音量”控制项，使用与现有蓝色设置控件一致的主题风格，显示为横向滑杆加百分比读数。
 - 当前音量控制为“总音量”：会同时影响 BGM 与移动/消除/补位音效，不区分背景音乐与音效的独立通道。
```

## 测试用例
### TC-001 README 中文顶部导航可见
- 类型：文档检查
- 优先级：中
- 关联模块：`README.md`
- 前置条件：在仓库首页打开中文 README
- 操作步骤：
1. 查看标题下方是否出现 4 枚徽章
2. 查看是否出现“目录”章节
3. 查看是否出现“截图预览”占位说明
- 预期结果：
- 中文 README 首屏可见徽章、TOC 与截图预览区
- 目录锚点文本与现有章节一致
- 是否通过：已通过

### TC-002 README 英文顶部导航可见
- 类型：文档检查
- 优先级：中
- 关联模块：`README.en.md`
- 前置条件：打开英文 README
- 操作步骤：
1. 查看标题下方是否出现 4 枚徽章
2. 查看是否出现 `Table of Contents`
3. 查看是否出现 `Screenshot Preview` 占位说明
- 预期结果：
- 英文 README 首屏结构与中文 README 对齐
- 后续可直接在占位区补正式截图
- 是否通过：已通过
