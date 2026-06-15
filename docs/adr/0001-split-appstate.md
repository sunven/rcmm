# ADR-0001: 拆分 AppState 为三个独立协调器

## 状态

已接受 (Accepted) - 2026-06-15

## 背景

当前 `AppState.swift` 承担了过多职责（1207 行）：

1. **领域模型** — `menuEntries`、`publishStates`、`errorRecords`
2. **编排逻辑** — 脚本同步队列、Darwin 通知、自动修复
3. **展示层** — 窗口引用、sheet 状态、onboarding 流程、健康监控、更新检查

这导致：
- **可测试性差** — 无法单独测试领域逻辑，必须同时处理 UI 和后台任务
- **职责不清** — 领域变更（保存配置）和展示变更（显示 sheet）混在一起
- **局部性差** — 相关变更分散在一个巨大的类中

通过 `/improve-codebase-architecture` 评审发现，AppState 是**浅模块**：接口复杂度（15+ @ObservationIgnored 属性）接近实现复杂度。删除测试表明它实际包含三个独立职责。

## 决策

将 AppState 拆分为三个独立协调器，采用**扁平组合**：

```
AppCoordinator
├── MenuConfigStore          // 领域模型
├── ScriptSyncCoordinator    // 编排逻辑
└── WindowCoordinator        // 展示层
```

### 职责分配

**MenuConfigStore**
- 管理：`menuEntries`、`publishStates`、`errorRecords`
- 方法：`loadEntries()`、`saveEntries()`、`updatePublishState()`、`clearScriptFileErrors()`
- 无依赖，纯领域模型

**ScriptSyncCoordinator**
- 管理：脚本编译管线、Darwin 通知、后台任务队列
- 方法：`syncScripts(entries:publishStates:)`
- 不持有 ConfigStore 引用，通过参数接收数据

**ScriptSyncCoordinator**
- 管理：脚本编译管线、Darwin 通知、后台任务队列
- 方法：`syncScripts(entries:publishStates:)`
- 不持有 ConfigStore 引用，通过参数接收数据

**WindowCoordinator**
- 管理：窗口生命周期、sheet 状态、onboarding 流程
- 功能：健康监控（每 30 分钟检查扩展状态）、更新检查
- 方法：`startHealthMonitoring()`、`scheduleUpdateCheck()`

**AppCoordinator**
- 持有三个独立协调器
- 编排自动修复逻辑（观察 `configStore.errorRecords`，触发 `syncCoordinator.syncScripts()`）
- 启动时同步初始化所有组件

### 关键设计选择

1. **扁平组合 vs 分层依赖** — 选择扁平组合，三个协调器彼此独立，避免传递依赖
2. **健康监控归属** — 放在 WindowCoordinator，因为主要消费者是 UI（菜单栏红点、popover 提示）
3. **自动修复编排** — 由 AppCoordinator 观察 ConfigStore 并触发 SyncCoordinator，保持协调器独立性
4. **更新检查归属** — 放在 WindowCoordinator，属于"启动时 UI 流程"
5. **初始化策略** — 全部同步初始化，避免可选类型和状态检查

## 理由

### 为什么扁平组合？

- **独立性** — 每个协调器可以独立测试、独立演化
- **灵活性** — 未来可以轻松添加新协调器（如 TelemetryCoordinator）
- **避免传递依赖** — 如果 C 依赖 B、B 依赖 A，修改 A 会影响 B 和 C

### 为什么健康监控在 WindowCoordinator？

- **主要消费者是 UI** — extensionStatus 驱动 popoverState、红点、提示文案
- **局部性** — 改"红点逻辑"很可能同时改健康检查频率，应该集中在一起
- **Deletion test** — 删除健康监控，WindowCoordinator 失去展示数据源；SyncCoordinator 不受影响

### 为什么自动修复在 AppCoordinator？

- **保持协调器独立** — ConfigStore 不应依赖 SyncCoordinator，SyncCoordinator 不应依赖 ConfigStore
- **明确编排逻辑** — "发现错误 → 触发修复"的决策在顶层可见
- **可测试** — 可以独立测试 ConfigStore 的错误加载、SyncCoordinator 的脚本同步

## 后果

### 正面

- **可测试性提升** — 可以独立测试领域逻辑（MenuConfigStore）、编排逻辑（SyncCoordinator）、UI 流程（WindowCoordinator）
- **职责清晰** — 每个协调器 200-400 行，单一职责
- **局部性改善** — 相关变更集中，跨协调器的变更在 AppCoordinator 清晰可见

### 负面

- **迁移成本** — 需要更新所有 UI 绑定（`appState.xxx` → `appCoordinator.configStore.xxx`）
- **路径变长** — 访问配置从 `appState.menuEntries` 变为 `appCoordinator.configStore.menuEntries`
- **学习曲线** — 新开发者需要理解三个协调器的边界

### 风险缓解

- **增量迁移** — 先创建新协调器，再逐步迁移，最后删除旧 AppState
- **测试覆盖** — 每个协调器独立添加单元测试
- **文档支持** — CONTEXT.md 记录架构术语，ADR 记录决策理由

## 参考

- [CONTEXT.md](../../CONTEXT.md) — 领域术语和架构概念
- `/improve-codebase-architecture` 评审报告 — 识别浅模块和深化机会