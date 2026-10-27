# 成就面板按主窗口定位

## 背景与目标
- 对应会话：会话-21 起，用户反馈点击“查看全部”后成就面板默认出现在屏幕边缘。
- 面板首次打开、切换详情入口及关闭后重开时，均应按游戏主窗口当前位置定位。
- 本轮开始时工作区已有前两轮未提交改动；下列 diff 严格相对本轮开始快照生成，仅包含本轮修复，保留已有文档与代码变化。

## 原因与修复
- 原流程先执行 `addChildWindow`，再检查 `!window.isVisible`；附加子窗口已使面板可见，导致首次定位直接跳过。
- 改为在附加和显示前计算并设置 frame，不再依赖可见性决定是否定位。
- 默认居中于主窗口；使用主窗口所在屏幕的 `visibleFrame`（可用区域），四边预留 8 点。面板过大时收敛尺寸，靠近边缘时收敛位置。
- 同一父窗口不重复附加；父窗口改变时先解除旧关联，再附加至当前父窗口。没有父窗口时使用系统居中行为。
- 保留非模态面板和不争夺游戏键盘焦点的设置。
- 本轮为局部窗口定位修复，不改变核心架构，因此不向 AGENTS.md 添加需求细节。

## 阶段与 TODO
- [x] 修正首次打开时的显示/定位顺序。
- [x] 每次打开依据当前主窗口重新定位。
- [x] 兼容屏幕边缘和可用区域限制。
- [x] 添加真实原生窗口的首次打开、再次打开、主窗口移动及边缘定位回归。
- [x] 完成测试、差异检查与增量变更文档/索引记录。

## 测试用例

### TC-001 首次打开和重新定位
- 类型：原生窗口回归；优先级：高；模块：AchievementsWindowController。
- 前置条件：创建并显示真实父窗口，成就面板使用独立测试存档。
- 操作步骤：首次调用 present；将可见面板移到旧位置后再打开详情；关闭面板、移动父窗口后重新打开。
- 预期结果：每次面板中心均与父窗口中心一致，保持正确的父子窗口关系。
- 是否通过：通过。

### TC-002 主窗口靠近屏幕边缘
- 类型：原生窗口回归；优先级：高；模块：AchievementsWindowController。
- 前置条件：将父窗口放到当前屏幕可用区域的左上角。
- 操作步骤：打开成就面板并读取最终窗口 frame。
- 预期结果：面板四边均在屏幕可用区域内且有约 8 点留白，仍归属父窗口，不获取键盘焦点。
- 是否通过：通过。

### TC-003 既有成就界面回归
- 类型：界面回归；优先级：中。
- 操作步骤：运行原有五枚标签、五语言图文布局/点击、分类筛选及图鉴布局用例。
- 预期结果：布局、操作和焦点行为保持正常。
- 是否通过：通过，共 4 项既有测试。

## 当前进展与验证
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AchievementPresentationTests`：6 项测试，0 失败；构建与链接正常。
- `git diff --check`：通过。
- 未重启用户当前的游戏进程，重启后可体验修复。

## 代码变更

以下为本轮全部代码、测试和索引的完整逐行增量 diff。

### `Sources/AchievementViews.swift`

```diff
diff --git a/Sources/AchievementViews.swift b/Sources/AchievementViews.swift
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -216,11 +216,27 @@
         scroll.contentView.scroll(to: .zero)
         scroll.reflectScrolledClipView(scroll.contentView)
         if let parent, let window {
-            parent.addChildWindow(window, ordered: .above)
-            if !window.isVisible {
-                window.setFrameOrigin(NSPoint(x: parent.frame.midX - window.frame.width / 2,
-                                               y: parent.frame.midY - window.frame.height / 2))
-            }
+            var frame = window.frame
+            let availableFrame = (parent.screen ?? NSScreen.main)?.visibleFrame.insetBy(dx: 8, dy: 8)
+            if let availableFrame {
+                frame.size.width = min(frame.width, availableFrame.width)
+                frame.size.height = min(frame.height, availableFrame.height)
+            }
+            frame.origin = NSPoint(x: parent.frame.midX - frame.width / 2,
+                                   y: parent.frame.midY - frame.height / 2)
+            if let availableFrame {
+                // 主窗口靠近屏幕边缘时，保证标题栏和整个面板仍处于可用区域。
+                frame.origin.x = min(max(frame.minX, availableFrame.minX), availableFrame.maxX - frame.width)
+                frame.origin.y = min(max(frame.minY, availableFrame.minY), availableFrame.maxY - frame.height)
+            }
+            // addChildWindow 会使子窗口可见，必须先完成定位，不能再依赖 isVisible 判断。
+            window.setFrame(frame, display: false)
+            if window.parent !== parent {
+                window.parent?.removeChildWindow(window)
+                parent.addChildWindow(window, ordered: .above)
+            }
+        } else {
+            window?.center()
         }
         window?.orderFront(nil)
     }
```

### `Tests/AchievementPresentationTests.swift`

```diff
diff --git a/Tests/AchievementPresentationTests.swift b/Tests/AchievementPresentationTests.swift
--- a/Tests/AchievementPresentationTests.swift
+++ b/Tests/AchievementPresentationTests.swift
@@ -120,4 +120,54 @@
         }
     }
 
+    func testPanelCentersOnParentOnFirstOpenAndAfterParentMoves() throws {
+        _ = NSApplication.shared
+        let screen = try XCTUnwrap(NSScreen.main?.visibleFrame)
+        let parent = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
+        parent.isReleasedWhenClosed = false
+        let parentSize = NSSize(width: min(800, screen.width - 64), height: min(700, screen.height - 64))
+        parent.setFrame(NSRect(x: screen.midX - parentSize.width / 2, y: screen.midY - parentSize.height / 2,
+                               width: parentSize.width, height: parentSize.height), display: false)
+        parent.orderFront(nil)
+        let panel = AchievementsWindowController(manager: manager)
+        defer { panel.close(); parent.close() }
+        let window = try XCTUnwrap(panel.window)
+
+        func verifyCentered() {
+            XCTAssertEqual(window.frame.midX, parent.frame.midX, accuracy: 1)
+            XCTAssertEqual(window.frame.midY, parent.frame.midY, accuracy: 1)
+            XCTAssertTrue(window.parent === parent)
+        }
+        panel.present(from: parent)
+        verifyCentered()
+        // 面板已经可见时再次点击入口，也应从旧位置回到主窗口中央。
+        window.setFrameOrigin(screen.origin)
+        panel.present(from: parent, detailID: 1)
+        verifyCentered()
+        panel.close()
+        parent.setFrameOrigin(NSPoint(x: parent.frame.minX + 24, y: parent.frame.minY + 16))
+        panel.present(from: parent)
+        verifyCentered()
+    }
+
+    func testPanelStaysWithinUsableScreenWhenParentIsNearEdge() throws {
+        _ = NSApplication.shared
+        let screen = try XCTUnwrap(NSScreen.main?.visibleFrame)
+        let parent = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
+        parent.isReleasedWhenClosed = false
+        parent.setFrame(NSRect(x: screen.minX, y: screen.maxY - 280, width: 300, height: 280), display: false)
+        parent.orderFront(nil)
+        let panel = AchievementsWindowController(manager: manager)
+        defer { panel.close(); parent.close() }
+        panel.present(from: parent)
+        let window = try XCTUnwrap(panel.window)
+        let available = try XCTUnwrap((parent.screen ?? NSScreen.main)?.visibleFrame)
+        XCTAssertGreaterThanOrEqual(window.frame.minX, available.minX + 7)
+        XCTAssertGreaterThanOrEqual(window.frame.minY, available.minY + 7)
+        XCTAssertLessThanOrEqual(window.frame.maxX, available.maxX - 7)
+        XCTAssertLessThanOrEqual(window.frame.maxY, available.maxY - 7)
+        XCTAssertTrue(window.parent === parent)
+        XCTAssertFalse(window.canBecomeKey)
+    }
+
 }
```

### `.agentdocs/index.md`

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261027225436-achievement-panel-position.md` - 会话-21 起修复成就面板在屏幕边缘显示：先按主窗口定位再附加，每次打开重新居中并限制在当前屏幕可用区域；含完整增量 diff 和 6 项界面回归结果。
 `workflow/20261027224658-achievement-badge-layout.md` - 会话-16 起修复成就标签遮挡、图文居中与标签过宽；默认完整显示 5 枚，含本轮增量 diff 及 4 项界面回归测试结果。
 `workflow/20261026092356-achievement-system.md` - 会话-5 起实现 20 枚事件驱动成就、版本化存档迁移、五语言徽章/非模态图鉴与提示队列；含完整逐行 diff 和 29 项测试结果。
 `workflow/20260615223620-readme-screenshot-preview-remove-note-and-table.md` - 移除中英文 README 截图预览区的说明提示，并把表格布局改为更自然的分段图片展示。
@@ -61,6 +62,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 成就面板首次打开位置异常、需要跟随主窗口定位或处理靠近屏幕边缘时，读取 `20261027225436-achievement-panel-position.md`。
 - 需要调整成就徽章栏高度、默认五枚布局、图文居中、滚动条兼容或长名称展示时，读取 `20261027224658-achievement-badge-layout.md`。
 - 需要了解成就清单、真实交换/结算事件、旧成就迁移、进度存档、非模态图鉴或成就测试时，读取 `20261026092356-achievement-system.md`。
 - 需要确认“截图预览区是否已经去掉提示文案与表格，改为纵向分段展示”时，优先读取 `20260615223620` 文档。
@@ -122,6 +124,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 成就面板需在 `addChildWindow` 之前完成定位，因为附加子窗口会使其可见；每次打开以主窗口 frame 为中心，并限制在主窗口所在屏幕的 visibleFrame 内，四边预留 8 点。
 - 成就卡片高度由标题、内边距与 64 点高的标签区域决定，不再与顶部横幅等高；标签按实际可视宽度适配五枚，图标与文字整体居中，长名称截断后可通过悬浮提示或详情查看。
 - 成就统计由棋盘控制器提交真实事件，独立于 HUD 刷新和挑战排行；累计值与历史最佳跨局保存，节奏/连续交换在重开和模式切换时清零。
 - 旧版仅迁移成就编号 1—3 的解锁与时间；不使用排行榜或开发 seed 回推新成就。
```
