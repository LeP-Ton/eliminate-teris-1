# 截图资源说明

本目录用于存放 `README.md` 与 `README.en.md` 展示用的截图资源。

## 当前文件
- `desktop-main.svg`：桌面主界面占位图
- `touchbar-board.gif`：Touch Bar 棋盘预览图

## 后续替换建议
1. 如果你已经有正式截图，优先保留这两个逻辑位置：
   - 桌面主界面
   - Touch Bar 主战场
2. 如果你想继续沿用当前 README 链接：
   - 可以直接替换为同名资源文件
3. 如果你更想使用 `.png` 或 `.jpg`：
   - 把正式图片放到本目录
   - 再同步修改 `README.md` 与 `README.en.md` 中的图片链接

## 推荐命名
- `desktop-main.png`
- `touchbar-board.png`

## 维护原则
- README 展示图只放文档资源，不放进 `Sources/Resources/`，避免被当成应用运行资源一起打包。
