# README 英文结尾邀请文案同步

## 背景与目标
- 上一轮只调整了中文 `README.md` 的结尾邀请文案，英文 `README.en.md` 仍保留“run it, tweak it, and keep building on it”的开源协作语气。
- 本次目标是把英文结尾也同步成与中文一致的轻松展示页式收尾，统一整体项目介绍气质。

## 约束与原则
- 仅调整英文 README 的最后一句邀请文案，不扩散修改其他英文段落。
- 新文案保持简洁、自然，并与中文“关注并留言”的语义尽量对齐。
- 同步更新索引与项目认知，确保中英文 README 的收尾策略都可追溯。

## 阶段与 TODO
- [x] 定位英文 README 结尾原文。
- [x] 替换为与中文同风格的新文案。
- [x] 更新 `.agentdocs/index.md` 与 `AGENTS.md`。
- [x] 完成基础文档自检。

## 关键风险
- 如果英文改得过于字面直译，可能显得生硬，因此本次在贴近原意的同时，尽量保留自然口吻。
- 如果只改中文不改英文，双语 README 的结尾语气会继续不一致。

## 当前进展
- 英文 README 结尾已从“run it, tweak it, and keep building on it”改为“follow and leave a comment”。
- 中英文 README 现在都统一为更轻松、更偏展示页式的结尾邀请语气。

## 代码变更
- `README.en.md`
```diff
--- a/README.en.md
+++ b/README.en.md
@@ -221,4 +221,4 @@
 
 `Eliminate Teris 1` is not trying to be a huge content-heavy game. It is a small work with a very clear personality: the satisfaction of match-clearing, the uniqueness of the Touch Bar, and a bit of pixel-arcade flavor compressed into a narrow but surprisingly playful space.
 
-If you like projects that are modest in scale but serious in intent, feel free to run it, tweak it, and keep building on it.
+If you also like things that are small but fun, feel free to follow and leave a comment.
```

- `.agentdocs/index.md`
```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260610234858-readme-english-closing-copy-sync.md` - 同步调整英文 README 结尾邀请文案，与中文版本统一为更轻松的“关注并留言”语气。
 `workflow/20260610234418-readme-closing-copy-update.md` - 调整中文 README 结尾邀请文案，从“运行它、改它”改为更轻松的“关注并留言”表达。
@@ -53,6 +54,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要确认“英文 README 结尾是否也已经同步改成更轻松的关注/留言语气”时，优先读取 `20260610234858` 文档。
 - 需要确认“README 最后一段的邀请文案现在是什么语气、是否已经改成‘关注并留言’”时，优先读取 `20260610234418` 文档。
@@ -106,6 +108,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 英文 README 结尾现已与中文同步，改为更轻松的展示页式邀请语：强调“small but fun”，并以“follow and leave a comment”收尾。
 - 中文 README 结尾的邀请语现已改为“如果你也喜欢这种‘不大，但有趣’的东西，欢迎关注并留言。”，整体语气比此前更轻、更偏展示页式收束。
```

- `AGENTS.md`
```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -1,7 +1,8 @@
 # 项目认知记录
 
 ## 2026-06-10
 - README 顶部现已增强为“项目首页入口”形态：`README.md` 与 `README.en.md` 都新增了静态徽章，首屏即可看到平台、Swift 版本、Touch Bar 适配与当前可玩状态。
 - 中英文 README 顶部都已加入目录（TOC）与“截图预览”占位区；当前仓库还没有正式截图资源，后续补图时应优先填充该区域，而不是把截图分散插入正文各处。
 - 仓库现已新增 `docs/screenshots/` 文档资源目录：内置 3 张 SVG 截图占位图与一份替换说明，README 截图区已改为实际图片链接模板，后续可直接替换资源文件。
 - 中文 README 结尾 CTA 已改为更轻松的展示型文案：“如果你也喜欢这种‘不大，但有趣’的东西，欢迎关注并留言。”
+- 英文 README 结尾 CTA 也已同步改写为同风格表达：`If you also like things that are small but fun, feel free to follow and leave a comment.`
```

## 测试用例
### TC-001 英文 README 结尾文案同步
- 类型：文档检查
- 优先级：低
- 关联模块：`README.en.md`
- 前置条件：打开英文 README
- 操作步骤：
1. 滚动到 `Closing` 章节
2. 检查最后一句邀请文案
- 预期结果：
- 文案显示为 `If you also like things that are small but fun, feel free to follow and leave a comment.`
- 是否通过：已通过
