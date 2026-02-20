# Story 3.1: 引导流程框架与扩展启用引导

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 首次用户,
I want 打开 rcmm 后自动进入引导流程，第一步引导我启用 Finder Extension,
So that 我不需要自己摸索如何让右键菜单生效。

## Acceptance Criteria

1. **首次启动自动引导** — 用户首次打开 rcmm（无已保存配置，`SharedKeys.onboardingCompleted` 为 false）时，应用自动弹出引导窗口（独立 NSWindow，非 MenuBarExtra popover），显示 `OnboardingFlowView`。顶部显示 `OnboardingStepIndicator`（步骤 1/3，当前高亮）。如果 Extension 已启用（`FIFinderSyncController.isExtensionEnabled` 为 true），自动跳过扩展启用步骤，直接进入步骤 2。
2. **扩展启用引导** — 用户在引导步骤 1（启用扩展）时，点击"前往系统设置"按钮后，通过 `FIFinderSyncController.showExtensionManagementInterface()` 跳转到系统设置中 Extension 管理页面。页面显示适配当前 macOS 版本的说明文字。
3. **扩展状态检测** — 用户从系统设置返回后，引导界面提供"重新检测"按钮，点击后通过 `FIFinderSyncController.isExtensionEnabled` 检测 Extension 状态。同时自动每 3 秒轮询一次状态。检测到已启用时，自动进入步骤 2。提供"跳过"选项，用户可选择稍后启用。
4. **引导窗口管理** — 引导窗口为独立窗口（通过 `Window` scene 或 `NSWindow` 实现），固定尺寸约 480×500pt，不可缩放。引导窗口关闭时如果未完成引导，下次启动仍会弹出。引导完成后（由 Story 3.3 标记 `onboardingCompleted`），不再弹出。
5. **OnboardingStepIndicator 组件** — 自定义步骤指示器组件，展示 3 个步骤的进度：已完成（绿色勾 `checkmark.circle.fill`）/ 当前（高亮强调色）/ 待完成（灰色 `circle`）。使用 `HStack` + `Circle` + `Text` 布局。包含 `.accessibilityLabel("步骤 X，共 3 步，当前：[步骤名]")` 无障碍支持。

## Tasks / Subtasks

- [x] Task 1: 创建 PluginKitService 扩展检测服务 (AC: #2, #3)
  - [x] 1.1 在 `RCMMApp/Services/` 创建 `PluginKitService.swift`
  - [x] 1.2 导入 `FinderSync` framework（注意：需在 RCMMApp target 添加 FinderSync.framework 依赖）
  - [x] 1.3 实现 `static var isExtensionEnabled: Bool` 属性，封装 `FIFinderSyncController.isExtensionEnabled`
  - [x] 1.4 实现 `static func showExtensionManagement()` 方法，封装 `FIFinderSyncController.showExtensionManagementInterface()`
  - [x] 1.5 添加 os_log 日志（subsystem: `com.sunven.rcmm`, category: `"health"`）

- [x] Task 2: 创建 OnboardingStepIndicator 自定义组件 (AC: #5)
  - [x] 2.1 在 `RCMMApp/Views/Onboarding/` 创建 `OnboardingStepIndicator.swift`
  - [x] 2.2 定义 `OnboardingStep` 枚举：`.enableExtension`, `.selectApps`, `.verify`
  - [x] 2.3 实现 3 步指示器 UI：`HStack` + 圆形图标 + 步骤标题 + 连接线
  - [x] 2.4 状态样式：已完成（`.green` + `checkmark.circle.fill`）、当前（`.accentColor` + `circle.fill`）、待完成（`.secondary` + `circle`）
  - [x] 2.5 添加 `.accessibilityLabel("步骤 X，共 3 步，当前：[步骤名]")` 和 `.accessibilityElement(children: .combine)`

- [x] Task 3: 创建 EnableExtensionStepView 扩展启用视图 (AC: #2, #3)
  - [x] 3.1 在 `RCMMApp/Views/Onboarding/` 创建 `EnableExtensionStepView.swift`
  - [x] 3.2 顶部显示 SF Symbol 图标和标题文字
  - [x] 3.3 显示适配说明文字（引导用户到 系统设置 > 通用 > 登录项与扩展 > 文件提供程序）
  - [x] 3.4 实现"前往系统设置"主按钮（`.buttonStyle(.borderedProminent)`），调用 `PluginKitService.showExtensionManagement()`
  - [x] 3.5 实现"重新检测"次要按钮（`.buttonStyle(.bordered)`），手动触发状态检测
  - [x] 3.6 实现 `Timer.publish(every: 3, on: .main, in: .common)` 自动轮询扩展状态
  - [x] 3.7 检测到已启用时显示成功状态（绿色勾 + "Extension 已启用"）
  - [x] 3.8 添加所有交互元素的 `.accessibilityLabel`

- [x] Task 4: 创建 OnboardingFlowView 引导流程容器 (AC: #1, #4)
  - [x] 4.1 在 `RCMMApp/Views/Onboarding/` 创建 `OnboardingFlowView.swift`
  - [x] 4.2 管理当前步骤状态（使用 `@State private var currentStep: OnboardingStep`）
  - [x] 4.3 顶部放置 `OnboardingStepIndicator`，中间根据 `currentStep` switch 渲染对应步骤视图
  - [x] 4.4 底部导航按钮区：左侧"跳过"（仅步骤 1）/ 右侧"下一步"（`.buttonStyle(.borderedProminent)`）
  - [x] 4.5 步骤 1 初始化时检测扩展状态，若已启用则自动跳到步骤 2
  - [x] 4.6 为步骤 2（选择应用）和步骤 3（验证）创建占位 View（实际实现在 Story 3.2 和 3.3）
  - [x] 4.7 接受 `AppState` 通过 `.environment()` 传递（供步骤 2 使用）

- [x] Task 5: 集成引导窗口到 rcmmApp 入口 (AC: #1, #4)
  - [x] 5.1 在 `AppState` 中添加 `var isOnboardingCompleted: Bool` 属性，从 App Group UserDefaults 读取 `SharedKeys.onboardingCompleted`
  - [x] 5.2 在 `AppState.swift` 中使用 NSWindow + NSHostingView 实现引导窗口（替代原计划的 SwiftUI Window scene，因 MenuBarExtra app 中 Window scene 无法可靠自动弹出）
  - [x] 5.3 实现启动逻辑：若 `isOnboardingCompleted == false`，自动弹出引导窗口并 activate app
  - [x] 5.4 引导窗口固定尺寸约 480×500pt，`.windowResizability(.contentSize)`，居中显示
  - [x] 5.5 确保 MenuBarExtra 在引导期间仍然正常显示
  - [x] 5.6 引导窗口关闭时恢复 `.accessory` activation policy

- [x] Task 6: 编译验证与基础测试 (AC: 全部)
  - [x] 6.1 Xcode 添加 FinderSync.framework 到 RCMMApp target 的 Frameworks 依赖
  - [x] 6.2 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 6.3 RCMMShared 全部现有测试通过，无回归
  - [ ] 6.4 手动测试：首次启动（清空 UserDefaults）→ 自动弹出引导窗口
  - [ ] 6.5 手动测试：点击"前往系统设置" → 跳转到正确的系统设置页面
  - [ ] 6.6 手动测试：启用 Extension 后返回 → 自动检测到已启用 → 跳到步骤 2
  - [ ] 6.7 手动测试：点击"跳过" → 进入步骤 2（占位视图）
  - [ ] 6.8 SwiftUI Preview 验证：OnboardingStepIndicator 三种状态 + Light/Dark Mode

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 3（首次引导体验）的第一个 Story，建立引导流程的基础框架和扩展启用引导。后续 Story 3.2 将在此框架内实现应用选择步骤，Story 3.3 将实现验证步骤和引导完成标记。本 Story 完成后，引导流程框架和步骤 1 可独立运行。

**FRs 覆盖：** FR-ONBOARDING-001（首次自动引导）、FR-ONBOARDING-003（引导启用扩展）

**跨 Story 依赖：**
- 依赖 Story 1.2：`SharedConfigService`、`SharedKeys`（`onboardingCompleted` 键已定义）
- 依赖 Story 2.2：`AppState`、`SettingsView`、`rcmmApp.swift` 入口
- 依赖 Story 2.1：`AppDiscoveryService`（步骤 2 将复用，本 Story 仅创建占位）
- Epic 2 已建立的配置同步管道（saveAndSync → Darwin Notification）将在步骤 2 复用
- Story 3.2 将实现 `SelectAppsStepView`
- Story 3.3 将实现 `VerifyStepView` 并标记 `onboardingCompleted = true`

### 关键技术决策

**1. 扩展检测方案：FIFinderSyncController API（非 pluginkit CLI）**

架构文档提到 `PluginKitService` 使用 `pluginkit -m -i <extension-bundle-id>` 检测状态，但技术研究发现更优方案：

`FIFinderSyncController.isExtensionEnabled`（静态布尔属性）— Apple 官方 API，直接从 containing app 调用，无需 Process/NSTask，无沙盒限制。

`FIFinderSyncController.showExtensionManagementInterface()` — Apple 维护的 API，自动适配不同 macOS 版本的系统设置入口位置。

**为什么不用 pluginkit CLI：**
- `FIFinderSyncController` API 是 Apple 为 containing app 提供的官方检测方式
- 无需解析 CLI 输出（pluginkit 输出格式无官方文档）
- `showExtensionManagementInterface()` 自动处理 macOS 15.0-15.1 系统设置 UI 缺失问题
- 无 Process 创建开销和超时风险

**注意：** 使用此 API 需要在 RCMMApp target 中链接 `FinderSync.framework`。这不会引入对 Extension target 的循环依赖，`FinderSync` framework 中的 `FIFinderSyncController` 在 containing app 中是合法使用的。

**实现：**
```swift
import FinderSync
import os.log

enum PluginKitService {
    private static let logger = Logger(subsystem: "com.sunven.rcmm", category: "health")

    static var isExtensionEnabled: Bool {
        let enabled = FIFinderSyncController.isExtensionEnabled
        logger.debug("Extension 状态检测: \(enabled ? "已启用" : "未启用")")
        return enabled
    }

    static func showExtensionManagement() {
        logger.info("跳转系统设置 - Extension 管理页面")
        FIFinderSyncController.showExtensionManagementInterface()
    }
}
```

**2. 引导窗口实现方案：SwiftUI Window Scene**

rcmm 当前使用 MenuBarExtra + Settings scene 架构。引导流程需要独立窗口（popover 空间不足）。

**方案选择：SwiftUI `Window` scene + `@Environment(\.openWindow)` 触发**

macOS 15+ 支持 `Window` scene，这是最简洁的 SwiftUI 原生方案：

```swift
@main
struct rcmmApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("rcmm", systemImage: "contextualmenu.and.cursorarrow") {
            // ... 现有菜单内容
        }
        Settings {
            SettingsView()
                .environment(appState)
                .onDisappear {
                    DispatchQueue.main.async {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
        Window("欢迎使用 rcmm", id: "onboarding") {
            OnboardingFlowView()
                .environment(appState)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
```

启动时通过 `@Environment(\.openWindow)` action 触发窗口打开。由于 `@main` App struct 无法直接使用 `@Environment`，需要在 MenuBarExtra 内容或 AppState init 中触发。

**替代方案（如果 Window scene 有兼容性问题）：**
使用 `NSWindow` + `NSHostingView` 手动创建窗口。这在 MenuBarExtra app 中更灵活但代码更多。

**3. 引导状态管理**

引导状态使用 App Group UserDefaults 存储（`SharedKeys.onboardingCompleted`），确保：
- 主应用和 Extension 均可读取（虽然 Extension 不需要引导逻辑）
- 重启后状态持久化
- 与现有 `SharedConfigService` 模式一致

```swift
// AppState 中新增
var isOnboardingCompleted: Bool {
    get {
        let defaults = UserDefaults(suiteName: AppGroupConstants.appGroupID)
        return defaults?.bool(forKey: SharedKeys.onboardingCompleted) ?? false
    }
    set {
        let defaults = UserDefaults(suiteName: AppGroupConstants.appGroupID)
        defaults?.set(newValue, forKey: SharedKeys.onboardingCompleted)
    }
}
```

**4. 扩展状态轮询策略**

在 `EnableExtensionStepView` 中，用户跳转系统设置后返回时需要检测状态变化：
- 使用 `Timer.publish(every: 3, on: .main, in: .common)` 每 3 秒轮询
- 手动"重新检测"按钮作为备选
- 检测到 `isExtensionEnabled == true` 后自动停止轮询并触发进入下一步
- 轮询在视图消失时自动停止（`.onReceive` 生命周期绑定）

**5. 引导窗口与 ActivationPolicy 协调**

当前 `rcmmApp` 使用 `LSUIElement = YES`（无 Dock 图标）。引导窗口显示时需要临时切换到 `.regular` policy 以便窗口获得焦点：

- 引导窗口出现 → `NSApp.setActivationPolicy(.regular)` + `NSApp.activate(ignoringOtherApps: true)`
- 引导窗口关闭 → `NSApp.setActivationPolicy(.accessory)`

这与现有 Settings 窗口的 workaround 模式一致（Story 2.2 已建立此模式）。

### macOS 版本兼容说明

**macOS 15 Sequoia (15.0-15.1)：**
- Apple 意外移除了系统设置中 Finder Sync 扩展管理 UI
- `FIFinderSyncController.showExtensionManagementInterface()` 仍可调用，但可能无法跳转到正确页面
- 建议在说明文字中提供备选路径：命令行 `pluginkit -e use -i com.sunven.rcmm.FinderExtension`

**macOS 15.2+：**
- 系统设置 > 通用 > 登录项与扩展 > 文件提供程序
- `showExtensionManagementInterface()` 正常工作

**macOS 26 Tahoe (ARM)：**
- 已知 bug (FB20947446): FinderSync Extension 注册但无法在 Apple Silicon 上运行
- 引导流程应处理"Extension 已注册但实际不工作"的边缘情况
- 暂不针对此 bug 做特殊处理，跟踪 Apple 修复进度

### 前序 Story 经验总结

**来自 Story 2.4（直接前序）：**
- `saveAndSync()` 模式已建立完整的配置同步管道
- Darwin 通知监听模式已在 FinderSync 中验证
- 脚本同步使用串行队列避免竞态
- SettingsAccess 已集成解决 MenuBarExtra → Settings 窗口打开问题

**来自 Story 2.2（Settings 窗口基础）：**
- `SettingsView` TabView 3 页分页已实现（MenuConfigTab / GeneralTab / AboutTab）
- `AppState` 通过 `.environment()` 传递到子 View
- `NSApp.setActivationPolicy(.regular/.accessory)` workaround 已验证可用
- `SettingsAccess` 库已集成

**来自 Story 2.1（应用发现）：**
- `AppDiscoveryService` 已实现，扫描 /Applications 和 ~/Applications
- `AppSelectionSheet` 已实现应用选择 UI（Story 3.2 将在引导流程中复用类似模式）
- `AppInfo+Icon` 扩展提供应用图标

**Git 提交模式：**
- 提交消息格式：`feat: implement [feature description] (Story X.Y)`
- 每个 Story 一个 commit

**当前代码状态（需修改的核心文件）：**
- `RCMMApp/rcmmApp.swift:1-34` — 需添加 `Window` scene 和启动引导逻辑
- `RCMMApp/AppState.swift:1-124` — 需添加 `isOnboardingCompleted` 属性

**需新建的文件：**
- `RCMMApp/Services/PluginKitService.swift` — Extension 状态检测服务
- `RCMMApp/Views/Onboarding/OnboardingFlowView.swift` — 引导流程容器
- `RCMMApp/Views/Onboarding/OnboardingStepIndicator.swift` — 步骤指示器组件
- `RCMMApp/Views/Onboarding/EnableExtensionStepView.swift` — 扩展启用步骤视图

### Swift 6 并发注意事项

- `PluginKitService` 定义为 `enum`（无状态，纯静态方法），天然线程安全
- `FIFinderSyncController.isExtensionEnabled` 是线程安全的静态属性
- Timer 回调在主线程（`.main` RunLoop），UI 更新无线程问题
- `AppState` 标记为 `@MainActor`，`isOnboardingCompleted` 属性访问在主线程

### 反模式清单（禁止）

- ❌ 使用 `pluginkit` CLI 命令检测扩展状态（使用 `FIFinderSyncController.isExtensionEnabled` API）
- ❌ 硬编码系统设置 URL scheme（使用 `FIFinderSyncController.showExtensionManagementInterface()`）
- ❌ 在 MenuBarExtra popover 中展示引导流程（空间不足，使用独立窗口）
- ❌ 使用 `ObservableObject/@Published`（统一用 `@Observable`）
- ❌ 在 RCMMShared 中引入 FinderSync 依赖（仅在 RCMMApp 中使用）
- ❌ 硬编码 `onboardingCompleted` 键名字符串（使用 `SharedKeys.onboardingCompleted` 常量）
- ❌ 实现应用选择步骤和验证步骤的完整逻辑（属于 Story 3.2 和 3.3 范围）
- ❌ 修改 `MenuItemConfig` 或其他 RCMMShared 模型结构
- ❌ 使用 `try!` 或 force unwrap
- ❌ 在引导窗口中使用 `.sheet` 或 `.popover`（使用独立 View 切换）

### 范围边界说明

**本 Story 范围内：**
- OnboardingFlowView 引导流程容器（3 步框架）
- OnboardingStepIndicator 自定义组件
- EnableExtensionStepView 扩展启用步骤（步骤 1 完整实现）
- PluginKitService 扩展检测服务
- 引导窗口集成到 rcmmApp 入口（首次启动自动弹出）
- AppState 添加 `isOnboardingCompleted` 属性
- 步骤 2（选择应用）和步骤 3（验证）的占位 View

**本 Story 范围外（明确排除）：**
- 应用选择步骤的完整实现（Story 3.2：SelectAppsStepView、预选常见工具）
- 验证步骤和引导完成标记（Story 3.3：VerifyStepView、标记 onboardingCompleted）
- 健康检测定期轮询（Epic 6：PluginKitService 扩展为定期检测）
- 菜单栏图标状态变体（Epic 6：HealthStatusPanel）
- 恢复引导面板（Epic 6：RecoveryGuidePanel）

### Project Structure Notes

**本 Story 新建文件：**

```
rcmm/
├── RCMMApp/
│   ├── Services/
│   │   └── PluginKitService.swift              # [新建] Extension 状态检测（FIFinderSyncController）
│   └── Views/
│       └── Onboarding/
│           ├── OnboardingFlowView.swift        # [新建] 引导流程容器（步骤路由 + 导航按钮）
│           ├── OnboardingStepIndicator.swift   # [新建] 自定义步骤指示器组件
│           └── EnableExtensionStepView.swift   # [新建] 扩展启用引导步骤
```

**本 Story 修改文件：**

```
RCMMApp/AppState.swift                          # [修改] 添加 isOnboardingCompleted 属性、NSWindow 引导窗口管理、import SwiftUI
rcmm.xcodeproj/project.pbxproj                  # [修改] 添加新文件 + FinderSync.framework 依赖
```

**不变的文件（已验证无需修改）：**

```
RCMMShared/Sources/Constants/SharedKeys.swift          # 不变 — onboardingCompleted 已定义
RCMMShared/Sources/Models/PopoverState.swift           # 不变 — .onboarding case 已存在
RCMMShared/Sources/Models/ExtensionStatus.swift        # 不变 — 枚举已定义
RCMMApp/Views/Settings/SettingsView.swift              # 不变
RCMMApp/Views/Settings/MenuConfigTab.swift             # 不变
RCMMApp/Services/AppDiscoveryService.swift             # 不变（Story 3.2 复用）
RCMMApp/Services/ScriptInstallerService.swift          # 不变
RCMMFinderExtension/FinderSync.swift                   # 不变
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.1] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries] — 项目目录结构（RCMMApp/Views/Onboarding/、RCMMApp/Services/PluginKitService.swift）
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns] — 命名规范、结构模式、反模式清单
- [Source: _bmad-output/planning-artifacts/architecture.md#Architectural Boundaries] — 进程边界（主 App 非沙盒，可调用 pluginkit；Package 依赖边界）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#User Journey Flows] — Journey 1: First-Time Setup 引导流程 UX 定义
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Custom Components] — OnboardingStepIndicator 组件规范（HStack + Circle + Text，三种状态）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] — 按钮层级规范（主要/次要/三级）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Accessibility Strategy] — VoiceOver、键盘导航、动态字体要求
- [Source: _bmad-output/planning-artifacts/prd.md#首次引导] — FR-ONBOARDING-001（首次自动引导）、FR-ONBOARDING-003（引导启用扩展）
- [Source: _bmad-output/implementation-artifacts/2-4-config-realtime-sync-and-dynamic-context-menu.md] — 前序 Story dev notes（saveAndSync 模式、Darwin 通知）
- [Source: _bmad-output/implementation-artifacts/2-2-settings-window-and-menu-item-management.md] — SettingsAccess 集成、ActivationPolicy workaround
- [Source: RCMMApp/rcmmApp.swift:1-34] — 当前 App 入口结构（MenuBarExtra + Settings scene）
- [Source: RCMMApp/AppState.swift:1-124] — 当前 AppState 实现（@Observable + @MainActor）
- [Source: RCMMShared/Sources/Constants/SharedKeys.swift:6] — `onboardingCompleted` 键已定义
- [Source: RCMMShared/Sources/Models/PopoverState.swift:6] — `.onboarding` case 已存在
- [Source: RCMMShared/Sources/Models/ExtensionStatus.swift:1-7] — ExtensionStatus 枚举已定义
- [Apple: FIFinderSyncController.isExtensionEnabled](https://developer.apple.com/documentation/findersync/fifindersynccontroller/isextensionenabled) — 官方 Extension 状态检测 API
- [Apple: FIFinderSyncController.showExtensionManagementInterface()](https://developer.apple.com/documentation/findersync/fifindersynccontroller/showextensionmanagementinterface()) — 官方系统设置跳转 API
- [Apple Developer Forums: FinderSync extensions gone in macOS settings](https://developer.apple.com/forums/thread/756711) — macOS 15.0-15.1 系统设置 UI 缺失问题
- [Apple Developer Forums: macOS 26.1 ARM FinderSync bug](https://developer.apple.com/forums/thread/806607) — macOS 26 Tahoe ARM bug (FB20947446)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

- 编译验证: `xcodebuild -scheme rcmm -configuration Debug build` → BUILD SUCCEEDED (零错误)
- 回归测试: `swift test --package-path RCMMShared` → 25/25 测试通过

### Completion Notes List

- ✅ Task 1: 创建 PluginKitService.swift，使用 FIFinderSyncController API 而非 pluginkit CLI，封装为无状态 enum
- ✅ Task 2: 创建 OnboardingStepIndicator.swift，包含 OnboardingStep 枚举和三状态指示器 UI（已完成/当前/待完成），含完整无障碍支持
- ✅ Task 3: 创建 EnableExtensionStepView.swift，包含系统设置跳转、3秒自动轮询、手动检测、成功状态显示、完整 accessibilityLabel
- ✅ Task 4: 创建 OnboardingFlowView.swift，包含步骤路由、导航按钮、初始扩展检测跳转、步骤2/3占位视图
- ✅ Task 5: AppState 添加 isOnboardingCompleted 存储属性（didSet 写入 UserDefaults），使用 NSWindow + NSHostingView 实现引导窗口（比 SwiftUI Window scene 更可靠地支持 MenuBarExtra app 的自动弹出），包含 ActivationPolicy 切换和窗口关闭通知处理
- ✅ Task 6: FinderSync.framework 已添加到 rcmm target，编译零错误，RCMMShared 25个测试全部通过无回归
- 注意: 引导窗口使用 NSWindow 方案（Dev Notes 中的替代方案），因为 MenuBarExtra-only app 中 SwiftUI Window scene 无法可靠地在启动时自动弹出
- 注意: Task 6.4-6.8 为手动测试项，需要用户在 Xcode 中运行应用验证

### File List

- RCMMApp/Services/PluginKitService.swift (新建)
- RCMMApp/Views/Onboarding/OnboardingStepIndicator.swift (新建)
- RCMMApp/Views/Onboarding/EnableExtensionStepView.swift (新建)
- RCMMApp/Views/Onboarding/OnboardingFlowView.swift (新建)
- RCMMApp/AppState.swift (修改 — 添加 isOnboardingCompleted 属性、引导窗口管理方法、import SwiftUI)
- rcmm.xcodeproj/project.pbxproj (修改 — 添加 FinderSync.framework 依赖到 rcmm target)
- _bmad-output/implementation-artifacts/sprint-status.yaml (修改 — Story 3.1 状态设为 review)

### Change Log

- 2026-02-20: 实现引导流程框架与扩展启用引导 (Story 3.1) — 新增 PluginKitService、OnboardingStepIndicator、EnableExtensionStepView、OnboardingFlowView，集成引导窗口到 AppState 启动流程
- 2026-02-20: Code Review 修复 — EnableExtensionStepView 添加 macOS 版本适配说明(M1)、修复自动轮询在 onAppear 启动(M2)、移除无效 isChecking ProgressView(M3)；更新 architecture.md FinderSync 依赖边界(H1+M5)；修正 Task 5.2 描述和 File List(H2+M4)
