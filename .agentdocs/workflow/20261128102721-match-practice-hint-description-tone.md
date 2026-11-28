# 对齐自由模式提示与联系说明的文字样式

## 背景与目标

- 会话-145 要求把自由模式练习提示改为与「欢迎报告问题或分享玩法建议。」相同的字重和颜色。

## 实施

- 练习提示使用常规字重与主题灰蓝色。字号适配和逐帧绘制均采用常规字重。

## 验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 全部 110 项通过。
- 核对大厅的原生预览，比较统计背板提示与联系我们说明的字重和颜色。运行 `./run.sh` 后可在自由模式查看。

## 本轮完整增量 diff

以会话-145 开始时的工作区为基线。

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 3c7e4a14c63e0f76b2f2ed3d32bf2a1cb9ad11d5..2ca82071bf407f983412d678f43a7aafaa93093b 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261128102721-match-practice-hint-description-tone.md` - 会话-145 起让自由模式练习提示与联系我们说明使用同样的常规字重和灰蓝色。
 `workflow/20261128101138-type-free-mode-practice-hint.md` - 会话-142 起在自由模式背板加入蓝色斜杠和逐字显示的练习提示。
 `workflow/20261128094456-synchronize-budget-fill-with-highlight.md` - 会话-136 起让统计卡预算填充和前板上沿扫光同步起播。
 `workflow/20261128090504-animate-statistics-budget-fill.md` - 会话-129 起在统计卡叠合后从零填充挑战预算，开局后动态跟随剩余值。
@@ -122,6 +123,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要核对自由模式练习提示和联系我们说明的字重或颜色时，读取 `20261128102721-match-practice-hint-description-tone.md`。
 - 需要调整自由模式背板文案、蓝色斜杠、打字动画或首次进大厅的提示时，读取 `20261128101138-type-free-mode-practice-hint.md`。
 - 需要调整统计卡扫光和预算填充的共同起点，读取 `20261128094456-synchronize-budget-fill-with-highlight.md`。
 - 需要调整切换模式后的预算填充、开局时的剩余目标或限步分格显示时，读取 `20261128090504-animate-statistics-budget-fill.md`。
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 7193623d3c0bfdae39c6d0bc69f0c31614caf547..b7fc337204a468fb48da77455d78e54aa19b425a 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -371,8 +371,8 @@ final class HomeChallengeHUDView: NSView {
         guard !text.isEmpty, width > 0 else { return }
         // 按完整文案计算字号，逐字显示时文字位置和大小不跳动。
         let size = GameLobbyStyle.fittedSize(practiceHint, width: width, preferred: min(17, max(10, headerHeight * 0.38)),
-                                           minimum: 9, weight: .bold)
-        label(text, x: x, y: band.midY, width: width, size: size, weight: .bold)
+                                           minimum: 9, weight: .regular)
+        label(text, x: x, y: band.midY, width: width, size: size, weight: .regular, color: HomeDashboardStyle.muted)
     }
 
     private func drawTotals(_ totalCleared: Int, on face: Face, accent: NSColor) {
```
