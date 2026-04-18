# 修复打包版 Touch Bar 黑屏（release 回退公开路径）

## 背景与目标
- 问题：启动 `dist/Eliminate Teris 1.app` 后，Touch Bar 只显示黑色背景，没有方块内容。
- 目标：优先保证打包版可用，避免分发版本因私有 API 路径导致黑屏。

## 方案
- 调整 Touch Bar 挂载策略：
  - `DEBUG` 构建仍默认使用私有 `presentSystemModalTouchBar` 路径（保持开发环境原有效果）。
  - `release` 构建默认回退公开 `window.touchBar` 路径，提升分发兼容性。
  - 如需在 release 强制启用私有 modal，可显式设置环境变量 `ELIMINATE_TOUCHBAR_MODAL=1`。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 701b711..8d38dce 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -531,8 +531,8 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
 
     override func viewDidAppear() {
         super.viewDidAppear()
-        // 优先使用系统级 modal touch bar；仅在不可用时回退 window.touchBar。
-        if presentSystemModalTouchBarIfPossible() {
+        // release 分发包默认关闭私有 modal 路径，规避个别环境出现 Touch Bar 黑屏问题。
+        if shouldUseSystemModalTouchBar(), presentSystemModalTouchBarIfPossible() {
             view.window?.touchBar = nil
         } else {
             view.window?.touchBar = gameTouchBar
@@ -620,6 +620,14 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         isPresentingSystemModalTouchBar = false
     }
 
+    private func shouldUseSystemModalTouchBar() -> Bool {
+#if DEBUG
+        return true
+#else
+        return ProcessInfo.processInfo.environment["ELIMINATE_TOUCHBAR_MODAL"] == "1"
+#endif
+    }
+
     @objc private func languageSelectionChanged(_ sender: NSPopUpButton) {
         let index = max(0, sender.indexOfSelectedItem)
         let language = AppLanguage.allCases[min(index, AppLanguage.allCases.count - 1)]
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index ce63011..e4c4242 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -40,3 +40,4 @@
 - 动画时序现已按最新需求调整为三阶段：交换位移（0.16s）→ 消除反馈（0.20s）→ 左侧补位（0.24s）；通过 `lastSwapPair + transitionPhases` 串联，确保“先交换、再消除、后补位”。
 - 已新增程序化音效系统 `GameAudioSystem`：自由/竞分/竞速模式会自动切换不同 BGM，且在三阶段动画中按阶段触发移动、消除、补位音效；音频由运行时合成 WAV，不依赖外部资源文件。
 - 已新增 `package.sh` 打包脚本：构建 release 后生成 `.app`，自动拷贝 SwiftPM 资源 Bundle、写入 `Info.plist`、执行 ad-hoc 签名，并优先输出 DMG（失败时自动回退 ZIP）。
+- 为规避打包版 Touch Bar 黑屏，release 构建默认关闭私有 `presentSystemModalTouchBar` 路径并回退 `window.touchBar`；如需强制启用私有 modal，可设置环境变量 `ELIMINATE_TOUCHBAR_MODAL=1`。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 1121c8a..4ad6b28 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260301153306-release-touchbar-modal-fallback.md` - 修复打包版 Touch Bar 黑屏：release 默认回退公开 Touch Bar 路径，并保留环境变量开关启用私有 modal。
 `workflow/20260301151213-macos-package-script.md` - 新增 macOS 打包脚本，产出 `.app` 并优先生成 DMG（失败回退 ZIP）。
 `workflow/20260221200836-audio-system-bgm-sfx.md` - 新增程序化音效系统：按模式切换 BGM，并按动画阶段播放移动/消除/补位音效。
 `workflow/20260221193822-touchbar-three-phase-animation-sequence.md` - Touch Bar 动画改为三阶段：先交换，再消除，最后左侧补位。
@@ -40,6 +41,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要排查“打包后 Touch Bar 黑屏”时，优先读取 `20260301153306` 文档。
 - 需要确认“如何打包成可安装 macOS 应用（.app/.dmg/.zip）”时，优先读取 `20260301151213` 文档。
 - 需要确认“模式切换 BGM + 交换/消除/补位音效”是否已接入时，优先读取 `20260221200836` 文档。
 - 需要确认“交换后才消除、消除后才补位”是否落地时，优先读取 `20260221193822` 文档。
@@ -80,6 +82,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 打包 release 版本为兼容稳定性，默认走公开 `window.touchBar` 路径；私有 modal 仅在显式设置 `ELIMINATE_TOUCHBAR_MODAL=1` 时启用。
 - 当前通过 `package.sh` 一键打包：`swift build -c release` 后组装 `.app`（含资源 Bundle + Info.plist + ad-hoc 签名），并尝试生成 DMG；若 DMG 不可用则自动回退为 ZIP。
 - 已新增 `GameAudioSystem` 程序化音频链路：自由/竞分/竞速模式切换会切 BGM，且仅在“交换触发”的三阶段过渡中按阶段播放移动、消除、补位音效，避免模式切换/重置触发误报声。
 - Touch Bar 动画时序当前为三阶段链路：交换位移（0.16s）→ 消除反馈（0.20s）→ 左侧补位（0.24s）；交换对由 `GameBoardController.lastSwapPair` 提供，渲染端以 `transitionPhases` 顺序执行。
```

## 测试与验证
### TC-001 调试构建编译验证
- 类型：构建测试
- 操作步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`
- 预期结果：构建成功。
- 实际结果：已通过。

### TC-002 打包构建验证
- 类型：构建测试
- 操作步骤：执行 `./package.sh`
- 预期结果：生成 `.app`，并输出 DMG 或 ZIP。
- 实际结果：已生成 `.app` 和 `.zip`（当前环境 DMG 不可用时自动回退）。

### TC-003 打包版 Touch Bar 手工验证
- 类型：功能测试
- 操作步骤：启动 `dist/Eliminate Teris 1.app` 并观察 Touch Bar。
- 预期结果：不再黑屏，可看到方块内容。
- 实际结果：待你本机确认（CLI 环境无法直接观测 Touch Bar 画面）。
