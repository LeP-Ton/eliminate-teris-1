# 新增音效系统：模式 BGM + 交换/消除/补位音效

## 背景与目标
- 用户要求新增音效系统：不同模式播放不同 BGM。
- 用户要求在关键交互阶段增加音效：移动、补位、消除。
- 约束：不依赖外部音频资源文件，保持现有三阶段动画与交互逻辑。

## 方案设计
- 新增 `GameAudioSystem`，通过程序化合成 PCM 并封装为 WAV 数据，使用 `AVAudioPlayer` 播放。
- BGM 按模式（自由/竞分/竞速）切换，循环播放并缓存生成数据。
- 在 `GameTouchBarView` 的三阶段动画中按阶段触发音效：
  - 交换阶段：移动音效
  - 消除阶段：消除音效
  - 左补位阶段：补位音效
- 仅当本次过渡由交换触发时播放阶段音效，避免模式切换/重置时误触发音效。

## 代码变更
- Sources/GameAudioSystem.swift
```diff
diff --git a/Sources/GameAudioSystem.swift b/Sources/GameAudioSystem.swift
new file mode 100644
index 0000000..c8f33bc
--- /dev/null
+++ b/Sources/GameAudioSystem.swift
@@ -0,0 +1,430 @@
+import AVFoundation
+import Foundation
+
+final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
+    enum SoundEffect: Hashable {
+        case move
+        case eliminate
+        case refill
+    }
+
+    static let shared = GameAudioSystem()
+
+    private enum MusicTheme: Hashable {
+        case free
+        case scoreAttack
+        case speedRun
+    }
+
+    private enum Waveform {
+        case sine
+        case square
+        case triangle
+    }
+
+    private struct Note {
+        let frequency: Double
+        let beats: Double
+        let waveform: Waveform
+        let amplitude: Double
+    }
+
+    private let sampleRate: Double = 44_100
+    private let stateLock = NSLock()
+
+    private var currentTheme: MusicTheme?
+    private var backgroundPlayer: AVAudioPlayer?
+    private var activeEffectPlayers: [AVAudioPlayer] = []
+    private var backgroundDataCache: [MusicTheme: Data] = [:]
+    private var effectDataCache: [SoundEffect: Data] = [:]
+
+    private override init() {
+        super.init()
+    }
+
+    func updateBackgroundMusic(for mode: GameMode) {
+        let theme = theme(for: mode)
+        stateLock.lock()
+        defer { stateLock.unlock() }
+
+        if currentTheme == theme, let player = backgroundPlayer {
+            if !player.isPlaying {
+                player.play()
+            }
+            return
+        }
+
+        let data = backgroundData(theme)
+        do {
+            let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
+            player.numberOfLoops = -1
+            player.volume = backgroundVolume(for: theme)
+            player.prepareToPlay()
+
+            backgroundPlayer?.stop()
+            backgroundPlayer = player
+            currentTheme = theme
+            player.play()
+        } catch {
+            backgroundPlayer?.stop()
+            backgroundPlayer = nil
+            currentTheme = nil
+        }
+    }
+
+    func stopBackgroundMusic() {
+        stateLock.lock()
+        defer { stateLock.unlock() }
+
+        backgroundPlayer?.stop()
+        backgroundPlayer = nil
+        currentTheme = nil
+
+        for player in activeEffectPlayers {
+            player.stop()
+        }
+        activeEffectPlayers.removeAll()
+    }
+
+    func playEffect(_ effect: SoundEffect) {
+        stateLock.lock()
+        defer { stateLock.unlock() }
+
+        let data = effectData(effect)
+        do {
+            let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
+            player.delegate = self
+            player.volume = effectVolume(for: effect)
+            player.prepareToPlay()
+
+            activeEffectPlayers.removeAll(where: { !$0.isPlaying })
+            activeEffectPlayers.append(player)
+            player.play()
+        } catch {
+            return
+        }
+    }
+
+    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
+        removeEffectPlayer(player)
+    }
+
+    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
+        removeEffectPlayer(player)
+    }
+
+    private func removeEffectPlayer(_ player: AVAudioPlayer) {
+        stateLock.lock()
+        defer { stateLock.unlock() }
+        activeEffectPlayers.removeAll(where: { $0 === player })
+    }
+
+    private func theme(for mode: GameMode) -> MusicTheme {
+        switch mode {
+        case .free:
+            return .free
+        case .scoreAttack:
+            return .scoreAttack
+        case .speedRun:
+            return .speedRun
+        }
+    }
+
+    private func backgroundVolume(for theme: MusicTheme) -> Float {
+        switch theme {
+        case .free:
+            return 0.22
+        case .scoreAttack:
+            return 0.25
+        case .speedRun:
+            return 0.27
+        }
+    }
+
+    private func effectVolume(for effect: SoundEffect) -> Float {
+        switch effect {
+        case .move:
+            return 0.5
+        case .eliminate:
+            return 0.56
+        case .refill:
+            return 0.48
+        }
+    }
+
+    private func backgroundData(_ theme: MusicTheme) -> Data {
+        if let cached = backgroundDataCache[theme] {
+            return cached
+        }
+        let data = createBackgroundData(theme)
+        backgroundDataCache[theme] = data
+        return data
+    }
+
+    private func effectData(_ effect: SoundEffect) -> Data {
+        if let cached = effectDataCache[effect] {
+            return cached
+        }
+        let data = createEffectData(effect)
+        effectDataCache[effect] = data
+        return data
+    }
+
+    private func createBackgroundData(_ theme: MusicTheme) -> Data {
+        switch theme {
+        case .free:
+            return synthesize(
+                tempo: 92,
+                tracks: [
+                    sequence(
+                        [72, 76, 79, 76, 74, 77, 81, 77, 72, 76, 79, 76, 74, 77, 79, -1],
+                        beat: 0.5,
+                        waveform: .triangle,
+                        amplitude: 0.34
+                    ),
+                    sequence(
+                        [48, -1, 55, -1, 45, -1, 50, -1, 48, -1, 55, -1, 43, -1, 50, -1],
+                        beat: 0.5,
+                        waveform: .sine,
+                        amplitude: 0.2
+                    )
+                ]
+            )
+
+        case .scoreAttack:
+            return synthesize(
+                tempo: 128,
+                tracks: [
+                    sequence(
+                        [76, 79, 81, 84, 81, 79, 76, 74, 76, 79, 83, 86, 83, 79, 76, -1],
+                        beat: 0.5,
+                        waveform: .square,
+                        amplitude: 0.31
+                    ),
+                    sequence(
+                        [52, 52, 55, 55, 57, 57, 55, 55, 50, 50, 53, 53, 55, 55, 53, 53],
+                        beat: 0.5,
+                        waveform: .triangle,
+                        amplitude: 0.2
+                    )
+                ]
+            )
+
+        case .speedRun:
+            return synthesize(
+                tempo: 146,
+                tracks: [
+                    sequence(
+                        [79, 83, 86, 88, 86, 83, 79, 76, 79, 83, 86, 91, 86, 83, 79, -1],
+                        beat: 0.5,
+                        waveform: .square,
+                        amplitude: 0.3
+                    ),
+                    sequence(
+                        [43, 43, 47, 47, 50, 50, 47, 47, 45, 45, 48, 48, 52, 52, 48, 48],
+                        beat: 0.5,
+                        waveform: .triangle,
+                        amplitude: 0.21
+                    )
+                ]
+            )
+        }
+    }
+
+    private func createEffectData(_ effect: SoundEffect) -> Data {
+        switch effect {
+        case .move:
+            return synthesize(
+                tempo: 300,
+                tracks: [
+                    sequence(
+                        [(76, 0.24), (83, 0.24)],
+                        waveform: .square,
+                        amplitude: 0.36
+                    ),
+                    sequence(
+                        [(64, 0.48)],
+                        waveform: .sine,
+                        amplitude: 0.16
+                    )
+                ]
+            )
+
+        case .eliminate:
+            return synthesize(
+                tempo: 260,
+                tracks: [
+                    sequence(
+                        [(88, 0.16), (83, 0.16), (79, 0.16), (67, 0.2), (-1, 0.08)],
+                        waveform: .square,
+                        amplitude: 0.4
+                    ),
+                    sequence(
+                        [(55, 0.76)],
+                        waveform: .triangle,
+                        amplitude: 0.2
+                    )
+                ]
+            )
+
+        case .refill:
+            return synthesize(
+                tempo: 320,
+                tracks: [
+                    sequence(
+                        [(67, 0.18), (72, 0.18), (76, 0.18)],
+                        waveform: .triangle,
+                        amplitude: 0.34
+                    ),
+                    sequence(
+                        [(55, 0.54)],
+                        waveform: .sine,
+                        amplitude: 0.16
+                    )
+                ]
+            )
+        }
+    }
+
+    private func sequence(_ notes: [Int], beat: Double, waveform: Waveform, amplitude: Double) -> [Note] {
+        return notes.map {
+            makeNote(midi: $0, beats: beat, waveform: waveform, amplitude: amplitude)
+        }
+    }
+
+    private func sequence(_ notes: [(Int, Double)], waveform: Waveform, amplitude: Double) -> [Note] {
+        return notes.map {
+            makeNote(midi: $0.0, beats: $0.1, waveform: waveform, amplitude: amplitude)
+        }
+    }
+
+    private func makeNote(midi: Int, beats: Double, waveform: Waveform, amplitude: Double) -> Note {
+        guard midi > 0 else {
+            return Note(frequency: 0, beats: beats, waveform: waveform, amplitude: 0)
+        }
+        return Note(
+            frequency: frequency(forMIDINote: midi),
+            beats: beats,
+            waveform: waveform,
+            amplitude: amplitude
+        )
+    }
+
+    private func synthesize(tempo: Double, tracks: [[Note]]) -> Data {
+        let secondsPerBeat = 60.0 / max(1, tempo)
+        let rendered = tracks.map { renderTrack($0, secondsPerBeat: secondsPerBeat) }
+        let mixedSamples = mixTracks(rendered)
+        return makeWAVData(samples: mixedSamples)
+    }
+
+    private func renderTrack(_ notes: [Note], secondsPerBeat: Double) -> [Double] {
+        var samples: [Double] = []
+
+        for note in notes {
+            let sampleCount = max(1, Int((note.beats * secondsPerBeat * sampleRate).rounded()))
+            let attackSamples = max(1, Int(sampleRate * 0.006))
+            let releaseSamples = max(1, Int(sampleRate * 0.02))
+
+            for sampleIndex in 0..<sampleCount {
+                guard note.frequency > 0 else {
+                    samples.append(0)
+                    continue
+                }
+
+                let time = Double(sampleIndex) / sampleRate
+                let phase = 2 * Double.pi * note.frequency * time
+                let wave = oscillatorSample(waveform: note.waveform, phase: phase)
+                let attackGain = min(1, Double(sampleIndex) / Double(attackSamples))
+                let releaseSource = max(0, sampleCount - sampleIndex - 1)
+                let releaseGain = min(1, Double(releaseSource) / Double(releaseSamples))
+                let envelope = max(0, min(attackGain, releaseGain))
+
+                samples.append(wave * note.amplitude * envelope)
+            }
+        }
+
+        return samples
+    }
+
+    private func oscillatorSample(waveform: Waveform, phase: Double) -> Double {
+        switch waveform {
+        case .sine:
+            return sin(phase)
+        case .square:
+            return sin(phase) >= 0 ? 1 : -1
+        case .triangle:
+            let normalized = phase / (2 * Double.pi)
+            return 2 * abs(2 * (normalized - floor(normalized + 0.5))) - 1
+        }
+    }
+
+    private func mixTracks(_ tracks: [[Double]]) -> [Int16] {
+        let maxSamples = tracks.map(\.count).max() ?? 0
+        guard maxSamples > 0 else { return [0] }
+
+        var mixed = [Double](repeating: 0, count: maxSamples)
+        for track in tracks {
+            for (index, sample) in track.enumerated() {
+                mixed[index] += sample
+            }
+        }
+
+        let peak = mixed.reduce(0) { max($0, abs($1)) }
+        let gain = peak > 0 ? 0.84 / peak : 0
+
+        return mixed.map { value in
+            let normalized = max(-1, min(1, value * gain))
+            return Int16(normalized * Double(Int16.max))
+        }
+    }
+
+    private func frequency(forMIDINote midi: Int) -> Double {
+        return 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
+    }
+
+    private func makeWAVData(samples: [Int16]) -> Data {
+        let channels: UInt16 = 1
+        let bitsPerSample: UInt16 = 16
+        let bytesPerSample: UInt16 = bitsPerSample / 8
+        let blockAlign: UInt16 = channels * bytesPerSample
+        let sampleRateValue = UInt32(sampleRate)
+        let byteRate: UInt32 = sampleRateValue * UInt32(blockAlign)
+        let dataSize: UInt32 = UInt32(samples.count) * UInt32(bytesPerSample)
+        let riffChunkSize: UInt32 = 36 + dataSize
+
+        var data = Data(capacity: Int(riffChunkSize + 8))
+        data.appendASCII("RIFF")
+        data.appendLittleEndian(riffChunkSize)
+        data.appendASCII("WAVE")
+        data.appendASCII("fmt ")
+        data.appendLittleEndian(UInt32(16))
+        data.appendLittleEndian(UInt16(1))
+        data.appendLittleEndian(channels)
+        data.appendLittleEndian(sampleRateValue)
+        data.appendLittleEndian(byteRate)
+        data.appendLittleEndian(blockAlign)
+        data.appendLittleEndian(bitsPerSample)
+        data.appendASCII("data")
+        data.appendLittleEndian(dataSize)
+
+        for sample in samples {
+            data.appendLittleEndian(UInt16(bitPattern: sample))
+        }
+        return data
+    }
+}
+
+private extension Data {
+    mutating func appendASCII(_ string: String) {
+        if let ascii = string.data(using: .ascii) {
+            append(ascii)
+        }
+    }
+
+    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
+        var littleEndian = value.littleEndian
+        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
+            append(bytes.bindMemory(to: UInt8.self))
+        }
+    }
+}
```

- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 664e82a..701b711 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -42,6 +42,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private let scoreAttackMinutes = [1, 2, 3]
     private let speedRunTargets = [300, 600, 900]
     private let recordStore = ModeRecordStore.shared
+    private let audioSystem = GameAudioSystem.shared
 
     private lazy var controller = GameBoardController(columns: columns)
     private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)
@@ -521,6 +522,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         }
         dismissSystemModalTouchBarIfNeeded()
         hudTimer?.invalidate()
+        audioSystem.stopBackgroundMusic()
     }
 
     override func makeTouchBar() -> NSTouchBar? {
@@ -659,6 +661,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
 
     private func applyModeSelection(resetGame: Bool) {
         let selection = currentModeSelection
+        let selectedMode = gameMode(for: selection)
         let windowFrameBeforeUpdate = view.window?.frame
         populateOptionPopup(for: selection)
         updateStartControlVisibility(for: selection)
@@ -668,8 +671,9 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         if resetGame {
             resetRuntimeIndicators()
             hasSavedFinishedRecord = false
-            controller.configure(mode: gameMode(for: selection))
+            controller.configure(mode: selectedMode)
         }
+        audioSystem.updateBackgroundMusic(for: selectedMode)
 
         updateCompetitiveInfo()
         preserveWindowFrame(windowFrameBeforeUpdate)
```

- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 3942ce9..a3e551f 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -319,6 +319,7 @@ final class GameTouchBarView: NSView {
     }
 
     private let controller: GameBoardController
+    private let audioSystem = GameAudioSystem.shared
     private let columnRange: Range<Int>
     private let columnCount: Int
     private let leadingCompensationX: CGFloat
@@ -335,6 +336,7 @@ final class GameTouchBarView: NSView {
     private var transitionPhases: [TransitionPhase] = []
     private var transitionPhaseIndex = 0
     private var activePhaseDuration: TimeInterval = 0.28
+    private var shouldPlayTransitionEffects = false
     private var transitionStartTime: TimeInterval = 0
     private var transitionProgress: CGFloat = 1
     private var transitionTimer: Timer?
@@ -518,6 +520,7 @@ final class GameTouchBarView: NSView {
         transitionTimer?.invalidate()
         transitionPhases = []
         transitionPhaseIndex = 0
+        shouldPlayTransitionEffects = swapPair != nil
 
         // 通过 tile id 做前后帧配对：既能识别交换位移，也能识别消除/补位。
         let oldIndices = Dictionary(uniqueKeysWithValues: oldTiles.enumerated().map { ($1.id, $0) })
@@ -711,6 +714,7 @@ final class GameTouchBarView: NSView {
         if phases.isEmpty {
             pieceTransitions = []
             transitionProgress = 1
+            shouldPlayTransitionEffects = false
             needsDisplay = true
             return
         }
@@ -747,6 +751,7 @@ final class GameTouchBarView: NSView {
         activePhaseDuration = max(0.01, phase.duration)
         transitionStartTime = Date().timeIntervalSinceReferenceDate
         transitionProgress = 0
+        playPhaseSoundEffectIfNeeded(transitions: phase.transitions)
         needsDisplay = true
     }
 
@@ -767,6 +772,29 @@ final class GameTouchBarView: NSView {
         pieceTransitions = []
         transitionPhases = []
         transitionPhaseIndex = 0
+        shouldPlayTransitionEffects = false
+    }
+
+    private func playPhaseSoundEffectIfNeeded(transitions: [PieceTransition]) {
+        guard shouldPlayTransitionEffects else { return }
+        guard !transitions.isEmpty else { return }
+
+        if transitions.contains(where: { $0.transitionKind == .remove }) {
+            audioSystem.playEffect(.eliminate)
+            return
+        }
+
+        if transitions.contains(where: { $0.transitionKind == .insert }) {
+            audioSystem.playEffect(.refill)
+            return
+        }
+
+        let hasMove = transitions.contains {
+            $0.transitionKind == .move && $0.fromIndex != $0.toIndex
+        }
+        if hasMove {
+            audioSystem.playEffect(.move)
+        }
     }
 
     private func drawTransitionPiece(_ transition: PieceTransition) {
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 9181ac7..6c8fe01 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -38,3 +38,4 @@
 - 已增强消除动画可见性：新增消除光晕/外环特效，消除缩放范围扩大（`1.22 -> 0.12`），并把过渡时长提升到 `0.28s`，使消除反馈更明显。
 - 已按“答-25”回退动画时序：取消两阶段串联，恢复为单阶段过渡（`0.28s`），保留增强后的消除光晕/外环与缩放淡出效果。
 - 动画时序现已按最新需求调整为三阶段：交换位移（0.16s）→ 消除反馈（0.20s）→ 左侧补位（0.24s）；通过 `lastSwapPair + transitionPhases` 串联，确保“先交换、再消除、后补位”。
+- 已新增程序化音效系统 `GameAudioSystem`：自由/竞分/竞速模式会自动切换不同 BGM，且在三阶段动画中按阶段触发移动、消除、补位音效；音频由运行时合成 WAV，不依赖外部资源文件。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index d0f2562..a86d4db 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260221200836-audio-system-bgm-sfx.md` - 新增程序化音效系统：按模式切换 BGM，并按动画阶段播放移动/消除/补位音效。
 `workflow/20260221193822-touchbar-three-phase-animation-sequence.md` - Touch Bar 动画改为三阶段：先交换，再消除，最后左侧补位。
 `workflow/20260221192738-touchbar-animation-rollback-to-answer25.md` - 按“答-25”回退 Touch Bar 动画时序，取消两阶段串联并恢复单阶段过渡。
 `workflow/20260221185955-touchbar-animation-sequence-move-then-eliminate.md` - Touch Bar 动画改为两阶段顺序：先移动后消除与补位。
@@ -38,6 +39,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要确认“模式切换 BGM + 交换/消除/补位音效”是否已接入时，优先读取 `20260221200836` 文档。
 - 需要确认“交换后才消除、消除后才补位”是否落地时，优先读取 `20260221193822` 文档。
 - 需要确认“已回退到答-25的动画时序”时，优先读取 `20260221192738` 文档。
 - 需要确认“动画顺序为何曾改为先移动后消除（历史方案）”时，优先读取 `20260221185955` 文档。
@@ -76,6 +78,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 已新增 `GameAudioSystem` 程序化音频链路：自由/竞分/竞速模式切换会切 BGM，且仅在“交换触发”的三阶段过渡中按阶段播放移动、消除、补位音效，避免模式切换/重置触发误报声。
 - Touch Bar 动画时序当前为三阶段链路：交换位移（0.16s）→ 消除反馈（0.20s）→ 左侧补位（0.24s）；交换对由 `GameBoardController.lastSwapPair` 提供，渲染端以 `transitionPhases` 顺序执行。
 - Touch Bar 动画时序已回退到答-25：单阶段过渡（`0.28s`），保留消除光晕/外环与放大缩放淡出，取消两阶段 pending 串联逻辑。
- 消除动画可见性已增强：消除帧使用 `easeIn` + 光晕外环，缩放区间 `1.22 -> 0.12`，动画总时长 `0.28s`，并对移动/插入采用分离 easing。
```

## 代码补充修订
- Sources/GameAudioSystem.swift
```diff
diff --git a/Sources/GameAudioSystem.swift b/Sources/GameAudioSystem.swift
@@ -42,6 +42,7 @@ final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
         stateLock.lock()
         defer { stateLock.unlock() }
 
+        // 同一模式直接复用播放器，避免频繁重建导致的听感抖动。
         if currentTheme == theme, let player = backgroundPlayer {
             if !player.isPlaying {
                 player.play()
@@ -146,6 +147,7 @@ final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
         if let cached = backgroundDataCache[theme] {
             return cached
         }
+        // BGM 只在首次使用时合成一次，后续直接读取缓存。
         let data = createBackgroundData(theme)
         backgroundDataCache[theme] = data
         return data
@@ -157,6 +159,7 @@ final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
         if let cached = effectDataCache[effect] {
             return cached
         }
+        // 交互音效同样缓存，减少交换高频触发时的分配开销。
         let data = createEffectData(effect)
         effectDataCache[effect] = data
         return data
@@ -301,6 +304,7 @@ final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
     }
 
     private func synthesize(tempo: Double, tracks: [[Note]]) -> Data {
+        // 通过简单波形 + 包络生成 PCM，再封装成 WAV 交给 AVAudioPlayer 播放。
         let secondsPerBeat = 60.0 / max(1, tempo)
         let rendered = tracks.map { renderTrack($0, secondsPerBeat: secondsPerBeat) }
         let mixedSamples = mixTracks(rendered)
@@ -373,6 +377,7 @@ final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
     }
 
     private func makeWAVData(samples: [Int16]) -> Data {
+        // 写入标准 WAV 头，保持全平台播放器可识别。
         let channels: UInt16 = 1
         let bitsPerSample: UInt16 = 16
         let bytesPerSample: UInt16 = bitsPerSample / 8
```

- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
@@ -776,6 +776,7 @@ final class GameTouchBarView: NSView {
         guard shouldPlayTransitionEffects else { return }
         guard !transitions.isEmpty else { return }
 
+        // 三阶段按优先级触发：消除 > 补位 > 移动，确保同一阶段只播一种提示音。
         if transitions.contains(where: { $0.transitionKind == .remove }) {
             audioSystem.playEffect(.eliminate)
             return
```

## 测试用例
### TC-001 模式 BGM 切换
- 类型：功能测试
- 操作步骤：
  1. 启动应用并切换自由/竞分/竞速模式。
  2. 监听背景音乐是否立即切换并循环播放。
- 预期结果：
  - 三种模式对应三套不同背景音乐。
  - 切换模式后旧 BGM 停止，新 BGM 生效。

### TC-002 三阶段音效联动
- 类型：交互测试
- 操作步骤：
  1. 进行一次可消除交换操作。
  2. 观察三阶段动画并监听音效。
- 预期结果：
  - 交换阶段播放移动音效。
  - 消除阶段播放消除音效。
  - 左补位阶段播放补位音效。

### TC-003 非交换场景静默
- 类型：稳定性测试
- 操作步骤：
  1. 切换模式、重置棋盘等非交换触发场景。
- 预期结果：
  - 不触发移动/消除/补位音效误报。

### TC-004 构建验证
- 类型：构建测试
- 操作步骤：
  1. 执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期结果：
  - 构建成功。
- 实际结果：
  - 已通过。
