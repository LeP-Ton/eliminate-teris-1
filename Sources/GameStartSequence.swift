import Cocoa

/// 三种开局入口共用的过渡状态机；准备棋盘与正式计时分开，动画不占用游戏时间。
final class GameStartSequence {
    enum Phase { case waiting, dragging, returning, opening, playing }
    private struct Observer {
        weak var owner: AnyObject?
        let callback: () -> Void
    }
    private struct Animation {
        let start: TimeInterval
        let from: Double
        let to: Double
        let duration: TimeInterval
    }

    private let board: GameBoardController
    private let clock: () -> TimeInterval
    private let automaticallyAnimates: Bool
    private var observers: [UUID: Observer] = [:]
    private var animation: Animation?
    private var timer: Timer?
    private var hasPreparedBoard = false
    private(set) var phase = Phase.waiting
    private(set) var progress: Double = 0
    var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var isOpening: Bool { phase == .opening }

    init(board: GameBoardController, clock: @escaping () -> TimeInterval = { Date.timeIntervalSinceReferenceDate },
         automaticallyAnimates: Bool = true) {
        self.board = board; self.clock = clock; self.automaticallyAnimates = automaticallyAnimates
    }
    deinit { timer?.invalidate() }

    @discardableResult
    func requestAutomaticStart() -> Bool {
        guard phase != .opening else { return false }
        let needsPreparation = !hasPreparedBoard || phase == .playing
        if phase == .playing { progress = 0 }
        phase = .opening
        if needsPreparation { prepareBoard() }
        animate(to: 1, duration: max(0.12, 0.45 * (1 - progress)))
        return true
    }

    @discardableResult
    func beginDrag() -> Bool {
        guard (phase == .waiting || phase == .returning), !board.snapshot().isRunning else { return false }
        stopAnimation()
        phase = .dragging
        if !hasPreparedBoard { prepareBoard() }
        notifyChange()
        return true
    }

    func updateDrag(progress value: Double) {
        guard phase == .dragging else { return }
        progress = min(1, max(0, value))
        if progress >= 0.98 {
            phase = .opening
            animate(to: 1, duration: 0.12)
        } else { notifyChange() }
    }

    /// 松手未完成或触摸取消均回弹，不启动计时；已到终点的开场继续完成。
    func endDrag() {
        guard phase == .dragging else { return }
        phase = .returning
        animate(to: 0, duration: 0.22)
    }

    func reset(notify: Bool = true) {
        stopAnimation()
        phase = .waiting; progress = 0; hasPreparedBoard = false
        if notify { notifyChange() }
    }

    func cancelPendingStart() {
        guard phase != .playing else { return }
        reset()
    }

    /// 外部重开与正常结算仍可驱动展示；开场期间的未运行快照不会重置滑动进度。
    func synchronize(with snapshot: GameSnapshot) {
        if snapshot.isRunning, phase != .playing {
            stopAnimation(); phase = .playing; progress = 1; hasPreparedBoard = false
            notifyChange()
        } else if !snapshot.isRunning, phase == .playing { reset() }
    }

    /// 注入时钟用于确定性验证；运行时由同一方法按 60 Hz 推进动画。
    func advanceAnimation() {
        guard let animation else { return }
        let t = min(1, max(0, (clock() - animation.start) / animation.duration))
        let eased = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
        progress = animation.from + (animation.to - animation.from) * eased
        if t >= 1 { finishAnimation(to: animation.to) }
        else { notifyChange() }
    }

    func addObserver(owner: AnyObject, callback: @escaping () -> Void) -> UUID {
        let id = UUID(); observers[id] = Observer(owner: owner, callback: callback); return id
    }
    func removeObserver(_ id: UUID) { observers.removeValue(forKey: id) }

    private func prepareBoard() {
        hasPreparedBoard = true
        board.prepareRound()
    }
    private func animate(to target: Double, duration: TimeInterval) {
        stopAnimation()
        if reducesMotion() { finishAnimation(to: target); return }
        animation = Animation(start: clock(), from: progress, to: target, duration: duration)
        notifyChange()
        guard automaticallyAnimates else { return }
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.advanceAnimation() }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    private func finishAnimation(to target: Double) {
        stopAnimation(); progress = target
        if target == 1 {
            phase = .playing; hasPreparedBoard = false
            board.beginPreparedRound()
        } else { phase = .waiting }
        notifyChange()
    }
    private func stopAnimation() { timer?.invalidate(); timer = nil; animation = nil }
    private func notifyChange() {
        let current = observers
        for (id, observer) in current {
            if observer.owner == nil { observers.removeValue(forKey: id) }
            else { observer.callback() }
        }
    }
}
