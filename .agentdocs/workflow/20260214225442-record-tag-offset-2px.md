# 序号 Tag 下移量从 4px 调整为 2px

## 背景与目标
- 用户反馈序号 Tag 下移 4px 后仍不理想，要求改为下移 2px。
- 目标：减轻序号 Tag 的下沉幅度，使其更贴合同一行文本中线。

## 约束与原则
- 仅调整序号 Tag 垂直偏移量，不改动记录排序、文本样式与其它布局。
- 保持当前模式记录上限与 seed 分布策略不变。

## 阶段与 TODO
- [x] 将附件 Y 偏移从 -4 调整为 -2。
- [x] 更新项目认知与索引。
- [x] 编译验证。

## 关键风险
- 仍可能在不同屏幕缩放比例下出现轻微视觉偏差，需要实机确认。

## 当前进展
- 序号 Tag 的垂直偏移已调整为 `attachment.bounds.y = -2`。
- 构建验证通过。

## git记录
- branch：main
- commit：5be59e6 微调挑战记录序号标签下移为2px

## 代码变更
- AGENTS.md
```diff
@@ -7,5 +7,5 @@
 - 挑战记录标题区域已去掉模式/细分 Tag，仅保留标题文本，减少头部视觉干扰。
 - 模式记录每个分桶的最大条数调整为 9，初始化时会对历史数据做排序与截断归一化。
 - 挑战记录行内序号 Tag 通过 `baselineOffset` 与附件 bounds 微调，实现与分数/日期文本的中线对齐。
-- 序号 Tag 当前按视觉反馈下移 4px（`attachment.bounds.y = -4`）以贴齐同一行文本。
+- 序号 Tag 当前按视觉反馈下移 2px（`attachment.bounds.y = -2`）以贴齐同一行文本。
 - 测试 seed 数据采用“9条 + 0/1条混合”策略：竞分 1分钟=9、2分钟=1、3分钟=0；竞速 300分=9、600分=1、900分=0。
```

- Sources/GameViewController.swift
```diff
@@ -955,8 +955,8 @@
     private func rankTagAttributedText(rank: Int) -> NSAttributedString {
         let attachment = NSTextAttachment()
         let image = rankTagImage(rank: rank)
         attachment.image = image
-        // 根据视觉反馈，将序号 Tag 整体向下平移 4px，避免与同行文本中线错位。
-        attachment.bounds = NSRect(x: 0, y: -4, width: image.size.width, height: image.size.height)
+        // 根据视觉反馈，将序号 Tag 整体向下平移 2px，避免与同行文本中线错位。
+        attachment.bounds = NSRect(x: 0, y: -2, width: image.size.width, height: image.size.height)
         return NSAttributedString(attachment: attachment)
     }
```

## 测试用例
### TC-001 序号 Tag 纵向偏移验证
- 类型：UI测试
- 前置条件：挑战记录至少一条
- 操作步骤：观察序号 Tag 与同一行文本中线关系
- 预期结果：较 -4px 版本更居中，不再过度下沉

### TC-002 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- 预期结果：构建成功
