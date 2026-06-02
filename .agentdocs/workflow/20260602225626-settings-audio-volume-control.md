# 游戏设置新增音量控制

## 背景与目标
- 当前项目已经具备 BGM 与移动/消除/补位音效，但游戏设置中还没有提供面向玩家的音量入口。
- 本次目标是在“游戏设置”面板中新增一个清晰、易用、与现有风格一致的音量设置功能，并保证它能在重启应用后保留上次选择。

## 约束与原则
- 保持现有设置面板的视觉风格，不额外引入复杂弹窗或新页面。
- 优先做“总音量”控制，同时影响 BGM 与音效，避免本轮改动过大。
- 音量设置应支持本地持久化，重新打开应用后自动恢复。

## 阶段与 TODO
- [x] 梳理当前音频系统与设置面板结构，确认接入点。
- [x] 在设置面板新增音量滑杆与百分比显示。
- [x] 将音量状态接入 `GameAudioSystem`，统一控制 BGM 与音效音量。
- [x] 通过 `UserDefaults` 持久化音量，并补齐多语言文案。
- [x] 使用 Xcode Developer 路径执行 `swift build` 通过编译验证。

## 关键风险
- 如果只更新新创建的播放器音量，而不更新正在播放的 BGM / 音效，会造成“滑杆有值但听感未立即变化”的错觉。
- 设置面板新增一行控件后，若尺寸或约束处理不当，可能破坏自由模式与双列布局的现有稳定性。

## 当前进展
- 游戏设置已新增音量滑杆，显示为蓝色主题容器 + 横向滑杆 + 实时百分比。
- `GameAudioSystem` 已支持主音量读取、设置与持久化，并会在运行中同步刷新当前 BGM 与正在播放的音效音量。
- 中、英、日、韩、俄文案已补齐 `volume.label`，可随语言切换正常显示。

## 代码变更
- `Sources/GameAudioSystem.swift`
```diff
--- a/Sources/GameAudioSystem.swift
+++ b/Sources/GameAudioSystem.swift
@@ -29,19 +29,51 @@ final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
         let amplitude: Double
     }
 
+    private struct ActiveEffectPlayer {
+        let effect: SoundEffect
+        let player: AVAudioPlayer
+    }
+
+    private static let masterVolumeKey = "game_audio_master_volume_v1"
+
     private let sampleRate: Double = 44_100
     private let stateLock = NSLock()
+    private let defaults: UserDefaults
 
     private var currentTheme: MusicTheme?
     private var backgroundPlayer: AVAudioPlayer?
-    private var activeEffectPlayers: [AVAudioPlayer] = []
+    private var activeEffectPlayers: [ActiveEffectPlayer] = []
     private var backgroundDataCache: [MusicTheme: Data] = [:]
     private var effectDataCache: [SoundEffect: Data] = [:]
+    private var storedMasterVolume: Float
 
     private override init() {
+        let defaults = UserDefaults.standard
+        self.defaults = defaults
+        self.storedMasterVolume = Self.clampedVolume(Float(defaults.double(forKey: Self.masterVolumeKey)))
+        if defaults.object(forKey: Self.masterVolumeKey) == nil {
+            self.storedMasterVolume = 1
+        }
         super.init()
     }
 
+    var masterVolume: Float {
+        stateLock.lock()
+        defer { stateLock.unlock() }
+        return storedMasterVolume
+    }
+
+    func setMasterVolume(_ volume: Float) {
+        let clampedVolume = Self.clampedVolume(volume)
+
+        stateLock.lock()
+        storedMasterVolume = clampedVolume
+        defaults.set(Double(clampedVolume), forKey: Self.masterVolumeKey)
+        applyMasterVolumeToBackgroundPlayer()
+        applyMasterVolumeToActiveEffects()
+        stateLock.unlock()
+    }
+
     func updateBackgroundMusic(for mode: GameMode) {
         let theme = theme(for: mode)
         stateLock.lock()
@@ -49,6 +81,7 @@ final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
 
         // 同一模式直接复用播放器，避免频繁重建导致的听感抖动。
         if currentTheme == theme, let player = backgroundPlayer {
+            player.volume = backgroundVolume(for: theme) * storedMasterVolume
             if !player.isPlaying {
                 player.play()
             }
@@ -59,7 +92,7 @@ final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
         do {
             let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
             player.numberOfLoops = -1
-            player.volume = backgroundVolume(for: theme)
+            player.volume = backgroundVolume(for: theme) * storedMasterVolume
             player.prepareToPlay()
 
             backgroundPlayer?.stop()
@@ -81,8 +114,8 @@ final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
         backgroundPlayer = nil
         currentTheme = nil
 
-        for player in activeEffectPlayers {
-            player.stop()
+        for activeEffectPlayer in activeEffectPlayers {
+            activeEffectPlayer.player.stop()
         }
         activeEffectPlayers.removeAll()
     }
@@ -95,11 +128,11 @@ final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
         do {
             let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
             player.delegate = self
-            player.volume = effectVolume(for: effect)
+            player.volume = effectVolume(for: effect) * storedMasterVolume
             player.prepareToPlay()
 
-            activeEffectPlayers.removeAll(where: { !$0.isPlaying })
-            activeEffectPlayers.append(player)
+            activeEffectPlayers.removeAll(where: { !$0.player.isPlaying })
+            activeEffectPlayers.append(ActiveEffectPlayer(effect: effect, player: player))
             player.play()
         } catch {
             return
@@ -117,7 +150,23 @@ final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
     private func removeEffectPlayer(_ player: AVAudioPlayer) {
         stateLock.lock()
         defer { stateLock.unlock() }
-        activeEffectPlayers.removeAll(where: { $0 === player })
+        activeEffectPlayers.removeAll(where: { $0.player === player })
+    }
+
+    private func applyMasterVolumeToBackgroundPlayer() {
+        guard backgroundPlayer != nil else { return }
+        backgroundPlayer?.volume = backgroundVolume(for: currentTheme ?? .free) * storedMasterVolume
+    }
+
+    private func applyMasterVolumeToActiveEffects() {
+        activeEffectPlayers.removeAll(where: { !$0.player.isPlaying })
+        for activeEffectPlayer in activeEffectPlayers {
+            activeEffectPlayer.player.volume = effectVolume(for: activeEffectPlayer.effect) * storedMasterVolume
+        }
+    }
+
+    private static func clampedVolume(_ volume: Float) -> Float {
+        return min(max(volume, 0), 1)
     }
 
     private func theme(for mode: GameMode) -> MusicTheme {
```

- `Sources/GameViewController.swift`
```diff
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -11,7 +11,8 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         case language = 0
         case mode = 1
         case option = 2
-        case action = 3
+        case volume = 3
+        case action = 4
     }
 
     private enum BadgeTone {
@@ -193,6 +194,18 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
     }()
 
+    private lazy var volumeTitleLabel: NSTextField = {
+        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
+    }()
+
+    private lazy var volumeControlView: ArcadeVolumeControlView = {
+        let view = ArcadeVolumeControlView(themeColor: settingsThemeColor)
+        view.slider.target = self
+        view.slider.action = #selector(volumeSliderChanged(_:))
+        view.translatesAutoresizingMaskIntoConstraints = false
+        return view
+    }()
+
     private lazy var startButton: ArcadeActionButton = {
         let button = ArcadeActionButton(title: "", target: self, action: #selector(startButtonTapped(_:)))
         button.imagePosition = .imageLeading
@@ -206,6 +219,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
             [languageTitleLabel, languagePopup],
             [modeTitleLabel, modePopup],
             [optionTitleLabel, optionPopup],
+            [volumeTitleLabel, volumeControlView],
             [startTitleLabel, startButton]
         ])
         grid.translatesAutoresizingMaskIntoConstraints = false
@@ -495,13 +509,16 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
             modePopup.heightAnchor.constraint(equalToConstant: 38),
             optionPopup.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),
             optionPopup.heightAnchor.constraint(equalToConstant: 38),
+            volumeControlView.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),
+            volumeControlView.heightAnchor.constraint(equalToConstant: 38),
             startButton.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),
             startButton.leadingAnchor.constraint(equalTo: languagePopup.leadingAnchor),
             startButton.heightAnchor.constraint(equalToConstant: 38),
 
             languageTitleLabel.centerYAnchor.constraint(equalTo: languagePopup.centerYAnchor),
             modeTitleLabel.centerYAnchor.constraint(equalTo: modePopup.centerYAnchor),
-            optionTitleLabel.centerYAnchor.constraint(equalTo: optionPopup.centerYAnchor)
+            optionTitleLabel.centerYAnchor.constraint(equalTo: optionPopup.centerYAnchor),
+            volumeTitleLabel.centerYAnchor.constraint(equalTo: volumeControlView.centerYAnchor)
         ])
     }
 
@@ -514,6 +531,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
             self?.updateCompetitiveInfo()
         }
 
+        syncVolumeControlFromAudioSystem()
         modePopup.selectItem(at: ModeSelection.free.rawValue)
         applyModeSelection(resetGame: true)
     }
@@ -678,6 +696,12 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         applyModeSelection(resetGame: true)
     }
 
+    @objc private func volumeSliderChanged(_ sender: NSSlider) {
+        let volume = Float(sender.doubleValue)
+        audioSystem.setMasterVolume(volume)
+        updateVolumeControlDisplay(for: volume)
+    }
+
     @objc private func startButtonTapped(_ sender: NSButton) {
         guard currentModeSelection != .free else { return }
         resetRuntimeIndicators()
@@ -723,7 +747,9 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         rulesTitleLabel.stringValue = localized("panel.rules")
         languageTitleLabel.stringValue = localized("language.label")
         modeTitleLabel.stringValue = localized("mode.label")
+        volumeTitleLabel.stringValue = localized("volume.label")
         startTitleLabel.stringValue = ""
+        syncVolumeControlFromAudioSystem()
 
         if let icon = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: titleLabel.stringValue) {
             headerIconView.image = icon
@@ -1324,6 +1350,17 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         return String(format: "%02d:%02d", minutes, seconds)
     }
 
+    private func syncVolumeControlFromAudioSystem() {
+        updateVolumeControlDisplay(for: audioSystem.masterVolume)
+    }
+
+    private func updateVolumeControlDisplay(for volume: Float) {
+        let clampedVolume = min(max(volume, 0), 1)
+        let percentage = Int((clampedVolume * 100).rounded())
+        volumeControlView.setVolume(Double(clampedVolume))
+        volumeControlView.setDisplayText("\(percentage)%")
+    }
+
     private func localized(_ key: String) -> String {
         return localizer.string(key)
     }
@@ -1789,6 +1826,130 @@ private final class ArcadePopupButton: NSPopUpButton {
     }
 }
 
+private final class ArcadeVolumeControlView: NSView {
+    private let themeColor: NSColor
+    private var hoverTrackingArea: NSTrackingArea?
+    private var isHovering = false
+
+    let slider: NSSlider = {
+        let slider = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
+        slider.translatesAutoresizingMaskIntoConstraints = false
+        slider.isContinuous = true
+        slider.controlSize = .small
+        slider.allowsTickMarkValuesOnly = false
+        slider.numberOfTickMarks = 0
+        slider.focusRingType = .none
+        return slider
+    }()
+
+    private lazy var valueLabel: NSTextField = {
+        let label = NSTextField(labelWithString: "100%")
+        label.translatesAutoresizingMaskIntoConstraints = false
+        label.alignment = .right
+        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
+        label.setContentCompressionResistancePriority(.required, for: .horizontal)
+        label.setContentHuggingPriority(.required, for: .horizontal)
+        return label
+    }()
+
+    override var intrinsicContentSize: NSSize {
+        return NSSize(width: NSView.noIntrinsicMetric, height: 38)
+    }
+
+    init(themeColor: NSColor) {
+        self.themeColor = themeColor
+        super.init(frame: .zero)
+        commonInit()
+    }
+
+    required init?(coder: NSCoder) {
+        self.themeColor = NSColor(calibratedRed: 0.7, green: 0.86, blue: 1.0, alpha: 0.96)
+        super.init(coder: coder)
+        commonInit()
+    }
+
+    func setVolume(_ value: Double) {
+        if abs(slider.doubleValue - value) > 0.0001 {
+            slider.doubleValue = value
+        }
+    }
+
+    func setDisplayText(_ text: String) {
+        valueLabel.stringValue = text
+        updateAppearance()
+    }
+
+    override func updateTrackingAreas() {
+        super.updateTrackingAreas()
+
+        if let hoverTrackingArea {
+            removeTrackingArea(hoverTrackingArea)
+        }
+
+        let options: NSTrackingArea.Options = [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited]
+        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
+        addTrackingArea(area)
+        hoverTrackingArea = area
+    }
+
+    override func mouseEntered(with event: NSEvent) {
+        super.mouseEntered(with: event)
+        isHovering = true
+        updateAppearance()
+    }
+
+    override func mouseExited(with event: NSEvent) {
+        super.mouseExited(with: event)
+        isHovering = false
+        updateAppearance()
+    }
+
+    private func commonInit() {
+        wantsLayer = true
+
+        addSubview(slider)
+        addSubview(valueLabel)
+
+        NSLayoutConstraint.activate([
+            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
+            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
+            valueLabel.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 10),
+            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
+            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
+            valueLabel.widthAnchor.constraint(equalToConstant: 42)
+        ])
+
+        updateAppearance()
+    }
+
+    private func updateAppearance() {
+        guard let layer else { return }
+
+        let background: NSColor
+        let border: NSColor
+
+        if isHovering {
+            background = NSColor(calibratedRed: 0.1, green: 0.24, blue: 0.42, alpha: 0.94)
+            border = NSColor(calibratedRed: 0.36, green: 0.64, blue: 0.94, alpha: 0.9)
+        } else {
+            background = NSColor(calibratedRed: 0.09, green: 0.18, blue: 0.31, alpha: 0.9)
+            border = NSColor(calibratedRed: 0.3, green: 0.53, blue: 0.8, alpha: 0.84)
+        }
+
+        layer.backgroundColor = background.cgColor
+        layer.borderColor = border.cgColor
+        layer.borderWidth = ArcadeControlStyle.borderWidth
+        layer.cornerRadius = ArcadeControlStyle.cornerRadius
+        layer.masksToBounds = false
+        layer.shadowColor = border.withAlphaComponent(0.72).cgColor
+        layer.shadowRadius = isHovering ? 5 : 3
+        layer.shadowOpacity = 0.26
+        layer.shadowOffset = .zero
+
+        valueLabel.textColor = themeColor.withAlphaComponent(0.94)
+    }
+}
+
 private final class ArcadeActionButton: NSButton {
     override var alignmentRectInsets: NSEdgeInsets {
         NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
```

- `Sources/Resources/zh-Hans.lproj/Localizable.strings`
```diff
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -24,6 +24,7 @@
 "option.target_score" = "目标分数";
 "option.minute_format" = "%d 分钟";
 "option.target_format" = "%d 分";
+"volume.label" = "音量";
 
 "start.label" = "状态";
 "start.action_start" = "开始";
```

- `Sources/Resources/en.lproj/Localizable.strings`
```diff
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -24,6 +24,7 @@
 "option.target_score" = "Target";
 "option.minute_format" = "%d min";
 "option.target_format" = "%d pts";
+"volume.label" = "Volume";
 
 "start.label" = "Action";
 "start.action_start" = "Start";
```

- `Sources/Resources/ja.lproj/Localizable.strings`
```diff
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -24,6 +24,7 @@
 "option.target_score" = "目標スコア";
 "option.minute_format" = "%d分";
 "option.target_format" = "%d点";
+"volume.label" = "音量";
 
 "start.label" = "状態";
 "start.action_start" = "開始";
```

- `Sources/Resources/ko.lproj/Localizable.strings`
```diff
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -24,6 +24,7 @@
 "option.target_score" = "목표 점수";
 "option.minute_format" = "%d분";
 "option.target_format" = "%d점";
+"volume.label" = "볼륨";
 
 "start.label" = "상태";
 "start.action_start" = "시작";
```

- `Sources/Resources/ru.lproj/Localizable.strings`
```diff
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -24,6 +24,7 @@
 "option.target_score" = "Цель";
 "option.minute_format" = "%d мин";
 "option.target_format" = "%d очк.";
+"volume.label" = "Громкость";
 
 "start.label" = "Состояние";
 "start.action_start" = "Старт";
```

- `AGENTS.md`
```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -1,5 +1,10 @@
 # 项目认知记录
 
+## 2026-06-02
+- 游戏设置面板已新增“音量”控制项，使用与现有蓝色设置控件一致的主题风格，显示为横向滑杆加百分比读数。
+- 当前音量控制为“总音量”：会同时影响 BGM 与移动/消除/补位音效，不区分背景音乐与音效的独立通道。
+- 音量设置已接入 `GameAudioSystem` 持久化，使用 `UserDefaults` 记忆上次选择；重新启动应用后会自动恢复。
+
 ## 2026-06-01
 - 仓库已新增面向玩家与开发者的 `README.md`，系统介绍游戏定位、核心玩法、三种模式、Touch Bar 交互方式、本地挑战记录、多语言与程序化音频能力。
 - `README.md` 已补充运行与打包说明：推荐通过 `./run.sh` 本地启动，通过 `./package.sh` 生成通用 macOS `.app/.dmg/.zip` 分发产物。
```

- `.agentdocs/index.md`
```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,5 +1,6 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260602225626-settings-audio-volume-control.md` - 在游戏设置中新增总音量滑杆，统一控制 BGM 与音效，并通过 `UserDefaults` 持久化上次音量。
 `workflow/20260601210110-readme-project-introduction.md` - 新增面向玩家与开发者的 README，完整介绍游戏定位、玩法模式、运行打包方式、硬件要求与项目结构。
 `workflow/20260419210231-public-touchbar-only-retire-modal.md` - 正式回退为公开 `window.touchBar` 唯一路径，停用私有 modal 与相关状态机，优先保证打包版稳定显示。
 `workflow/20260419203037-touchbar-modal-warmup-promotion.md` - Touch Bar 启动改为先公开预热、再晋升私有 modal，降低 modal 首挂载阶段的概率黑屏。
@@ -49,6 +50,7 @@
 
 ## 读取场景
+- 需要确认“游戏设置里的音量滑杆接在哪里、是否会记住上次设置、是否同时影响 BGM 与音效”时，优先读取 `20260602225626` 文档。
 - 需要快速了解“这款游戏是什么、怎么玩、如何运行与打包、适合什么设备”时，优先读取 `20260601210110` 文档。
 - 需要确认“当前正式方案是否已经彻底放弃私有 modal，只保留公开 Touch Bar”时，优先读取 `20260419210231` 文档。
 - 需要处理“私有 modal 自身会偶发黑屏，但又不想彻底放弃左贴边效果”时，优先读取 `20260419203037` 文档。
@@ -99,6 +101,8 @@
 
 ## 关键记忆
+- 游戏设置已新增总音量滑杆：UI 位于设置面板内，采用蓝色主题容器 + 百分比显示，当前控制的是“总音量”而非独立 BGM/SFX 分轨。
+- `GameAudioSystem` 现已负责音量持久化：使用 `UserDefaults` 保存 `0...1` 区间的主音量，并在 BGM 播放、音效触发以及运行中调整时统一应用。
 - 仓库现已提供完整 `README.md`：包含项目介绍、玩法说明、模式设计、Touch Bar 交互方式、运行/打包命令、硬件要求与目录结构，可直接作为对外介绍入口。
 - 当前正式 Touch Bar 方案已经统一为公开 `window.touchBar`：私有 modal、`ELIMINATE_TOUCHBAR_MODAL` 与预热晋升链路都已停用并视为历史废案；启动时仅保留公开 Touch Bar 的异步首刷与一次延迟刷新。
 - Touch Bar 当前启动策略为：先挂载公开 `window.touchBar`，再异步执行一次 `prepareForDisplay()` 并追加 120ms 的二次刷新，避免首帧发生在零尺寸阶段。
```

## 测试用例
### TC-001 音量滑杆实时生效
- 类型：功能测试
- 优先级：高
- 关联模块：`GameViewController`、`GameAudioSystem`
- 前置条件：应用已启动，当前有 BGM 正在播放
- 操作步骤：
1. 打开游戏设置中的音量滑杆
2. 依次拖动到 `100%`、`50%`、`0%`
3. 观察 BGM 与后续交换/消除/补位音效是否同步变大、变小或静音
- 预期结果：
- 百分比显示与滑杆位置同步变化
- BGM 与音效同时受同一音量值控制
- 是否通过：待验证

### TC-002 音量设置持久化
- 类型：功能测试
- 优先级：高
- 关联模块：`GameAudioSystem`
- 前置条件：应用已启动
- 操作步骤：
1. 将音量调到非默认值（例如 `35%`）
2. 退出应用并重新启动
3. 观察设置面板中的滑杆位置与百分比
- 预期结果：
- 音量恢复到上次退出前的值
- 重启后 BGM 直接以恢复后的音量播放
- 是否通过：待验证

### TC-003 编译自检
- 类型：构建测试
- 优先级：中
- 关联模块：全部本次改动文件
- 前置条件：本机已安装 Xcode
- 操作步骤：
1. 执行 `/bin/bash -c 'DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build'`
- 预期结果：
- 项目可成功编译通过
- 是否通过：已通过
