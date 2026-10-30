# 首页设计稿插画

当前首页直接使用用户原始设计稿中提取的图像，不重新生成或重绘方块。

## 来源与提取
- 原始设计稿：`docs/design/home-reference.png`，1536×1024 像素。
- 提取脚本：`Tools/extract-home-design.swift`，使用系统 AppKit 直接读取原稿像素。
- 四个方块各自包含原稿中的材质、投影与装饰短线；交换箭头也来自原稿。
- 脚本只移除纸纹背景，对低透明投影反解背景混色，方块和短线主体保留原始像素。
- 每张图为透明 PNG；原始尺寸分别为橙色 190×150、蓝色 167×150、绿色 197×165、红色 207×160，箭头 75×43。

## 布局与运行
- `HomeHeroPieceRenderer` 按原稿坐标整体等比缩放，保持方块宽度、相互距离、箭头和短线的相对位置。
- 四个方块独立浮动，箭头保持原位；减少动态效果开启时停止浮动。
- 图片通过 `GameResourceLocator` 从应用资源 Bundle 读取并缓存，无网络依赖。
- 先前生成的近似插画移至 `docs/design/rejected-studio-artwork.png`，供历史回看，不再进入应用资源 Bundle。

## 重新提取

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift Tools/extract-home-design.swift docs/design/home-reference.png Sources/Resources/Artwork
```

需保留原始 1536×1024 尺寸，不能先缩放输入设计稿。自动化测试会对比提取图片中的不透明像素与原稿，避免出现无意重绘。
