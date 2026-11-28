# 更新自由模式背板练习提示

## 背景与目标

- 会话-149 要求将提示文案改为「在无时间与目标限制的自由模式中练习操作技巧」。

## 实施

- 更新简体中文原句，并同步英文、日文、韩文和俄文资源。现有的逐字显示按新句子长度运行。
- 将提示的原生动图回归设为 960 × 720 点，检查更长的文案在紧凑窗口中的呈现。

## 验证

- 五种语言文件均通过 `plutil -lint`。使用 AppKit 字体测量确认各语言在 960 × 720 点窗口通过现有字号适配可单行显示。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 110 项通过。查看简体中文紧凑窗口原生帧，核对全文和左侧斜杠。
- 运行 `./run.sh` 后在自由模式查看背板打字提示。

## 本轮完整增量 diff

以会话-149 开始时的工作区为基线。

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index d6cb90d16a5b8be92d7fb17b91dcdb6e670ad9c7..479d0e0acce695d5413ace276de2946f23934dee 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261128104839-update-free-mode-practice-copy.md` - 会话-149 起更新自由模式背板文案，补充无时间与目标限制的说明。
 `workflow/20261128103633-match-practice-hint-and-start-hint-size.md` - 会话-147 起让自由模式提示和开局提示共用字号与蓝色斜杠尺寸。
 `workflow/20261128102721-match-practice-hint-description-tone.md` - 会话-145 起让自由模式练习提示与联系我们说明使用同样的常规字重和灰蓝色。
 `workflow/20261128101138-type-free-mode-practice-hint.md` - 会话-142 起在自由模式背板加入蓝色斜杠和逐字显示的练习提示。
@@ -124,6 +125,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要核对自由模式练习提示的五种语言文案时，读取 `20261128104839-update-free-mode-practice-copy.md`。
 - 需要调整自由模式提示或开局提示的字号、斜杠尺寸时，读取 `20261128103633-match-practice-hint-and-start-hint-size.md`。
 - 需要核对自由模式练习提示和联系我们说明的字重或颜色时，读取 `20261128102721-match-practice-hint-description-tone.md`。
 - 需要调整自由模式背板文案、蓝色斜杠、打字动画或首次进大厅的提示时，读取 `20261128101138-type-free-mode-practice-hint.md`。
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index 59e80de8ae9b1dd39501bb23dcafa8ddb1c9bbee..ddb4737d8851a57049d84775a480b18846a6a530 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -709,9 +709,9 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         defer { Localizer.shared.setLanguage(original) }
         Localizer.shared.setLanguage(.chineseSimplified)
         let hint = AchievementText.string("home.practice_hint")
-        XCTAssertEqual(hint, "在自由模式中练习操作技巧")
+        XCTAssertEqual(hint, "在无时间与目标限制的自由模式中练习操作技巧")
 
-        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
+        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 960, height: 720))
         let header = home.modeHeader
         let hud = home.challengeHUD
         var clock: TimeInterval = 0
diff --git a/Sources/Resources/en.lproj/Localizable.strings b/Sources/Resources/en.lproj/Localizable.strings
index 026cad80cd3ea7b53206be1f06105b2b0d087f0e..623c324995b95684259e1a9d96c241bb5f421747 100644
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -188,7 +188,7 @@
 "home.subtitle.free" = "No countdown. Play at your own pace.";
 "home.subtitle.timed" = "Clear as many tiles as you can in one minute.";
 "home.subtitle.moves" = "Take your time. Make every swap worthwhile.";
-"home.practice_hint" = "Practice your moves in free play";
+"home.practice_hint" = "Practice in free play with no timer or goals";
 "home.mode.free" = "Free play";
 "home.mode.puzzle" = "Puzzle Mode";
 "home.mode.timed" = "Timed Challenge";
diff --git a/Sources/Resources/ja.lproj/Localizable.strings b/Sources/Resources/ja.lproj/Localizable.strings
index 69e89a6a0820721e870c246ae6a12d8f850c435b..0d0e99eae99798cc42d1bd2c0816b5f341e02024 100644
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -181,7 +181,7 @@
 "home.subtitle.free" = "時間を気にせず、自分のペースで。";
 "home.subtitle.timed" = "1 分間でできるだけ多く消そう。";
 "home.subtitle.moves" = "時間を気にせず、一手を大切に。";
-"home.practice_hint" = "フリーモードで操作を練習しよう";
+"home.practice_hint" = "時間・目標制限のないフリーモードで操作を練習";
 "home.mode.free" = "フリーモード";
 "home.mode.puzzle" = "パズルモード";
 "home.mode.timed" = "時間制チャレンジ";
diff --git a/Sources/Resources/ko.lproj/Localizable.strings b/Sources/Resources/ko.lproj/Localizable.strings
index f37e0a8fd6b229c99033c6c94e42f95ca1d7c931..143443396f86e4a07194e6e42c97731527d3aca4 100644
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -181,7 +181,7 @@
 "home.subtitle.free" = "시간에 쫓기지 않고, 내 속도로 즐겨요.";
 "home.subtitle.timed" = "1분 안에 최대한 많은 블록을 제거하세요.";
 "home.subtitle.moves" = "시간에 쫓기지 말고 매번 신중하게 교환하세요.";
-"home.practice_hint" = "자유 모드에서 조작을 연습해 보세요";
+"home.practice_hint" = "시간·목표 제한 없는 자유 모드에서 조작 연습";
 "home.mode.free" = "자유 모드";
 "home.mode.puzzle" = "퍼즐 모드";
 "home.mode.timed" = "시간 도전";
diff --git a/Sources/Resources/ru.lproj/Localizable.strings b/Sources/Resources/ru.lproj/Localizable.strings
index c7f684d79a0ee1fdd66d840a8290281c89267ea2..837a54890d0d68bd2a8f10ca9e477c8e727cc4d7 100644
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -181,7 +181,7 @@
 "home.subtitle.free" = "Без таймера. Играй в своём ритме.";
 "home.subtitle.timed" = "Уберите как можно больше фигур за минуту.";
 "home.subtitle.moves" = "Без спешки. Пусть каждый обмен будет полезным.";
-"home.practice_hint" = "Оттачивай навыки в свободной игре";
+"home.practice_hint" = "Тренируйся в свободной игре без таймера и целей";
 "home.mode.free" = "Свободная игра";
 "home.mode.puzzle" = "Головоломка";
 "home.mode.timed" = "На время";
diff --git a/Sources/Resources/zh-Hans.lproj/Localizable.strings b/Sources/Resources/zh-Hans.lproj/Localizable.strings
index c74e9fc58730c7df36dc4cbec72908435eeafe3a..48955cb720a19b3a455b9517336ad6248c9632d8 100644
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -188,7 +188,7 @@
 "home.subtitle.free" = "没有倒计时，按自己的节奏玩。";
 "home.subtitle.timed" = "和时间赛跑，迅速消除更多方块。";
 "home.subtitle.moves" = "不必赶时间，让每一步更有价值。";
-"home.practice_hint" = "在自由模式中练习操作技巧";
+"home.practice_hint" = "在无时间与目标限制的自由模式中练习操作技巧";
 "home.mode.free" = "自由模式";
 "home.mode.puzzle" = "解谜模式";
 "home.mode.timed" = "限时挑战";
```
