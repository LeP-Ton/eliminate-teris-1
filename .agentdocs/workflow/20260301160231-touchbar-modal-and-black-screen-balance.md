# 同时兼顾 Touch Bar 左侧贴边与打包黑屏

## 背景与目标
- 用户反馈：为了避开打包版黑屏把私有 modal 关掉后，左侧空白间距问题会回归。
- 目标：保持私有 modal 路径带来的左侧贴边效果，同时降低打包版出现黑屏的概率。

## 方案
- 恢复“默认优先私有 modal”策略，并保留显式关闭开关：
  - 默认启用私有 modal（保持左侧贴边）。
  - 设置 `ELIMINATE_TOUCHBAR_MODAL=0` 时回退公开 `window.touchBar` 路径。
- 增加渲染预热，缓解首帧黑屏：
  - `GameTouchBarView` 开启 `layerContentsRedrawPolicy = .onSetNeedsDisplay`。
  - 挂载后主动调用 `prepareForDisplay()` 清理过渡态并触发重绘。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 701b711..f435a69 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -531,11 +531,13 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
 
     override func viewDidAppear() {
         super.viewDidAppear()
-        // 优先使用系统级 modal touch bar；仅在不可用时回退 window.touchBar。
-        if presentSystemModalTouchBarIfPossible() {
+        // 默认优先走私有 modal 路径，保持最左侧贴边显示；异常时可通过环境变量关闭。
+        if shouldUseSystemModalTouchBar(), presentSystemModalTouchBarIfPossible() {
             view.window?.touchBar = nil
+            gameTouchBarView.prepareForDisplay()
         } else {
             view.window?.touchBar = gameTouchBar
+            gameTouchBarView.prepareForDisplay()
         }
         view.window?.makeFirstResponder(self)
         view.window?.minSize = NSSize(width: 720, height: 450)
@@ -620,6 +622,14 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         isPresentingSystemModalTouchBar = false
     }
 
+    private func shouldUseSystemModalTouchBar() -> Bool {
+        let value = ProcessInfo.processInfo.environment["ELIMINATE_TOUCHBAR_MODAL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
+        if value == "0" {
+            return false
+        }
+        return true
+    }
+
     @objc private func languageSelectionChanged(_ sender: NSPopUpButton) {
         let index = max(0, sender.indexOfSelectedItem)
         let language = AppLanguage.allCases[min(index, AppLanguage.allCases.count - 1)]
```

- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 1591173..3fd64e0 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -353,11 +353,13 @@ final class GameTouchBarView: NSView {
         super.init(frame: .zero)
 
         wantsLayer = true
+        layerContentsRedrawPolicy = .onSetNeedsDisplay
         layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
         allowedTouchTypes = [.direct, .indirect]
         wantsRestingTouches = true
         setContentHuggingPriority(.defaultLow, for: .horizontal)
         setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
+        needsDisplay = true
 
         observerToken = controller.addObserver(owner: self) { [weak self] in
             self?.handleControllerChange()
@@ -504,6 +506,16 @@ final class GameTouchBarView: NSView {
         controller.handleTap(at: index)
     }
 
+    func prepareForDisplay() {
+        renderedTiles = controller.tiles()
+        pieceTransitions = []
+        transitionPhases = []
+        transitionPhaseIndex = 0
+        transitionProgress = 1
+        shouldPlayTransitionEffects = false
+        needsDisplay = true
+    }
+
     private func handleControllerChange() {
         let latestTiles = controller.tiles()
         let swapPair = controller.consumeLastSwapPair()
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index ce63011..19e5949 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -40,3 +40,5 @@
 - 动画时序现已按最新需求调整为三阶段：交换位移（0.16s）→ 消除反馈（0.20s）→ 左侧补位（0.24s）；通过 `lastSwapPair + transitionPhases` 串联，确保“先交换、再消除、后补位”。
 - 已新增程序化音效系统 `GameAudioSystem`：自由/竞分/竞速模式会自动切换不同 BGM，且在三阶段动画中按阶段触发移动、消除、补位音效；音频由运行时合成 WAV，不依赖外部资源文件。
 - 已新增 `package.sh` 打包脚本：构建 release 后生成 `.app`，自动拷贝 SwiftPM 资源 Bundle、写入 `Info.plist`、执行 ad-hoc 签名，并优先输出 DMG（失败时自动回退 ZIP）。
+- 曾尝试以“release 默认公开路径”规避打包版 Touch Bar 黑屏（`ELIMINATE_TOUCHBAR_MODAL=1` 可强制私有 modal）；当前策略已迭代为默认私有 modal + 显式关闭开关。
+- Touch Bar 展示策略已升级为“默认私有 modal + 可显式关闭”：默认启用私有 modal 保持左侧贴边，设置 `ELIMINATE_TOUCHBAR_MODAL=0` 可回退公开路径；同时在挂载后调用 `prepareForDisplay` 并开启 `layerContentsRedrawPolicy = .onSetNeedsDisplay`，降低打包版黑屏概率。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 1121c8a..004e8e2 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,8 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260301160231-touchbar-modal-and-black-screen-balance.md` - 同时兼顾左侧贴边与打包黑屏：默认私有 modal，增加显式回退开关与强制重绘预热。
+`workflow/20260301153306-release-touchbar-modal-fallback.md` - 修复打包版 Touch Bar 黑屏：release 默认回退公开 Touch Bar 路径，并保留环境变量开关启用私有 modal。
 `workflow/20260301151213-macos-package-script.md` - 新增 macOS 打包脚本，产出 `.app` 并优先生成 DMG（失败回退 ZIP）。
 `workflow/20260221200836-audio-system-bgm-sfx.md` - 新增程序化音效系统：按模式切换 BGM，并按动画阶段播放移动/消除/补位音效。
 `workflow/20260221193822-touchbar-three-phase-animation-sequence.md` - Touch Bar 动画改为三阶段：先交换，再消除，最后左侧补位。
@@ -40,6 +42,8 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要同时处理“左侧空白间距 + 打包黑屏”时，优先读取 `20260301160231` 文档。
+- 需要排查“打包后 Touch Bar 黑屏”时，优先读取 `20260301153306` 文档。
 - 需要确认“如何打包成可安装 macOS 应用（.app/.dmg/.zip）”时，优先读取 `20260301151213` 文档。
 - 需要确认“模式切换 BGM + 交换/消除/补位音效”是否已接入时，优先读取 `20260221200836` 文档。
 - 需要确认“交换后才消除、消除后才补位”是否落地时，优先读取 `20260221193822` 文档。
@@ -80,6 +84,8 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- Touch Bar 当前默认仍启用私有 modal（用于维持左侧贴边），但增加了 `ELIMINATE_TOUCHBAR_MODAL=0` 显式回退开关；挂载后会执行 `prepareForDisplay` 且开启 `onSetNeedsDisplay` 重绘策略，缓解打包版黑屏。
+- 打包版 Touch Bar 策略已更新：默认启用私有 modal 以保持左侧贴边，若需规避兼容性问题可显式设置 `ELIMINATE_TOUCHBAR_MODAL=0` 回退公开 `window.touchBar` 路径。
 - 当前通过 `package.sh` 一键打包：`swift build -c release` 后组装 `.app`（含资源 Bundle + Info.plist + ad-hoc 签名），并尝试生成 DMG；若 DMG 不可用则自动回退为 ZIP。
 - 已新增 `GameAudioSystem` 程序化音频链路：自由/竞分/竞速模式切换会切 BGM，且仅在“交换触发”的三阶段过渡中按阶段播放移动、消除、补位音效，避免模式切换/重置触发误报声。
 - Touch Bar 动画时序当前为三阶段链路：交换位移（0.16s）→ 消除反馈（0.20s）→ 左侧补位（0.24s）；交换对由 `GameBoardController.lastSwapPair` 提供，渲染端以 `transitionPhases` 顺序执行。
```

## 测试与验证
### TC-001 调试构建
- 类型：构建测试
- 操作步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`
- 预期结果：构建成功。
- 实际结果：已通过。

### TC-002 打包构建
- 类型：构建测试
- 操作步骤：执行 `./package.sh`
- 预期结果：成功生成 `dist/Eliminate Teris 1.app`，并输出 DMG 或 ZIP。
- 实际结果：已生成 `.app` 与 `.zip`（当前环境 DMG 自动回退）。

### TC-003 左贴边 + 黑屏联调（手工）
- 类型：功能测试
- 操作步骤：
  1. 启动 `dist/Eliminate Teris 1.app`
  2. 观察 Touch Bar 是否正常显示方块且最左侧无留白
  3. 如需对照回退路径，使用 `ELIMINATE_TOUCHBAR_MODAL=0` 再启动
- 预期结果：
  - 默认路径：方块可见且左侧贴边
  - 回退路径：应不黑屏（允许出现系统路径的左侧空白差异）
- 实际结果：待你本机确认（CLI 无法直接观测 Touch Bar 图像）。
