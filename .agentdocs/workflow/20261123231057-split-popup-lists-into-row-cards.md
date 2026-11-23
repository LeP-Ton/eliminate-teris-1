# 将弹窗列表拆为逐条平行四边形卡片

## 背景与目标

- 会话-16 至会话-18 根据挑战记录截图，将较高的列表外框改为每条一个平行四边形。各行使用相同起点，避免名次与日期随高度向左错开。
- 玩法教学、当前挑战记录和历史记录采用同一布局原则。已有独立卡片的模式列表与成就详情沿用对应布局。

## 完成情况

- [x] 挑战记录的表头与每条数据各用一张独立卡片，以间隙分隔。共享行高、留白及名次、消除数与日期列宽。
- [x] 历史记录保留规则分组，组内每条记录分别呈现名次、结果和日期。原有历史入口、排行与存档数据继续沿用。
- [x] 三个教学步骤各用一张卡片，编号、标题、示意图和说明归在各自步骤内。
- [x] 无记录时显示一张空态卡。设置、模式说明和成就窗口继续使用共享斜边主题。

## 测试方法

- 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，验证新旧记录、并列名次、逐卡排版、五语言与宽窄窗口。90 项测试全部通过。
- 手动运行 `./run.sh` 后打开「挑战记录」，切换限时与限步，并查看旧规则记录。再打开「玩法说明」，核对三个教学步骤是否各在独立卡片中。

## 代码变更


```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 021351643a97b1c5a23fdc7e639d765571ea403c..8cf91f24b96c0438aefd69079055b295d012366f 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261123231057-split-popup-lists-into-row-cards.md` - 会话-16 至会话-18 将挑战记录、旧规则记录和玩法教学按条目拆为独立斜边卡，记录表头和数据保持列对齐。
 `workflow/20261123215822-restore-popup-parallelogram-borders.md` - 会话-12 至会话-15 恢复辅助弹窗卡片的整条斜边，逐行给文案和表格留白。含宽窄原生渲染与本轮增量 diff。
 `workflow/20261123092817-unify-lobby-and-panel-slants.md` - 会话-9 至会话-11 统一大厅和弹窗的斜边与文字，修正等宽统计格、斜切进度填充和滑块动画。含实际预览、回归与本轮增量 diff。
 `workflow/20261123082529-match-reference-rule-and-stat-card.md` - 会话-6 至会话-8 按参考图坐标还原规则背板、总数前板和四张分类斜卡。含双边暗缝像素回归与本轮增量 diff。
@@ -101,6 +102,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整弹窗逐行卡片、记录表头与列宽、历史记录分组或教学卡片间距时，读取 `20261123231057-split-popup-lists-into-row-cards.md`。
 - 需要调整玩法、设置、挑战记录或成就弹窗的完整平行四边形和内部行布局时，读取 `20261123215822-restore-popup-parallelogram-borders.md`。
 - 需要调整统一斜角、轻斜文字、成就进度的部分填充、等宽消除分格或弹窗分段滑块时，读取 `20261123092817-unify-lobby-and-panel-slants.md`。
 - 需要核对深色大厅规则与消除统计卡的原图尺寸、层间错位、分格暗缝、长数字或转场遮挡时，读取 `20261123082529-match-reference-rule-and-stat-card.md`。
diff --git a/Sources/HomeUtilityPanel.swift b/Sources/HomeUtilityPanel.swift
index e07a71e84a83080f9a3e1df6dfbe906f047b6445..d1cc9c1ca8f27e79e9d2ec79f135bc27a894317d 100644
--- a/Sources/HomeUtilityPanel.swift
+++ b/Sources/HomeUtilityPanel.swift
@@ -104,7 +104,7 @@ final class HomeUtilityPanel: NSWindowController {
         for view in recordBody.arrangedSubviews { recordBody.removeArrangedSubview(view); view.removeFromSuperview() }
         let mode: ModeRecordKey = recordTabs.selectedSegment == 0 ? .timed : .moves
         let entries = recordEntries(mode)
-        for view in [UtilityRecordContent.best(mode: mode, entry: entries.first), UtilityRecordContent.table(mode: mode, entries: entries)] {
+        for view in [UtilityRecordContent.best(mode: mode, entry: entries.first), UtilityRecordContent.table(entries: entries)] {
             recordBody.addArrangedSubview(view); UtilityStyle.fillWidth(view, in: recordBody)
         }
         let sections = store.legacySections()
@@ -120,8 +120,8 @@ final class HomeUtilityPanel: NSWindowController {
             recordBody.addArrangedSubview(historyButton); UtilityStyle.fillWidth(historyButton, in: recordBody)
             if showingHistory {
                 for section in sections {
-                    let card = UtilityRecordContent.legacyTable(section)
-                    recordBody.addArrangedSubview(card); UtilityStyle.fillWidth(card, in: recordBody)
+                    let list = UtilityRecordContent.legacyTable(section)
+                    recordBody.addArrangedSubview(list); UtilityStyle.fillWidth(list, in: recordBody)
                 }
             }
         }
diff --git a/Sources/HomeUtilityViews.swift b/Sources/HomeUtilityViews.swift
index 6a784d3898d7b2ba51977ac4501941de4e6a71cb..498c4129c059c7b01b1155453df84cb52639721d 100644
--- a/Sources/HomeUtilityViews.swift
+++ b/Sources/HomeUtilityViews.swift
@@ -271,7 +271,7 @@ final class UtilityLessonArtwork: NSView {
 enum UtilityRulesContent {
     static func populate(_ page: UtilityPageView, mode: HomeGameMode) {
         page.removeSections()
-        var lessons: [NSView] = []
+        let lessons = UtilityStyle.stack([], spacing: 8)
         for step in 0..<3 {
             let number = UtilityStyle.label(String(format: "%02d", step + 1), size: 13, weight: .heavy, color: HomeDashboardStyle.cyan)
             number.widthAnchor.constraint(equalToConstant: 25).isActive = true
@@ -282,14 +282,11 @@ enum UtilityRulesContent {
             // 标题和说明各自沿边框排版。说明使用整个横截面，插图不会挤占文案宽度。
             heading.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
             body.heightAnchor.constraint(greaterThanOrEqualToConstant: 25).isActive = true
-            lessons += [heading, body]
-            if step < 2 {
-                let divider = NSBox(); divider.boxType = .separator
-                divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
-                lessons.append(divider)
-            }
+            let stepCard = UtilityCard(rows: [heading, body], padding: 10, spacing: 4)
+            lessons.addArrangedSubview(stepCard)
+            UtilityStyle.fillWidth(stepCard, in: lessons)
         }
-        page.addSection(UtilityCard(rows: lessons, padding: 14, spacing: 7))
+        page.addSection(lessons)
         page.addSection(UtilityStyle.label(UtilityStyle.text("utility.rules.modes"), size: 14, weight: .bold))
         let modes = UtilityStyle.stack([], spacing: 10)
         for candidate in HomeGameMode.allCases {
@@ -333,65 +330,78 @@ enum UtilityRecordContent {
         return UtilityCard(row, accent: HomeDashboardStyle.yellow, padding: 18)
     }
 
-    /// 日期按行宽分配，窄窗仍给名次和消除数量预留位置。
-    static func table(mode: ModeRecordKey, entries: [ModeRecord]) -> NSView {
-        var rows: [NSView] = []
-        let headings = UtilityStyle.stack([
-            UtilityStyle.label(UtilityStyle.text("utility.records.rank"), size: 10, weight: .semibold, color: HomeDashboardStyle.muted),
+    static func table(entries: [ModeRecord]) -> NSView {
+        if entries.isEmpty {
+            let empty = UtilityStyle.stack([
+                UtilityStyle.icon("flag.checkered", color: HomeDashboardStyle.muted, size: 40),
+                UtilityStyle.label(UtilityStyle.text("records.empty"), size: 15, weight: .semibold, alignment: .center),
+                UtilityStyle.label(UtilityStyle.text("utility.records.empty_hint"), size: 12, color: HomeDashboardStyle.muted,
+                                   alignment: .center)
+            ], spacing: 12)
+            empty.alignment = .centerX
+            empty.heightAnchor.constraint(greaterThanOrEqualToConstant: 148).isActive = true
+            return UtilityCard(empty, padding: 16)
+        }
+
+        let headings = recordColumns(
+            UtilityStyle.label(UtilityStyle.text("utility.records.rank"), size: 10, weight: .semibold,
+                               color: HomeDashboardStyle.muted, alignment: .center),
             UtilityStyle.label(UtilityStyle.text("utility.records.result"), size: 10, weight: .semibold, color: HomeDashboardStyle.muted),
             UtilityStyle.label(UtilityStyle.text("utility.records.date"), size: 10, weight: .semibold,
                                color: HomeDashboardStyle.muted, alignment: .right)
-        ], vertical: false, spacing: 8)
-        headings.arrangedSubviews[0].widthAnchor.constraint(equalToConstant: 36).isActive = true
-        headings.arrangedSubviews[2].widthAnchor.constraint(equalTo: headings.widthAnchor, multiplier: 0.43).isActive = true
-        headings.arrangedSubviews[1].setContentHuggingPriority(.defaultLow, for: .horizontal)
-        rows.append(headings)
-        headings.heightAnchor.constraint(equalToConstant: 30).isActive = true
+        )
+        let headerCard = UtilityCard(headings, padding: 7)
+        let cards = UtilityStyle.stack([headerCard], spacing: 7)
+        UtilityStyle.fillWidth(headerCard, in: cards)
         let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
         let ranks = ModeRecordStore.ranks(for: entries)
         for (index, entry) in entries.enumerated() {
-            let divider = NSBox(); divider.boxType = .separator
-            divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
-            rows.append(divider)
             let rank = UtilityRankView(rank: ranks[index])
             rank.translatesAutoresizingMaskIntoConstraints = false
-            NSLayoutConstraint.activate([rank.widthAnchor.constraint(equalToConstant: 36), rank.heightAnchor.constraint(equalToConstant: 30)])
+            rank.heightAnchor.constraint(equalToConstant: 30).isActive = true
             let metric = AchievementText.format("records.metric.cleared", entry.clearedCount)
             let countLabel = UtilityStyle.label(metric, size: 15, weight: ranks[index] == 1 ? .bold : .semibold, monospacedDigits: true)
-            countLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
             let date = UtilityStyle.label(formatter.string(from: Date(timeIntervalSince1970: entry.createdAt)), size: 11,
                                           color: HomeDashboardStyle.muted, alignment: .right)
-            let row = UtilityStyle.stack([rank, countLabel, date], vertical: false, spacing: 8)
-            date.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.43).isActive = true
-            rows.append(row)
-            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
+            let row = recordColumns(rank, countLabel, date)
             row.setAccessibilityLabel("\(ranks[index]). \(metric), \(date.stringValue)")
+            let card = UtilityCard(row, padding: 7)
+            cards.addArrangedSubview(card)
+            UtilityStyle.fillWidth(card, in: cards)
         }
-        if entries.isEmpty {
-            let empty = UtilityStyle.stack([
-                UtilityStyle.icon("flag.checkered", color: HomeDashboardStyle.muted, size: 40),
-                UtilityStyle.label(UtilityStyle.text("records.empty"), size: 15, weight: .semibold, alignment: .center),
-                UtilityStyle.label(UtilityStyle.text("utility.records.empty_hint"), size: 12, color: HomeDashboardStyle.muted,
-                                   alignment: .center)
-            ], spacing: 12)
-            empty.alignment = .centerX
-            rows.append(empty)
-            empty.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
-        }
-        return UtilityCard(rows: rows, padding: 16)
+        return cards
     }
 
     static func legacyTable(_ section: LegacyRecordSection) -> NSView {
         let title = AchievementText.format(section.kind == .scoreAttack ? "utility.records.legacy_score" : "utility.records.legacy_speed", section.ruleValue)
         let heading = UtilityStyle.label(title, size: 13, weight: .bold)
-        var rows: [NSView] = [heading]
+        let cards = UtilityStyle.stack([heading], spacing: 7)
         let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
         for (index, record) in section.entries.enumerated() {
             let metric = section.kind == .scoreAttack ? AchievementText.format("records.metric.score", record.score) : String(format: "%.2f s", record.elapsedTime)
-            let label = UtilityStyle.label("\(index + 1).  \(metric)    \(formatter.string(from: Date(timeIntervalSince1970: record.createdAt)))", size: 12, color: HomeDashboardStyle.muted)
-            rows.append(label)
+            let rank = UtilityStyle.label("\(index + 1).", size: 12, weight: .semibold, alignment: .center, monospacedDigits: true)
+            let result = UtilityStyle.label(metric, size: 14, weight: .semibold, monospacedDigits: true)
+            let date = UtilityStyle.label(formatter.string(from: Date(timeIntervalSince1970: record.createdAt)), size: 11,
+                                          color: HomeDashboardStyle.muted, alignment: .right)
+            let row = recordColumns(rank, result, date)
+            row.setAccessibilityLabel("\(index + 1). \(metric), \(date.stringValue)")
+            let card = UtilityCard(row, padding: 7)
+            cards.addArrangedSubview(card)
+            UtilityStyle.fillWidth(card, in: cards)
         }
-        return UtilityCard(rows: rows, padding: 16, spacing: 8)
+        return cards
+    }
+
+    private static func recordColumns(_ rank: NSView, _ result: NSTextField, _ date: NSTextField) -> NSStackView {
+        let row = UtilityStyle.stack([rank, result, date], vertical: false, spacing: 8)
+        result.setContentHuggingPriority(.defaultLow, for: .horizontal)
+        // 表头与所有记录的高度、内边距和列宽相同，数据位数变化也不会移动列。
+        NSLayoutConstraint.activate([
+            rank.widthAnchor.constraint(equalToConstant: 36),
+            date.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.43),
+            row.heightAnchor.constraint(equalToConstant: 38)
+        ])
+        return row
     }
 }
 
diff --git a/Tests/HomeUtilityPanelTests.swift b/Tests/HomeUtilityPanelTests.swift
index 67b0b262f619709de09cf49afd050366656d42f3..59fc416105032bfe78da8f47112fb46a81b42209 100644
--- a/Tests/HomeUtilityPanelTests.swift
+++ b/Tests/HomeUtilityPanelTests.swift
@@ -107,14 +107,16 @@ final class HomeUtilityPanelTests: AchievementTestCase {
         Localizer.shared.setLanguage(.chineseSimplified)
         let old = LegacyModeRecord(id: "legacy-player-record", score: 450, elapsedTime: 60,
                                    durationMinutes: 1, targetScore: nil, createdAt: 1_793_361_600)
-        let bytes = try JSONEncoder().encode(["score_attack_1": [old]])
+        let previous = LegacyModeRecord(id: "legacy-player-previous", score: 390, elapsedTime: 60,
+                                        durationMinutes: 1, targetScore: nil, createdAt: 1_793_275_200)
+        let bytes = try JSONEncoder().encode(["score_attack_1": [old, previous]])
         defaults.set(bytes, forKey: ModeRecordStore.legacyStorageKey)
         let store = ModeRecordStore(defaults: defaults)
         _ = store.addRecord(mode: .timed, detailValue: 60, clearedCount: 12, swapsUsed: 4, elapsedTime: 60)
         let panel = HomeUtilityPanel(page: "records", store: store)
         defer { panel.close() }
         panel.refresh(mode: .timed, volume: 0.3)
-        let content = try XCTUnwrap(panel.window?.contentView)
+        let content = try XCTUnwrap(panel.window?.contentView as? UtilityPageView)
         XCTAssertTrue(labels(content).contains("12"))
         XCTAssertFalse(labels(content).contains { $0.contains("450") })
         let button = try XCTUnwrap(descendants(content).compactMap { $0 as? HomeButton }.first {
@@ -122,7 +124,10 @@ final class HomeUtilityPanelTests: AchievementTestCase {
         })
         button.performClick(nil)
         content.layoutSubtreeIfNeeded()
-        XCTAssertTrue(labels(content).contains { $0.contains("450") })
+        let historyCards = try [old, previous].map {
+            try card(containing: AchievementText.format("records.metric.score", $0.score), in: content)
+        }
+        try assertStackedCards(historyCards, in: content.document)
         XCTAssertEqual(store.records(for: .timed, detailValue: 60).map(\.clearedCount), [12])
         XCTAssertEqual(defaults.data(forKey: ModeRecordStore.legacyStorageKey), bytes)
         try export(content, name: "utility-records-history")
@@ -152,7 +157,7 @@ final class HomeUtilityPanelTests: AchievementTestCase {
         let store = try recordStore()
         for language in AppLanguage.allCases {
             Localizer.shared.setLanguage(language)
-            let lessonBodies = Set((0..<3).map { AchievementText.string("utility.lesson.\($0).body") })
+            let lessonBodies = (0..<3).map { AchievementText.string("utility.lesson.\($0).body") }
             for page in ["settings", "rules", "records"] {
                 let panel = HomeUtilityPanel(page: page, store: store)
                 defer { panel.close() }
@@ -169,6 +174,15 @@ final class HomeUtilityPanelTests: AchievementTestCase {
                     XCTAssertEqual(content.scroll.contentView.bounds.minY, 0, accuracy: 1, "初次打开应从顶部显示")
                     let cards = descendants(content).compactMap { $0 as? UtilityCard }
                     XCTAssertFalse(cards.isEmpty)
+                    if page == "rules" {
+                        let lessonCards = try lessonBodies.map { try card(containing: $0, in: content) }
+                        try assertStackedCards(lessonCards, in: content.document)
+                        for (index, lessonCard) in lessonCards.enumerated() {
+                            XCTAssertTrue(labels(lessonCard).contains(AchievementText.string("utility.lesson.\(index).title")))
+                        }
+                    } else if page == "records" {
+                        try assertRecordCards(store.records(for: .timed, detailValue: 60), in: content)
+                    }
                     for card in cards {
                         XCTAssertGreaterThan(card.frame.height, 20)
                         XCTAssertGreaterThan(card.frame.width, 200)
@@ -199,6 +213,7 @@ final class HomeUtilityPanelTests: AchievementTestCase {
                     if page == "records" {
                         let tabs = try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementFilterControl }.first)
                         tabs.selectedSegment = 1; tabs.sendAction(tabs.action, to: tabs.target)
+                        try assertRecordCards(store.records(for: .moves, detailValue: 30), in: content)
                         try export(content, name: "utility-records-speed")
                     }
                 }
@@ -230,6 +245,49 @@ final class HomeUtilityPanelTests: AchievementTestCase {
         XCTAssertEqual(content.scroll.contentView.bounds.origin, position)
     }
 
+    private func card(containing text: String, in parent: NSView) throws -> UtilityCard {
+        let label = try XCTUnwrap(descendants(parent).compactMap { $0 as? NSTextField }.first { $0.stringValue == text })
+        let ancestors = sequence(first: label as NSView, next: { $0.superview })
+        return try XCTUnwrap(ancestors.first { $0 is UtilityCard } as? UtilityCard, "该行应有独立卡片 \(text)")
+    }
+
+    private func assertStackedCards(_ cards: [UtilityCard], in document: NSView) throws {
+        XCTAssertEqual(Set(cards.map(ObjectIdentifier.init)).count, cards.count, "每一行要用不同的卡片")
+        let frames = cards.map { document.convert($0.bounds, from: $0) }
+        let first = try XCTUnwrap(frames.first)
+        for frame in frames.dropFirst() {
+            XCTAssertEqual(frame.minX, first.minX, accuracy: 0.5)
+            XCTAssertEqual(frame.width, first.width, accuracy: 0.5)
+        }
+        let gaps = zip(frames, frames.dropFirst()).map { $0.1.minY - $0.0.maxY }
+        let firstGap = try XCTUnwrap(gaps.first)
+        XCTAssertGreaterThan(firstGap, 0, "相邻卡片之间应留有间距")
+        for gap in gaps.dropFirst() { XCTAssertEqual(gap, firstGap, accuracy: 0.5) }
+    }
+
+    private func assertRecordCards(_ records: [ModeRecord], in content: UtilityPageView) throws {
+        let header = try card(containing: AchievementText.string("utility.records.rank"), in: content)
+        let rows = try records.map {
+            try card(containing: AchievementText.format("records.metric.cleared", $0.clearedCount), in: content)
+        }
+        try assertStackedCards([header] + rows, in: content.document)
+        func columns(in card: UtilityCard) throws -> [NSRect] {
+            let row = try XCTUnwrap(card.subviews.compactMap { $0 as? NSStackView }.first)
+            XCTAssertEqual(row.arrangedSubviews.count, 3)
+            // 文本框的外框还包含系统边距，三列按原生布局的对齐框比较。
+            return row.arrangedSubviews.map { column in
+                content.document.convert(column.alignmentRect(forFrame: column.frame), from: column.superview)
+            }
+        }
+        let headerColumns = try columns(in: header)
+        for card in rows {
+            for (column, expected) in zip(try columns(in: card), headerColumns) {
+                XCTAssertEqual(column.minX, expected.minX, accuracy: 1)
+                XCTAssertEqual(column.maxX, expected.maxX, accuracy: 1)
+            }
+        }
+    }
+
     private func assertFullLengthSlantedEdges(of card: UtilityCard) throws {
         let scale: CGFloat = 2
         let bitmap = try XCTUnwrap(NSBitmapImageRep(
```
