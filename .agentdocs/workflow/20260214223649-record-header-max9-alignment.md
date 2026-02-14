# 挑战记录标题去 Tag、记录上限改 9、序号 Tag 对齐修复

## 背景与目标
- 用户提出三项需求：
  1. 挑战记录标题后不再显示模式/细分 Tag。
  2. 挑战记录每个模式分组最多支持 9 条。
  3. 挑战记录行内序号 Tag 需要与同一行文本中线对齐。

## 约束与原则
- 保持现有玩法与记录排序规则不变，仅调整展示与数量上限。
- 保持本地历史数据兼容，升级后老数据也要遵守新上限。
- 不引入新依赖，维持现有 Swift AppKit 实现。

## 阶段与 TODO
- [x] 去掉挑战记录标题后 Tag 组件与相关逻辑。
- [x] 记录上限从 10 调整为 9。
- [x] 增加历史桶归一化，确保旧数据也被裁剪到 9。
- [x] 修复序号 Tag 基线对齐。
- [x] 完成编译验证。

## 关键风险
- 去掉标题 Tag 后，模式细分信息不再出现在标题后方（按当前需求执行）。
- 历史数据会在加载时被裁剪到 9 条，超过上限的旧记录将被丢弃。

## 当前进展
- 挑战记录标题后 Tag 已移除。
- 模式记录分桶上限已改为 9，且初始化会归一化旧数据。
- 序号 Tag 与文本中线对齐已修复。
- 本地 `swift build` 编译通过。

## git记录
- branch：main
- commit：待提交（本次对话自动提交）

## 代码变更
- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index bb76d23..0fd0eb7 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -4,3 +4,6 @@
 - 项目通过 `run.sh` 启动可执行程序，当前策略已改为“每次启动前强制重新编译”，避免启动到旧构建产物。
 - `run.sh` 会优先使用 `/Applications/Xcode.app/Contents/Developer` 作为 `DEVELOPER_DIR`（若用户未手动设置）。
 - 启动路径通过 `swift build --show-bin-path` 计算，避免手写架构目录导致路径偏差。
+- 挑战记录标题区域已去掉模式/细分 Tag，仅保留标题文本，减少头部视觉干扰。
+- 模式记录每个分桶的最大条数调整为 9，初始化时会对历史数据做排序与截断归一化。
+- 挑战记录行内序号 Tag 通过 `baselineOffset` 与附件 bounds 微调，实现与分数/日期文本的中线对齐。
```

- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 29daa53..4215caa 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -24,8 +24,6 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private struct RecordPanelContext {
         let modeKey: ModeRecordKey
         let detailValue: Int
-        let modeTagText: String
-        let detailTagText: String
 
         var scopeID: String {
             return ModeRecordStore.scopeID(mode: modeKey, detailValue: detailValue)
@@ -270,25 +268,11 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         return makeSectionTitleLabel()
     }()
 
-    private lazy var recordsModeTagView: RecordTagView = {
-        let view = RecordTagView()
-        view.translatesAutoresizingMaskIntoConstraints = false
-        view.isHidden = true
-        return view
-    }()
-
-    private lazy var recordsDetailTagView: RecordTagView = {
-        let view = RecordTagView()
-        view.translatesAutoresizingMaskIntoConstraints = false
-        view.isHidden = true
-        return view
-    }()
-
     private lazy var recordsHeaderStack: NSStackView = {
-        let stack = NSStackView(views: [recordsTitleLabel, recordsModeTagView, recordsDetailTagView])
+        let stack = NSStackView(views: [recordsTitleLabel])
         stack.orientation = .horizontal
         stack.alignment = .centerY
-        stack.spacing = 6
+        stack.spacing = 0
         stack.detachesHiddenViews = true
         stack.translatesAutoresizingMaskIntoConstraints = false
         return stack
@@ -899,26 +883,12 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         guard let context = recordPanelContext(for: snapshot.mode) else {
             recordsCardView.isHidden = true
             recordsTitleLabel.stringValue = localized("panel.records")
-            recordsModeTagView.isHidden = true
-            recordsDetailTagView.isHidden = true
             setRecordsText("")
             return
         }
 
         recordsCardView.isHidden = false
         recordsTitleLabel.stringValue = localized("panel.records")
-        configureRecordTag(
-            recordsModeTagView,
-            text: context.modeTagText,
-            fillColor: NSColor(calibratedRed: 0.96, green: 0.56, blue: 0.18, alpha: 0.26),
-            borderColor: NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.32, alpha: 0.82)
-        )
-        configureRecordTag(
-            recordsDetailTagView,
-            text: context.detailTagText,
-            fillColor: NSColor(calibratedRed: 0.96, green: 0.56, blue: 0.18, alpha: 0.26),
-            borderColor: NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.32, alpha: 0.82)
-        )
 
         let records = recordStore.records(for: context.modeKey, detailValue: context.detailValue)
         guard !records.isEmpty else {
@@ -985,8 +955,11 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         let attachment = NSTextAttachment()
         let image = rankTagImage(rank: rank)
         attachment.image = image
-        attachment.bounds = NSRect(x: 0, y: -1, width: image.size.width, height: image.size.height)
-        return NSAttributedString(attachment: attachment)
+        attachment.bounds = NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
+        let attributed = NSMutableAttributedString(attachment: attachment)
+        // 统一基线，避免序号 Tag 与同一行文本出现“贴底”错位。
+        attributed.addAttribute(.baselineOffset, value: 1, range: NSRange(location: 0, length: attributed.length))
+        return attributed
     }
 
     private func rankTagImage(rank: Int) -> NSImage {
@@ -1059,18 +1032,14 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
             let minutes = max(1, Int((duration / 60).rounded()))
             return RecordPanelContext(
                 modeKey: .scoreAttack,
-                detailValue: minutes,
-                modeTagText: localized("mode.score_attack"),
-                detailTagText: localizedFormat("option.minute_format", minutes)
+                detailValue: minutes
             )
 
         case .speedRun(let targetScore):
             let normalizedTarget = max(1, targetScore)
             return RecordPanelContext(
                 modeKey: .speedRun,
-                detailValue: normalizedTarget,
-                modeTagText: localized("mode.speed_run"),
-                detailTagText: localizedFormat("option.target_format", normalizedTarget)
+                detailValue: normalizedTarget
             )
         }
     }
@@ -1124,16 +1093,6 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         return String(format: format, locale: localizer.locale, arguments: arguments)
     }
 
-    private func configureRecordTag(
-        _ tagView: RecordTagView,
-        text: String,
-        fillColor: NSColor,
-        borderColor: NSColor
-    ) {
-        tagView.configure(text: text, fillColor: fillColor, borderColor: borderColor)
-        tagView.isHidden = false
-    }
-
     private func makeControlTitleLabel() -> NSTextField {
         let label = NSTextField(labelWithString: "")
         label.alignment = .right
@@ -1248,66 +1207,6 @@ private final class ArcadeStageView: NSView {
     }
 }
 
-
-private final class RecordTagView: NSView {
-    private let insets = NSEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
-    private let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .heavy)
-    private var text: String = ""
-    private var fillColor = NSColor(calibratedRed: 0.25, green: 0.24, blue: 0.32, alpha: 0.95)
-    private var borderColor = NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.62, alpha: 0.95)
-
-    override var isFlipped: Bool {
-        return true
-    }
-
-    override var intrinsicContentSize: NSSize {
-        let textSize = (text as NSString).size(withAttributes: [.font: font])
-        return NSSize(
-            width: ceil(textSize.width + insets.left + insets.right),
-            height: ceil(textSize.height + insets.top + insets.bottom)
-        )
-    }
-
-    func configure(text: String, fillColor: NSColor, borderColor: NSColor) {
-        self.text = text
-        self.fillColor = fillColor
-        self.borderColor = borderColor
-        invalidateIntrinsicContentSize()
-        needsDisplay = true
-    }
-
-    override func draw(_ dirtyRect: NSRect) {
-        super.draw(dirtyRect)
-
-        guard !text.isEmpty else { return }
-
-        let pillRect = bounds.insetBy(dx: 0.5, dy: 0.5)
-        let path = NSBezierPath(roundedRect: pillRect, xRadius: 4, yRadius: 4)
-        fillColor.setFill()
-        path.fill()
-        borderColor.setStroke()
-        path.lineWidth = 1
-        path.stroke()
-
-        let paragraph = NSMutableParagraphStyle()
-        paragraph.alignment = .center
-        let attributes: [NSAttributedString.Key: Any] = [
-            .font: font,
-            .foregroundColor: NSColor.white.withAlphaComponent(0.96),
-            .paragraphStyle: paragraph
-        ]
-
-        let textSize = (text as NSString).size(withAttributes: attributes)
-        let textRect = NSRect(
-            x: insets.left,
-            y: floor((bounds.height - textSize.height) / 2),
-            width: max(1, bounds.width - insets.left - insets.right),
-            height: textSize.height
-        )
-        (text as NSString).draw(in: textRect, withAttributes: attributes)
-    }
-}
-
 private final class PixelFrameCardView: NSView {
     private let accentColor: NSColor
```

- Sources/ModeRecordStore.swift
```diff
diff --git a/Sources/ModeRecordStore.swift b/Sources/ModeRecordStore.swift
index f6e42e7..4e1baa9 100644
--- a/Sources/ModeRecordStore.swift
+++ b/Sources/ModeRecordStore.swift
@@ -23,8 +23,8 @@ final class ModeRecordStore {
 
     private let storageKey = "mode_records_v1"
     private let seedVersionKey = "mode_records_seed_version"
-    private let seedVersion = 3
-    private let maxRecordsPerScope = 10
+    private let seedVersion = 4
+    private let maxRecordsPerScope = 9
     private let scoreAttackDurations = [1, 2, 3]
     private let speedRunTargets = [300, 600, 900]
     private let defaults: UserDefaults
@@ -33,6 +33,9 @@ final class ModeRecordStore {
     init(defaults: UserDefaults = .standard) {
         self.defaults = defaults
         load()
+        if normalizeBucketsToMaxCount() {
+            save()
+        }
         seedTestRecordsIfNeeded()
     }
@@ -175,6 +178,34 @@ final class ModeRecordStore {
         }
     }
 
+    private func normalizeBucketsToMaxCount() -> Bool {
+        var changed = false
+
+        for (scopeID, bucket) in recordsByScope {
+            guard let mode = modeKey(forScopeID: scopeID) else { continue }
+
+            var normalized = bucket
+            sortAndTrim(&normalized, for: mode)
+            if normalized.map(\.id) != bucket.map(\.id) {
+                changed = true
+            }
+
+            recordsByScope[scopeID] = normalized
+        }
+
+        return changed
+    }
+
+    private func modeKey(forScopeID scopeID: String) -> ModeRecordKey? {
+        if scopeID.hasPrefix("\(ModeRecordKey.scoreAttack.rawValue)_") || scopeID == ModeRecordKey.scoreAttack.rawValue {
+            return .scoreAttack
+        }
+        if scopeID.hasPrefix("\(ModeRecordKey.speedRun.rawValue)_") || scopeID == ModeRecordKey.speedRun.rawValue {
+            return .speedRun
+        }
+        return nil
+    }
+
     private func compareScoreAttackRecords(_ lhs: ModeRecord, _ rhs: ModeRecord) -> Bool {
         if lhs.score != rhs.score {
             return lhs.score > rhs.score
```

## 测试用例
### TC-001 标题后 Tag 去除
- 类型：UI测试
- 前置条件：切换到竞分或竞速模式
- 操作步骤：查看挑战记录卡片标题区域
- 预期结果：仅显示“挑战记录”标题，不再出现模式/细分 Tag

### TC-002 记录上限 9 条
- 类型：功能测试
- 前置条件：存在超过 9 条的历史记录或导入旧数据
- 操作步骤：启动应用并查看任一模式分组记录
- 预期结果：每个模式分组最多显示 9 条

### TC-003 序号 Tag 中线对齐
- 类型：UI测试
- 前置条件：挑战记录存在至少 1 条
- 操作步骤：观察序号 Tag 与同一行分数/日期的垂直对齐
- 预期结果：序号 Tag 与文本中线一致，不再出现明显“贴底”

### TC-004 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- 预期结果：构建成功
