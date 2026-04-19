# 修复打包后启动即崩的资源 Bundle 路径问题

## 背景与目标
- 用户反馈：把新的 ZIP 发到另一台 M1 机器前，本机 Intel 打包版也已经“一打开就意外退出”。
- 崩溃报告显示并非通用二进制本身有问题，而是应用启动时在读取本地化资源时触发断言。
- 本次目标是修复手工组装 `.app` 后的资源查找路径，让打包版在 Intel 与 M1 上都能正常启动。

## 根因分析
- 最新崩溃报告位于 `~/Library/Logs/DiagnosticReports/Eliminate Teris 1-2026-04-18-234136.ips`。
- 崩溃栈关键帧：
  - `closure #1 in variable initialization expression of static NSBundle.module`
  - `specialized Localizer.bundle(for:)`
  - `AppDelegate.applicationDidFinishLaunching(_:)`
- 说明问题出在 `Bundle.module`。
- SwiftPM 为 executable target 生成的 `resource_bundle_accessor.swift` 默认优先查找：
  - `Bundle.main.bundleURL.appendingPathComponent("EliminateTeris1_EliminateTeris1.bundle")`
- 而我们手工组装 `.app` 时把资源 Bundle 放在标准的 `Contents/Resources` 下。
- 结果是：
  - 放在 `Contents/Resources` 时，`Bundle.module` 找不到资源并断言崩溃。
  - 强行放在 `.app` 根目录时，`codesign` 又会报 `unsealed contents present in the bundle root`。

## 方案
- 不再依赖 `Bundle.module` 作为打包运行时的唯一入口。
- 在 `Localization.swift` 内新增自定义资源定位器，按以下顺序查找资源 Bundle：
  1. `Bundle.main.resourceURL`
  2. `Bundle.main.bundleURL`
  3. 可执行文件同级目录
  4. 可执行文件上级目录下的 `Resources`
- 打包脚本继续使用标准 `.app/Contents/Resources` 布局，避免破坏 codesign 结构。

## 代码变更
- Sources/Localization.swift
```diff
diff --git a/Sources/Localization.swift b/Sources/Localization.swift
index 00d4ee5..7b852a9 100644
--- a/Sources/Localization.swift
+++ b/Sources/Localization.swift
@@ -1,5 +1,31 @@
 import Foundation
 
+private enum LocalizerResourceLocator {
+    static let bundleName = "EliminateTeris1_EliminateTeris1"
+
+    static func resourceBundle() -> Bundle? {
+        let bundleFileName = "\(bundleName).bundle"
+        let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent()
+        let executableParentDirectory = executableDirectory?.deletingLastPathComponent()
+
+        // 同时兼容 SwiftPM 直接运行（bundle 与可执行文件同级）和手工打包 .app（bundle 位于 Contents/Resources）。
+        let candidates: [URL?] = [
+            Bundle.main.resourceURL?.appendingPathComponent(bundleFileName),
+            Bundle.main.bundleURL.appendingPathComponent(bundleFileName),
+            executableDirectory?.appendingPathComponent(bundleFileName),
+            executableParentDirectory?.appendingPathComponent("Resources").appendingPathComponent(bundleFileName)
+        ]
+
+        for candidate in candidates {
+            guard let candidate else { continue }
+            if let bundle = Bundle(url: candidate) {
+                return bundle
+            }
+        }
+
+        return nil
+    }
+}
+
 enum AppLanguage: String, CaseIterable {
     case english = "en"
     case chineseSimplified = "zh-Hans"
@@ -87,6 +113,10 @@ final class Localizer {
     }
 
     private func bundle(for language: AppLanguage) -> Bundle? {
+        guard let resourceBundle = LocalizerResourceLocator.resourceBundle() else {
+            return nil
+        }
+
         let rawCode = language.rawValue
         let candidates = [
             rawCode,
@@ -95,7 +125,7 @@ final class Localizer {
         ]
 
         for candidate in candidates {
-            guard let path = Bundle.module.path(forResource: candidate, ofType: "lproj") else {
+            guard let path = resourceBundle.path(forResource: candidate, ofType: "lproj") else {
                 continue
             }
             if let bundle = Bundle(path: path) {
```

- package.sh
```diff
diff --git a/package.sh b/package.sh
index fd996e1..05a95d3 100755
--- a/package.sh
+++ b/package.sh
@@ -88,9 +88,7 @@ lipo -create "${EXECUTABLE_PATHS[@]}" -output "$APP_DIR/Contents/MacOS/$APP_NAM
 chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
 
 if [[ -n "$RESOURCE_BUNDLE_PATH" ]]; then
-  # SwiftPM 生成的 Bundle.module 会从 Bundle.main.bundleURL 旁查找资源 Bundle。
-  # 对手工组装的 .app 来说，Bundle.main.bundleURL 是 .app 根目录，而不是 Contents/Resources。
-  cp -R "$RESOURCE_BUNDLE_PATH" "$APP_DIR/"
+  cp -R "$RESOURCE_BUNDLE_PATH" "$APP_DIR/Contents/Resources/"
 else
   echo "[package.sh] 警告：未找到 SwiftPM 资源 Bundle，多语言资源可能无法加载。"
 fi
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index b002133..b5a5999 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -43,3 +43,4 @@
 - 曾尝试以“release 默认公开路径”规避打包版 Touch Bar 黑屏（`ELIMINATE_TOUCHBAR_MODAL=1` 可强制私有 modal）；当前策略已迭代为默认私有 modal + 显式关闭开关。
 - Touch Bar 展示策略已升级为“默认私有 modal + 可显式关闭”：默认启用私有 modal 保持左侧贴边，设置 `ELIMINATE_TOUCHBAR_MODAL=0` 可回退公开路径；同时在挂载后调用 `prepareForDisplay` 并开启 `layerContentsRedrawPolicy = .onSetNeedsDisplay`，降低打包版黑屏概率。
 - `package.sh` 现在默认构建 `x86_64 + arm64` 通用二进制，并通过 `lipo` 合成为单个 `.app`，用于同时兼容 Intel 与 Apple Silicon（M1/M2/M3）Mac；可用 `PACKAGE_ARCHS` 覆盖目标架构。
+- 打包后“应用意外退出”的最新根因已确认：不是通用二进制本身，而是 `Bundle.module` 在手工 `.app` 中查找资源 Bundle 的路径与 `Contents/Resources` 不一致；现已在 `Localization.swift` 中改为兼容开发态与打包态的多路径资源查找。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index d912993..c89258f 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260418235435-fix-packaged-app-resource-bundle-crash.md` - 修复打包后启动即崩：绕开 `Bundle.module` 对手工 `.app` 的路径假设，兼容 `Contents/Resources` 资源布局。
 `workflow/20260418231251-universal-macos-package.md` - 打包脚本改为默认生成 `x86_64 + arm64` 通用 `.app`，解决发给 M1 机器后架构不匹配导致的崩溃风险。
 `workflow/20260301160231-touchbar-modal-and-black-screen-balance.md` - 同时兼顾左侧贴边与打包黑屏：默认私有 modal，增加显式回退开关与强制重绘预热。
 `workflow/20260301153306-release-touchbar-modal-fallback.md` - 修复打包版 Touch Bar 黑屏：release 默认回退公开 Touch Bar 路径，并保留环境变量开关启用私有 modal。
@@ -43,6 +44,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要排查“通用包已生成但 `.app` 启动仍意外退出”时，优先读取 `20260418235435` 文档。
 - 需要排查“压缩 `.app` 发给 M1 后应用意外退出/架构不匹配”时，优先读取 `20260418231251` 文档。
 - 需要同时处理“左侧空白间距 + 打包黑屏”时，优先读取 `20260301160231` 文档。
 - 需要排查“打包后 Touch Bar 黑屏”时，优先读取 `20260301153306` 文档。
@@ -86,6 +88,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 最新打包启动崩溃根因是资源 Bundle 路径：SwiftPM 生成的 `Bundle.module` 更适合直接从 `.build` 运行，手工组装 `.app` 时应显式兼容 `Bundle.main.resourceURL/Contents/Resources`。
 - 当前打包脚本默认输出通用二进制：分别构建 `x86_64` 与 `arm64`，再用 `lipo` 合成，最终 `file dist/Eliminate Teris 1.app/Contents/MacOS/Eliminate Teris 1` 应显示 `Mach-O universal binary with 2 architectures`。
 - Touch Bar 当前默认仍启用私有 modal（用于维持左侧贴边），但增加了 `ELIMINATE_TOUCHBAR_MODAL=0` 显式回退开关；挂载后会执行 `prepareForDisplay` 且开启 `onSetNeedsDisplay` 重绘策略，缓解打包版黑屏。
 - 打包版 Touch Bar 策略已更新：默认启用私有 modal 以保持左侧贴边，若需规避兼容性问题可显式设置 `ELIMINATE_TOUCHBAR_MODAL=0` 回退公开 `window.touchBar` 路径。
```

## 测试用例
### TC-001 本地调试构建
- 类型：构建测试
- 操作步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`
- 预期结果：构建成功，无 `Localization.swift` 编译错误。
- 是否通过：已通过。

### TC-002 通用包重新打包
- 类型：构建测试
- 操作步骤：执行 `./package.sh`
- 预期结果：
- 生成 `.app` 与 `.zip`
- `codesign` 不再因 bundle 根目录内容报错
- 可执行文件仍为 `x86_64 + arm64`
- 是否通过：已通过。

### TC-003 资源 Bundle 布局检查
- 类型：静态验证
- 操作步骤：检查 `dist/Eliminate Teris 1.app/Contents/Resources/EliminateTeris1_EliminateTeris1.bundle`
- 预期结果：资源 Bundle 位于标准 `Contents/Resources` 路径。
- 是否通过：已通过。

### TC-004 Intel/M1 启动实机验证
- 类型：兼容性测试
- 操作步骤：
  1. 在 Intel Mac 上打开新生成的 `dist/Eliminate Teris 1.app`
  2. 把新生成的 `dist/Eliminate Teris 1.zip` 发到 M1 机器，解压后打开
- 预期结果：不再因资源 Bundle 路径断言导致启动即崩。
- 是否通过：待用户在两台机器确认。
