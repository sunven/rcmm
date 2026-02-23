# Story 5.1: 菜单栏常驻应用与弹出窗口

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户,
I want rcmm 以菜单栏图标常驻运行，点击图标弹出状态概览和快捷操作,
So that 我可以随时查看状态和访问设置，同时不占用 Dock 空间。

## Acceptance Criteria

1. **菜单栏图标与弹出窗口** — rcmm 启动后，菜单栏显示 rcmm 图标（`MenuBarExtra` + `.menuBarExtraStyle(.window)`）。Dock 中不显示 rcmm 图标（Info.plist `LSUIElement = YES`，已在 Story 1.1 中配置）。点击菜单栏图标时弹出 `PopoverContainerView`，根据 `AppState` 的 `PopoverState` 枚举路由到对应视图。弹出窗口宽度 ~280-320pt，高度自适应内容。（FR-UI-MENUBAR-001, FR-UI-MENUBAR-002）

2. **正常状态弹出窗口内容** — 正常状态（`PopoverState.normal`）显示 `NormalPopoverView`：简洁状态行（`HealthStatusPanel` 展示扩展当前状态）+ "打开设置"按钮 + "退出"按钮。HealthStatusPanel 根据 `ExtensionStatus` 枚举显示三种状态：正常（绿色，`.checkmark.circle.fill`）/ 警告（黄色，`.exclamationmark.triangle.fill`）/ 异常（红色，`.xmark.circle.fill`）。状态同时使用图标变体和颜色传达（色盲友好）。（FR-UI-MENUBAR-001）

3. **打开设置功能** — 用户在弹出窗口中点击"打开设置"时，通过 `ActivationPolicyManager` 切换 `ActivationPolicy` 打开 Settings 窗口。正确处理 `MenuBarExtra` → Settings 窗口的跨版本兼容 workaround（使用 `SettingsAccess` 库现有模式）。（FR-UI-MENUBAR-001）

4. **退出功能** — 用户在弹出窗口中点击"退出"时，应用正常退出（`NSApplication.shared.terminate`）。（FR-UI-MENUBAR-001）

## Tasks / Subtasks

- [x] Task 1: 创建 ActivationPolicyManager 服务 (AC: #3)
  - [x] 1.1 创建 `RCMMApp/Services/ActivationPolicyManager.swift`
  - [x] 1.2 提供 `showSettings()` 方法：切换 ActivationPolicy 为 `.regular` + 激活应用
  - [x] 1.3 提供 `hideToMenuBar()` 方法：延迟切换 ActivationPolicy 为 `.accessory`
  - [x] 1.4 重构 `rcmmApp.swift` 和 `AppState.swift` 中散落的激活策略代码，统一使用 ActivationPolicyManager

- [x] Task 2: 扩展 AppState，添加 PopoverState 和 ExtensionStatus 支持 (AC: #1, #2)
  - [x] 2.1 在 AppState 中添加 `popoverState: PopoverState` 属性（默认 `.normal`）
  - [x] 2.2 在 AppState 中添加 `extensionStatus: ExtensionStatus` 属性（默认 `.unknown`）
  - [x] 2.3 添加 `checkExtensionStatus()` 方法：使用 `PluginKitService.isExtensionEnabled` 检测状态，更新 `extensionStatus`（.enabled / .disabled），检测失败时设为 `.unknown`
  - [x] 2.4 在应用启动时调用 `checkExtensionStatus()`
  - [x] 2.5 根据 `extensionStatus` 计算 `popoverState`：`.enabled` → `.normal`，`.disabled` → `.healthWarning`，`.unknown` → `.normal`（不误报）

- [x] Task 3: 创建 HealthStatusPanel 自定义组件 (AC: #2)
  - [x] 3.1 创建 `RCMMApp/Views/MenuBar/HealthStatusPanel.swift`
  - [x] 3.2 实现三种状态的图标 + 颜色 + 文字展示：
    - `.enabled`：绿色 `.checkmark.circle.fill` + "Finder 扩展已启用"
    - `.unknown`：黄色 `.exclamationmark.triangle.fill` + "扩展状态未知"
    - `.disabled`：红色 `.xmark.circle.fill` + "Finder 扩展未启用"
  - [x] 3.3 添加 `.accessibilityLabel("扩展状态：[状态描述]")` 和 `.accessibilityValue`
  - [x] 3.4 添加 `#Preview` 宏，提供三种状态 + Light/Dark Mode 预览

- [x] Task 4: 创建 NormalPopoverView (AC: #2, #3, #4)
  - [x] 4.1 创建 `RCMMApp/Views/MenuBar/NormalPopoverView.swift`
  - [x] 4.2 布局：HealthStatusPanel（顶部）+ Divider + "打开设置"按钮 + "退出"按钮
  - [x] 4.3 "打开设置"按钮使用 `SettingsLink`（SettingsAccess 库）+ ActivationPolicyManager
  - [x] 4.4 "退出"按钮调用 `NSApplication.shared.terminate(nil)`
  - [x] 4.5 添加 `.accessibilityLabel` 和键盘导航支持
  - [x] 4.6 添加 `#Preview` 宏

- [x] Task 5: 创建 PopoverContainerView (AC: #1)
  - [x] 5.1 创建 `RCMMApp/Views/MenuBar/PopoverContainerView.swift`
  - [x] 5.2 实现 `switch popoverState` 路由：`.normal` → NormalPopoverView，`.healthWarning` → 占位符（Epic 6 实现），`.onboarding` → 占位符（当前引导使用独立 NSWindow）
  - [x] 5.3 设置弹出窗口宽度 ~300pt（`.frame(width: 300)`）
  - [x] 5.4 添加 `#Preview` 宏

- [x] Task 6: 重构 rcmmApp.swift — 从 menu 样式迁移到 window 样式 (AC: #1, #3, #4)
  - [x] 6.1 将 `MenuBarExtra` 的内容从当前下拉菜单改为 `PopoverContainerView`
  - [x] 6.2 添加 `.menuBarExtraStyle(.window)` 修饰符
  - [x] 6.3 移除当前的 `SettingsLink` + `Divider` + `Button("退出")` 菜单项（已迁移到 NormalPopoverView）
  - [x] 6.4 保持 `Settings` scene 不变（Settings 窗口仍然正常工作）
  - [x] 6.5 使用 ActivationPolicyManager 替换内联的 ActivationPolicy 切换代码
  - [x] 6.6 在 App 启动时调用 `appState.checkExtensionStatus()`

- [x] Task 7: 编译验证与测试 (AC: 全部)
  - [x] 7.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 7.2 `swift test --package-path RCMMShared` 全部测试通过，无回归
  - [ ] 7.3 手动测试：启动应用 → 菜单栏出现图标 → Dock 无图标
  - [ ] 7.4 手动测试：点击菜单栏图标 → 弹出窗口显示 HealthStatusPanel + "打开设置" + "退出"
  - [ ] 7.5 手动测试：点击"打开设置" → Settings 窗口打开 → 正常显示 TabView
  - [ ] 7.6 手动测试：点击"退出" → 应用退出
  - [ ] 7.7 手动测试：扩展已启用时 → HealthStatusPanel 显示绿色正常状态
  - [ ] 7.8 手动测试：关闭 Settings 窗口 → 应用回到菜单栏常驻（Dock 图标消失）

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 5（系统集成与菜单栏体验）的第一个 Story。Epic 5 共 2 个 Story，本 Story 实现菜单栏常驻应用核心体验（MenuBarExtra popover），Story 5.2 实现开机自启管理（SMAppService）。

**FRs 覆盖：** FR-UI-MENUBAR-001（菜单栏图标 + 弹出窗口）、FR-UI-MENUBAR-002（无 Dock 图标）

**跨 Story 依赖：**
- 依赖 Story 1.1：项目结构、Info.plist LSUIElement = YES、App Group 配置
- 依赖 Story 1.2：SharedConfigService、DarwinNotificationCenter、共享模型（PopoverState、ExtensionStatus）
- 依赖 Story 2.2：SettingsView（TabView 设置窗口，已完整实现）
- 依赖 Story 3.1-3.3：OnboardingFlowView（引导流程使用独立 NSWindow，本 Story 不修改引导逻辑）
- Story 5.2 依赖本 Story：开机自启 UI 将在 GeneralTab 中实现（本 Story 不涉及）
- Epic 6（Story 6.1-6.3）依赖本 Story：扩展健康检测将扩展 HealthStatusPanel 和 PopoverContainerView

### 关键技术决策

**1. MenuBarExtra 从 menu 样式迁移到 window 样式**

当前 `rcmmApp.swift` 使用默认 menu 样式的 `MenuBarExtra`（渲染为下拉菜单），需要迁移到 `.menuBarExtraStyle(.window)`（渲染为弹出窗口）。这是一个破坏性变更——当前菜单中的 `SettingsLink` 和 `Button("退出")` 需要迁移到弹出窗口 View 中。

关键变更：
```swift
// 之前（menu 样式）
MenuBarExtra("rcmm", systemImage: "contextualmenu.and.cursorarrow") {
    SettingsLink { ... }
    Button("退出") { ... }
}

// 之后（window 样式）
MenuBarExtra("rcmm", systemImage: "contextualmenu.and.cursorarrow") {
    PopoverContainerView()
        .environment(appState)
}
.menuBarExtraStyle(.window)
```

**2. SettingsAccess 库的 Settings 窗口打开**

当前项目已使用 `SettingsAccess` 库（通过 `SettingsLink` 组件）处理从 agent 应用打开 Settings 窗口的跨版本兼容 workaround。迁移到 window 样式后，`SettingsLink` 继续在 `NormalPopoverView` 中使用。同时将激活策略切换提取到 `ActivationPolicyManager`。

注意：`SettingsLink` 的 `preAction` 和 `postAction` 回调用于切换 `ActivationPolicy`。`preAction` 在打开 Settings 前将 policy 切换为 `.regular`（应用出现在 Dock），`postAction` 目前为空。Settings 窗口的 `.onDisappear` 回调将 policy 切回 `.accessory`。

**3. ActivationPolicyManager 集中管理激活策略**

当前激活策略切换散落在 `rcmmApp.swift`（Settings 窗口）和 `AppState.swift`（引导窗口）两处。本 Story 创建 `ActivationPolicyManager` 集中管理，提供：
- `showSettings()`：.regular + activate
- `hideToMenuBar()`：.accessory（延迟执行，避免 Settings 窗口关闭时闪烁）

**注意：** 引导窗口（`AppState.showOnboardingIfNeeded`）的激活策略切换也应迁移到 `ActivationPolicyManager`，但引导流程已在 Epic 3 中完成且稳定运行。为避免回归风险，本 Story 只在 `AppState` 中替换调用点，保持引导窗口行为不变。

**4. PopoverState 路由与占位符**

`PopoverState` 枚举已在 RCMMShared 中定义（`.normal`, `.healthWarning`, `.onboarding`）。本 Story 仅实现 `.normal` 路由到 `NormalPopoverView`。`.healthWarning` 和 `.onboarding` 在 `PopoverContainerView` 中使用占位符 View，待 Epic 6 和后续迭代实现。

当前引导流程使用独立 `NSWindow`（AppState.showOnboardingIfNeeded），不通过 PopoverState 路由。本 Story 不修改引导流程架构。

**5. ExtensionStatus 检测**

在 AppState 中添加启动时的扩展状态检测。使用现有 `PluginKitService.isExtensionEnabled` 方法，将 `Bool` 结果映射为 `ExtensionStatus` 枚举。

注意：`PluginKitService.isExtensionEnabled` 目前使用 `FIFinderSyncController.isExtensionEnabled` API。本 Story 仅做启动时一次性检测，定期检测（每 30 分钟）属于 Epic 6 范围。

**6. HealthStatusPanel 组件设计**

`HealthStatusPanel` 是 UX 规格中定义的 5 个自定义组件之一。本 Story 实现基础版本（展示扩展状态），Epic 6 将扩展其功能（添加操作按钮、详细异常信息）。

布局：`HStack` + SF Symbol 图标 + 状态文字，使用系统语义颜色（`.green` / `.yellow` / `.red`）。

### 前序 Story 经验总结

**来自 Story 4.3（最近完成）：**
- `CommandEditor` 的 `#Preview` 宏模式已建立：提供多个预览变体（状态 + Light/Dark Mode）
- Code Review 发现缺少 `#Preview` 是 HIGH 优先级问题——本 Story 所有新 View 必须包含
- `.accessibilityLabel` 和 `.accessibilityValue` 的使用模式已确立

**来自 Story 3.1（引导流程 — PluginKitService 相关）：**
- `PluginKitService.isExtensionEnabled` 使用 `FIFinderSyncController.isExtensionEnabled`
- 引导流程使用独立 NSWindow（`AppState.onboardingWindow`），不通过 PopoverState 路由
- 激活策略切换：`NSApp.setActivationPolicy(.regular)` 在显示窗口前，`.accessory` 在关闭后

**来自 rcmmApp.swift 当前实现：**
- `SettingsAccess` 库的 `SettingsLink` 已稳定运行
- `preAction` 中 `NSApp.setActivationPolicy(.regular)` + `NSApp.activate(ignoringOtherApps: true)`
- Settings `.onDisappear` 中 `DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }`
- 这些模式需要保留并迁移到 ActivationPolicyManager

### Git 近期提交分析

最近 5 个提交：
1. `427a1cb` feat: implement command preview and validation with code review fixes (Story 4.3)
2. `5e1ac9d` feat: implement custom command editor with template placeholders (Story 4.2)
3. `95fb022` feat: implement command mapping service and builtin terminal support (Story 4.1)
4. `cb2662e` feat: implement verify step and onboarding completion (Story 3.3)
5. `af2b2e5` feat: implement onboarding flow and state management in AppState

模式观察：
- 提交消息格式统一：`feat: implement [描述] (Story X.Y)`
- 每个 Story 一个提交（含 code review 修复）
- 当前 42 个单元测试全部通过

### 反模式清单（禁止）

- ❌ 使用 `ObservableObject/@Published`（统一用 `@Observable`）
- ❌ 在 RCMMShared 中引入 SwiftUI 或 AppKit 依赖（PopoverState/ExtensionStatus 已在 RCMMShared，但 View 层在 RCMMApp）
- ❌ 硬编码 App Group 键名或 Darwin Notification 名称（使用 SharedKeys / NotificationNames 常量）
- ❌ 在 MenuBarExtra popover 中直接调用 `NSApp.setActivationPolicy`（通过 ActivationPolicyManager）
- ❌ 修改引导流程架构（OnboardingFlowView 使用独立 NSWindow，本 Story 不改变）
- ❌ 实现定期健康检测（Epic 6 范围，本 Story 仅启动时一次性检测）
- ❌ 实现恢复引导面板 RecoveryGuidePanel（Epic 6 Story 6.3 范围）
- ❌ 修改 Finder Extension 代码（本 Story 不涉及 Extension 变更）
- ❌ 在弹出窗口中使用自定义颜色（使用系统语义颜色 `.green`, `.yellow`, `.red`）
- ❌ 缺少 `#Preview` 宏（所有新 View 必须包含，参考 Story 4.3 Code Review 教训）
- ❌ 缺少 `.accessibilityLabel`（所有交互元素和状态指示器必须包含）

### 范围边界说明

**本 Story 范围内：**
- 创建 `ActivationPolicyManager`（新文件）
- 创建 `HealthStatusPanel`（新文件）
- 创建 `NormalPopoverView`（新文件）
- 创建 `PopoverContainerView`（新文件）
- 修改 `AppState.swift`（添加 popoverState、extensionStatus、checkExtensionStatus）
- 修改 `rcmmApp.swift`（MenuBarExtra 从 menu 迁移到 window 样式，使用 PopoverContainerView）

**本 Story 范围外（明确排除）：**
- 菜单栏图标健康状态变体（图标颜色随状态变化 — Epic 6 Story 6.2）
- 定期健康检测（每 30 分钟 — Epic 6 Story 6.1）
- 恢复引导面板 RecoveryGuidePanel（Epic 6 Story 6.3）
- 开机自启功能（Epic 5 Story 5.2）
- 错误队列展示（Epic 7）
- GeneralTab 和 AboutTab 的具体实现（当前为占位符，后续 Story 实现）

### Project Structure Notes

**本 Story 新建和修改的文件：**

```
rcmm/
├── RCMMApp/
│   ├── rcmmApp.swift                           # [修改] MenuBarExtra 从 menu 迁移到 window 样式
│   ├── AppState.swift                          # [修改] 添加 popoverState、extensionStatus、checkExtensionStatus
│   ├── Views/
│   │   └── MenuBar/                            # [新建目录]
│   │       ├── PopoverContainerView.swift      # [新建] PopoverState 路由容器
│   │       ├── NormalPopoverView.swift          # [新建] 正常状态弹出窗口
│   │       └── HealthStatusPanel.swift          # [新建] 扩展健康状态面板
│   └── Services/
│       └── ActivationPolicyManager.swift       # [新建] 集中管理激活策略切换
```

**不变的文件（已验证无需修改）：**

```
RCMMApp/Views/Settings/SettingsView.swift              # 不变 — TabView 设置窗口
RCMMApp/Views/Settings/MenuConfigTab.swift              # 不变 — 菜单配置 Tab
RCMMApp/Views/Onboarding/OnboardingFlowView.swift       # 不变 — 引导流程
RCMMApp/Services/PluginKitService.swift                 # 不变 — 已有 isExtensionEnabled 方法
RCMMApp/Services/ScriptInstallerService.swift           # 不变 — 脚本生成无关
RCMMFinderExtension/                                     # 不变 — Extension 无变更
RCMMShared/Sources/Models/PopoverState.swift             # 不变 — 枚举已定义
RCMMShared/Sources/Models/ExtensionStatus.swift          # 不变 — 枚举已定义
```

**与架构文档的对齐：**
- `PopoverContainerView` 对应 architecture.md 中的 `RCMMApp/Views/MenuBar/PopoverContainerView.swift`
- `NormalPopoverView` 对应 architecture.md 中的 `RCMMApp/Views/MenuBar/NormalPopoverView.swift`
- `HealthStatusPanel` 是 UX 规格中定义的 5 个自定义组件之一
- `ActivationPolicyManager` 对应 architecture.md 中的 `RCMMApp/Services/ActivationPolicyManager.swift`
- 弹出窗口状态路由对应 architecture.md 中的 "MenuBarExtra 弹出窗口：状态驱动的 View 路由"

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.1] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 5] — Epic 5 整体目标：系统集成与菜单栏体验
- [Source: _bmad-output/planning-artifacts/architecture.md#UI Architecture] — MenuBarExtra 弹出窗口：状态驱动 View 路由
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure] — 完整目录结构定义（含 Views/MenuBar/ 路径）
- [Source: _bmad-output/planning-artifacts/architecture.md#Architectural Boundaries] — 进程边界图、Package 依赖边界
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns] — 状态管理（@Observable + @MainActor）、命名规范
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Design Direction Decision] — 方向 B+C 混合：分层架构 + 状态驱动弹出窗口
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#HealthStatusPanel] — HealthStatusPanel 组件规格（3 种状态、图标、颜色、无障碍）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Component Strategy] — 5 个自定义组件定义和实现策略
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Responsive Design] — 弹出窗口尺寸策略（~280-320pt 宽）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Accessibility] — VoiceOver 和键盘导航要求
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] — 三级按钮层级（主要/次要/三级）
- [Source: _bmad-output/planning-artifacts/prd.md#FR-UI-MENUBAR-001] — 菜单栏图标 + 弹出设置界面
- [Source: _bmad-output/planning-artifacts/prd.md#FR-UI-MENUBAR-002] — 无 Dock 图标
- [Source: _bmad-output/implementation-artifacts/4-3-command-preview-and-validation.md] — 前序 Story 经验（#Preview 宏、accessibilityLabel 要求）
- [Source: RCMMApp/rcmmApp.swift] — 当前 MenuBarExtra 实现（menu 样式 + SettingsAccess）
- [Source: RCMMApp/AppState.swift] — 当前 AppState 实现（@Observable + 引导窗口管理 + 激活策略切换）
- [Source: RCMMApp/Services/PluginKitService.swift] — 扩展状态检测（isExtensionEnabled）
- [Source: RCMMShared/Sources/Models/PopoverState.swift] — PopoverState 枚举定义（.normal, .healthWarning, .onboarding）
- [Source: RCMMShared/Sources/Models/ExtensionStatus.swift] — ExtensionStatus 枚举定义（.enabled, .disabled, .unknown）

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

- xcodebuild -scheme rcmm: BUILD SUCCEEDED (零错误)
- swift test --package-path RCMMShared: 42/42 tests passed, 7 suites, 0 failures

### Completion Notes List

- Task 1: 创建 ActivationPolicyManager（enum + static methods），重构 rcmmApp.swift 和 AppState.swift 中的 3 处 NSApp.setActivationPolicy 调用
- Task 2: AppState 新增 popoverState/extensionStatus 属性和 checkExtensionStatus() 方法，init 中自动检测
- Task 3: HealthStatusPanel 实现三种状态（enabled/unknown/disabled）的图标+颜色+文字，含 accessibilityLabel/Value 和 5 个 Preview 变体
- Task 4: NormalPopoverView 使用 VStack 布局 HealthStatusPanel + Divider + SettingsLink + 退出按钮，SettingsLink 使用 ActivationPolicyManager
- Task 5: PopoverContainerView 实现 switch popoverState 路由，.healthWarning 和 .onboarding 使用占位符（NormalPopoverView），宽度 300pt
- Task 6: rcmmApp.swift MenuBarExtra 从 menu 样式迁移到 .window 样式，内容改为 PopoverContainerView，移除旧的 SettingsLink/Divider/Button 菜单项
- Task 7: 编译成功 + 42 个单元测试全部通过，手动测试项需用户验证

### Change Log

- 2026-02-23: Story 5.1 实现完成 — 菜单栏常驻应用与弹出窗口（MenuBarExtra window 样式 + PopoverContainerView + HealthStatusPanel + ActivationPolicyManager）
- 2026-02-23: Code Review 修复 — 6 个问题已修复：废弃 API 替换（NSApp.activate）、按钮样式对齐 UX 规格（.plain）、方法重命名（activateAsRegularApp）、File List 补全、Preview 安全初始化、⌘Q 快捷键

### File List

- RCMMApp/Services/ActivationPolicyManager.swift [新建]
- RCMMApp/Views/MenuBar/HealthStatusPanel.swift [新建]
- RCMMApp/Views/MenuBar/NormalPopoverView.swift [新建]
- RCMMApp/Views/MenuBar/PopoverContainerView.swift [新建]
- RCMMApp/AppState.swift [修改]
- RCMMApp/rcmmApp.swift [修改]
- _bmad-output/implementation-artifacts/sprint-status.yaml [修改]
