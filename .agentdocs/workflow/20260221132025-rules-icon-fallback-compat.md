# 修复玩法说明标题图标不显示（兼容性回退）

## 背景与目标
- 用户反馈“玩法说明”模块标题图标未显示。
- 目标：确保玩法说明标题图标在当前系统版本可见，并兼容系统符号缺失场景。

## 约束与原则
- 仅调整图标符号与回退策略，不改布局结构。
- 继续保持图标与标题的既有间距与主题色。

## 阶段与 TODO
- [x] 将玩法说明标题图标更换为兼容性更高符号。
- [x] 为标题图标生成逻辑增加符号缺失回退。
- [x] 更新项目认知与索引文档。
- [x] 完成构建验证。

## 当前进展
- 玩法说明图标由 `book.pages` 改为 `doc.text`。
- 当传入符号不可用时，自动回退为 `circle.fill`，避免图标缺失。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 58fd866..5ea35ce 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -237,7 +237,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }()
 
     private lazy var rulesTitleIconView: NSImageView = {
-        return makeSectionIconView(symbolName: "book.pages", color: rulesThemeColor)
+        return makeSectionIconView(symbolName: "doc.text", color: rulesThemeColor)
     }()
@@ -1251,8 +1251,11 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private func makeSectionIconView(symbolName: String, color: NSColor) -> NSImageView {
@@
         if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
             let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
             iconView.image = symbol.withSymbolConfiguration(config)
+        } else if let fallback = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil) {
+            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
+            iconView.image = fallback.withSymbolConfiguration(config)
         }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 913ee11..825de91 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -18,3 +18,4 @@
 - 玩法说明在所有模式下都已去掉模式小标题；基础规则第二条统一为“操作方式：...”前缀并保持多语言同步。
 - 自由模式下会隐藏右侧状态/记录列，并将“游戏设置”卡片扩展为占满整行宽度，与下方玩法说明卡片等宽。
 - 各模块（游戏设置/时间与得分/挑战记录/玩法说明）标题前已加入主题色图标，并统一保留约 6px 的图标与标题间距。
+- 玩法说明标题图标已切换为兼容性更高的 `doc.text`，并增加系统符号缺失时的回退图标，避免个别系统版本不显示。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
 ## 当前变更文档
+`workflow/20260221132025-rules-icon-fallback-compat.md` - 修复玩法说明标题图标不显示，改用兼容符号并增加缺失回退图标。
@@
 ## 读取场景
+- 需要确认“玩法说明标题图标在旧系统也可见”的兼容性修复时，优先读取 `20260221132025` 文档。
@@
 ## 关键记忆
+- 玩法说明标题图标已从 `book.pages` 调整为 `doc.text`，并在符号不可用时回退为 `circle.fill`，避免图标缺失。
```

## 测试用例
### TC-001 玩法说明图标显示
- 类型：UI测试
- 操作步骤：打开页面观察“玩法说明”标题左侧图标
- 预期结果：图标可见，不为空

### TC-002 回退逻辑验证（代码级）
- 类型：静态检查
- 操作步骤：确认 `makeSectionIconView` 中存在 `else if` 回退分支
- 预期结果：符号缺失时会回退到 `circle.fill`

### TC-003 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- 预期结果：构建成功
