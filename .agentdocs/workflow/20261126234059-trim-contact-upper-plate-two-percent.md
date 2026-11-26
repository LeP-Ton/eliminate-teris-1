# 联系卡上板从右侧再收短 2%

## 背景与目标

- 以上一轮的上板宽度为基准，再缩短 2%。沿用上板左缘和纵向位置。

## 实现

- 原上板宽度乘以 0.98。上板内容按更新后的可用宽度绘制，下板继续按既有几何定位。

## 验证

- 在 302 × 110、500 × 148 和 302 × 165 点联系卡检查宽度比例、左缘与纵向锚点，并核对新增露出的狭带与同高度下板渐隐一致。
- 检查标准大厅原生截图。`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 105 项，全部通过。
- 手动验证可运行 `./run.sh`，缩放窗口查看联系卡上板右缘和下板渐隐。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 5bb55cc8f6d8619f99ae5a995d7b77e8e53a0e0b..155e046e71a8a4a1c096f6dde46d8777472b50f1 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261126234059-trim-contact-upper-plate-two-percent.md` - 会话-87 起以上层当前宽度为基准从右侧再收短 2%。
 `workflow/20261126232129-align-contact-lower-plate-top.md` - 会话-85 起将联系卡下板右斜边收窄 8%，并沿原斜率向上延伸至与上板齐平。
 `workflow/20261126230618-reveal-contact-lower-plate-top-right.md` - 会话-83 起缩短联系卡上板右缘，让下板右上渐隐斜面露出更多。
 `workflow/20261126224828-refine-contact-stack-overlap-and-fade.md` - 会话-81 起向交界延伸联系卡上下板，让下板右上渐隐，并将 GitHub 反馈改为无边框链接。
@@ -114,6 +115,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要核对联系卡上板额外收短 2% 的宽度基准或新露出的渐隐区域时，读取 `20261126234059-trim-contact-upper-plate-two-percent.md`。
 - 需要调整联系卡下板右斜边、上下板顶部对齐或窄高窗口外缘约束时，读取 `20261126232129-align-contact-lower-plate-top.md`。
 - 需要调整联系卡上板右侧宽度或下板右上露出面积时，读取 `20261126230618-reveal-contact-lower-plate-top-right.md`。
 - 需要调整联系卡两块斜板的重叠、下板顶部透明度或反馈链接边框时，读取 `20261126224828-refine-contact-stack-overlap-and-fade.md`。
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index f3b236b955b4d9fcb6819e6b058d6a87e8fb6319..2edcb372f790c9e68ebb3a5550011ba40e378331 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -836,8 +836,8 @@ final class HomeContactPanelView: NSView {
         let height = bounds.height * 0.70
         // 只收窄右边，露出更宽的下板右上渐隐区域。
         let rightTrim = min(26, bounds.width * 0.05)
-        let width = max(0, lower.width + HomeDashboardStyle.edgeOffset(for: height - lower.height) - rightTrim)
-        return NSRect(x: bounds.minX, y: bounds.minY, width: width, height: height)
+        let width = lower.width + HomeDashboardStyle.edgeOffset(for: height - lower.height) - rightTrim
+        return NSRect(x: bounds.minX, y: bounds.minY, width: max(0, width * 0.98), height: height)
     }
 
     var lowerPlateRect: NSRect {
diff --git a/Tests/HomeContactPanelLayerTests.swift b/Tests/HomeContactPanelLayerTests.swift
index 64752bc38e38bf3cacd4d421d9cb16be216486cd..ecc2b0746622d4e93df7609f7a84921e4f5f7676 100644
--- a/Tests/HomeContactPanelLayerTests.swift
+++ b/Tests/HomeContactPanelLayerTests.swift
@@ -34,7 +34,7 @@ final class HomeContactPanelLayerTests: XCTestCase {
             let oldLowerWidth = card.bounds.maxX - lower.minX
             let oldUpperWidth = oldLowerWidth + HomeDashboardStyle.edgeOffset(for: upper.height - oldLowerHeight)
                 - min(26, size.width * 0.05)
-            XCTAssertEqual(upper.width, oldUpperWidth, accuracy: 0.01, context)
+            XCTAssertEqual(upper.width, oldUpperWidth * 0.98, accuracy: 0.01, context)
 
             // 沿用原下板左斜边，并在旧上沿高度核对右边的 8% 内收。
             let oldTopEdges = edges(of: lower, at: oldLowerTop)
@@ -90,7 +90,11 @@ final class HomeContactPanelLayerTests: XCTestCase {
             let beginningPoint = lowerRight(at: 0.12)
             let beginning = try alpha(at: beginningPoint)
             let nearJoin = try alpha(at: lowerRight(at: 0.88))
-            let stillCovered = NSPoint(x: edges(of: upper, at: beginningPoint.y).right - 3, y: beginningPoint.y)
+            let upperRight = edges(of: upper, at: beginningPoint.y).right
+            // 在额外收短的狭带中心采样，应露出同高度的下板渐隐。
+            let newlyExposed = NSPoint(x: upperRight + (oldUpperWidth - upper.width) / 2, y: beginningPoint.y)
+            XCTAssertEqual(try alpha(at: newlyExposed), beginning, accuracy: 0.05, context)
+            let stillCovered = NSPoint(x: upperRight - 3, y: beginningPoint.y)
             XCTAssertGreaterThan(try alpha(at: stillCovered), 0.90, context)
             let bottomY = upper.maxY + (lower.maxY - upper.maxY) * 0.75
             let bottom = NSPoint(x: edges(of: lower, at: bottomY).left + 18, y: bottomY)
```
