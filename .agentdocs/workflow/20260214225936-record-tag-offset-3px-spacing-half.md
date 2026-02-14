# 序号 Tag 下移 3px 与挑战记录行间距减半

## 背景与目标
- 用户要求：
  1. 序号 Tag 下沉幅度从 2px 调整为 3px。
  2. 每条挑战记录间距减少 50%。

## 约束与原则
- 仅调整挑战记录行内排版参数，不改动记录排序与模式逻辑。
- 保持现有序号 Tag 图片绘制与文本结构。

## 阶段与 TODO
- [x] 序号 Tag 垂直偏移改为 -3。
- [x] 挑战记录行间距从 7 降到 3.5（50%）。
- [x] 更新项目认知与文档索引。
- [x] 完成编译验证。

## 关键风险
- AppKit 字体渲染在不同缩放下可能有细微偏差，若仍有视觉误差可继续微调 1px。

## 当前进展
- 序号 Tag 已改为下移 3px。
- 记录行间距已减半。
- 构建通过。

## git记录
- branch：main
- commit：9c785ff 微调挑战记录序号偏移并收紧行间距

## 代码变更
- AGENTS.md
```diff
@@ -7,5 +7,6 @@
 - 挑战记录标题区域已去掉模式/细分 Tag，仅保留标题文本，减少头部视觉干扰。
 - 模式记录每个分桶的最大条数调整为 9，初始化时会对历史数据做排序与截断归一化。
 - 挑战记录行内序号 Tag 通过 `baselineOffset` 与附件 bounds 微调，实现与分数/日期文本的中线对齐。
-- 序号 Tag 当前按视觉反馈下移 2px（`attachment.bounds.y = -2`）以贴齐同一行文本。
+- 序号 Tag 当前按视觉反馈下移 3px（`attachment.bounds.y = -3`）以贴齐同一行文本。
 - 测试 seed 数据采用“9条 + 0/1条混合”策略：竞分 1分钟=9、2分钟=1、3分钟=0；竞速 300分=9、600分=1、900分=0。
+- 挑战记录行间距已缩减 50%，`paragraphStyle.lineSpacing` 从 `7` 调整为 `3.5`。
```

- Sources/GameViewController.swift
```diff
@@ -908,7 +908,8 @@
         paragraphStyle.lineBreakMode = .byTruncatingTail
         paragraphStyle.minimumLineHeight = 24
         paragraphStyle.maximumLineHeight = 24
-        paragraphStyle.lineSpacing = 7
+        // 记录项行间距缩减 50%，从 7 调整为 3.5。
+        paragraphStyle.lineSpacing = 3.5
@@ -955,8 +956,8 @@
         let attachment = NSTextAttachment()
         let image = rankTagImage(rank: rank)
         attachment.image = image
-        // 根据视觉反馈，将序号 Tag 整体向下平移 2px，避免与同行文本中线错位。
-        attachment.bounds = NSRect(x: 0, y: -2, width: image.size.width, height: image.size.height)
+        // 根据视觉反馈，将序号 Tag 整体向下平移 3px，避免与同行文本中线错位。
+        attachment.bounds = NSRect(x: 0, y: -3, width: image.size.width, height: image.size.height)
         return NSAttributedString(attachment: attachment)
     }
```

## 测试用例
### TC-001 序号 Tag 偏移验证
- 类型：UI测试
- 前置条件：挑战记录至少有一条
- 操作步骤：观察序号 Tag 与同行分数/日期文本
- 预期结果：Tag 较 2px 方案下沉 1px，贴合中线

### TC-002 行间距减半验证
- 类型：UI测试
- 前置条件：挑战记录至少有多条
- 操作步骤：对比相邻记录行距
- 预期结果：行距由原 7 缩减到 3.5，视觉更紧凑

### TC-003 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- 预期结果：构建成功
