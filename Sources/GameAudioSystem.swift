import AVFoundation
import Foundation

final class GameAudioSystem: NSObject, AVAudioPlayerDelegate {
    enum SoundEffect: Hashable {
        case move
        case eliminate
        case refill
    }

    static let shared = GameAudioSystem()

    private enum MusicTheme: Hashable {
        case free
        case scoreAttack
        case speedRun
    }

    private enum Waveform {
        case sine
        case square
        case triangle
    }

    private struct Note {
        let frequency: Double
        let beats: Double
        let waveform: Waveform
        let amplitude: Double
    }

    private let sampleRate: Double = 44_100
    private let stateLock = NSLock()

    private var currentTheme: MusicTheme?
    private var backgroundPlayer: AVAudioPlayer?
    private var activeEffectPlayers: [AVAudioPlayer] = []
    private var backgroundDataCache: [MusicTheme: Data] = [:]
    private var effectDataCache: [SoundEffect: Data] = [:]

    private override init() {
        super.init()
    }

    func updateBackgroundMusic(for mode: GameMode) {
        let theme = theme(for: mode)
        stateLock.lock()
        defer { stateLock.unlock() }

        // 同一模式直接复用播放器，避免频繁重建导致的听感抖动。
        if currentTheme == theme, let player = backgroundPlayer {
            if !player.isPlaying {
                player.play()
            }
            return
        }

        let data = backgroundData(theme)
        do {
            let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
            player.numberOfLoops = -1
            player.volume = backgroundVolume(for: theme)
            player.prepareToPlay()

            backgroundPlayer?.stop()
            backgroundPlayer = player
            currentTheme = theme
            player.play()
        } catch {
            backgroundPlayer?.stop()
            backgroundPlayer = nil
            currentTheme = nil
        }
    }

    func stopBackgroundMusic() {
        stateLock.lock()
        defer { stateLock.unlock() }

        backgroundPlayer?.stop()
        backgroundPlayer = nil
        currentTheme = nil

        for player in activeEffectPlayers {
            player.stop()
        }
        activeEffectPlayers.removeAll()
    }

    func playEffect(_ effect: SoundEffect) {
        stateLock.lock()
        defer { stateLock.unlock() }

        let data = effectData(effect)
        do {
            let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
            player.delegate = self
            player.volume = effectVolume(for: effect)
            player.prepareToPlay()

            activeEffectPlayers.removeAll(where: { !$0.isPlaying })
            activeEffectPlayers.append(player)
            player.play()
        } catch {
            return
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        removeEffectPlayer(player)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        removeEffectPlayer(player)
    }

    private func removeEffectPlayer(_ player: AVAudioPlayer) {
        stateLock.lock()
        defer { stateLock.unlock() }
        activeEffectPlayers.removeAll(where: { $0 === player })
    }

    private func theme(for mode: GameMode) -> MusicTheme {
        switch mode {
        case .free:
            return .free
        case .scoreAttack:
            return .scoreAttack
        case .speedRun:
            return .speedRun
        }
    }

    private func backgroundVolume(for theme: MusicTheme) -> Float {
        switch theme {
        case .free:
            return 0.22
        case .scoreAttack:
            return 0.25
        case .speedRun:
            return 0.27
        }
    }

    private func effectVolume(for effect: SoundEffect) -> Float {
        switch effect {
        case .move:
            return 0.5
        case .eliminate:
            return 0.56
        case .refill:
            return 0.48
        }
    }

    private func backgroundData(_ theme: MusicTheme) -> Data {
        if let cached = backgroundDataCache[theme] {
            return cached
        }
        // BGM 只在首次使用时合成一次，后续直接读取缓存。
        let data = createBackgroundData(theme)
        backgroundDataCache[theme] = data
        return data
    }

    private func effectData(_ effect: SoundEffect) -> Data {
        if let cached = effectDataCache[effect] {
            return cached
        }
        // 交互音效同样缓存，减少交换高频触发时的分配开销。
        let data = createEffectData(effect)
        effectDataCache[effect] = data
        return data
    }

    private func createBackgroundData(_ theme: MusicTheme) -> Data {
        switch theme {
        case .free:
            return synthesize(
                tempo: 92,
                tracks: [
                    sequence(
                        [72, 76, 79, 76, 74, 77, 81, 77, 72, 76, 79, 76, 74, 77, 79, -1],
                        beat: 0.5,
                        waveform: .triangle,
                        amplitude: 0.34
                    ),
                    sequence(
                        [48, -1, 55, -1, 45, -1, 50, -1, 48, -1, 55, -1, 43, -1, 50, -1],
                        beat: 0.5,
                        waveform: .sine,
                        amplitude: 0.2
                    )
                ]
            )

        case .scoreAttack:
            return synthesize(
                tempo: 128,
                tracks: [
                    sequence(
                        [76, 79, 81, 84, 81, 79, 76, 74, 76, 79, 83, 86, 83, 79, 76, -1],
                        beat: 0.5,
                        waveform: .square,
                        amplitude: 0.31
                    ),
                    sequence(
                        [52, 52, 55, 55, 57, 57, 55, 55, 50, 50, 53, 53, 55, 55, 53, 53],
                        beat: 0.5,
                        waveform: .triangle,
                        amplitude: 0.2
                    )
                ]
            )

        case .speedRun:
            return synthesize(
                tempo: 146,
                tracks: [
                    sequence(
                        [79, 83, 86, 88, 86, 83, 79, 76, 79, 83, 86, 91, 86, 83, 79, -1],
                        beat: 0.5,
                        waveform: .square,
                        amplitude: 0.3
                    ),
                    sequence(
                        [43, 43, 47, 47, 50, 50, 47, 47, 45, 45, 48, 48, 52, 52, 48, 48],
                        beat: 0.5,
                        waveform: .triangle,
                        amplitude: 0.21
                    )
                ]
            )
        }
    }

    private func createEffectData(_ effect: SoundEffect) -> Data {
        switch effect {
        case .move:
            return synthesize(
                tempo: 300,
                tracks: [
                    sequence(
                        [(76, 0.24), (83, 0.24)],
                        waveform: .square,
                        amplitude: 0.36
                    ),
                    sequence(
                        [(64, 0.48)],
                        waveform: .sine,
                        amplitude: 0.16
                    )
                ]
            )

        case .eliminate:
            return synthesize(
                tempo: 260,
                tracks: [
                    sequence(
                        [(88, 0.16), (83, 0.16), (79, 0.16), (67, 0.2), (-1, 0.08)],
                        waveform: .square,
                        amplitude: 0.4
                    ),
                    sequence(
                        [(55, 0.76)],
                        waveform: .triangle,
                        amplitude: 0.2
                    )
                ]
            )

        case .refill:
            return synthesize(
                tempo: 320,
                tracks: [
                    sequence(
                        [(67, 0.18), (72, 0.18), (76, 0.18)],
                        waveform: .triangle,
                        amplitude: 0.34
                    ),
                    sequence(
                        [(55, 0.54)],
                        waveform: .sine,
                        amplitude: 0.16
                    )
                ]
            )
        }
    }

    private func sequence(_ notes: [Int], beat: Double, waveform: Waveform, amplitude: Double) -> [Note] {
        return notes.map {
            makeNote(midi: $0, beats: beat, waveform: waveform, amplitude: amplitude)
        }
    }

    private func sequence(_ notes: [(Int, Double)], waveform: Waveform, amplitude: Double) -> [Note] {
        return notes.map {
            makeNote(midi: $0.0, beats: $0.1, waveform: waveform, amplitude: amplitude)
        }
    }

    private func makeNote(midi: Int, beats: Double, waveform: Waveform, amplitude: Double) -> Note {
        guard midi > 0 else {
            return Note(frequency: 0, beats: beats, waveform: waveform, amplitude: 0)
        }
        return Note(
            frequency: frequency(forMIDINote: midi),
            beats: beats,
            waveform: waveform,
            amplitude: amplitude
        )
    }

    private func synthesize(tempo: Double, tracks: [[Note]]) -> Data {
        // 通过简单波形 + 包络生成 PCM，再封装成 WAV 交给 AVAudioPlayer 播放。
        let secondsPerBeat = 60.0 / max(1, tempo)
        let rendered = tracks.map { renderTrack($0, secondsPerBeat: secondsPerBeat) }
        let mixedSamples = mixTracks(rendered)
        return makeWAVData(samples: mixedSamples)
    }

    private func renderTrack(_ notes: [Note], secondsPerBeat: Double) -> [Double] {
        var samples: [Double] = []

        for note in notes {
            let sampleCount = max(1, Int((note.beats * secondsPerBeat * sampleRate).rounded()))
            let attackSamples = max(1, Int(sampleRate * 0.006))
            let releaseSamples = max(1, Int(sampleRate * 0.02))

            for sampleIndex in 0..<sampleCount {
                guard note.frequency > 0 else {
                    samples.append(0)
                    continue
                }

                let time = Double(sampleIndex) / sampleRate
                let phase = 2 * Double.pi * note.frequency * time
                let wave = oscillatorSample(waveform: note.waveform, phase: phase)
                let attackGain = min(1, Double(sampleIndex) / Double(attackSamples))
                let releaseSource = max(0, sampleCount - sampleIndex - 1)
                let releaseGain = min(1, Double(releaseSource) / Double(releaseSamples))
                let envelope = max(0, min(attackGain, releaseGain))

                samples.append(wave * note.amplitude * envelope)
            }
        }

        return samples
    }

    private func oscillatorSample(waveform: Waveform, phase: Double) -> Double {
        switch waveform {
        case .sine:
            return sin(phase)
        case .square:
            return sin(phase) >= 0 ? 1 : -1
        case .triangle:
            let normalized = phase / (2 * Double.pi)
            return 2 * abs(2 * (normalized - floor(normalized + 0.5))) - 1
        }
    }

    private func mixTracks(_ tracks: [[Double]]) -> [Int16] {
        let maxSamples = tracks.map(\.count).max() ?? 0
        guard maxSamples > 0 else { return [0] }

        var mixed = [Double](repeating: 0, count: maxSamples)
        for track in tracks {
            for (index, sample) in track.enumerated() {
                mixed[index] += sample
            }
        }

        let peak = mixed.reduce(0) { max($0, abs($1)) }
        let gain = peak > 0 ? 0.84 / peak : 0

        return mixed.map { value in
            let normalized = max(-1, min(1, value * gain))
            return Int16(normalized * Double(Int16.max))
        }
    }

    private func frequency(forMIDINote midi: Int) -> Double {
        return 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
    }

    private func makeWAVData(samples: [Int16]) -> Data {
        // 写入标准 WAV 头，保持全平台播放器可识别。
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerSample: UInt16 = bitsPerSample / 8
        let blockAlign: UInt16 = channels * bytesPerSample
        let sampleRateValue = UInt32(sampleRate)
        let byteRate: UInt32 = sampleRateValue * UInt32(blockAlign)
        let dataSize: UInt32 = UInt32(samples.count) * UInt32(bytesPerSample)
        let riffChunkSize: UInt32 = 36 + dataSize

        var data = Data(capacity: Int(riffChunkSize + 8))
        data.appendASCII("RIFF")
        data.appendLittleEndian(riffChunkSize)
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(channels)
        data.appendLittleEndian(sampleRateValue)
        data.appendLittleEndian(byteRate)
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(bitsPerSample)
        data.appendASCII("data")
        data.appendLittleEndian(dataSize)

        for sample in samples {
            data.appendLittleEndian(UInt16(bitPattern: sample))
        }
        return data
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        if let ascii = string.data(using: .ascii) {
            append(ascii)
        }
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(bytes.bindMemory(to: UInt8.self))
        }
    }
}
