# Story 3.2: 应用选择引导步骤

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 首次用户,
I want 在引导流程中从已安装应用列表中快速选择要添加到右键菜单的应用,
So that 我不需要手动逐个配置。

## Acceptance Criteria

1. **步骤指示器与应用扫描** — 用户进入引导步骤 2（选择应用）时，`OnboardingStepIndicator` 更新为步骤 2/3（步骤 1 显示已完成绿色勾）。自动调用 `AppDiscoveryService.scanApplications()` 扫描已安装应用（在后台线程执行），扫描期间显示 `ProgressView` 加载指示。扫描完成后展示紧凑模式的应用列表（应用图标 + 名称 + 勾选框），按类别分组（终端类优先、编辑器次之、其他最后）。
2. **预选常见开发工具** — 应用列表加载后，系统自动预选常见开发工具：Terminal（`com.apple.Terminal`）、VS Code（`com.microsoft.VSCode`）、iTerm2（`com.googlecode.iterm2`），基于 `bundleId` 匹配。已存在于 `appState.menuItems` 中的应用显示"已添加"标签且不可勾选。
3. **选择交互** — 用户勾选/取消勾选应用时，选择状态实时更新。底部显示已选数量（如"已选择 3 个应用"）。至少选择 1 个应用时"下一步"按钮可用，未选择时按钮禁用但仍可通过"跳过"继续。
4. **保存并同步** — 用户点击"下一步"时，选中的应用通过 `appState.addMenuItems(from:)` 批量保存为 `MenuItemConfig` 写入 App Group UserDefaults。`saveAndSync()` 触发 `ScriptInstallerService` 为每个选中应用生成 `.scpt` 文件，并通过 `DarwinNotificationCenter` 发送 `configChanged` 通知 Extension。
5. **手动添加支持** — 列表底部提供"手动添加"按钮，点击后弹出 `NSOpenPanel` 文件选择器（过滤 `.app`），选择后应用加入列表并自动勾选。

## Tasks / Subtasks

- [x] Task 1: 创建 SelectAppsStepView 应用选择步骤视图 (AC: #1, #2, #3, #5)
  - [x] 1.1 在 `RCMMApp/Views/Onboarding/` 创建 `SelectAppsStepView.swift`
  - [x] 1.2 定义视图状态：`@State private var selectedAppIds: Set<UUID> = []`、`@State private var isLoading = false`
  - [x] 1.3 通过 `@Environment(AppState.self) private var appState` 接收状态
  - [x] 1.4 实现 `.task` 修饰符中的应用扫描逻辑：`Task.detached { AppDiscoveryService().scanApplications() }` → 存入 `appState.discoveredApps`
  - [x] 1.5 扫描期间显示 `ProgressView("正在扫描已安装应用...")`
  - [x] 1.6 扫描完成后执行预选逻辑：遍历 `appState.discoveredApps`，将 bundleId 匹配 `com.apple.Terminal`、`com.microsoft.VSCode`、`com.googlecode.iterm2` 的应用 id 加入 `selectedAppIds`（排除已在 `appState.menuItems` 中的应用）
  - [x] 1.7 实现分组列表：复用 `AppSelectionSheet` 的 `AppGroup` 分组模式，按 `AppCategory` 分组（终端/编辑器/其他），使用 `Section(header:)` 展示
  - [x] 1.8 每行显示：应用图标（`NSWorkspace.shared.icon(forFile:)` 缩放到 28x28）+ 应用名称 + 勾选 `Toggle`（或"已添加"标签）
  - [x] 1.9 底部显示已选数量文本（`.caption` + `.secondary`）
  - [x] 1.10 实现"手动添加"按钮，调用 `AppDiscoveryService().selectApplicationManually()`，选择后追加到 `appState.discoveredApps` 并自动勾选
  - [x] 1.11 添加所有交互元素的 `.accessibilityLabel`

- [x] Task 2: 集成 SelectAppsStepView 到 OnboardingFlowView (AC: #1, #3, #4)
  - [x] 2.1 在 `OnboardingFlowView.swift` 中替换 `selectAppsPlaceholder` 为 `SelectAppsStepView(onSaveApps: saveSelectedApps)`
  - [x] 2.2 修改"下一步"按钮逻辑：当 `currentStep == .selectApps` 时，先触发保存回调再调用 `advanceToNextStep()`
  - [x] 2.3 在步骤 2 添加"跳过"选项（左下角次要按钮），允许用户不选择任何应用直接进入步骤 3
  - [x] 2.4 传递保存回调：`SelectAppsStepView` 通过 `onSaveApps: ([AppInfo]) -> Void` 闭包返回选中的应用列表
  - [x] 2.5 在回调中调用 `appState.addMenuItems(from: selectedApps)` 完成批量保存

- [x] Task 3: 编译验证与测试 (AC: 全部)
  - [x] 3.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 3.2 `swift test --package-path RCMMShared` 全部现有测试通过，无回归
  - [x] 3.3 手动测试：引导步骤 1 完成后 → 自动进入步骤 2 → 应用列表正确扫描展示
  - [x] 3.4 手动测试：常见开发工具自动预选（如已安装）
  - [x] 3.5 手动测试：勾选/取消勾选 → 已选数量更新 → 点击下一步 → 配置保存并进入步骤 3
  - [x] 3.6 手动测试：点击"手动添加" → NSOpenPanel 弹出 → 选择应用 → 追加到列表
  - [x] 3.7 手动测试：点击"跳过" → 不保存任何应用 → 直接进入步骤 3
  - [x] 3.8 SwiftUI Preview 验证：SelectAppsStepView 加载状态 + 列表状态 + Light/Dark Mode

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 3（首次引导体验）的第二个 Story，在 Story 3.1 建立的引导流程框架内实现应用选择步骤（步骤 2）。Story 3.1 已创建 `OnboardingFlowView` 容器和 `selectAppsPlaceholder` 占位视图。本 Story 完成后，用户可以在引导流程中选择要添加到右键菜单的应用。Story 3.3 将实现验证步骤和引导完成标记。

**FRs 覆盖：** FR-ONBOARDING-002（引导中选择应用）

**跨 Story 依赖：**
- 依赖 Story 3.1：`OnboardingFlowView`（引导容器）、`OnboardingStepIndicator`（步骤指示器）、`PluginKitService`
- 依赖 Story 2.1：`AppDiscoveryService`（应用扫描）、`AppInfo` 模型、`AppCategorizer`（类型识别）
- 依赖 Story 2.2：`AppState`（状态管理）、`AppSelectionSheet`（模式参考）
- 依赖 Story 1.2：`SharedConfigService`、`SharedKeys`、`MenuItemConfig`
- 复用 Epic 2 已建立的 `saveAndSync()` → Darwin Notification 配置同步管道
- Story 3.3 将实现 `VerifyStepView` 并标记 `onboardingCompleted = true`

### 关键技术决策

**1. 复用 AppSelectionSheet 模式（非复用组件本身）**

设置窗口中的 `AppSelectionSheet`（`RCMMApp/Views/Settings/AppSelectionSheet.swift`）已实现完整的应用选择模式，包含：
- 扫描加载（`.task` + `Task.detached`）
- 分组展示（`AppGroup` + `Section`）
- 已添加检测（`existingAppIdentifiers` Set）
- 勾选状态管理（`Set<UUID>`）
- 批量提交（`addMenuItems(from:)`）

**为什么不直接复用 AppSelectionSheet 组件：**
- `AppSelectionSheet` 是 `.sheet` 模态弹出，引导步骤需要内嵌在 `OnboardingFlowView` 中
- 引导步骤需要预选逻辑（auto-select 常见工具），sheet 没有这个需求
- 引导步骤的确认按钮由父视图 `OnboardingFlowView` 统一管理（"下一步"），而非组件内部的"确认"按钮
- 视觉风格需要更紧凑以适配引导窗口尺寸

**方案：** 创建独立的 `SelectAppsStepView`，复用相同的数据加载和分组逻辑模式，但适配引导流程的交互需求。

**2. 预选逻辑**

预选的 bundleId 列表：
```swift
private let preselectBundleIds: Set<String> = [
    "com.apple.Terminal",
    "com.microsoft.VSCode",
    "com.googlecode.iterm2"
]
```

预选在扫描完成后执行（`.task` 中），仅预选当前未在 `appState.menuItems` 中的应用。已在菜单中的应用显示"已添加"标签，不可勾选。

**3. 保存时机与回调模式**

参考 `EnableExtensionStepView` 使用 `onNext` 闭包的模式，`SelectAppsStepView` 通过闭包将选中的应用传给父视图：

```swift
struct SelectAppsStepView: View {
    var onSaveApps: ([AppInfo]) -> Void
    @Environment(AppState.self) private var appState
    @State private var selectedAppIds: Set<UUID> = []
    // ...
}
```

`OnboardingFlowView` 中：
```swift
case .selectApps:
    SelectAppsStepView(onSaveApps: { apps in
        appState.addMenuItems(from: apps)
    })
```

"下一步"按钮点击时，先由 `SelectAppsStepView` 内部触发 `onSaveApps`（传递选中的应用），然后 `OnboardingFlowView` 调用 `advanceToNextStep()`。

**替代方案考虑：** 也可以让 `SelectAppsStepView` 直接接收 `advanceToNextStep` 回调，在自己的"下一步"点击处理中先保存再前进。但这会违反当前 `OnboardingFlowView` 统一管理导航按钮的模式。最终方案需要在实现时根据代码结构灵活调整。

**4. 应用图标获取**

使用与 `AppSelectionSheet` 相同的方式：
```swift
Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
    .resizable()
    .frame(width: 28, height: 28)
```

注意：`NSWorkspace.shared.icon(forFile:)` 在主线程调用即可（系统缓存，几乎无开销）。图标获取不需要后台线程。

**5. AppCategory 分组展示**

复用 `AppSelectionSheet` 中的 `AppGroup` 私有类型和分组逻辑：
```swift
private var groupedApps: [AppGroup] {
    let grouped = Dictionary(grouping: appState.discoveredApps) { $0.category ?? .other }
    return grouped
        .map { AppGroup(category: $0.key, apps: $0.value) }
        .sorted { $0.category < $1.category }
}
```

`AppCategory` 的 `displayName` 扩展已在 `AppSelectionSheet.swift` 中定义为私有扩展。`SelectAppsStepView` 需要复制该扩展或将其提取为公共扩展。**推荐：** 在 `SelectAppsStepView` 中定义相同的私有扩展（保持简单，不为两个使用点引入公共扩展）。

### 前序 Story 经验总结

**来自 Story 3.1（直接前序）：**
- 引导窗口使用 `NSWindow + NSHostingView` 实现（非 SwiftUI Window scene），通过 `AppState.showOnboardingIfNeeded()` 管理
- `OnboardingFlowView` 使用 `@State currentStep: OnboardingStep` 管理步骤，`advanceToStep()` / `advanceToNextStep()` 控制导航
- 步骤 1 的 `EnableExtensionStepView` 使用 `onNext` 回调通知父视图前进
- `isExtensionEnabled` 状态由引导容器管理，通过 `$isExtensionEnabled` Binding 传递给子视图
- 引导窗口固定尺寸 480×500pt
- 步骤 2 占位视图在 `OnboardingFlowView.swift:73-83`（`selectAppsPlaceholder` 计算属性）
- "下一步"按钮在 `OnboardingFlowView.swift:50-56`，当 `currentStep != .enableExtension` 时显示

**来自 Story 2.1（应用发现）：**
- `AppDiscoveryService` 是同步方法（文件系统 IO），调用方需在后台线程执行
- `AppDiscoveryService().scanApplications()` 返回按类别排序的 `[AppInfo]`
- `selectApplicationManually()` 是 `@MainActor async` 方法，返回 `AppInfo?`
- 扫描结果存储在 `appState.discoveredApps`

**来自 Story 2.2（设置窗口 / AppSelectionSheet）：**
- `AppSelectionSheet` 是完整的应用选择参考实现
- 使用 `Set<UUID>` 管理选中状态
- 使用 `existingAppIdentifiers` Set 检测已添加的应用
- 使用 `AppGroup` 私有结构体进行分类分组
- 批量添加通过 `appState.addMenuItems(from: [AppInfo])` 完成（单次 `saveAndSync()`）

**Git 提交模式：**
- 提交消息格式：`feat: implement [feature description] (Story X.Y)`
- 每个 Story 一个 commit

**当前代码状态（需修改的核心文件）：**
- `RCMMApp/Views/Onboarding/OnboardingFlowView.swift:26` — `selectAppsPlaceholder` 需替换为 `SelectAppsStepView`
- `RCMMApp/Views/Onboarding/OnboardingFlowView.swift:50-56` — "下一步"按钮需添加保存逻辑
- `RCMMApp/Views/Onboarding/OnboardingFlowView.swift:38-47` — "跳过"按钮需扩展到步骤 2

**需新建的文件：**
- `RCMMApp/Views/Onboarding/SelectAppsStepView.swift` — 应用选择步骤视图

### macOS 版本兼容说明

本 Story 无特殊 macOS 版本兼容问题。`AppDiscoveryService`、`NSWorkspace.shared.icon(forFile:)`、`NSOpenPanel` 均为稳定 API，macOS 15+ 完全支持。

### Swift 6 并发注意事项

- `AppDiscoveryService.scanApplications()` 在 `Task.detached` 中执行（后台线程），结果赋值回 `appState.discoveredApps` 时自动调度到 `@MainActor`（因为 `AppState` 标记为 `@MainActor`）
- `AppDiscoveryService.selectApplicationManually()` 标记为 `@MainActor async`，在 `Task { }` 中直接调用即可
- `selectedAppIds` 是 `@State` 本地状态，SwiftUI 保证主线程访问
- `Toggle` 绑定操作在主线程，无并发问题

### 反模式清单（禁止）

- ❌ 直接复用 `AppSelectionSheet` 组件（它是 `.sheet` 模态，不适合内嵌引导步骤）
- ❌ 在主线程同步调用 `AppDiscoveryService.scanApplications()`（必须 `Task.detached` 后台执行）
- ❌ 使用 `ObservableObject/@Published`（统一用 `@Observable`）
- ❌ 硬编码预选 bundleId 字符串散落在代码各处（定义为视图内私有常量集合）
- ❌ 修改 `MenuItemConfig`、`AppInfo` 或其他 RCMMShared 模型结构
- ❌ 使用 `try!` 或 force unwrap
- ❌ 在 `SelectAppsStepView` 中实现自己的导航按钮（导航由 `OnboardingFlowView` 统一管理）
- ❌ 实现验证步骤或标记 `onboardingCompleted`（属于 Story 3.3 范围）
- ❌ 将 `AppCategory.displayName` 扩展添加到 RCMMShared（保持在 View 文件内的私有扩展）

### 范围边界说明

**本 Story 范围内：**
- `SelectAppsStepView` 应用选择步骤视图（紧凑模式列表 + 勾选 + 分组 + 预选 + 手动添加）
- 替换 `OnboardingFlowView` 中的步骤 2 占位视图
- 修改 `OnboardingFlowView` 导航逻辑以支持保存回调和步骤 2 的"跳过"选项
- 选中应用通过 `addMenuItems(from:)` 批量保存并同步脚本

**本 Story 范围外（明确排除）：**
- 验证步骤的完整实现（Story 3.3：VerifyStepView）
- 标记 `onboardingCompleted = true`（Story 3.3）
- 自定义命令编辑（Epic 4）
- 菜单栏图标状态指示（Epic 6）
- 任何 RCMMShared 模型修改

### Project Structure Notes

**本 Story 新建文件：**

```
rcmm/
├── RCMMApp/
│   └── Views/
│       └── Onboarding/
│           └── SelectAppsStepView.swift        # [新建] 应用选择引导步骤
```

**本 Story 修改文件：**

```
RCMMApp/Views/Onboarding/OnboardingFlowView.swift  # [修改] 替换占位视图 + 修改导航逻辑
rcmm.xcodeproj/project.pbxproj                      # [修改] 添加新文件
```

**不变的文件（已验证无需修改）：**

```
RCMMApp/AppState.swift                                # 不变 — addMenuItems(from:) 已实现
RCMMApp/Services/AppDiscoveryService.swift            # 不变 — 直接复用
RCMMApp/Services/ScriptInstallerService.swift          # 不变 — saveAndSync 自动调用
RCMMApp/Views/Onboarding/OnboardingStepIndicator.swift # 不变 — 步骤指示器已支持 selectApps
RCMMApp/Views/Onboarding/EnableExtensionStepView.swift # 不变
RCMMApp/Views/Settings/AppSelectionSheet.swift         # 不变 — 模式参考，非修改对象
RCMMApp/Views/Settings/MenuConfigTab.swift             # 不变
RCMMShared/Sources/Models/MenuItemConfig.swift         # 不变
RCMMShared/Sources/Models/AppInfo.swift                # 不变
RCMMShared/Sources/Models/AppCategory.swift            # 不变
RCMMShared/Sources/Constants/SharedKeys.swift          # 不变
RCMMFinderExtension/FinderSync.swift                   # 不变
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.2] — Story 需求定义和验收标准（引导步骤 2：应用选择）
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries] — 项目目录结构（RCMMApp/Views/Onboarding/）
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns] — 命名规范、结构模式、反模式清单
- [Source: _bmad-output/planning-artifacts/architecture.md#Architectural Boundaries] — 进程边界、数据流边界
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#User Journey Flows] — Journey 1: First-Time Setup Step 2 应用选择 UX 定义
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Custom Components] — AppListRow 组件规范（紧凑模式 vs 完整模式）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] — 引导流程按钮层级（主要/次要/三级）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Accessibility Strategy] — VoiceOver、键盘导航、Dynamic Type
- [Source: _bmad-output/planning-artifacts/prd.md#首次引导] — FR-ONBOARDING-002（引导中选择应用）
- [Source: _bmad-output/implementation-artifacts/3-1-onboarding-flow-and-extension-enable-guide.md] — 前序 Story（引导框架 + OnboardingFlowView 结构 + 步骤 2 占位视图）
- [Source: RCMMApp/Views/Onboarding/OnboardingFlowView.swift:19-29] — 步骤路由 switch（selectAppsPlaceholder 在 line 26）
- [Source: RCMMApp/Views/Onboarding/OnboardingFlowView.swift:73-83] — selectAppsPlaceholder 占位视图实现
- [Source: RCMMApp/Views/Onboarding/OnboardingFlowView.swift:50-56] — "下一步"按钮逻辑
- [Source: RCMMApp/Views/Onboarding/OnboardingFlowView.swift:38-47] — "跳过"按钮逻辑
- [Source: RCMMApp/AppState.swift:131-144] — addMenuItems(from:) 批量添加方法
- [Source: RCMMApp/AppState.swift:181-184] — saveAndSync() 保存与同步链
- [Source: RCMMApp/AppState.swift:10] — discoveredApps 属性
- [Source: RCMMApp/Views/Settings/AppSelectionSheet.swift] — 完整应用选择模式参考（分组、勾选、已添加检测、批量提交）
- [Source: RCMMApp/Services/AppDiscoveryService.swift:18-58] — scanApplications() 扫描逻辑
- [Source: RCMMApp/Services/AppDiscoveryService.swift:62-83] — selectApplicationManually() 手动添加
- [Source: RCMMShared/Sources/Services/AppCategorizer.swift:5-14] — terminalBundleIds 已知终端列表
- [Source: RCMMShared/Sources/Services/AppCategorizer.swift:16-27] — editorBundleIds 已知编辑器列表

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

无异常。编译和测试一次通过。

### Completion Notes List

- 创建 `SelectAppsStepView.swift`：实现应用选择引导步骤视图，包含扫描加载、分组列表、预选常见开发工具、勾选交互、已选数量显示、手动添加功能
- 采用 `@Binding var selectedAppIds: Set<UUID>` 模式替代 `onSaveApps` 闭包 — 因为"下一步"按钮在父视图 `OnboardingFlowView` 中，使用 Binding 让父视图可以直接访问选中状态并在点击时执行保存逻辑，这比闭包回调更符合 SwiftUI 数据流模式
- 修改 `OnboardingFlowView.swift`：替换步骤 2 占位视图、添加 `selectedAppIds` 状态、修改"下一步"按钮逻辑（先保存再前进）、扩展"跳过"按钮到步骤 2、添加 `saveSelectedApps()` 方法
- 删除 `selectAppsPlaceholder` 占位视图（已被 `SelectAppsStepView` 替代）
- 项目使用 `PBXFileSystemSynchronizedRootGroup`，新文件自动被 Xcode 发现，无需修改 `project.pbxproj`
- 编译验证：`xcodebuild -scheme rcmm` BUILD SUCCEEDED（零错误）
- 回归测试：`swift test --package-path RCMMShared` 25/25 通过
- 手动测试项（3.3-3.8）需用户在应用运行时验证

### Change Log

- 2026-02-21: 实现应用选择引导步骤（Story 3.2）— 新建 SelectAppsStepView，集成到 OnboardingFlowView，支持扫描/预选/勾选/手动添加/跳过
- 2026-02-21: Code Review 修复 — 空状态添加"手动添加"按钮(H1)；修复手动添加重复检测改用 bundleId/path(M1)；isLoading 初始值改为 true 消除空状态闪烁(M2)；补充列表状态 Preview 并修正 Preview 窗口尺寸(M3)

### File List

- RCMMApp/Views/Onboarding/SelectAppsStepView.swift [新建]
- RCMMApp/Views/Onboarding/OnboardingFlowView.swift [修改]
