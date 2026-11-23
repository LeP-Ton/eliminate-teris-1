# 历史首页设计稿插画

这组透明图像来自浅色版首页设计稿，保留用于追溯与像素校验。深色版首页由 `HomeLobbyArtwork` 使用 AppKit 绘制游戏方块、反光与触控栏示意。

## 来源与提取
- 原始设计稿：`docs/design/home-reference.png`，1536×1024 像素。
- 提取脚本：`Tools/extract-home-design.swift`，使用系统 AppKit 直接读取原稿像素。
- 四个方块各自包含原稿中的材质、投影与装饰短线；交换箭头也来自原稿。
- 脚本只移除纸纹背景，对低透明投影反解背景混色，方块和短线主体保留原始像素。
- 每张图为透明 PNG；原始尺寸分别为橙色 190×150、蓝色 167×150、绿色 197×165、红色 207×160，箭头 75×43。

## 历史素材
- 旧版将方块按原稿坐标整体等比缩放，各自浮动，交换箭头保持原位。
- 测试通过 `GameResourceLocator` 从应用资源包读取这些图片，逐像素校验提取结果。
- 先前生成的近似插画保存在 `docs/design/rejected-studio-artwork.png`，可供回看。

## 重新提取

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift Tools/extract-home-design.swift docs/design/home-reference.png Sources/Resources/Artwork
```

需保留原始 1536×1024 尺寸，不能先缩放输入设计稿。自动化测试会对比提取图片中的不透明像素与原稿，避免出现无意重绘。
