# 游戏界面测试图

这些文件仅用于开发测试与评审，正式应用中没有图标预览按钮或图标预览页面。

## 游戏大厅美术与交互反馈

- [待机首页](lobby-idle.png)展示开局按钮与联系我们卡片的底边对齐，成就之路横跨下方两栏。
- [三种模式新图案](mode-artwork.png)：自由悬浮方块、橙金冲刺秒表、蓝色 30 次行动计数器；展示大图和 24 点小图。
- [实际交互动画](lobby-feedback.gif)：使用真实控件导出的选中辉光、悬停提亮与按压下沉。
- [挑战卡选中动画](challenge-preview.gif)展示限时卡片在一秒内从右侧模式面板后方滑出。卡片从较小、偏窄的形态逐渐放大，侧缘和阴影随转场收拢，最终与模式面板顶边齐平。限步沿用同样动效。
- [限时局内](challenge-timed.png)与[限步局内](challenge-moves.png)在左侧集中显示剩余时间或次数、进度条和消除总数。四类方块等分消除统计右侧区域，每个图标从列左侧起排，数字紧随图标。
- [最后三次行动](lobby-last-moves.png)、[本局结束](lobby-finished.png)：紧张阶段改用红色提示，结束后保留本局结果。
- 模式入口图案不读取本局剩余次数；其中 30 表示固定模式规则。
- 减少动态效果开启时交互立即定位；测试在独立存档和可控时间下生成预览。

重新生成：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameLobbyPresentationTests`。

临时目录中的 `eliminate-lobby-idle-free.png` 对应 `lobby-idle.png`，`eliminate-lobby-timed.png` / `eliminate-lobby-moves.png` 对应两张 `challenge-*.png`；其余 `eliminate-mode-artwork.png`、`eliminate-lobby-feedback.gif`、`eliminate-lobby-last-moves.png`、`eliminate-lobby-finished.png` 去掉 `eliminate-` 前缀后归档。

挑战卡动图为 `eliminate-challenge-preview.gif`，去掉 `eliminate-` 前缀后归档。

## 消除数量、限时与限步

- [限时挑战首页](challenge-timed.png)：固定 60 秒，显示已消除数量与剩余时间。
- [限步挑战首页](challenge-moves.png)：固定 30 次交换，显示已消除数量与剩余次数；思考时间不限。
- 两种挑战只按消除数量排名，相同数量共享名次。
- [历史记录入口效果](utility-records-history.png)：新榜与旧分数/用时分区展示，旧存档保持原样。
- 成就页条件已改用消除数量，已获得的旧成就仍保留。

## 触控栏滑动开局

- [查看开局动画](touchbar-start.gif)：待机滑轨与按钮触发的从左到右自动显现，使用真实 `GameTouchBarView` 导出。
- [查看三种状态](touchbar-start-states.png)：等待开始、滑动半程、正式 16 格棋盘。
- 开局动画结束后才计时；未完成松手回弹，开局手指抬起后才接受交换。减少动态效果开启时跳过自动过渡。
- 测试使用独立存档和可控时钟，不挂载玩家的真实 Touch Bar。

重新生成：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameStartSequenceTests`。

将临时目录中的 `eliminate-touchbar-start.gif` 与 `eliminate-touchbar-start-states.png` 分别复制为本目录对应文件。

## 游戏设置、玩法说明与挑战记录

三个辅助面板共用首页的暖白背景、圆角卡片、蓝色信息色和黄色强调色。

- [游戏设置](utility-settings.png)：语言选择卡片、金色音量滑杆、实时百分比与即时生效提示。
- [玩法说明](utility-rules.png)：三步操作示意、60 秒/30 次交换规则和本局/累计进度说明。
- [限时排行榜](utility-records.png)、[限步排行榜](utility-records-speed.png)：带滑动过渡的模式切换、按数量计算的个人最佳及并列名次；第二张沿用原预览文件名。
- [暂无记录状态](utility-records-empty.png)：显示空榜单提示，不生成虚构成绩。
- 上述截图中的成绩来自隔离测试存档；正式应用没有测试预览入口。
- 小窗口可滚动查看内容，系统减少动态效果开启时切换立即完成。

重新生成辅助面板截图：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter HomeUtilityPanelTests
```

将临时目录中的 `eliminate-utility-*.png` 复制为本目录对应的 `utility-*.png`；`*-compact-ru.png` 仅用于长翻译与紧凑窗口检查，无需归档。

## 筛选切换动画

![筛选切换动画](achievement-filter.gif)

- 共用暖白轨道，黄色选中滑块在全部、未解锁、已解锁之间移动，显示对应数量。
- 过渡时长 0.24 秒，快速切换从当前视觉位置接续；系统减少动态效果开启时即时切换。
- 动画由真实 Core Animation（核心动画）展示层导出，测试入口不进入正式应用。
- [查看成就页完整效果](achievement-panel.png)。页头仅显示“成就”与彩色奖章；页面中的进度和时间来自隔离测试存档。

## 标签实际效果

![成就标签实际效果](achievement-labels.png)

- 使用首页真实标签组件渲染，重点展示“百格起步”“千格熟手”和“万格旅人”的尺寸与居中效果。
- [全屏尺寸标签效果](achievement-labels-fullscreen.png)展示 1920 点宽度下的单行布局。每枚标签的状态标记固定左侧，成就图案与名称单独居中。
- [大窗口成就栏](achievement-grid.png)展示 1600 点宽度下跨越左右两栏的 8 枚成就。窗口更宽时一行可容纳更多徽章，通过「查看全部」浏览完整清单。
- 截图中的解锁状态来自独立的测试存档，不修改玩家存档。

## 全部 32 枚徽章

![全部成就徽章](achievement-icons.png)

- 图标入口：`Sources/GameIcons.swift` 中的 `AchievementIconCatalog`。
- 游戏主题绘制：`Sources/AchievementBadgeArtwork.swift`，使用无外框、无底板的彩色摇杆、节拍光柱、指尖消除火花、纯脚印、挑战票券等游戏图案。
- 总累计百/千/万图案仅保留两、三、四层方块，不含五角星；调整单格尺寸以保持整体大小接近并居中。
- 四种类型的百/千/万档分别使用一、二、三颗星。
- 测试总览夹具：`Tests/AchievementIconContactSheet.swift`，只编入 XCTest target，不进入正式 App。

## 更新测试图

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameIconPresentationTests
```

将系统临时目录中的 `eliminate-all-achievement-icons.png` 和 `eliminate-game-badge-labels.png` 分别复制为本目录中的 `achievement-icons.png` 和 `achievement-labels.png`；`eliminate-fullscreen-badge-labels.png` 复制为 `achievement-labels-fullscreen.png`。

运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter HomeDashboardTests` 可生成 `eliminate-home-achievement-grid.png`，复制为 `achievement-grid.png`。

更新筛选条动画与完整成就页截图：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AchievementFilterControlTests
```

将临时目录中的 `eliminate-achievement-filter.gif` 和 `eliminate-achievement-panel-refined.png` 分别复制到本目录的 `achievement-filter.gif` 和 `achievement-panel.png`。
