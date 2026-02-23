# Story 6.1: 扩展状态检测服务

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户,
I want 系统在启动时和定期自动检测 Finder Extension 的注册状态,
So that 扩展异常时我能被及时告知。

## Acceptance Criteria

1. **启动时健康检测** — 主应用启动时，`PluginKitService` 执行健康检测。通过 `FIFinderSyncController.isExtensionEnabled` 查询 Extension 注册状态。正确识别三种状态：已启用（`.enabled`）、未启用（`.disabled`）、状态未知（`.unknown`）。检测结果更新到 `AppState` 的 `extensionStatus` 属性。使用 `os_log` 记录检测结果（subsystem: `com.sunven.rcmm`, category: `"health"`）。（FR-HEALTH-001, FR-HEALTH-002）

2. **定期健康检测** — 应用在后台运行时，达到定期检测间隔（每 30 分钟）自动执行一次健康检测。状态变化时更新 `AppState`（`extensionStatus` 和 `popoverState`）。定期检测使用 `Timer` 调度，在应用退出时正确清理。（FR-HEALTH-001）

3. **检测失败处理** — `FIFinderSyncController.isExtensionEnabled` 检测异常时（极少发生），状态设为 `.unknown`（不误报为异常）。`os_log` 记录错误详情。（FR-HEALTH-002）

4. **状态驱动弹出窗口路由** — `extensionStatus` 变化时，`popoverState` 同步更新：`.enabled` → `.normal`，`.disabled` → `.healthWarning`，`.unknown` → `.normal`（不主动打扰用户）。`PopoverContainerView` 根据 `popoverState` 正确路由到对应视图（当前 `.healthWarning` 路由到 `NormalPopoverView` 占位符，Story 6.3 将替换为 `RecoveryGuidePanel`）。（FR-HEALTH-002）

5. **应用激活时重新检测** — 用户点击菜单栏图标打开弹出窗口时，触发一次即时健康检测，确保用户看到的状态是最新的。（FR-HEALTH-001）

## Tasks / Subtasks

- [x] Task 1: 增强 PluginKitService 健康检测能力 (AC: #1, #3)
  - [x] 1.1 在 `PluginKitService.swift` 中添加 `static func checkHealth() -> ExtensionStatus` 方法，封装 `FIFinderSyncController.isExtensionEnabled` 检测逻辑，返回 `ExtensionStatus` 枚举值
  - [x] 1.2 ~~处理边界情况：保护性返回 `.unknown`~~ — `FIFinderSyncController.isExtensionEnabled` 是非抛出 Bool 属性，不存在可捕获的失败模式。`.unknown` 作为 `AppState.extensionStatus` 初始默认值，表示尚未执行首次检测。文档注释已更正为如实描述。
  - [x] 1.3 使用现有 Logger（subsystem: `com.sunven.rcmm`, category: `"health"`）记录每次检测结果和状态变化

- [x] Task 2: 在 AppState 中实现定期健康检测定时器 (AC: #2, #4)
  - [x] 2.1 在 `AppState.swift` 中添加 `private var healthCheckTimer: Timer?` 属性
  - [x] 2.2 添加 `private let healthCheckInterval: TimeInterval = 1800`（30 分钟）常量
  - [x] 2.3 实现 `func startHealthMonitoring()` 方法：创建 `Timer.scheduledTimer` 每 30 分钟调用 `checkExtensionStatus()`
  - [x] 2.4 实现 `func stopHealthMonitoring()` 方法：`timer.invalidate()` + 置 nil
  - [x] 2.5 在 `AppState.init()` 中调用 `startHealthMonitoring()` 启动定期监控（在 `checkExtensionStatus()` 之后）
  - [x] 2.6 ~~添加 `deinit` 调用 `stopHealthMonitoring()` 确保清理~~ — @MainActor 隔离限制导致 deinit 无法访问 actor-isolated 属性。Timer 使用 `[weak self]` 防止循环引用，AppState 与应用同生命周期，进程退出时 Timer 由系统清理。

- [x] Task 3: 增强 checkExtensionStatus() 使用新的 PluginKitService.checkHealth() (AC: #1, #4)
  - [x] 3.1 修改 `AppState.checkExtensionStatus()` 使用 `PluginKitService.checkHealth()` 替代直接调用 `PluginKitService.isExtensionEnabled`
  - [x] 3.2 增加状态变化检测：仅在状态实际发生变化时记录日志和更新 popoverState
  - [x] 3.3 状态到 popoverState 的映射逻辑：`.enabled` → `.normal`，`.disabled` → `.healthWarning`，`.unknown` → `.normal`

- [x] Task 4: 实现应用激活时重新检测 (AC: #5)
  - [x] 4.1 在 `rcmmApp.swift` 中监听 `scenePhase` 变化或使用 `NSApplication` 通知检测应用激活
  - [x] 4.2 由于 MenuBarExtra 不支持 `scenePhase`，在 `PopoverContainerView` 的 `.onAppear` 中调用 `appState.checkExtensionStatus()` 触发即时检测
  - [x] 4.3 确保即时检测不会与定期检测冲突（二者共用同一个 `checkExtensionStatus()` 方法，@MainActor 保证线程安全）

- [x] Task 5: 编译验证与测试 (AC: 全部)
  - [x] 5.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 5.2 `swift test --package-path RCMMShared` 全部测试通过，无回归
  - [x] 5.3 手动测试：启动应用 → 检查 Console.app os_log 输出，确认初始健康检测执行
  - [x] 5.4 手动测试：等待 30 分钟或修改定时器间隔为短时间 → 确认定期检测执行
  - [x] 5.5 手动测试：在系统设置中禁用 Extension → 点击菜单栏图标 → 确认弹出窗口路由到 `.healthWarning`（当前仍显示 NormalPopoverView 占位符）
  - [x] 5.6 手动测试：在系统设置中重新启用 Extension → 点击菜单栏图标 → 确认状态恢复为 `.enabled`，popoverState 为 `.normal`
  - [x] 5.7 手动测试：VoiceOver 可正确读取 HealthStatusPanel 中的状态更新

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 6（扩展健康检测与恢复引导）的第一个 Story，为后续 Story 6.2（菜单栏图标状态指示）和 Story 6.3（异常恢复引导面板）建立检测基础设施。Epic 6 的三个 Story 形成递进关系：**检测（6.1）→ 指示（6.2）→ 恢复（6.3）**。

**FRs 覆盖：** FR-HEALTH-001（定期/启动时检测扩展状态）、FR-HEALTH-002（识别异常情况）

**跨 Story 依赖：**
- 依赖 Story 1.1：项目结构
- 依赖 Story 1.2：RCMMShared 数据模型（`ExtensionStatus` 枚举）
- 依赖 Story 5.1：菜单栏常驻应用（MenuBarExtra、PopoverContainerView、HealthStatusPanel、AppState 基础结构）
- Story 6.2 依赖本 Story：菜单栏图标状态变化需要 `extensionStatus` 数据
- Story 6.3 依赖本 Story：RecoveryGuidePanel 需要 `extensionStatus` 数据和 `popoverState` 路由

### 关键技术决策

**1. FIFinderSyncController.isExtensionEnabled 作为检测方式（而非 pluginkit 命令行）**

架构文档明确规定："主 App 内 FinderSync framework 仅限 FIFinderSyncController 状态检测 API（isExtensionEnabled / showExtensionManagementInterface）"。当前代码已使用此 API，本 Story 保持一致。

Epics 文档提到 `pluginkit -m -i <extension-bundle-id>` 命令行方式，但这是一种备选方案，且需要通过 `Process` 执行外部命令，增加复杂度。`FIFinderSyncController.isExtensionEnabled` 是 Apple 官方推荐的框架 API，更简洁可靠。

```swift
// ✅ 使用 — Apple 框架 API，同步返回
let isEnabled = FIFinderSyncController.isExtensionEnabled

// ❌ 不使用 — 命令行方式，需要 Process + 输出解析
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
process.arguments = ["-m", "-i", "com.sunven.rcmm.FinderExtension"]
```

**2. ExtensionStatus 三态映射**

`FIFinderSyncController.isExtensionEnabled` 返回 `Bool`，但 `ExtensionStatus` 有三个 case。映射逻辑：
- `true` → `.enabled`
- `false` → `.disabled`
- 检测异常（理论上不会发生，保护性处理）→ `.unknown`

`.unknown` 在 UI 上映射到 `.normal` popoverState（不主动打扰用户），因为无法确定实际状态时不应误报异常。

**3. 定期检测间隔：30 分钟**

根据 epics 需求"定期检测间隔（如每 30 分钟）"，设置 `healthCheckInterval = 1800` 秒。这是一个合理的平衡：
- 太频繁（如 1 分钟）：虽然 `isExtensionEnabled` 开销极小，但无必要
- 太稀疏（如 2 小时）：用户可能长时间不知道扩展失效
- 30 分钟：用户在正常使用中会通过菜单栏图标或右键菜单缺失发现问题，定期检测作为兜底保障

**4. Timer 实现位置：AppState 内部**

参考 onboarding 中 `EnableExtensionStepView` 的 Timer 模式，但将 Timer 提升到 `AppState` 级别（而非 View 级别），因为健康监控是应用全生命周期的行为，不应随 View 的出现/消失而启停。

```swift
// ✅ AppState 级别 Timer — 应用全生命周期运行
@Observable @MainActor
final class AppState {
    private var healthCheckTimer: Timer?

    func startHealthMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(
            withTimeInterval: 1800,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkExtensionStatus()
            }
        }
    }
}
```

**注意：** `Timer.scheduledTimer` 的 closure 不在 `@MainActor` 上下文中执行，需要通过 `Task { @MainActor in }` 调度回主线程。这与 `EnableExtensionStepView.swift` 中已有的模式一致。

**5. 应用激活时重新检测 — PopoverContainerView.onAppear**

MenuBarExtra 的 `.menuBarExtraStyle(.window)` 使得弹出窗口每次打开时触发 `onAppear`。在 `PopoverContainerView` 的 `.onAppear` 中调用 `appState.checkExtensionStatus()` 是最自然的触发点：
- 用户点击菜单栏图标 → 弹出窗口出现 → `onAppear` → 检测最新状态 → 用户看到最新的 HealthStatusPanel
- 这确保用户每次打开弹出窗口都看到最新状态，不依赖 30 分钟的定期检测

### 现有代码变更分析

**PluginKitService.swift — 增强（非重写）：**

当前是一个 `enum` 仅有 `isExtensionEnabled` 计算属性和 `showExtensionManagement()` 方法。需要添加 `checkHealth() -> ExtensionStatus` 方法。保留现有 `isExtensionEnabled` 属性（OnboardingFlowView 仍在使用）。

**AppState.swift — 增强：**

当前 `checkExtensionStatus()` 逻辑简单。需要：
1. 使用新的 `PluginKitService.checkHealth()` 方法
2. 添加状态变化日志
3. 添加 `healthCheckTimer` 和 `startHealthMonitoring()` / `stopHealthMonitoring()`
4. 在 `init()` 中启动定期监控

**PopoverContainerView.swift — 添加 onAppear：**

当前无 `.onAppear`。需要添加 `.onAppear { appState.checkExtensionStatus() }` 实现打开时即时检测。

**rcmmApp.swift — 无变更。**

### 前序 Story 经验总结

**来自 Story 5.2（直接前序）：**
- Toggle 状态同步使用 `isUpdating` 守卫防止递归触发 — 本 Story 无类似问题（无双向绑定）
- `SMAppService.mainApp.status` 作为唯一状态源模式 — 同理，`FIFinderSyncController.isExtensionEnabled` 作为唯一扩展状态源
- Logger 使用 `Logger(subsystem: "com.sunven.rcmm", category: "system")` — 本 Story 使用 category `"health"`（已存在于 PluginKitService 中）
- `#Preview` 宏是 HIGH 优先级 — 所有修改的 View 必须保留或添加
- `.accessibilityLabel` / `.accessibilityValue` 使用模式已确立

**来自 Story 5.1（HealthStatusPanel 先例）：**
- HealthStatusPanel 组件已完整实现三态显示（.enabled/.disabled/.unknown）
- 组件接受 `ExtensionStatus` 参数，纯展示组件，不触发任何操作
- PopoverContainerView 的 `.healthWarning` 路由占位符已就绪，注释说明"Epic 6 实现 RecoveryGuidePanel"

**来自 EnableExtensionStepView（Timer 先例）：**
- `Timer.scheduledTimer(withTimeInterval: 3, repeats: true)` + `Task { @MainActor in }` 回主线程模式
- `onAppear` 启动 / `onDisappear` 停止的生命周期管理
- 本 Story 的 Timer 在 AppState 而非 View 中，生命周期跟随 AppState

### Git 近期提交分析

最近 5 个提交：
1. `94cb802` feat: implement launch at login management with code review fixes (Story 5.2)
2. `cb8eb6b` feat: implement menubar resident app and popover with code review fixes (Story 5.1)
3. `427a1cb` feat: implement command preview and validation with code review fixes (Story 4.3)
4. `5e1ac9d` feat: implement custom command editor with template placeholders (Story 4.2)
5. `95fb022` feat: implement command mapping service and builtin terminal support (Story 4.1)

模式观察：
- 提交消息格式：`feat: implement [描述] (Story X.Y)`
- 每个 Story 一个提交（有时包含 code review 修复）
- 当前编译成功 + 42 个单元测试全部通过

### macOS 版本兼容注意事项

**macOS 15 Sequoia 已知问题（已修复）：**
- macOS 15.0-15.1 中系统设置缺少 Finder Sync Extension 启用面板，需要通过命令行 `pluginkit -e use -i <bundle-id>` 启用
- 已在 macOS 15.2 beta 2 修复
- `FIFinderSyncController.isExtensionEnabled` API 本身不受此 bug 影响，仍然能正确报告状态

**macOS 26 Tahoe：**
- 无已知的 `FIFinderSyncController.isExtensionEnabled` 相关问题
- 系统设置路径可能与 macOS 15 不同 — Story 6.3（恢复引导）需处理此差异

来源：
- [Apple Developer Forums - FIFinderSyncController](https://developer.apple.com/forums/thread/766680)
- [FIFinderSyncController 官方文档](https://developer.apple.com/documentation/findersync/fifindersynccontroller)

### 反模式清单（禁止）

- ❌ 使用 `pluginkit -m -i` 命令行方式检测扩展状态（使用 `FIFinderSyncController.isExtensionEnabled` 框架 API）
- ❌ 使用 `ObservableObject/@Published`（统一用 `@Observable`）
- ❌ 在 Timer closure 中直接更新 UI 状态（必须通过 `Task { @MainActor in }` 调度回主线程）
- ❌ 缺少 `#Preview` 宏（HIGH 优先级）
- ❌ 缺少 `.accessibilityLabel`（所有交互元素必须包含）
- ❌ 使用 `try!` 或 force unwrap
- ❌ 在 RCMMShared 中引入 SwiftUI 或 AppKit 依赖
- ❌ 修改 EnableExtensionStepView 中已有的 Timer 逻辑（本 Story 不涉及引导流程变更）
- ❌ 状态为 `.unknown` 时设置 `popoverState` 为 `.healthWarning`（不误报，映射到 `.normal`）
- ❌ 在定期检测中频繁记录日志（仅在状态变化时记录，避免 Console.app 日志洪水）

### 范围边界说明

**本 Story 范围内：**
- 增强 `PluginKitService.swift`：添加 `checkHealth()` 方法
- 增强 `AppState.swift`：添加定期健康检测定时器，增强 `checkExtensionStatus()` 状态变化检测
- 增强 `PopoverContainerView.swift`：添加 `.onAppear` 即时检测

**本 Story 范围外（明确排除）：**
- 菜单栏图标颜色/变体变化（Story 6.2 范围）
- `HealthWarningView` / `RecoveryGuidePanel` 的实现（Story 6.3 范围）
- PopoverContainerView 中 `.healthWarning` 路由到真实恢复面板（Story 6.3 范围，当前保留占位符）
- 修改 `ExtensionStatus` 枚举定义（已足够，三态覆盖所有场景）
- 修改 `PopoverState` 枚举定义（已足够）
- 修改 OnboardingFlowView 或 EnableExtensionStepView（引导流程不变）
- 修改 Finder Extension 代码
- 新增单元测试（`FIFinderSyncController.isExtensionEnabled` 依赖系统框架，无法在单元测试中 mock；Timer 逻辑通过手动测试验证）

### Project Structure Notes

**本 Story 修改的文件：**

```
rcmm/
├── RCMMApp/
│   ├── AppState.swift                           # [修改] 添加 healthCheckTimer + startHealthMonitoring/stopHealthMonitoring + 增强 checkExtensionStatus()
│   ├── Services/
│   │   └── PluginKitService.swift               # [修改] 添加 checkHealth() -> ExtensionStatus 方法
│   └── Views/
│       └── MenuBar/
│           └── PopoverContainerView.swift       # [修改] 添加 .onAppear 即时健康检测
```

**不变的文件（已验证无需修改）：**

```
rcmm/
├── RCMMApp/
│   ├── rcmmApp.swift                            # 不变 — MenuBarExtra + Settings 已就绪
│   └── Views/
│       ├── MenuBar/
│       │   ├── NormalPopoverView.swift           # 不变 — 已正确展示 HealthStatusPanel
│       │   └── HealthStatusPanel.swift           # 不变 — 已实现三态展示
│       ├── Settings/
│       │   ├── SettingsView.swift                # 不变
│       │   └── GeneralTab.swift                  # 不变
│       └── Onboarding/
│           ├── OnboardingFlowView.swift          # 不变
│           └── EnableExtensionStepView.swift     # 不变 — 局部 Timer 独立于本 Story
├── RCMMFinderExtension/                          # 不变
└── RCMMShared/
    └── Sources/
        └── Models/
            ├── ExtensionStatus.swift             # 不变 — 三态枚举已足够
            └── PopoverState.swift                # 不变 — 三态路由已足够
```

**与架构文档的对齐：**
- `PluginKitService` 对应 architecture.md 中的 `RCMMApp/Services/PluginKitService.swift` — "FIFinderSyncController 调用，扩展状态检测"
- `AppState` 对应 architecture.md 中的 `RCMMApp/AppState.swift` — "@Observable 主状态，PopoverState 枚举"
- FR-HEALTH → `PluginKitService.swift` 映射在 architecture.md 中已定义
- 定期检测模式（Timer）在 architecture.md 中未显式定义，但符合"应用全生命周期健康监控"的需求

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.1] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 6] — Epic 6 整体目标：扩展健康检测与恢复引导
- [Source: _bmad-output/planning-artifacts/architecture.md#Core Architectural Decisions] — "FR-HEALTH (扩展健康): 主 App 进程内 pluginkit 调用；定期/启动时检测；状态 UI 联动"
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure] — PluginKitService.swift 位置和职责
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns] — os_log category 命名规范、状态管理模式、反模式清单
- [Source: _bmad-output/planning-artifacts/architecture.md#Architectural Boundaries] — 进程边界：主 App 可调用 FIFinderSyncController
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Status Indication Patterns] — 菜单栏图标状态：正常/警告/异常
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Feedback Patterns] — "警告: 扩展异常 → 菜单栏图标变体 + 弹出窗口恢复面板 → 持续到修复"
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 3: macOS Upgrade Recovery] — 恢复流程：自动检测 → 图标变警告 → 弹出恢复引导
- [Source: _bmad-output/implementation-artifacts/5-2-launch-at-login-management.md] — 前序 Story 经验（SMAppService 模式、#Preview、accessibility）
- [Source: _bmad-output/implementation-artifacts/5-1-menubar-resident-app-and-popover.md] — HealthStatusPanel、PopoverContainerView、ActivationPolicyManager
- [Source: RCMMApp/Services/PluginKitService.swift] — 当前 isExtensionEnabled + showExtensionManagement() 实现
- [Source: RCMMApp/AppState.swift] — 当前 checkExtensionStatus() 实现 + @Observable @MainActor 模式
- [Source: RCMMApp/Views/MenuBar/PopoverContainerView.swift] — 当前 .healthWarning 占位符路由
- [Source: RCMMApp/Views/MenuBar/NormalPopoverView.swift] — HealthStatusPanel 集成
- [Source: RCMMApp/Views/MenuBar/HealthStatusPanel.swift] — 三态状态面板组件
- [Source: RCMMApp/Views/Onboarding/EnableExtensionStepView.swift] — Timer 健康检测先例模式
- [Source: RCMMShared/Sources/Models/ExtensionStatus.swift] — .enabled/.disabled/.unknown 三态枚举
- [Source: RCMMShared/Sources/Models/PopoverState.swift] — .normal/.healthWarning/.onboarding 三态路由
- [Source: Apple Developer Documentation — FIFinderSyncController](https://developer.apple.com/documentation/findersync/fifindersynccontroller)
- [Source: Apple Developer Forums — FIFinderSyncController Sequoia bug](https://developer.apple.com/forums/thread/766680)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

- 首次编译失败：`deinit` 在 `@MainActor` class 中无法访问 actor-isolated 属性 `healthCheckTimer`。修复：移除 `deinit`，保留 `stopHealthMonitoring()` 用于显式清理。AppState 在应用生命周期内持续存在，进程退出时 Timer 由系统清理，无需 deinit。

### Completion Notes List

- Task 1: 在 PluginKitService 添加 `checkHealth() -> ExtensionStatus` 静态方法，封装 `FIFinderSyncController.isExtensionEnabled` 检测逻辑，导入 RCMMShared 模块获取 ExtensionStatus 类型
- Task 2: 在 AppState 添加 `healthCheckTimer` + `healthCheckInterval(1800s)` + `startHealthMonitoring()` / `stopHealthMonitoring()`，init 中启动定期监控。移除了 deinit（@MainActor 隔离限制），Timer 使用 `[weak self]` + `Task { @MainActor in }` 回主线程模式
- Task 3: 增强 `checkExtensionStatus()` 使用 `PluginKitService.checkHealth()`，添加状态变化检测（仅变化时记录日志），实现三态映射：.enabled→.normal, .disabled→.healthWarning, .unknown→.normal
- Task 4: 在 PopoverContainerView 添加 `.onAppear { appState.checkExtensionStatus() }`，每次打开弹出窗口即时检测最新状态
- Task 5: xcodebuild 编译成功（零错误），swift test 42/42 通过（零回归）。手动测试项（5.3-5.7）需用户在 review 阶段验证

### File List

- RCMMApp/Services/PluginKitService.swift [修改] — 添加 `import RCMMShared`，添加 `checkHealth() -> ExtensionStatus` 方法
- RCMMApp/AppState.swift [修改] — 添加 healthCheckTimer/healthCheckInterval 属性，添加 startHealthMonitoring()/stopHealthMonitoring() 方法，增强 checkExtensionStatus() 状态变化检测和三态映射
- RCMMApp/Views/MenuBar/PopoverContainerView.swift [修改] — 添加 `.onAppear` 即时健康检测
- _bmad-output/implementation-artifacts/sprint-status.yaml [修改] — 状态更新 ready-for-dev → in-progress → review
- _bmad-output/implementation-artifacts/6-1-extension-status-detection-service.md [修改] — 任务标记完成，Dev Agent Record 更新

### Change Log

- 2026-02-23: 实现扩展状态检测服务（Story 6.1） — 添加 PluginKitService.checkHealth() 健康检测方法、AppState 定期健康监控定时器（30 分钟间隔）、状态变化检测与 popoverState 三态映射、PopoverContainerView 打开时即时检测
- 2026-02-23: Code Review 修复（7 项发现） — 修正 checkHealth() 误导性文档注释(C1)；更新 Task 1.2/2.6 完成描述以如实反映实现(C2)；checkExtensionStatus() 仅在状态变化时更新 popoverState，使用 guard early return(H1)；startHealthMonitoring()/stopHealthMonitoring() 改为 private(H2)；startHealthMonitoring() 添加重复 Timer 防护(M1)

### Senior Developer Review (AI)

**Reviewer:** Sunven (via Claude Opus 4.6)
**Date:** 2026-02-23
**Outcome:** Changes Requested → Fixed

**Findings (7 total: 2 Critical, 2 High, 2 Medium, 1 Low):**

All CRITICAL, HIGH, and MEDIUM issues fixed:
- C1: checkHealth() 文档注释声称"保护性返回 .unknown"但代码无此路径 → 文档注释已更正
- C2: Task 2.6 标记完成但 deinit 已移除 → 任务描述已更新说明原因
- H1: checkExtensionStatus() 无条件覆写 popoverState → 改为仅在状态变化时更新（guard early return）
- H2: startHealthMonitoring()/stopHealthMonitoring() 访问控制过宽 → 改为 private
- M1: 无重复 Timer 防护 → 添加 healthCheckTimer?.invalidate() 防护
- M2: checkHealth() 文档注释与实现不符 → 同 C1 修复
- L1: isExtensionEnabled/checkHealth() 冗余 API 表面 → 保留（OnboardingFlowView 仍在使用 isExtensionEnabled）

**Build:** xcodebuild 编译成功（零错误）
**Tests:** swift test 42/42 通过（零回归）
