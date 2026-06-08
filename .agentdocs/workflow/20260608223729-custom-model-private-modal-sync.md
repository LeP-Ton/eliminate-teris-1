# 主线同步 `custom-model` 私有 modal Touch Bar 方案

## 背景与目标
- 放弃继续扩散版本树与 monorepo 方案，回到当前仓库主线处理真实需求。
- 将 `custom-model` 分支中的私有 modal Touch Bar 展示链路同步到当前 `main` 分支。
- 保留主线已经存在的能力，不回退 `README`、英文文档、总音量控制与音量持久化。

## 约束与原则
- 只同步“私有 model / 私有 modal Touch Bar”相关实现，不把 `custom-model` 中已删除的 README 与音量功能带回主线。
- 保持当前单仓库结构不变，不引入额外分支管理方案。
- 优先最小改动：本次核心代码只改 `Sources/GameViewController.swift`，其余只更新文档与项目认知。

## 阶段与 TODO
- [x] 确认当前所在分支为 `main`，并比对 `custom-model` 差异范围。
- [x] 将私有 modal 展示链路同步回 `GameViewController`。
- [x] 保留主线音量滑杆与 `GameAudioSystem` 主音量逻辑，不做回退。
- [x] 更新 `.agentdocs/index.md` 与 `AGENTS.md` 的当前正式方案描述。
- [x] 重新编译验证当前仓库可通过构建。

## 关键风险
- `custom-model` 分支历史上删除了音量 UI 与 `README.md`，若直接整文件回滚会误伤主线新增能力。
- 私有 modal 与公开 `window.touchBar` 生命周期完全不同，若只同步一半逻辑，容易出现黑屏、残留或失焦后不回收的问题。
- 当前项目认知文档里长期记录了“正式方案为公开 Touch Bar”，若不改，会误导后续继续开发。

## 当前进展
- `Sources/GameViewController.swift` 已切回私有 modal 路线：重新接入私有 API 展示、三段刷新、健康检查与重挂载。
- 主线已有的音量滑杆与 `GameAudioSystem` 总音量持久化保持不变。
- `AGENTS.md` 与 `.agentdocs/index.md` 已改为“当前正式方案 = 私有 modal”。
- 已执行 `swift build --disable-sandbox`，构建通过。

## 代码变更
- `Sources/GameViewController.swift`
```diff
@@
-import Cocoa
+import Cocoa
+import ObjectiveC.runtime
@@
-    private let touchBarSecondaryRefreshDelay: TimeInterval = 0.12
+    private let touchBarSecondaryRefreshDelay: TimeInterval = 0.12
+    private let touchBarTertiaryRefreshDelay: TimeInterval = 0.26
+    private let touchBarHealthCheckDelay: TimeInterval = 0.18
+    private let touchBarMaxReattachAttempts = 3
@@
-    private var observerToken: UUID?
+    private var observerToken: UUID?
+    private var isPresentingSystemModalTouchBar = false
@@
-    override func makeTouchBar() -> NSTouchBar? {
-        return gameTouchBar
-    }
+    override func makeTouchBar() -> NSTouchBar? {
+        // 当前正式方案固定使用私有 modal；不再通过公开 responder 链路提供游戏 Touch Bar。
+        return nil
+    }
@@
-        refreshTouchBarPresentationForCurrentWindow()
+        synchronizeSystemModalTouchBarPresentation(trigger: "viewDidAppear")
@@
-        invalidateTouchBarRefreshLifecycle()
+        invalidateSystemModalTouchBarPresentation(reason: "viewDidDisappear")
+        removeTouchBarLifecycleObservers()
@@
-    private func refreshTouchBarPresentationForCurrentWindow() {
-        guard isViewLoaded, view.window != nil else { return }
-        ...
-    }
+    private func installTouchBarLifecycleObservers(for window: NSWindow) {
+        ...
+    }
+
+    private func synchronizeSystemModalTouchBarPresentation(trigger: String) {
+        ...
+    }
+
+    private func scheduleSystemModalDisplayRefreshes(
+        for generation: Int,
+        attempt: Int,
+        trigger: String,
+        includeHealthCheck: Bool
+    ) {
+        ...
+    }
+
+    private func handleSystemModalHealthCheckFailure(trigger: String, attempt: Int) {
+        ...
+    }
+
+    private func presentSystemModalTouchBarIfPossible() -> Bool {
+        ...
+    }
+
+    private func dismissSystemModalTouchBarIfNeeded(reason: String) {
+        ...
+    }
```

- `AGENTS.md`
```diff
@@
-- `README.md` 已明确硬件定位：完整体验依赖带 Touch Bar 的 MacBook，当前正式 Touch Bar 方案优先走公开 `window.touchBar`，以稳定显示为先。
+- `README.md` 已明确硬件定位：完整体验依赖带 Touch Bar 的 MacBook，当前正式 Touch Bar 方案已重新同步为 `custom-model` 分支的私有 modal 路线，以全宽展示与左贴边体验为先。
@@
-- Touch Bar 当前正式方案为“单槽位 16 列 + 0 宽 `escape-placeholder` + 公开 `window.touchBar`”：优先保证打包版稳定显示，接受左侧贴边效果相较私有 modal 略有回退。
+- Touch Bar 当前正式方案已重新同步为“单槽位 16 列 + 0 宽 `escape-placeholder` + 私有 `system modal`”：通过 `presentSystemModalTouchBar` / `dismissSystemModalTouchBar` 争取全宽显示与左贴边效果。
```

- `.agentdocs/index.md`
```diff
@@
+`workflow/20260608223729-custom-model-private-modal-sync.md` - 放弃继续发散版本后，直接把 `custom-model` 分支的私有 modal Touch Bar 方案同步回主线，同时保留现有 README 与音量功能。
@@
-- 当前正式 Touch Bar 方案已经统一为公开 `window.touchBar`：...
+- 当前正式 Touch Bar 方案已重新同步为 `custom-model` 分支的私有 modal：运行时通过 `presentSystemModalTouchBar` / `dismissSystemModalTouchBar` 管理展示，不再走公开 `window.touchBar` 唯一路径。
```

## 测试用例
### TC-001 主线私有 modal 构建通过
- 类型：构建验证
- 优先级：高
- 关联模块：`Sources/GameViewController.swift`
- 前置条件：本机已安装 Xcode 命令行构建环境
- 操作步骤：
1. 在项目根目录执行 `swift build --disable-sandbox`
- 预期结果：
- 工程可完成编译并成功链接 `Eliminate Teris 1`
- 不出现 `GameViewController` / Touch Bar 私有 modal 相关编译错误
- 是否通过：已通过

### TC-002 私有 modal 生命周期回归
- 类型：手动功能测试
- 优先级：高
- 关联模块：`Sources/GameViewController.swift`
- 前置条件：设备带 Touch Bar
- 操作步骤：
1. 执行 `./run.sh`
2. 进入游戏后观察 Touch Bar 是否以私有 modal 方式展示
3. 切换应用前后台、让窗口失焦再聚焦
- 预期结果：
- Touch Bar 在进入游戏后正常显示
- 失焦时关闭，重新激活后可重新挂载
- 是否通过：待人工验证

### TC-003 音量功能未回退
- 类型：手动功能测试
- 优先级：中
- 关联模块：`Sources/GameViewController.swift`、`Sources/GameAudioSystem.swift`
- 前置条件：应用可正常运行
- 操作步骤：
1. 打开游戏设置中的音量滑杆
2. 调整到不同百分比
3. 重新开始一局并观察 BGM 与音效音量
- 预期结果：
- 音量滑杆仍可见
- BGM 与音效音量随滑杆变化
- 是否通过：待人工验证
