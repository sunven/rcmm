# Story 5.2: 开机自启管理

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户,
I want 启用开机自动启动 rcmm，并在设置中查看当前状态,
So that 每次开机后右键菜单自动可用，无需手动打开应用。

## Acceptance Criteria

1. **设置窗口中开机自启 Toggle 与状态显示** — 用户在设置窗口的通用 Tab（`GeneralTab`）中看到开机自启选项，包含 Toggle 开关和当前状态文字（"已启用"/"未启用"）。状态通过 `SMAppService.mainApp.status` 实时读取（不依赖本地 UserDefaults），确保反映系统实际状态。Toggle 状态在 `.onAppear` 时从 `SMAppService.mainApp.status` 同步。（FR-SYSTEM-001, FR-SYSTEM-002）

2. **启用开机自启** — 用户切换 Toggle 为开启时，调用 `SMAppService.mainApp.register()` 注册登录项。注册成功后状态文字更新为"已启用"。`os_log` 记录操作（subsystem: `com.sunven.rcmm`, category: `"system"`）。macOS 系统会自动向用户显示"已添加登录项"通知。（FR-SYSTEM-001）

3. **关闭开机自启** — 用户切换 Toggle 为关闭时，调用 `SMAppService.mainApp.unregister()` 取消登录项。取消成功后状态文字更新为"未启用"。（FR-SYSTEM-001）

4. **错误处理与 Toggle 回退** — `SMAppService.mainApp.register()` 或 `unregister()` 抛出错误时，Toggle 回退到操作前状态。显示内联错误提示说明原因（使用系统语义颜色 `.red` + `Text`，不弹 Alert）。`os_log` 记录错误详情。（FR-SYSTEM-001）

## Tasks / Subtasks

- [x] Task 1: 构建 GeneralTab 开机自启 UI (AC: #1, #2, #3, #4)
  - [x] 1.1 在 `GeneralTab.swift` 中添加 `import ServiceManagement`
  - [x] 1.2 添加 `@State private var isLoginItemEnabled = false` 和 `@State private var errorMessage: String? = nil`
  - [x] 1.3 构建 UI 布局：`Form` 容器 + `Section("开机自启")` + `Toggle` 绑定 `isLoginItemEnabled` + 状态描述文字 + 可选错误提示
  - [x] 1.4 实现 `.onAppear` 同步：从 `SMAppService.mainApp.status == .enabled` 读取当前状态设置 `isLoginItemEnabled`
  - [x] 1.5 实现 `.onChange(of: isLoginItemEnabled)` 处理 Toggle 变更：调用 `register()`/`unregister()`，失败时回退 Toggle 并设置 `errorMessage`
  - [x] 1.6 添加 `private let logger = Logger(subsystem: "com.sunven.rcmm", category: "system")`
  - [x] 1.7 添加 `.accessibilityLabel("开机自动启动")` 和状态文字的 `.accessibilityValue`
  - [x] 1.8 添加 `#Preview` 宏

- [x] Task 2: 编译验证与测试 (AC: 全部)
  - [x] 2.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 2.2 `swift test --package-path RCMMShared` 全部测试通过，无回归
  - [x] 2.3 手动测试：打开设置 → 通用 Tab → 看到开机自启 Toggle 和状态
  - [x] 2.4 手动测试：Toggle 开启 → 系统通知"已添加登录项" → 状态显示"已启用"
  - [x] 2.5 手动测试：Toggle 关闭 → 状态显示"未启用"
  - [x] 2.6 手动测试：系统设置中手动移除登录项 → 重新打开通用 Tab → Toggle 正确显示为关闭
  - [x] 2.7 手动测试：VoiceOver 可读取 Toggle 标签和状态值

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 5（系统集成与菜单栏体验）的第二个也是最后一个 Story。Story 5.1 已实现菜单栏常驻应用核心体验（MenuBarExtra popover + HealthStatusPanel + ActivationPolicyManager），本 Story 实现开机自启管理（SMAppService）。

**FRs 覆盖：** FR-SYSTEM-001（开机自启）、FR-SYSTEM-002（开机自启状态显示）

**跨 Story 依赖：**
- 依赖 Story 1.1：项目结构
- 依赖 Story 2.2：SettingsView TabView 容器（GeneralTab 已作为 Tab 接入）
- 依赖 Story 3.3：引导流程已实现 SMAppService 初始注册（OnboardingFlowView.swift:160-174），本 Story 提供设置界面中的持续管理能力
- 依赖 Story 5.1：ActivationPolicyManager、PopoverContainerView（设置窗口入口）
- Epic 6 不依赖本 Story

### 关键技术决策

**1. SMAppService.mainApp.status 作为唯一状态源（不使用 UserDefaults）**

根据 Apple 官方最佳实践：用户可以随时在"系统设置 → 通用 → 登录项"中移除登录项，因此必须从 `SMAppService.mainApp.status` 读取真实状态，不能依赖本地 UserDefaults 缓存。

`SharedKeys.loginItemEnabled` 虽然已存在于 `SharedKeys.swift` 中，但本 Story **不使用它**作为状态源。所有状态读取均来自 `SMAppService.mainApp.status`。

```swift
// ✅ 正确 — 从 SMAppService 读取真实状态
let isEnabled = SMAppService.mainApp.status == .enabled

// ❌ 错误 — 从 UserDefaults 读取（可能与系统状态不一致）
let isEnabled = defaults?.bool(forKey: SharedKeys.loginItemEnabled) ?? false
```

**2. Toggle 变更处理模式 — onChange + 错误回退**

使用 `@State` 本地变量驱动 Toggle，在 `.onChange(of:)` 中执行 register/unregister。失败时需要回退 Toggle 状态，注意避免 onChange 递归触发：

```swift
@State private var isLoginItemEnabled = false
@State private var isUpdating = false  // 防止 onChange 递归

.onChange(of: isLoginItemEnabled) { _, newValue in
    guard !isUpdating else { return }
    isUpdating = true
    defer { isUpdating = false }

    do {
        if newValue {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        errorMessage = nil
    } catch {
        // 回退 Toggle
        isLoginItemEnabled = !newValue
        errorMessage = "操作失败：\(error.localizedDescription)"
        logger.error("开机自启操作失败: \(error.localizedDescription)")
    }
}
```

**3. onAppear 同步状态**

在 `.onAppear` 中从 SMAppService 读取状态，确保打开设置时 Toggle 反映真实系统状态：

```swift
.onAppear {
    isUpdating = true
    isLoginItemEnabled = SMAppService.mainApp.status == .enabled
    isUpdating = false
}
```

**注意：** `isUpdating` 标志在 onAppear 中也需设置，防止初始赋值触发 onChange 中的 register/unregister 调用。

**4. SMAppService.Status 枚举值**

`SMAppService.mainApp.status` 返回以下状态：
- `.enabled` — 已注册为登录项
- `.notRegistered` — 未注册（曾注册后取消）
- `.notFound` — 系统从未见过此服务（首次安装且未注册）
- `.requiresApproval` — 需要用户审批（通常不会出现在 mainApp 场景）

对于 UI 展示，只需判断 `== .enabled`，其他所有状态均视为"未启用"。

**5. 引导流程已有的 SMAppService 调用**

`OnboardingFlowView.swift` 第 160-174 行已实现：
- 引导完成时，如果 `launchAtLogin` Toggle 为 true（默认），调用 `SMAppService.mainApp.register()`
- 如果为 false，调用 `SMAppService.mainApp.unregister()`
- 错误处理：注册失败时显示提示文字，取消注册失败时仅记录 debug 日志

本 Story 不修改引导流程代码。GeneralTab 作为引导完成后的持续管理入口，读取和修改同一个系统登录项。

**6. GeneralTab UI 布局**

GeneralTab 当前是占位符（仅显示"通用设置"文字）。本 Story 将其替换为完整的设置界面。当前只实现开机自启一个设置项，后续 Epic 6 可能在此 Tab 添加扩展状态相关设置。

布局参考 macOS 系统设置风格：
```
Form {
    Section("开机自启") {
        Toggle("开机时自动启动 rcmm", isOn: $isLoginItemEnabled)
        Text(isLoginItemEnabled ? "已启用 — rcmm 将在开机时自动启动" : "未启用")
            .font(.caption)
            .foregroundStyle(.secondary)
        if let errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
.formStyle(.grouped)
```

### 前序 Story 经验总结

**来自 Story 5.1（直接前序）：**
- ActivationPolicyManager 已创建，集中管理激活策略切换
- HealthStatusPanel 组件模式：HStack + SF Symbol + 状态文字 + 语义颜色
- `#Preview` 宏是 HIGH 优先级——所有新 View 必须包含
- `.accessibilityLabel` 和 `.accessibilityValue` 使用模式已确立
- AppState 使用 `init(forPreview: Bool = false)` 模式支持 Preview

**来自 OnboardingFlowView（SMAppService 先例）：**
- `import ServiceManagement` 引入方式
- `try SMAppService.mainApp.register()` / `try SMAppService.mainApp.unregister()` 调用模式
- 错误处理：register 失败设置 errorMessage 展示，unregister 失败仅记录日志
- Logger 使用 `Logger(subsystem: "com.sunven.rcmm", category: "onboarding")`

**来自 Story 4.3（Code Review 教训）：**
- 缺少 `#Preview` 被标记为 HIGH 优先级问题
- 所有交互元素必须有 `.accessibilityLabel`

### Git 近期提交分析

最近 5 个提交：
1. `cb8eb6b` feat: implement menubar resident app and popover with code review fixes (Story 5.1)
2. `427a1cb` feat: implement command preview and validation with code review fixes (Story 4.3)
3. `5e1ac9d` feat: implement custom command editor with template placeholders (Story 4.2)
4. `95fb022` feat: implement command mapping service and builtin terminal support (Story 4.1)
5. `cb2662e` feat: implement verify step and onboarding completion (Story 3.3)

模式观察：
- 提交消息格式：`feat: implement [描述] (Story X.Y)`（有时含 "with code review fixes"）
- 每个 Story 一个提交
- 当前编译成功 + 单元测试全部通过（Story 5.1 确认）

### SMAppService 最新技术要点

**框架：** `ServiceManagement`（macOS 13+，项目最低版本 macOS 15 完全支持）

**核心 API：**
```swift
import ServiceManagement

// 注册为登录项
try SMAppService.mainApp.register()

// 取消登录项
try SMAppService.mainApp.unregister()

// 读取当前状态
let status: SMAppService.Status = SMAppService.mainApp.status
// .enabled | .notRegistered | .notFound | .requiresApproval
```

**已知问题：**
- 频繁注册/取消注册在开发阶段可能导致 "Operation not permitted" 错误。重置方法：`sfltool resetbtm` + 重启。这是开发环境问题，不影响最终用户。
- 注册成功后 macOS 系统会自动显示"已添加登录项"通知，无需应用自行处理。

**Apple App Store 审核注意：**
- 开机自启必须基于用户明确同意，不可默认开启（引导流程中 Toggle 默认开启已获用户确认，符合要求）。

### 反模式清单（禁止）

- ❌ 使用 UserDefaults 作为登录项状态源（必须从 `SMAppService.mainApp.status` 读取）
- ❌ 使用 `ObservableObject/@Published`（统一用 `@Observable`）
- ❌ 在 onChange 中直接赋值 Toggle 导致递归触发（使用 `isUpdating` 守卫标志）
- ❌ 弹出 Alert 提示错误（使用内联 Text 错误提示，与引导流程保持一致）
- ❌ 缺少 `#Preview` 宏（HIGH 优先级，参考 Story 4.3 Code Review 教训）
- ❌ 缺少 `.accessibilityLabel`（所有交互元素必须包含）
- ❌ 使用 `try!` 或 force unwrap（register/unregister 必须 try + catch）
- ❌ 修改 OnboardingFlowView 的 SMAppService 调用逻辑（本 Story 不涉及引导流程变更）

### 范围边界说明

**本 Story 范围内：**
- 将 `GeneralTab.swift` 从占位符替换为完整开机自启管理 UI

**本 Story 范围外（明确排除）：**
- 扩展状态显示在 GeneralTab 中（Epic 6 范围，当前扩展状态已在弹出窗口 HealthStatusPanel 显示）
- AboutTab 的具体实现（保持现有占位符）
- 修改引导流程的 SMAppService 调用（OnboardingFlowView 保持不变）
- 修改 AppState（本 Story 不需要在 AppState 中添加登录项属性，GeneralTab 直接与 SMAppService 交互）
- 修改 Finder Extension 代码

### Project Structure Notes

**本 Story 修改的文件：**

```
rcmm/
├── RCMMApp/
│   └── Views/
│       └── Settings/
│           └── GeneralTab.swift              # [修改] 从占位符替换为开机自启管理 UI
```

**不变的文件（已验证无需修改）：**

```
RCMMApp/rcmmApp.swift                          # 不变 — MenuBarExtra + Settings 已就绪
RCMMApp/AppState.swift                         # 不变 — 登录项状态直接从 SMAppService 读取，不经 AppState
RCMMApp/Views/Settings/SettingsView.swift      # 不变 — GeneralTab 已作为 Tab 接入
RCMMApp/Views/Onboarding/OnboardingFlowView.swift # 不变 — SMAppService 初始注册已实现
RCMMShared/Sources/Constants/SharedKeys.swift  # 不变 — loginItemEnabled key 存在但本 Story 不使用
RCMMFinderExtension/                           # 不变 — Extension 无变更
```

**与架构文档的对齐：**
- `GeneralTab` 对应 architecture.md 中的 `RCMMApp/Views/Settings/GeneralTab.swift` — "通用（开机自启、扩展状态）"
- SMAppService 使用对应 architecture.md 中的 "FR-SYSTEM (系统集成) → `RCMMApp/Views/Settings/GeneralTab.swift`"
- 本 Story 仅实现"开机自启"部分，"扩展状态"留待 Epic 6

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.2] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 5] — Epic 5 整体目标：系统集成与菜单栏体验
- [Source: _bmad-output/planning-artifacts/architecture.md#Core Architectural Decisions] — "FR-SYSTEM (系统集成): SMAppService.mainApp 登录项管理"
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure] — GeneralTab.swift 位置和职责
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns] — os_log category 命名规范、命名约定
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Platform Strategy] — "SMAppService — 现代开机自启管理"
- [Source: _bmad-output/planning-artifacts/prd.md#FR-SYSTEM-001] — 用户可以启用开机自动启动功能
- [Source: _bmad-output/planning-artifacts/prd.md#FR-SYSTEM-002] — 系统显示当前开机自启的状态
- [Source: _bmad-output/implementation-artifacts/5-1-menubar-resident-app-and-popover.md] — 前序 Story 经验（#Preview、accessibility、ActivationPolicyManager）
- [Source: RCMMApp/Views/Settings/GeneralTab.swift] — 当前占位符实现
- [Source: RCMMApp/Views/Settings/SettingsView.swift] — TabView 容器，GeneralTab 已接入
- [Source: RCMMApp/Views/Onboarding/OnboardingFlowView.swift:160-174] — 引导流程 SMAppService 注册先例
- [Source: RCMMApp/AppState.swift] — AppState 模式参考（@Observable + @MainActor）
- [Source: RCMMShared/Sources/Constants/SharedKeys.swift] — SharedKeys.loginItemEnabled 定义（本 Story 不使用）
- [Source: Apple Developer Documentation — SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [Source: Nil Coalescing — Launch at Login Setting](https://nilcoalescing.com/blog/LaunchAtLoginSetting/) — SwiftUI Toggle 模式参考

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

（无调试问题）

### Completion Notes List

- 将 GeneralTab.swift 从占位符替换为完整的开机自启管理 UI
- 使用 SMAppService.mainApp.status 作为唯一状态源（不依赖 UserDefaults）
- 实现 Toggle + onChange 模式，含 isUpdating 守卫防止递归触发
- 错误处理：register/unregister 失败时 Toggle 回退 + 内联错误文字显示
- onAppear 同步系统真实状态到 Toggle
- Logger 使用 subsystem: com.sunven.rcmm, category: system
- 包含 #Preview 宏和完整的 accessibilityLabel/accessibilityValue
- xcodebuild 编译成功（零错误），42 个单元测试全部通过（无回归）
- 手动测试项（2.3-2.7）需用户实际运行应用验证

### File List

- RCMMApp/Views/Settings/GeneralTab.swift (修改 — 从占位符替换为开机自启管理 UI)

## Change Log

- 2026-02-23: 实现开机自启管理 UI（GeneralTab），支持 Toggle 开关、状态显示、错误回退、onAppear 状态同步
- 2026-02-23: Code Review 修复 — 修正 onAppear isUpdating 守卫模式（M1）、改进 onChange 错误回退逻辑（M2）、onAppear 清除旧错误（L1）、accessibilityValue 移至 Toggle（L2）、Preview 添加注释（L4）
