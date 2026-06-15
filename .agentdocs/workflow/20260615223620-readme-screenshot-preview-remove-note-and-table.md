# README 截图预览去掉提示文案与表格布局

## 背景与目标
- 当前中英文 README 的截图预览区虽然已经只保留两类截图，但顶部仍有一段提示文案，且图片区仍采用表格布局。
- 本次目标是让截图预览更像正式展示页：去掉说明提示，并将表格改为纵向分段展示。

## 约束与原则
- 中英文 README 要同步调整，保持展示结构一致。
- 本次不改图片资源，只改展示结构与说明文案。
- 保持截图区信息简洁，每张图只保留一个标题和一句说明。

## 阶段与 TODO
- [x] 检查当前中英文截图预览结构。
- [x] 移除中文 README 中的顶部提示文案与表格布局。
- [x] 移除英文 README 中的顶部提示文案与表格布局。
- [x] 更新索引与项目认知，并完成文档自检。

## 关键风险
- 如果只移除表格但保留大段说明，截图区仍会显得偏“说明文档”而不够像展示页，因此本次一并去掉顶部提示。
- 如果中英文只改一边，视觉结构会继续不统一，因此两份 README 同步处理。

## 当前进展
- 中英文 README 的截图预览区都已改为“标题 + 图片 + 说明”结构。
- 截图区顶部的资源说明提示已完全移除，阅读节奏更直接。

## 代码变更
- `README.md`
```diff
--- a/README.md
+++ b/README.md
@@ -28,11 +28,13 @@
 ## 截图预览
 
- > 当前已补上文档资源目录与占位图；后续你只需要替换 `docs/screenshots/` 下的同名文件，或同步改链接为正式截图即可。
- 
- | 桌面主界面 | Touch Bar 棋盘 |
- | --- | --- |
- | ![桌面主界面占位图](docs/screenshots/desktop-main.svg) | ![Touch Bar 棋盘占位图](docs/screenshots/touchbar-board.gif) |
- 
- - **桌面主界面**：建议展示设置、时间与得分、挑战记录、玩法说明四大模块。
- - **Touch Bar 棋盘**：建议展示 16 格主战场、交换动作、消除反馈与补位节奏。
+### 桌面主界面
+
+![桌面主界面占位图](docs/screenshots/desktop-main.svg)
+
+建议展示设置、时间与得分、挑战记录、玩法说明四大模块。
+
+### Touch Bar 棋盘
+
+![Touch Bar 棋盘占位图](docs/screenshots/touchbar-board.gif)
+
+建议展示 16 格主战场、交换动作、消除反馈与补位节奏。
```

- `README.en.md`
```diff
--- a/README.en.md
+++ b/README.en.md
@@ -28,11 +28,13 @@
 ## Screenshot Preview
 
- > The repository now includes a dedicated documentation asset folder with placeholder images. Later, you can simply replace the files in `docs/screenshots/`, or update the links here to point to your final screenshots.
- 
- | Desktop Window | Touch Bar Board |
- | --- | --- |
- | ![Desktop window placeholder](docs/screenshots/desktop-main.svg) | ![Touch Bar board placeholder](docs/screenshots/touchbar-board.gif) |
- 
- - **Desktop Window**: ideally shows the settings panel, time and score panel, challenge records, and mode briefing together.
- - **Touch Bar Board**: ideally shows the 16-cell battlefield, swap actions, clear feedback, and refill rhythm.
+### Desktop Window
+
+![Desktop window placeholder](docs/screenshots/desktop-main.svg)
+
+Ideally shows the settings panel, time and score panel, challenge records, and mode briefing together.
+
+### Touch Bar Board
+
+![Touch Bar board placeholder](docs/screenshots/touchbar-board.gif)
+
+Ideally shows the 16-cell battlefield, swap actions, clear feedback, and refill rhythm.
```

## 测试用例
### TC-001 中文 README 截图区改为分段展示
- 类型：文档检查
- 优先级：低
- 关联模块：`README.md`
- 前置条件：打开中文 README
- 操作步骤：
1. 定位到“截图预览”章节
2. 检查是否还存在提示文案
3. 检查是否还存在表格结构
- 预期结果：
- 不再出现顶部提示文案
- 不再使用表格布局
- 每张图按“标题 + 图片 + 说明”展示
- 是否通过：已通过

### TC-002 英文 README 截图区改为分段展示
- 类型：文档检查
- 优先级：低
- 关联模块：`README.en.md`
- 前置条件：打开英文 README
- 操作步骤：
1. 定位到 `Screenshot Preview`
2. 检查是否还存在提示文案
3. 检查是否还存在表格结构
- 预期结果：
- 不再出现顶部提示文案
- 不再使用表格布局
- 每张图按 `title + image + short note` 展示
- 是否通过：已通过
