# ADR-0001: 将 AppState 拆分为扁平组合模块

## 状态

已接受 (Accepted) - 2026-06-15

注：其中 `ScriptSyncCoordinator` 的形状已被 [ADR-0002](0002-deepen-script-compilation-pipeline.md) 覆盖；当前脚本发布模块为 `ScriptCompilationPipeline`。

## 背景

当前 `AppState.swift` 承担了过多职责（1207 行）：

1. **领域模型** — `menuEntries`、`publishStates`、`errorRecords`
2. **编排逻辑** — 脚本同步队列、Darwin 通知、自动修复
3. **展示层** — 窗口引用、sheet 状态、onboarding 流程、健康监控、更新检查

这导致：
- **可测试性差** — 无法单独测试领域逻辑，必须同时处理 UI 和后台任务
- **职责不清** — 领域变更（保存配置）和展示变更（显示 sheet）混在一起
- **局部性差** — 相关变更分散在一个巨大的类中

通过 `/improve-codebase-architecture` 评审发现，AppState 是**浅模块**：接口复杂度（15+ @ObservationIgnored 属性）接近实现复杂度。删除测试表明它实际包含多个独立职责。

## 决策

将 AppState 拆分为独立模块，由 `AppModel` 采用**扁平组合**：

```
AppModel
├── AppCoordinator
│   ├── MenuConfigStore
│   └── ScriptCompilationPipeline
├── WindowCoordinator
├── ApplicationDiscoveryCoordinator
├── ExtensionHealthMonitor
├── ExtensionCleanupCoordinator
├── UpdateCoordinator
└── AppFlowCoordinator
```

### 职责分配

**MenuConfigStore**
- 管理：`menuEntries`、`publishStates`、`errorRecords`
- 用户变更只修改内存，持久化与脚本发布由 AppCoordinator 的四入口写模型编排

**ScriptCompilationPipeline**
- 管理：已保存配置的串行发布、脚本编译、发布状态、错误记录与 Darwin 通知
- 不持有 MenuConfigStore 引用，interface 为 `publishCurrentConfiguration()`

**WindowCoordinator**
- 只管理 onboarding、更新提示与扩展清理窗口的创建、复用、关闭和 activation policy
- 窗口标题、尺寸与样式由 destination 隐藏
- 不承载更新或扩展清理业务状态机

**ExtensionHealthMonitor**
- 管理：扩展健康状态、诊断详情、popover 路由与 30 分钟定期刷新
- interface：`refresh()`、`activateCurrentFinderExtension()`、监控启停

**ExtensionCleanupCoordinator**
- 管理：清理计划、确认、执行进度、取消、过期请求与结果状态
- 完成后通过 AppModel 注入的窄回调触发健康刷新

**ApplicationDiscoveryCoordinator**
- 管理应用扫描单飞、结果缓存与常用编辑器/终端预设创建
- interface：扫描结果、扫描状态、预设反馈、`refresh()` 与 `addEditorTerminalPreset()`

**UpdateCoordinator**
- 管理更新状态、feed 请求、启动检查、安装动作与更新提示窗口
- interface：只读 `UpdatePresentation`、手动检查、主动作与一次性启动检查

**AppCoordinator**
- 持有 MenuConfigStore 与 ScriptCompilationPipeline
- 编排配置写入、脚本发布和自动修复

**AppFlowCoordinator**
- 编排应用启动、Onboarding 完成状态与扩展清理的独立窗口流程
- 不复制健康、清理、更新或应用发现状态，只调用对应 module 的 interface

**AppModel**
- 作为 composition root 持有各模块
- 通过窄回调连接 cleanup 完成后的健康刷新与 Onboarding 完成后的更新调度
- 组装 `AppFlowCoordinator` 所需的窗口与领域模块依赖

### 关键设计选择

1. **扁平组合 vs 分层依赖** — 选择扁平组合，各模块彼此独立，避免传递依赖
2. **健康监控归属** — 独立为 ExtensionHealthMonitor；定时与 PluginKit 状态没有窗口语义
3. **自动修复编排** — 由 AppCoordinator 观察 ConfigStore 并触发 ScriptCompilationPipeline，保持模块独立性
4. **更新检查归属** — 独立为 UpdateCoordinator；WindowCoordinator 只管理提示窗口生命周期
5. **初始化策略** — 全部同步初始化，避免可选类型和状态检查
6. **跨模块窗口流程** — AppFlowCoordinator 只持有 Onboarding 完成状态，其余业务状态留在对应模块

### 自动修复编排的后续落实（2026-08-10）

- `AppCoordinator` 在启动、popover 打开和发布完成时摄取错误快照；只有带稳定脚本身份的
  `.scriptLoad` 记录可触发修复，旧版未分类记录只展示
- 启动同步和自动修复共享一次发布；其他已有发布也可承担修复，发布在途时不追加第二次
- 每次发布捕获开始前的错误 UUID，完成后按脚本 ID 只清除 `.current` 或已从配置删除的目标；
  发布期间新产生的错误保留
- 失败不会在完成回调中循环重试，下一次独立错误摄取才允许再次尝试
- `ScriptCompilationPipeline.publishCurrentConfiguration()` 的 interface 不变；自动修复的状态、
  重试和结果归并仍全部隐藏在顶层协调器中
- 共享错误队列仍是跨进程非原子的低频诊断通道，其存储重构不属于本次决策

## 理由

### 为什么扁平组合？

- **独立性** — 每个协调器可以独立测试、独立演化
- **灵活性** — 未来可以轻松添加新协调器（如 TelemetryCoordinator）
- **避免传递依赖** — 如果 C 依赖 B、B 依赖 A，修改 A 会影响 B 和 C

### 为什么健康监控独立于 WindowCoordinator？

- **窗口语义缺失** — 健康检查即使没有任何独立窗口也必须持续运行
- **可测试性** — 状态映射、手动刷新和计时启停可通过一个小 interface 验证
- **局部性** — PluginKit 查询、状态详情与 popover 路由集中在同一模块

### 为什么自动修复在 AppCoordinator？

- **保持模块独立** — MenuConfigStore 不应依赖 ScriptCompilationPipeline，Pipeline 不应依赖 MenuConfigStore
- **明确编排逻辑** — "发现错误 → 触发修复"的决策在顶层可见
- **可测试** — 可以独立测试 MenuConfigStore 的错误加载、Pipeline 的脚本发布

## 后果

### 正面

- **可测试性提升** — 可以分别测试配置、发布、窗口生命周期与健康监控
- **职责清晰** — 窗口生命周期不再与更新、cleanup 或健康状态机混合
- **局部性改善** — 相关变更集中，跨模块联动在 AppModel 组装处可见

### 负面

- **迁移成本** — 需要更新所有 UI 绑定（`appState.xxx` → `appCoordinator.configStore.xxx`）
- **路径变长** — 访问配置从 `appState.menuEntries` 变为 `appCoordinator.configStore.menuEntries`
- **学习曲线** — 新开发者需要理解各模块及 AppModel composition root

### 风险缓解

- **增量迁移** — 先创建新协调器，再逐步迁移，最后删除旧 AppState
- **测试覆盖** — 每个协调器独立添加单元测试
- **文档支持** — CONTEXT.md 记录架构术语，ADR 记录决策理由

### 分阶段落实（2026-08-10）

- 已创建 `WindowCoordinator`，接管三类独立 NSWindow 的引用、关闭 observer、复用与 activation policy
- 已创建 `ExtensionHealthMonitor`，接管扩展状态、诊断详情、popover 路由与 30 分钟 Timer
- 已创建 `ExtensionCleanupCoordinator`，接管清理状态机；cleanup sheet 直接观察该 module
- 已创建 `UpdateCoordinator`，接管完整更新状态机；关于页直接观察该 module
- 已创建 `ApplicationDiscoveryCoordinator`，接管应用扫描缓存和组合预设创建
- 已创建 `AppFlowCoordinator`，集中剩余的启动、Onboarding 和 cleanup 窗口编排
- 所有视图直接观察实际状态 owner；`AppState` 已删除

## 参考

- [CONTEXT.md](../../CONTEXT.md) — 领域术语和架构概念
- `/improve-codebase-architecture` 评审报告 — 识别浅模块和深化机会
