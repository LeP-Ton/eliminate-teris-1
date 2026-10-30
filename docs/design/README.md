# 首页设计参考

- `home-reference.png`：用户最初提供的 1536×1024 首页设计稿，作为当前主插画的直接像素来源。
- `rejected-studio-artwork.png`：此前生成但未能对齐设计稿的近似素材，仅保留作变更追溯，不参与应用打包。
- 当前应用使用 `Sources/Resources/Artwork/home-design-*.png`，由 `Tools/extract-home-design.swift` 从原设计稿直接提取。
- 设计稿整体不作为界面背景使用；文字、按钮、统计、模式选择与成就仍为可交互的原生视图。
