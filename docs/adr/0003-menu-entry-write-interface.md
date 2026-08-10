# ADR-0003: Menu Entry 配置的四入口写模型

状态：已接受 (Accepted) - 2026-08-09

## 背景

`AppState` → `AppCoordinator` → `MenuConfigStore` 形成了三层转发：每个 Menu Entry
变更都要声明三遍。`AppState` 有 33 处纯转发、零增量；`AppCoordinator` 的 22 个具名方法
只比 store 多一行 `syncScriptsInBackground()`。`updateNewFileTemplate` 带着 9 个参数
穿过全部三层。

删除测试：删掉 `AppState` 的变更面，复杂度直接消失，调用方不需要补任何东西 —— 它是
pass-through。删掉 `AppCoordinator` 的 22 个包装，只有「变更后发布」这一条规则会重新
出现，且只出现一次 —— 它作为一个 seam 是值得留的，作为 22 个方法不是。

同时写入通道并不止一条：`saveAndSync()`（拖拽提交）、`moveEntry(sync: false)`（拖拽
预览）、`menuEntries` 的直接赋值（拖拽取消）、`ensureNewFileMenu()`（存而不发布）各走各的，
「这次改动会不会落盘、会不会发布」在调用点看不出来。

## 决策

`AppCoordinator` 暴露四个写入入口，取代 22 个具名方法：

| 入口 | 改内存 | 落盘 | 脚本发布 |
|---|---|---|---|
| `edit { store in … }` | ✓ | ✓ | ✓ |
| `preview { store in … }` | ✓ | — | — |
| `commitPreview()` | — | ✓ | ✓ |
| `updateMenuPresentationMode(_:)` | ✓ | ✓ | 仅 Cross-Process Sync 通知 |

**不变量**：每一次已提交编辑恰好触发一次发布。

视图读配置改用 `@Environment(MenuConfigStore.self)`，写配置用
`@Environment(AppCoordinator.self)`。读写落在两个 environment 值上，调用点一眼可辨。

`MenuConfigStore` 保留全部具名方法。其中 8 个带真实领域规则（bundleId/路径去重、
Built-in Entry 与 New File Menu 的删除保护、唯一命名、New File Template fingerprint、
默认配置与模板迁移），删掉会把规则散到调用方；其余的纯 setter 也保留，删掉会把
`case .composite(var config)` 这类 enum 拆包推进视图 —— 换来一个新的泄漏。
三层转发的收益在删掉两层时已经拿到。

## 理由

### 为什么 `edit` 收闭包而不是 intent 枚举

intent 枚举等于把 22 个方法换成 22 个 case，接口宽度没变。闭包让领域规则留在
`MenuConfigStore` 的具名方法里，同时把「变更后必须发布」这条规则收进一个地方。

### 为什么 `edit` 是同步的

发布在重构前就是 fire-and-forget（`syncScriptsInBackground` 起 `Task` 就返回）。
改成 `async` 会让 20 处视图调用点全都要包 `Task { }`，属于把行为改动混进结构重构。
`AppCoordinator.publishTask` 暴露最近一次发布任务，测试用它等待发布结束。

### 为什么 preview 的回滚不在 MenuConfigStore

考虑过给 store 加 `beginPreview()` / `commit()` / `rollback()` 事务。否决：拖拽期间的
原始顺序是货真价实的视图状态（还牵着选中项和动画），搬进 store 等于把 UI 生命周期塞进
领域模型。而且预览目前只有拖拽排序一个消费者 —— 一个消费者是假 seam，两个才是真的。
出现第二个预览场景时可以重开这个决定。

### 为什么 `updateMenuPresentationMode` 不走 `edit`

它改的不是 Menu Entry 列表，是展示方式，不影响 `.scpt` 内容。走 `edit` 会为一个枚举
触发全量 AppleScript 重编译。也考虑过给 `edit` 加一个「跳过发布」参数 —— 否决：那正是
`moveEntry(sync:)` 那种布尔标志的形状，本次重构要消灭的就是它。

### 为什么不给 ScriptCompilationPipeline 抽 protocol

`PipelineHarness` 已经能注入 fake compiler / notifier / iconPublisher / 文件系统 ——
seam 是真的，而且已经在那儿。再抽一层 protocol 是在一个真 seam 上叠一个假 seam。

## 后果

### 正面

- `AppState` 920 → 741 行，`AppCoordinator` 311 → 205 行，删掉 21 个转发包装
- 「这次改动会不会落盘、会不会发布」在调用点直接可读
- 协调器层从 0 个专属测试文件变成 2 个（`AppCoordinatorEditTests`、`MenuConfigStoreTests`）
- 拖拽的预览／提交／取消三段语义显式化，`sync: Bool` 标志消失

### 负面

- 视图需要注入两个 environment 值（`AppCoordinator` + `MenuConfigStore`）
- `MenuConfigStore.menuEntries` 仍然可写，「写只走四个入口」靠纪律而非类型系统

### 后续落实（2026-08-10）

`MenuConfigStore` 的具名用户变更已改为只修改内存，持久化由 `edit` / `commitPreview`
统一触发；`moveEntry` 的 `save` 布尔参数同时删除。初始化、迁移与加载修复仍可直接落盘，
Script Compilation Pipeline 仍负责写入发布阶段生成的 New File Template Fingerprint。

## 与既有 ADR 的关系

沿用 [ADR-0001](0001-split-appstate.md) 的扁平组合与「自动修复编排在顶层可见」，
只改写 `AppCoordinator` 编排接口的具体形状。不影响 [ADR-0002](0002-deepen-script-compilation-pipeline.md)
的 `ScriptCompilationPipeline` seam —— 四个入口都落在它的 `publishCurrentConfiguration()` 上。

`AppState` 的窗口生命周期与健康监控已分别迁入 `WindowCoordinator` 和
`ExtensionHealthMonitor`，扩展清理状态机与更新检查已分别迁入
`ExtensionCleanupCoordinator` 和 `UpdateCoordinator`；本 ADR 不涉及这些模块的内部接口。

## 参考

- [CONTEXT.md](../../CONTEXT.md) — 四入口写模型的术语定义
- `/improve-codebase-architecture` 评审报告 — 候选 1「Collapse the Menu Entry mutation forwarding」
