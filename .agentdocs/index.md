# Agent 文档索引

## 当前变更文档
`workflow/20260221200836-audio-system-bgm-sfx.md` - 新增程序化音效系统：按模式切换 BGM，并按动画阶段播放移动/消除/补位音效。
`workflow/20260221193822-touchbar-three-phase-animation-sequence.md` - Touch Bar 动画改为三阶段：先交换，再消除，最后左侧补位。
`workflow/20260221192738-touchbar-animation-rollback-to-answer25.md` - 按“答-25”回退 Touch Bar 动画时序，取消两阶段串联并恢复单阶段过渡。
`workflow/20260221185955-touchbar-animation-sequence-move-then-eliminate.md` - Touch Bar 动画改为两阶段顺序：先移动后消除与补位。
`workflow/20260221184845-touchbar-eliminate-animation-visibility-boost.md` - 增强消除动画可见性，增加消除光晕特效并放大缩放/时长参数。
`workflow/20260221174959-touchbar-hide-esc-placeholder.md` - 恢复 ESC 隐藏占位，避免系统 ESC 键重新显示。
`workflow/20260221174215-touchbar-eliminate-move-animation.md` - 为 Touch Bar 增加交换/消除/左补位动画，并基于 tile id 做位移插值渲染。
`workflow/20260221162356-touchbar-private-api-modal-fallback-window-fallback.md` - 私有 API 触发改为双签名回退，并将 `window.touchBar` 限制为私有调用失败时的兜底路径。
`workflow/20260221161737-touchbar-private-api-system-modal.md` - 引入私有 API 系统级 Touch Bar 展示，改为单槽位 16 列并尝试消除 ESC 预留留白。
`workflow/20260221160132-touchbar-split-seam-compensation.md` - 重新启用 ESC 分槽位并加入主棋盘左移补偿，兼顾左贴边与首二列间距。
`workflow/20260221155545-touchbar-single-slot-remove-first-second-gap.md` - 回退为单槽位 Touch Bar，移除首二列跨槽位分隔导致的间距放大问题。
`workflow/20260221153857-touchbar-first-second-gap-balance.md` - 修复首二列间距偏大：收敛第 1 列左内边距，拉齐首二列与其余列间距。
`workflow/20260221151827-touchbar-escape-column-width-sync.md` - 修复首按钮偏窄：ESC 槽位宽度跟随主棋盘单列宽度动态同步。
`workflow/20260221151437-touchbar-escape-slot-split-with-fixed-width.md` - 重构 Touch Bar 左侧布局：首列挂到 ESC 槽位并增加显式宽度，主棋盘显示 1...15 列。
`workflow/20260221150546-touchbar-first-cell-visual-compensation.md` - 首列左贴边与图案居中并行修复：首列背景左扩 6px，图案按可见区域居中。
`workflow/20260221145833-touchbar-rollback-escape-split-first-button.md` - 回退 ESC 槽位拆分方案，修复首按钮不显示，恢复单视图 16 列渲染。
`workflow/20260221144850-touchbar-escape-slot-split-fix.md` - 修复首按钮左侧留白根因：将第 0 列挂载到 ESC 替换槽位，主棋盘改为第 1...15 列，避免首列图案偏移。
`workflow/20260221144303-touchbar-left-padding-root-cause-board-offset.md` - 修复首列按钮左侧留白：恢复首列图案居中并通过棋盘左移补偿消除容器留白。
`workflow/20260221143750-touchbar-first-cell-piece-left-align.md` - 继续修复首列留白：首列图案改为左对齐，避免首列仍然居中导致视觉空白。
`workflow/20260221143308-touchbar-left-edge-align-piece-shift.md` - 继续修复首列留白：首列方块图案左移，配合背景贴边实现更彻底左对齐。
`workflow/20260221142842-touchbar-left-edge-align.md` - 修复 Touch Bar 首个方块左侧留白，使最左格贴齐左边缘。
`workflow/20260221134551-touchbar-columns-16.md` - Touch Bar 方块列数从 12 调整为 16。
`workflow/20260221133502-mode-switch-window-lock-record-align.md` - 修复模式切换导致窗口尺寸变化，并在切换后重算挑战记录两端对齐。
`workflow/20260221132025-rules-icon-fallback-compat.md` - 修复玩法说明标题图标不显示，改用兼容符号并增加缺失回退图标。
`workflow/20260221131220-section-title-icons.md` - 为游戏设置/时间与得分/挑战记录/玩法说明标题加入图标，并统一图标与标题间距。
`workflow/20260221130438-free-mode-settings-full-width.md` - 自由模式隐藏右侧列，游戏设置卡片扩展为整行，与玩法说明等宽。
`workflow/20260221125656-rules-copy-all-modes-no-title.md` - 所有模式玩法说明去掉小标题，第二条统一为“操作方式：...”文案。
`workflow/20260221125059-rules-copy-speedrun-title-operation-prefix.md` - 竞速玩法说明去掉小标题，基础规则第二条改为“操作方式：...”，并补齐多语言键值。
`workflow/20260214235230-rules-core-bullets-record-align-theme.md` - 恢复基础规则与圆点序号，修复挑战记录两侧对齐，并把模块文字改为主题色。
`workflow/20260214233712-rules-panel-simplified-copy.md` - 玩法说明改为简短文案，仅保留模式规则与结算方式两条。
`workflow/20260214231624-rules-panel-rhodes-red.md` - 新增玩法说明模块（红色主题），按规则分类并随模式动态解释玩法。
`workflow/20260214225936-record-tag-offset-3px-spacing-half.md` - 序号 Tag 下移量调整为 3px，挑战记录行间距缩减 50%。
`workflow/20260214225442-record-tag-offset-2px.md` - 序号 Tag 下移量从 4px 调整为 2px，修正过度下沉。
`workflow/20260214224358-record-tag-offset-and-seed-mix.md` - 序号 Tag 下移 4px，挑战记录 seed 改为 9 条与 0/1 条混合分布。
`workflow/20260214223649-record-header-max9-alignment.md` - 去掉挑战记录标题后 Tag，记录上限改为 9，修复序号 Tag 与文字中线对齐。
`workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。

## 读取场景
- 需要确认“模式切换 BGM + 交换/消除/补位音效”是否已接入时，优先读取 `20260221200836` 文档。
- 需要确认“交换后才消除、消除后才补位”是否落地时，优先读取 `20260221193822` 文档。
- 需要确认“已回退到答-25的动画时序”时，优先读取 `20260221192738` 文档。
- 需要确认“动画顺序为何曾改为先移动后消除（历史方案）”时，优先读取 `20260221185955` 文档。
- 需要确认“消除动画不明显如何增强”时，优先读取 `20260221184845` 文档。
- 需要确认“为什么 ESC 又出现、如何重新隐藏 ESC”时，优先读取 `20260221174959` 文档。
- 需要确认“交换、消除、左补位动画是否已接入 Touch Bar”时，优先读取 `20260221174215` 文档。
- 需要确认“私有 API 触发失败时如何回退、是否还会与 window.touchBar 冲突”时，优先读取 `20260221162356` 文档。
- 需要确认“私有 API 路线（system modal）是否已接入”时，优先读取 `20260221161737` 文档。
- 需要确认“左贴边 + 首二列间距收敛”的最新方案（分槽位 + seam 补偿）时，优先读取 `20260221160132` 文档。
- 需要确认“首二列间距仍异常”后的结构性回退（单槽位渲染）时，优先读取 `20260221155545` 文档。
- 需要确认“首二列间距偏大”修复（第 1 列左内边距补偿）时，优先读取 `20260221153857` 文档。
- 需要确认“首按钮偏窄”修复（ESC 槽位与主棋盘列宽同步）时，优先读取 `20260221151827` 文档。
- 需要确认“最左按钮占用 ESC 槽位且不再消失”的重构修复时，优先读取 `20260221151437` 文档。
- 需要确认“首列向左贴边但图案仍居中”的并行修复时，优先读取 `20260221150546` 文档。
- 需要确认“首按钮不显示”回退修复时，优先读取 `20260221145833` 文档。
- 需要确认“首按钮左侧留白来自 ESC 槽位、并通过拆分 Touch Bar 视图修复”时，优先读取 `20260221144850` 文档。
- 需要确认“首列方块居中且首按钮左侧留白消除”的根因修复时，优先读取 `20260221144303` 文档。
- 需要确认“首列图案从居中改为左对齐后留白消除”时，优先读取 `20260221143750` 文档。
- 需要确认“首列图案也左移、首列视觉留白进一步消除”时，优先读取 `20260221143308` 文档。
- 需要确认“Touch Bar 最左方块左对齐、无额外留白”时，优先读取 `20260221142842` 文档。
- 需要确认“Touch Bar 显示 16 个方块”时，优先读取 `20260221134551` 文档。
- 需要确认“模式切换后窗口尺寸稳定 + 挑战记录两端对齐稳定”时，优先读取 `20260221133502` 文档。
- 需要确认“玩法说明标题图标在旧系统也可见”的兼容性修复时，优先读取 `20260221132025` 文档。
- 需要确认“四个模块标题增加图标且间距一致”时，优先读取 `20260221131220` 文档。
- 需要确认“自由模式游戏设置卡片占满整行、与玩法说明同宽”时，优先读取 `20260221130438` 文档。
- 需要确认“所有模式均不显示玩法说明小标题 + 第二条固定为操作方式前缀”时，优先读取 `20260221125656` 文档。
- 需要确认“竞速模式不显示小标题 + 第二条基础规则改为操作方式前缀”时，优先读取 `20260221125059` 文档。
- 需要确认“基础规则已恢复 + 玩法说明圆点序号 + 挑战记录两侧对齐恢复 + 模块文本主题色”时，优先读取 `20260214235230` 文档。
- 需要确认玩法说明“精简文案版（模式规则 + 结算方式）”时，优先读取 `20260214233712` 文档。
- 需要确认玩法说明模块布局、红色主题与模式化文案时，优先读取 `20260214231624` 文档。
- 需要确认“序号 Tag 下移量 3px”与“记录间距减半”时，优先读取 `20260214225936` 文档。
- 需要确认“序号 Tag 下移量从 4px 调整到 2px”时，优先读取 `20260214225442` 文档。
- 需要确认“序号 Tag 下移 4px”与“部分模式 0/1 条 seed”时，优先读取 `20260214224358` 文档。
- 需要确认挑战记录标题简化、记录上限、序号对齐的实现时，优先读取 `20260214223649` 文档。
- 遇到“`./run.sh` 启动还是旧版本”时，优先读取此文档。
- 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。

## 关键记忆
- 已新增 `GameAudioSystem` 程序化音频链路：自由/竞分/竞速模式切换会切 BGM，且仅在“交换触发”的三阶段过渡中按阶段播放移动、消除、补位音效，避免模式切换/重置触发误报声。
- Touch Bar 动画时序当前为三阶段链路：交换位移（0.16s）→ 消除反馈（0.20s）→ 左侧补位（0.24s）；交换对由 `GameBoardController.lastSwapPair` 提供，渲染端以 `transitionPhases` 顺序执行。
- Touch Bar 动画时序已回退到答-25：单阶段过渡（`0.28s`），保留消除光晕/外环与放大缩放淡出，取消两阶段 pending 串联逻辑。
- 消除动画可见性已增强：消除帧使用 `easeIn` + 光晕外环，缩放区间 `1.22 -> 0.12`，动画总时长 `0.28s`，并对移动/插入采用分离 easing。
- Touch Bar 当前通过 `escapeKeyReplacementItemIdentifier = escape-placeholder`（0 宽视图）隐藏系统 ESC，避免私有 API 链路中再次显示 ESC 键。
- Touch Bar 已接入过渡动画：共享 tile 使用位置插值，消除使用缩放淡出，新补位从左侧滑入；动画时长约 `0.22s`，曲线为 `easeOutCubic`。
- 私有 API 当前采用双签名回退：优先调用 `presentSystemModalTouchBar:systemTrayItemIdentifier:`，不可用时回退到 `presentSystemModalTouchBar:placement:systemTrayItemIdentifier:`（placement=自动）；仅在两者都不可用时才启用 `window.touchBar`。
- 已接入私有 API 调用链：`presentSystemModalTouchBar` / `dismissSystemModalTouchBar`，当前策略为单槽位 16 列 + system modal 展示，以规避公开 API 下 ESC 预留留白。
- Touch Bar 最新策略为分槽位渲染：ESC 槽位承载第 0 列、主槽位承载 1...15，并对主槽位施加 `leadingCompensationX=8` 左移补偿，减少跨槽位缝隙。
- Touch Bar 曾回到单槽位渲染（`0..<16` + 0 宽 ESC 占位）用于排查首二列间距；当前已切回分槽位并增加 seam 补偿。
- ESC 槽位和主棋盘之间存在系统级分隔，曾尝试通过 `globalIndex == 1` 左内边距补偿收敛首二列间距，当前改为主槽位整体左移 seam 补偿。
- ESC 槽位首列宽度不再固定常量，改为实时同步 `主棋盘宽度 / 15`，并监听主棋盘 frame 变化自动更新，避免首列视觉偏窄。
- Touch Bar 左侧最新实现为“ESC 槽位首列 + 主区 1...15 列”，ESC 槽位先用 fallback 宽度保底，再同步为主棋盘单列宽度。
- Touch Bar 首列使用独立视觉补偿：背景区域左扩 6px（不改触摸索引），图案绘制按首列可见区域居中，减少左留白同时避免首列图案偏移。
- ESC 槽位拆分在当前环境会导致首按钮不显示，已回退为单一棋盘视图 `0..<16` + 0 宽 ESC 占位；优先保证首按钮可见。
- Touch Bar 左侧留白的最新根因定位为 ESC 专属槽位与主棋盘区域分离；当前方案是“ESC 槽位承载第 0 列 + 主棋盘承载第 1...15 列”。
- 首列图案在排查期曾改为左对齐，现已回退为按钮内居中；当前留白修复基于“ESC 槽位拆分”，不再移动整盘坐标。
- 旧的“棋盘整体左移补偿（`boardOriginX = -6`）”方案已下线，避免首列可视宽度变窄导致“图案不居中”副作用。
- 首列对齐当前仅作用于背景层：仅全局第 0 列执行左补偿 `tileOuterInsetX`，图案层统一保持居中绘制。
- Touch Bar 首列背景绘制会在 x 方向向左补偿 `tileOuterInsetX`，以贴齐最左边界并保留其余列间距策略。
- Touch Bar 当前列数为 16（原 12），`GameViewController` 通过 `columns` 常量驱动 `GameBoardController` 与 `GameTouchBarView` 的显示范围。
- 模式切换流程中已加入窗口 frame 保护与切换后记录面板二次重排，解决窗口跳变和记录对齐漂移。
- 玩法说明标题图标已从 `book.pages` 调整为 `doc.text`，并在符号不可用时回退为 `circle.fill`，避免图标缺失。
- 四个模块标题均采用“图标 + 标题”头部，图标使用 SF Symbols 并按模块主题色着色，图标与标题间距统一为 `6`。
- 自由模式会隐藏右侧状态/挑战记录列，并启用设置卡片整行宽约束；竞分/竞速模式恢复双列布局约束。
- 玩法说明在所有模式下都不再显示模式标题行，基础规则第二条统一为“操作方式：...”文案，并已同步中英日韩俄多语言。
- `run.sh` 现在每次执行都先 `swift build --disable-sandbox`。
- 启动路径通过 `swift build --show-bin-path` 计算，不再依赖手动拼接构建目录。
- 挑战记录头部不再显示模式/细分 Tag，序号 Tag 对齐通过 `baselineOffset` 微调。
- 模式记录分桶上限为 9，加载后会对历史桶执行排序与裁剪。
- 序号 Tag 当前使用 `attachment.bounds.y = -3` 做视觉下移；seed 分布为“满 9 条 + 部分分组 0/1 条”；挑战记录 `lineSpacing` 为 `3.5`。
- 玩法说明模块位于 `cardsStack` 下方，使用红色 `PixelFrameCardView`，按分类文案动态解释当前模式规则。
- 玩法说明当前采用更短文案：模式标题 + 两条规则（模式规则、结算方式），并随模式/子规则动态更新。
- 玩法说明现已补回“基础规则”并统一 `•` 圆点样式；挑战记录会在布局宽度变化时重建富文本，确保“排名+得分/日期”保持两侧对齐。
- 游戏设置/时间与得分/挑战记录模块标题与主要内容文本统一为蓝/绿/橙主题色，避免白色正文与主题割裂。
