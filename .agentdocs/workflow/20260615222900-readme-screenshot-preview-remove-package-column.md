# README 截图预览移除打包产物栏位

## 背景与目标
- 当前中英文 README 的截图预览区包含三栏：桌面主界面、Touch Bar 棋盘、打包产物。
- 本次目标是让截图预览更聚焦于游戏本体展示，因此移除“打包产物”部分，只保留桌面界面与 Touch Bar 棋盘两类截图。

## 约束与原则
- 中英文 README 要同步调整，保持结构一致。
- 截图资源说明文档也要同步收敛，避免仍保留“打包产物”这一已废弃说明。
- 本次不处理实际文件删除，仅先移除 README 展示与说明层面的该栏位。

## 阶段与 TODO
- [x] 检查当前中英文 README 的截图预览结构。
- [x] 从 `README.md` 中移除“打包产物”一栏及说明文字。
- [x] 从 `README.en.md` 中移除 `Package Preview` 一栏及说明文字。
- [x] 更新 `docs/screenshots/README.md`，改为仅说明两类截图资源。
- [x] 更新索引与项目认知，并完成文档自检。

## 关键风险
- 如果只改 README 不改截图资源说明文档，后续维护者仍会误以为需要保留三类截图。
- 如果直接删除 `docs/screenshots/package-preview.svg`，可能影响后续回看历史；因此本次先只移除展示层与说明层引用。

## 当前进展
- 中英文 README 截图预览现已统一为两栏布局。
- 截图资源说明文档已从“三类截图”收敛为“两类截图”，并同步纠正 Touch Bar 资源文件名为 `touchbar-board.gif`。

## 代码变更
- `README.md`
```diff
--- a/README.md
+++ b/README.md
@@ -28,10 +28,9 @@
 ## 截图预览
 
 > 当前已补上文档资源目录与占位图；后续你只需要替换 `docs/screenshots/` 下的同名文件，或同步改链接为正式截图即可。
 
-| 桌面主界面 | Touch Bar 棋盘 | 打包产物 |
-| --- | --- | --- |
-| ![桌面主界面占位图](docs/screenshots/desktop-main.svg) | ![Touch Bar 棋盘占位图](docs/screenshots/touchbar-board.gif) | ![打包产物占位图](docs/screenshots/package-preview.svg) |
+| 桌面主界面 | Touch Bar 棋盘 |
+| --- | --- |
+| ![桌面主界面占位图](docs/screenshots/desktop-main.svg) | ![Touch Bar 棋盘占位图](docs/screenshots/touchbar-board.gif) |
 
 - **桌面主界面**：建议展示设置、时间与得分、挑战记录、玩法说明四大模块。
 - **Touch Bar 棋盘**：建议展示 16 格主战场、交换动作、消除反馈与补位节奏。
- - **打包产物**：建议展示 `.app`、`.dmg` 或 `.zip` 的最终分发形态，方便玩家快速理解如何安装体验。
```

- `README.en.md`
```diff
--- a/README.en.md
+++ b/README.en.md
@@ -28,10 +28,9 @@
 ## Screenshot Preview
 
 > The repository now includes a dedicated documentation asset folder with placeholder images. Later, you can simply replace the files in `docs/screenshots/`, or update the links here to point to your final screenshots.
 
-| Desktop Window | Touch Bar Board | Package Preview |
-| --- | --- | --- |
-| ![Desktop window placeholder](docs/screenshots/desktop-main.svg) | ![Touch Bar board placeholder](docs/screenshots/touchbar-board.gif) | ![Packaged app placeholder](docs/screenshots/package-preview.svg) |
+| Desktop Window | Touch Bar Board |
+| --- | --- |
+| ![Desktop window placeholder](docs/screenshots/desktop-main.svg) | ![Touch Bar board placeholder](docs/screenshots/touchbar-board.gif) |
 
 - **Desktop Window**: ideally shows the settings panel, time and score panel, challenge records, and mode briefing together.
 - **Touch Bar Board**: ideally shows the 16-cell battlefield, swap actions, clear feedback, and refill rhythm.
- - **Package Preview**: ideally shows the final `.app`, `.dmg`, or `.zip` distribution format so players can understand installation at a glance.
```

- `docs/screenshots/README.md`
```diff
--- a/docs/screenshots/README.md
+++ b/docs/screenshots/README.md
@@ -3,22 +3,19 @@
 本目录用于存放 `README.md` 与 `README.en.md` 展示用的截图资源。
 
 ## 当前文件
 - `desktop-main.svg`：桌面主界面占位图
- - `touchbar-board.svg`：Touch Bar 棋盘占位图
- - `package-preview.svg`：打包产物占位图
+- `touchbar-board.gif`：Touch Bar 棋盘预览图
 
 ## 后续替换建议
-1. 如果你已经有正式截图，优先保留这三个逻辑位置：
+1. 如果你已经有正式截图，优先保留这两个逻辑位置：
    - 桌面主界面
    - Touch Bar 主战场
-   - 打包产物或安装形态
 2. 如果你想继续沿用当前 README 链接：
-   - 可以直接把占位图替换为同名 `.svg`
+   - 可以直接替换为同名资源文件
 3. 如果你更想使用 `.png` 或 `.jpg`：
    - 把正式图片放到本目录
    - 再同步修改 `README.md` 与 `README.en.md` 中的图片链接
 
 ## 推荐命名
 - `desktop-main.png`
 - `touchbar-board.png`
- - `package-preview.png`
```

## 测试用例
### TC-001 中文 README 截图预览去掉打包产物
- 类型：文档检查
- 优先级：低
- 关联模块：`README.md`
- 前置条件：打开中文 README
- 操作步骤：
1. 定位到“截图预览”章节
2. 检查表格列数
3. 检查说明 bullet 数量
- 预期结果：
- 只保留“桌面主界面”和“Touch Bar 棋盘”两栏
- 不再出现“打包产物”文案
- 是否通过：已通过

### TC-002 英文 README 截图预览去掉 Package Preview
- 类型：文档检查
- 优先级：低
- 关联模块：`README.en.md`
- 前置条件：打开英文 README
- 操作步骤：
1. 定位到 `Screenshot Preview`
2. 检查表格列数
3. 检查说明 bullet 数量
- 预期结果：
- 只保留 `Desktop Window` 和 `Touch Bar Board`
- 不再出现 `Package Preview`
- 是否通过：已通过
