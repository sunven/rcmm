# AppState 拆分 - 实现总结

**完成时间**: 2026-06-15  
**技能**: `/improve-codebase-architecture`  
**候选项**: #1 - Split AppState into Three Coordinators

## 目标

将 1207 行的 AppState 拆分为三个独立的协调器，提升可测试性、明确职责边界、改善局部性。

## 完成的工作

### 1. 架构文档

- ✅ **CONTEXT.md** — 定义领域术语（Menu Entry、Script Compilation Pipeline、Coordinator 等）
- ✅ **docs/adr/0001-split-appstate.md** — 记录架构决策、理由和后果
- ✅ **docs/MIGRATION-GUIDE.md** — 详细的迁移步骤和属性访问路径对照表

### 2. 新协调器实现

#### MenuConfigStore.swift (纯领域模型)

**职责**：管理菜单配置、发布状态、错误记录  
**特点**：无 UI 依赖、无脚本编译逻辑、可独立测试  
**行数**：~250 行

**关键接口**：
```swift
func loadMenuEntries()
func saveEntries()
func addMenuItem(from: AppInfo) -> UUID?
func toggleEntry(for: String, isEnabled: Bool)
func loadPublishStates()
func loadErrors()
var hasScriptFileErrors: Bool
```

#### ScriptSyncCoordinator.swift (编排逻辑)

**职责**：脚本编译管线、Darwin 通知、后台队列  
**特点**：不持有 ConfigStore 引用、通过参数接收数据、串行执行  
**行数**：~65 行

**关键接口**：
```swift
func syncScripts(entries: [MenuEntry]) async -> [ScriptPublishState]
func syncScriptsInBackground(entries: [MenuEntry], onComplete: ([ScriptPublishState]) -> Void)
```

#### WindowCoordinator.swift (展示层)

**职责**：窗口生命周期、健康监控、更新检查  
**特点**：不依赖领域模型、所有 UI 状态集中管理  
**行数**：~350 行

**关键接口**：
```swift
func startHealthMonitoring()
func checkExtensionStatus()
func scheduleStartupUpdateCheckIfNeeded()
func checkForUpdates() async
func showOnboardingIfNeeded()
func beginExtensionCleanup()
```

#### AppCoordinator.swift (顶层编排器)

**职责**：持有三个协调器、编排自动修复、统一接口  
**特点**：扁平组合、全部同步初始化  
**行数**：~115 行

**关键接口**：
```swift
let configStore: MenuConfigStore
let syncCoordinator: ScriptSyncCoordinator
let windowCoordinator: WindowCoordinator

func saveAndSync()
func dismissAllErrors()
```

### 3. 文件清单

**新增文件**：
- `RCMMApp/Coordinators/MenuConfigStore.swift`
- `RCMMApp/Coordinators/ScriptSyncCoordinator.swift`
- `RCMMApp/Coordinators/WindowCoordinator.swift`
- `RCMMApp/Coordinators/AppCoordinator.swift`
- `CONTEXT.md`
- `docs/adr/0001-split-appstate.md`
- `docs/MIGRATION-GUIDE.md`

**待修改**（迁移阶段）：
- `RCMMApp/rcmmApp.swift` — 替换 AppState 为 AppCoordinator
- 所有 View 文件 — 更新属性访问路径

**待删除**（迁移完成后）：
- `RCMMApp/AppState.swift`

## 架构决策

### 采用扁平组合

**理由**：
- 每个协调器可独立测试、独立演化
- 避免传递依赖（如果 C 依赖 B、B 依赖 A，修改 A 会影响 B 和 C）
- 未来可轻松添加新协调器（如 TelemetryCoordinator）

### 职责分配

| 协调器 | 职责 | 决策理由 |
|--------|------|----------|
| MenuConfigStore | 领域模型 | 纯数据管理，无副作用 |
| ScriptSyncCoordinator | 脚本编译 | 独立编排逻辑，通过参数接收数据 |
| WindowCoordinator | UI 流程 | 主要消费者是 UI，局部性最佳 |
| AppCoordinator | 顶层编排 | 协调三者交互，保持它们独立 |

**健康监控归 WindowCoordinator**：主要用于 UI（菜单栏红点、popover 提示）  
**自动修复由 AppCoordinator 编排**：保持协调器独立，逻辑在顶层可见  
**全部同步初始化**：启动开销小，避免可选类型和状态检查

## 架构收益

### 可测试性

| 之前 | 之后 |
|------|------|
| 无法单独测试领域逻辑，必须同时处理 UI 和后台任务 | 可独立测试 MenuConfigStore（配置持久化）、ScriptSyncCoordinator（脚本编译）、WindowCoordinator（UI 流程） |
| 1207 行巨型类，难以模拟和隔离 | 每个协调器 65-350 行，易于测试 |

### 职责清晰

| 之前 | 之后 |
|------|------|
| 1207 行，15+ @ObservationIgnored 属性 | 每个协调器 200-400 行，单一职责 |
| 领域、编排、展示混在一起 | 明确分层：领域 → 编排 → 展示 |

### 局部性

| 之前 | 之后 |
|------|------|
| 领域变更（保存配置）和展示变更（显示 sheet）混杂 | 相关变更集中在各自协调器 |
| 改"红点逻辑"可能需要跨越 UI、健康检查、扩展状态多处 | 健康监控和 popover 状态在 WindowCoordinator 一起 |

## 架构图

```
AppCoordinator
├── MenuConfigStore (领域模型)
│   ├── menuEntries: [MenuEntry]
│   ├── scriptPublishStates: [String: ScriptPublishState]
│   └── errorRecords: [ErrorRecord]
│
├── ScriptSyncCoordinator (编排逻辑)
│   ├── syncQueue: DispatchQueue
│   └── installer: ScriptInstallerService
│
└── WindowCoordinator (展示层)
    ├── 窗口管理 (onboarding, settings, cleanup)
    ├── 健康监控 (extensionStatus, popoverState)
    └── 更新检查 (updateState)
```

## 下一步

### 立即执行（迁移 UI）

1. ✅ 创建四个协调器文件
2. ⏳ 更新 `rcmmApp.swift`（替换 AppState 为 AppCoordinator）
3. ⏳ 批量替换 View 文件的属性访问路径（参考 MIGRATION-GUIDE.md）
4. ⏳ 处理未迁移的功能（discoveredApps、compositePresetMessage）
5. ⏳ 测试所有功能
6. ⏳ 删除旧的 AppState.swift

### 后续优化（参考架构评审）

1. **候选项 #2**：实现显式脚本编译管线（CompilationRequest + generation counter）
   - 当前：隐式 I/O 检查 staleness
   - 优化：显式 generation counter，无隐藏 I/O

2. **候选项 #3**：添加同步世代计数器（sync epoch）
   - 当前：Darwin 通知无版本跟踪
   - 优化：epoch 检测错过的更新

3. **候选项 #4**：内联浅工具类（CommandTemplateProcessor、FinderMenuPresenter）
   - 当前：interface ≈ implementation
   - 优化：内联或作为扩展方法

4. **测试覆盖**：为每个协调器添加单元测试

## 参考

- **架构评审报告**：`/var/folders/.../architecture-review-20260615-143924.html`
- **设计决策**：`docs/adr/0001-split-appstate.md`
- **迁移指南**：`docs/MIGRATION-GUIDE.md`
- **领域术语**：`CONTEXT.md`
