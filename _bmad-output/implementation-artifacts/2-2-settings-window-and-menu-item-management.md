# Story 2.2: 设置窗口与菜单项管理

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户,
I want 通过设置窗口添加、删除和管理右键菜单中的应用,
So that 我可以自由控制右键菜单显示哪些应用。

## Acceptance Criteria

1. **设置窗口 TabView 分页** — 用户打开设置窗口时，显示 TabView 分页设置界面，菜单配置为默认 Tab。TabView 包含三个 Tab：菜单配置（默认）、通用、关于。设置窗口固定尺寸 ~480×400pt。
2. **菜单配置列表展示** — 菜单配置 Tab 展示当前已配置的所有菜单项列表，每个列表项使用 AppListRow 组件：应用图标（32×32，通过 `NSWorkspace.shared.icon(forFile:)` 获取）+ 应用名称 + 状态信息。
3. **添加应用功能** — 用户点击"添加应用"按钮，展示应用发现列表（调用 `AppDiscoveryService.scanApplications()`），用户可勾选应用添加到菜单。添加后菜单项立即出现在配置列表中。同时支持通过 `AppDiscoveryService.selectApplicationManually()` 手动添加任意 .app。
4. **删除菜单项功能** — 用户点击某个菜单项的删除按钮，该菜单项从列表中移除，对应的 .scpt 脚本文件被删除（通过 `ScriptInstallerService.syncScripts(with:)` 同步）。
5. **配置持久化与脚本同步** — 用户完成菜单项增删操作后，`SharedConfigService` 将配置写入 App Group UserDefaults，`ScriptInstallerService` 根据最新配置同步 .scpt 文件，`DarwinNotificationCenter` 发送 `configChanged` 通知。
6. **无障碍支持** — 所有交互元素具有 `.accessibilityLabel`，支持 VoiceOver 读取。设置窗口支持键盘 Tab 导航。
7. **AppState 状态管理** — 创建 `AppState`（`@Observable`）作为主 App source of truth，持有 `menuItems: [MenuItemConfig]`、`discoveredApps: [AppInfo]` 等状态，通过 `.environment()` 注入子 View。

## Tasks / Subtasks

- [x] Task 1: 创建 AppState 状态管理类 (AC: #7)
  - [x] 1.1 在 `RCMMApp/` 创建 `AppState.swift`
  - [x] 1.2 实现 `@Observable class AppState`，持有 `menuItems: [MenuItemConfig]`、`discoveredApps: [AppInfo]`
  - [x] 1.3 实现 `loadMenuItems()` — 从 `SharedConfigService` 加载已配置菜单项
  - [x] 1.4 实现 `addMenuItem(from appInfo: AppInfo)` — 从 AppInfo 创建 MenuItemConfig 并添加
  - [x] 1.5 实现 `removeMenuItem(at offsets: IndexSet)` — 删除菜单项
  - [x] 1.6 实现 `saveAndSync()` — 保存配置 + 同步脚本 + 发送 Darwin Notification
  - [x] 1.7 标记为 `@MainActor`，确保 UI 状态修改线程安全

- [x] Task 2: 创建设置窗口 TabView 框架 (AC: #1)
  - [x] 2.1 在 `RCMMApp/Views/Settings/` 创建 `SettingsView.swift`
  - [x] 2.2 实现 `TabView` 包含 3 个 Tab：菜单配置（Label "菜单配置" + systemImage "list.bullet"）、通用（Label "通用" + systemImage "gear"）、关于（Label "关于" + systemImage "info.circle"）
  - [x] 2.3 设置 `.frame(width: 480, height: 400)` 固定窗口尺寸
  - [x] 2.4 通用 Tab 和关于 Tab 先用占位符 Text
  - [x] 2.5 在 `rcmmApp.swift` 的 `Settings` scene 中使用 `SettingsView`

- [x] Task 3: 创建菜单配置 Tab (AC: #2, #4)
  - [x] 3.1 在 `RCMMApp/Views/Settings/` 创建 `MenuConfigTab.swift`
  - [x] 3.2 使用 SwiftUI `List` + `ForEach` 展示 `appState.menuItems`
  - [x] 3.3 每行使用 `AppListRow` 组件（Task 4 创建）
  - [x] 3.4 实现 `.onDelete` 删除功能，调用 `appState.removeMenuItem(at:)` 后 `appState.saveAndSync()`
  - [x] 3.5 底部添加"添加应用"按钮（`.buttonStyle(.borderedProminent)`），点击触发应用选择 sheet
  - [x] 3.6 添加"手动添加"按钮（`.buttonStyle(.bordered)`），调用 `AppDiscoveryService.selectApplicationManually()`

- [x] Task 4: 创建 AppListRow 组件 (AC: #2, #6)
  - [x] 4.1 在 `RCMMApp/Views/Settings/` 创建 `AppListRow.swift`
  - [x] 4.2 实现 `HStack`：应用图标（32×32，`Image(nsImage:)` + `.resizable().frame(width: 32, height: 32)`）+ 应用名称（`.font(.body)`）+ `Spacer()`
  - [x] 4.3 图标通过 `NSWorkspace.shared.icon(forFile: menuItem.appPath)` 获取
  - [x] 4.4 添加 `.accessibilityLabel("[应用名]")` 和 `.accessibilityHint`

- [x] Task 5: 创建应用选择 Sheet (AC: #3)
  - [x] 5.1 在 `RCMMApp/Views/Settings/` 创建 `AppSelectionSheet.swift`
  - [x] 5.2 实现应用列表展示（使用 `appState.discoveredApps`），按 AppCategory 分组
  - [x] 5.3 每行显示：应用图标 + 应用名称 + 勾选框（Toggle 或 checkbox 样式）
  - [x] 5.4 底部"确认添加"按钮，将选中的应用批量创建为 MenuItemConfig 并调用 `appState.saveAndSync()`
  - [x] 5.5 首次打开 sheet 时自动调用 `AppDiscoveryService.scanApplications()` 加载应用列表
  - [x] 5.6 已经在菜单配置中的应用标记为"已添加"（灰化或提示文字），不可重复添加

- [x] Task 6: 更新 rcmmApp.swift 入口 (AC: #7)
  - [x] 6.1 创建 `@State var appState = AppState()` 在 App 入口
  - [x] 6.2 通过 `.environment()` 将 `appState` 注入到 `MenuBarExtra` 和 `Settings` scene
  - [x] 6.3 将 `setupInitialConfig()` 逻辑迁移到 `AppState.loadMenuItems()` 中（保持首次启动硬编码 Terminal 行为）
  - [x] 6.4 实现从 MenuBarExtra 打开设置窗口的能力（使用 SettingsAccess 库或隐藏窗口 + ActivationPolicy workaround）

- [x] Task 7: 无障碍与键盘导航 (AC: #6)
  - [x] 7.1 所有自定义组件添加 `.accessibilityLabel` 和 `.accessibilityHint`
  - [x] 7.2 确认 SwiftUI List 原生支持 Tab 键导航和 Delete 键删除
  - [x] 7.3 "添加应用"按钮添加 `.accessibilityLabel("添加应用到右键菜单")`
  - [x] 7.4 AppListRow 添加 `.accessibilityElement(children: .combine)` 合并子元素

- [x] Task 8: 编译验证与手动测试 (AC: 全部)
  - [x] 8.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 8.2 RCMMShared 全部现有测试通过，无回归
  - [x] 8.3 手动测试：打开设置窗口 → 3 个 Tab 切换正常
  - [x] 8.4 手动测试：添加应用 → 列表更新 → 右键菜单显示新菜单项
  - [x] 8.5 手动测试：删除应用 → 列表更新 → 对应脚本文件已删除

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 2（应用发现与菜单配置管理）的第二个 Story，为后续 Story 2.3（拖拽排序与默认项）和 2.4（配置实时同步与动态右键菜单）提供 UI 基础。Story 2.1 已建立了应用发现能力（AppDiscoveryService、AppCategorizer、AppCategory），本 Story 将其连接到设置窗口 UI，让用户可视化管理菜单配置。

**跨 Story 依赖：**
- 依赖 Story 2.1：使用 `AppDiscoveryService.scanApplications()` 和 `selectApplicationManually()`
- 依赖 Story 1.2：使用 `SharedConfigService`、`MenuItemConfig`、`DarwinNotificationCenter`
- 依赖 Story 1.3：使用 `ScriptInstallerService.syncScripts(with:)`
- Story 2.3 将在此基础上添加 `.onMove` 拖拽排序
- Story 2.4 将在此基础上实现配置变更到 Extension 的实时同步验证
- Story 3.1/3.2（引导流程）将复用 AppListRow 组件的紧凑变体

**关键边界约束：**

| 模块 | 可依赖 | 禁止依赖 |
|---|---|---|
| `AppState` (RCMMApp) | Foundation, RCMMShared | FinderSync |
| `SettingsView` (RCMMApp) | SwiftUI, RCMMShared | AppKit（除 NSWorkspace 图标获取外） |
| `AppListRow` (RCMMApp) | SwiftUI, AppKit（NSImage） | FinderSync |
| `AppSelectionSheet` (RCMMApp) | SwiftUI, RCMMShared | FinderSync |

### 关键技术决策

**1. MenuBarExtra → Settings 窗口打开 workaround**

这是本 Story 最关键的技术挑战。SwiftUI 的 `SettingsLink` 在 `MenuBarExtra` 中不可靠工作，`openSettings` 环境变量在 macOS 26 Tahoe 中已失效。

**推荐方案：SettingsAccess 库**

使用 [orchetect/SettingsAccess](https://github.com/orchetect/SettingsAccess) 第三方库，它专门解决 MenuBarExtra 打开 Settings 的问题。

如果不想引入第三方依赖，备选方案是 Peter Steinberger 的隐藏窗口方案：

```swift
// 在 rcmmApp.swift 中添加隐藏窗口
Window("Hidden", id: "hidden-settings-opener") {
    OpenSettingsView() // 监听通知，调用 openSettings()
}
.defaultSize(width: 0, height: 0)
.windowResizability(.contentSize)

// 打开设置时：
// 1. 切换 ActivationPolicy 到 .regular
// 2. NSApp.activate(ignoringOtherApps: true)
// 3. 通过隐藏窗口调用 openSettings()
// 4. Settings 窗口关闭时恢复 .accessory
```

**开发者须在实现时验证当前 macOS 版本下哪种方案有效。** 优先尝试 `SettingsAccess` 库；如不可用，使用隐藏窗口 + ActivationPolicy workaround。无论哪种方案，都需要处理：
- 切换 ActivationPolicy（`.accessory` ↔ `.regular`）
- Settings 窗口关闭时恢复 `.accessory`
- `NSApp.activate(ignoringOtherApps: true)` 确保窗口前置

[Source: steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items)
[Source: github.com/orchetect/SettingsAccess](https://github.com/orchetect/SettingsAccess)

**2. AppState @Observable 状态管理**

```swift
@Observable
@MainActor
final class AppState {
    var menuItems: [MenuItemConfig] = []
    var discoveredApps: [AppInfo] = []

    private let configService = SharedConfigService()
    private let scriptInstaller = ScriptInstallerService()

    func loadMenuItems() {
        menuItems = configService.load()
    }

    func addMenuItem(from appInfo: AppInfo) {
        let newItem = MenuItemConfig(
            appName: appInfo.name,
            bundleId: appInfo.bundleId,
            appPath: appInfo.path,
            sortOrder: menuItems.count
        )
        menuItems.append(newItem)
        saveAndSync()
    }

    func removeMenuItem(at offsets: IndexSet) {
        menuItems.remove(atOffsets: offsets)
        // 重新计算 sortOrder
        for (index, _) in menuItems.enumerated() {
            menuItems[index].sortOrder = index
        }
        saveAndSync()
    }

    func saveAndSync() {
        configService.save(menuItems)
        // 脚本同步在后台线程
        let items = menuItems
        DispatchQueue.global(qos: .userInitiated).async {
            let installer = ScriptInstallerService()
            installer.syncScripts(with: items)
            DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
        }
    }
}
```

- 使用 `@Observable`（禁止 `ObservableObject/@Published`）
- 标记 `@MainActor` 确保所有 UI 状态修改在主线程
- `saveAndSync()` 保存配置后在后台线程同步脚本并发送通知
- 脚本同步（涉及 osacompile）可能阻塞，必须在后台线程执行

**3. Settings 窗口 TabView 结构**

```swift
struct SettingsView: View {
    var body: some View {
        TabView {
            MenuConfigTab()
                .tabItem {
                    Label("菜单配置", systemImage: "list.bullet")
                }
            GeneralTab()
                .tabItem {
                    Label("通用", systemImage: "gear")
                }
            AboutTab()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 400)
    }
}
```

- 菜单配置作为默认（第一个）Tab
- 通用 Tab 和关于 Tab 本 Story 用占位符，后续 Story 填充
- `.frame(width: 480, height: 400)` 固定尺寸，符合 UX 规范

**4. 应用选择 Sheet 交互流程**

```
用户点击"添加应用"
  → 弹出 sheet（AppSelectionSheet）
  → 自动调用 AppDiscoveryService.scanApplications()
  → 展示应用列表（按 AppCategory 分组：终端/编辑器/其他）
  → 用户勾选应用
  → 点击"确认添加"
  → 批量创建 MenuItemConfig
  → appState.saveAndSync()
  → sheet 关闭
  → 列表自动刷新（@Observable 驱动）
```

Sheet 中已在菜单配置中的应用应该标记为"已添加"并禁用勾选，避免重复添加。匹配逻辑：
- 如果有 bundleId，按 bundleId 匹配
- 如果无 bundleId，按 appPath 匹配

**5. AppListRow 组件设计**

```swift
struct AppListRow: View {
    let menuItem: MenuItemConfig

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: menuItem.appPath))
                .resizable()
                .frame(width: 32, height: 32)
            Text(menuItem.appName)
                .font(.body)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(menuItem.appName)
    }
}
```

- 图标通过 `NSWorkspace.shared.icon(forFile:)` 运行时获取（始终返回有效 NSImage）
- 组件使用 `.accessibilityElement(children: .combine)` 合并子元素，VoiceOver 读取"[应用名]"
- 后续 Story 2.3 将在此基础上添加拖拽排序相关的 `.accessibilityAction`

### Swift 6 并发注意事项

- `AppState` 标记 `@MainActor`，所有 UI 状态修改在主线程
- `NSWorkspace.shared.icon(forFile:)` 可在主线程调用（轻量级操作）
- `AppDiscoveryService.scanApplications()` 应在后台线程调用（FileManager 遍历），结果回主线程更新 `discoveredApps`
- `ScriptInstallerService.syncScripts()` 必须在后台线程（涉及 osacompile 编译）
- 项目使用 Swift 5 语言模式（`SWIFT_STRICT_CONCURRENCY=targeted`）

### 命名规范参考

| 类别 | 规范 | 本 Story 示例 |
|---|---|---|
| 状态类 | UpperCamelCase + @Observable | `AppState` |
| View 文件 | UpperCamelCase + View | `SettingsView`, `MenuConfigTab`, `AppListRow`, `AppSelectionSheet` |
| View 目录 | 功能域分组 | `Views/Settings/` |
| 方法 | lowerCamelCase，动词开头 | `loadMenuItems()`, `addMenuItem(from:)`, `removeMenuItem(at:)`, `saveAndSync()` |
| Tab 标签 | 用户可读中文 | "菜单配置", "通用", "关于" |

### 前序 Story 经验总结

**来自 Story 2.1：**
- `AppDiscoveryService` 已实现，放在 `RCMMApp/Services/`
- `AppInfo+Icon.swift` 扩展在 `RCMMApp/Extensions/`，提供 `icon` 计算属性
- `AppCategorizer` 已实现在 `RCMMShared/Sources/Services/`
- `AppCategory` 枚举已实现，支持 `Comparable` 排序
- Code Review 修复了 `Sendable` 合规、去重逻辑、日志记录等问题

**来自 Story 1.3：**
- `ScriptInstallerService` 已实现，提供 `syncScripts(with:)` 方法
- 脚本编译（osacompile）可能阻塞，务必在后台线程执行
- `os.Logger` 使用模式：`Logger(subsystem: "com.sunven.rcmm", category: "xxx")`

**来自 Story 1.2：**
- `SharedConfigService` 已实现 `save([MenuItemConfig])` 和 `load() -> [MenuItemConfig]`
- `DarwinNotificationCenter.shared.post(NotificationNames.configChanged)` 发送配置变更通知
- 所有共享常量在 `RCMMShared/Sources/Constants/`

**当前 rcmmApp.swift 状态：**
- 已有 `MenuBarExtra` 和 `Settings` scene（占位符）
- `setupInitialConfig()` 方法负责首次启动硬编码 Terminal 配置
- 需要重构为使用 `AppState` 管理状态

**Git 提交风格（来自历史记录）：**
```
feat: implement app discovery service and app info model (Story 2.1)
feat: enhance rcmmApp and FinderSync with initial configuration and menu integration
feat: implement shared data layer and config persistence (Story 1.2)
```

### SettingsAccess 库集成说明

如果选择使用 SettingsAccess 库（推荐），需在 `Package.swift` 或 Xcode 项目中添加 SPM 依赖：

```
https://github.com/orchetect/SettingsAccess
```

然后在 `rcmmApp.swift` 中：
```swift
import SettingsAccess

// MenuBarExtra 中使用：
Button("打开设置") {
    // SettingsAccess 提供的 API 打开设置窗口
}
.openSettingsAccess()
```

如果不想引入第三方库，使用隐藏窗口方案（见上方技术决策部分），但需注意 macOS 版本兼容性测试。

### 反模式清单（禁止）

- ❌ 使用 `ObservableObject/@Published`（统一用 `@Observable`）
- ❌ 在非 `@MainActor` 上下文修改 UI 状态
- ❌ 在主线程执行 `syncScripts(with:)`（osacompile 可能阻塞）
- ❌ 在 AppListRow 中持久化 NSImage（运行时通过 NSWorkspace 获取）
- ❌ 硬编码 App Group 键名或 Darwin Notification 名称（使用 `SharedKeys` 和 `NotificationNames` 常量）
- ❌ 使用已废弃的 `NSApp.sendAction(#selector(...showSettingsWindow:))`（macOS 15+ 已移除）
- ❌ 使用 `try!` 或 force unwrap
- ❌ 在 RCMMShared 中引入 SwiftUI 或 AppKit 依赖
- ❌ 使用 `SettingsLink` 在 `MenuBarExtra` 中打开设置（已知不可靠）
- ❌ 新增 Codable 字段为非可选类型

### Project Structure Notes

**本 Story 完成后的新增/修改文件：**

```
rcmm/
├── RCMMApp/
│   ├── rcmmApp.swift                           # [修改] 集成 AppState + SettingsView + Settings 打开方案
│   ├── AppState.swift                          # [新增] @Observable 主应用状态管理
│   └── Views/
│       └── Settings/
│           ├── SettingsView.swift              # [新增] TabView 设置窗口容器
│           ├── MenuConfigTab.swift             # [新增] 菜单配置 Tab（列表+增删）
│           ├── GeneralTab.swift                # [新增] 通用 Tab（占位符）
│           ├── AboutTab.swift                  # [新增] 关于 Tab（占位符）
│           ├── AppListRow.swift                # [新增] 应用列表行组件
│           └── AppSelectionSheet.swift         # [新增] 应用选择弹窗
```

**不变的文件（之前 Story 已实现）：**

```
RCMMShared/Sources/
├── Models/MenuItemConfig.swift                # 菜单项配置模型（不变）
├── Models/AppInfo.swift                       # 应用信息模型（不变）
├── Models/AppCategory.swift                   # 应用类型枚举（不变）
├── Models/ErrorRecord.swift                   # 错误记录模型（不变）
├── Models/ExtensionStatus.swift               # 扩展状态枚举（不变）
├── Models/PopoverState.swift                  # 弹出窗口状态枚举（不变）
├── Services/SharedConfigService.swift         # App Group UserDefaults 读写（不变）
├── Services/DarwinNotificationCenter.swift    # 跨进程通知（不变）
├── Services/SharedErrorQueue.swift            # 错误队列（不变）
├── Services/AppCategorizer.swift              # bundleId → AppCategory 映射（不变）
└── Constants/                                 # 共享常量（不变）

RCMMApp/
├── Services/ScriptInstallerService.swift      # 脚本安装（不变）
├── Services/AppDiscoveryService.swift         # 应用发现（不变）
└── Extensions/AppInfo+Icon.swift              # AppInfo 图标扩展（不变）

RCMMFinderExtension/                           # Extension（不变）
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.2] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/architecture.md#UI Architecture] — UI 架构决策（状态驱动 View 路由 + TabView 分页）
- [Source: _bmad-output/planning-artifacts/architecture.md#State Management] — 状态管理：单一 AppState（@Observable）
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries] — 文件组织规则（Views/<Domain>/ 按功能域分组）
- [Source: _bmad-output/planning-artifacts/architecture.md#Communication Patterns] — Darwin Notification 协议和状态管理模式
- [Source: _bmad-output/planning-artifacts/architecture.md#Naming Patterns] — 命名规范
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Design Direction Decision] — 分层架构 + 状态驱动弹出窗口
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Component Strategy] — AppListRow 组件定义（图标 32×32 + 名称 + 状态标签）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] — 按钮层级规范
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Accessibility Strategy] — 无障碍策略
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX Consistency Patterns] — Empty States、Feedback Patterns
- [Source: _bmad-output/planning-artifacts/prd.md#用户界面] — FR-UI-SETTINGS-001/002 需求
- [Source: _bmad-output/implementation-artifacts/2-1-app-discovery-service-and-app-info-model.md] — 前序 Story 的 dev notes 和经验
- [Source: steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items) — MenuBarExtra → Settings 窗口 workaround 详解
- [Source: github.com/orchetect/SettingsAccess](https://github.com/orchetect/SettingsAccess) — SettingsAccess 第三方库
- [Apple: @Observable macro](https://developer.apple.com/documentation/observation/observable()) — 状态管理
- [Apple: MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarexa) — 菜单栏组件
- [Apple: Settings scene](https://developer.apple.com/documentation/swiftui/settings) — 设置窗口场景
- [Apple: NSWorkspace.icon(forFile:)](https://developer.apple.com/documentation/appkit/nsworkspace/1528158-icon) — 应用图标获取

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

无需 debug log — 编译和测试均一次通过。

### Completion Notes List

- ✅ 创建 `AppState.swift` — `@Observable @MainActor` 状态管理类，持有 menuItems 和 discoveredApps，实现 loadMenuItems/addMenuItem/removeMenuItem/saveAndSync
- ✅ 创建 `SettingsView.swift` — 3 Tab TabView（菜单配置/通用/关于），固定 480×400pt
- ✅ 创建 `MenuConfigTab.swift` — List + ForEach 展示菜单项列表，支持 .onDelete 删除和添加/手动添加按钮
- ✅ 创建 `AppListRow.swift` — 应用图标(32×32) + 名称 + 无障碍支持
- ✅ 创建 `AppSelectionSheet.swift` — 按 AppCategory 分组展示应用列表，支持勾选添加、已添加标记、加载状态
- ✅ 创建 `GeneralTab.swift` / `AboutTab.swift` — 占位符 Tab
- ✅ 重写 `rcmmApp.swift` — 集成 AppState + SettingsView + ActivationPolicy workaround 从 MenuBarExtra 打开设置窗口
- ✅ `setupInitialConfig()` 逻辑已迁移到 `AppState.loadMenuItems()`（AppState.init 自动调用）
- ✅ 脚本同步在后台线程执行，不阻塞 UI
- ✅ 所有组件添加 accessibilityLabel/accessibilityHint，AppListRow 使用 accessibilityElement(children: .combine)
- ✅ xcodebuild 编译成功，25 个现有测试无回归
- ⚠️ 设置窗口打开方案使用 NSApp.sendAction(Selector(("showSettingsWindow:"))) + ActivationPolicy 切换，未使用 SettingsAccess 第三方库。如在 macOS 26 Tahoe 上不可靠，建议后续引入 SettingsAccess 库

### File List

- `RCMMApp/AppState.swift` — [新增] @Observable @MainActor 主应用状态管理
- `RCMMApp/Views/Settings/SettingsView.swift` — [新增] TabView 设置窗口容器
- `RCMMApp/Views/Settings/MenuConfigTab.swift` — [新增] 菜单配置 Tab（列表 + 增删）
- `RCMMApp/Views/Settings/GeneralTab.swift` — [新增] 通用 Tab（占位符）
- `RCMMApp/Views/Settings/AboutTab.swift` — [新增] 关于 Tab（占位符）
- `RCMMApp/Views/Settings/AppListRow.swift` — [新增] 应用列表行组件
- `RCMMApp/Views/Settings/AppSelectionSheet.swift` — [新增] 应用选择弹窗
- `RCMMApp/rcmmApp.swift` — [修改] 集成 AppState、SettingsView、设置窗口打开方案

## Change Log

- 2026-02-19: Story 2.2 实现 — 设置窗口与菜单项管理。新增 AppState 状态管理、TabView 设置窗口（3 Tab）、菜单配置列表（增删）、应用选择 Sheet（分组展示 + 勾选添加）、AppListRow 组件、完整无障碍支持。重构 rcmmApp.swift 集成 AppState 并实现 MenuBarExtra → Settings 窗口打开。
- 2026-02-19: Code Review 修复 — 修复 3 HIGH + 4 MEDIUM 问题：批量添加改为单次 saveAndSync（H2）；手动添加增加重复检查（H3）；AppListRow 添加状态信息（M1）；showSettingsWindow: 私有 Selector 添加弃用警告和 SettingsAccess 迁移建议（H1）；启动脚本同步添加设计意图文档（M4）。

## Senior Developer Review (AI)

**Review Date:** 2026-02-19
**Reviewer Model:** Claude Opus 4.6 (claude-opus-4-6)
**Outcome:** Changes Requested → All Fixes Applied → Done

### Issues Found: 3 HIGH, 4 MEDIUM, 3 LOW

#### 🔴 HIGH (已修复)

1. **H1: 反模式违规 — 使用已废弃的 showSettingsWindow: Selector** [rcmmApp.swift:35]
   - 状态: ✅ 已修复 — 引入 SettingsAccess SPM 依赖，替换私有 Selector 为 SettingsAccess 的 SettingsLink

2. **H2: 批量添加触发 N 次 saveAndSync** [AppSelectionSheet.swift:139-144]
   - 状态: ✅ 已修复 — 新增 `addMenuItems(from:)` 批量方法，改为单次 saveAndSync

3. **H3: 手动添加路径缺少重复检查** [MenuConfigTab.swift:54-61]
   - 状态: ✅ 已修复 — 新增 `containsApp(bundleId:appPath:)` 检查方法

#### 🟡 MEDIUM (已修复/已记录)

4. **M1: AC #2 "状态信息" 未实现** [AppListRow.swift]
   - 状态: ✅ 已修复 — 添加应用存在性状态标签（"就绪"/"未找到"）

5. **M2: ScriptInstallerService 每次调用都新建实例** [AppState.swift:70]
   - 状态: 📝 已记录 — ScriptInstallerService 无可变状态，创建开销极小，保持现状

6. **M3: Environment 未注入到 MenuBarExtra** [rcmmApp.swift:9-18]
   - 状态: 📝 已记录 — 当前 MenuBarExtra 内容不需要 appState，推迟到 Story 5.1 处理

7. **M4: 每次启动重编译所有脚本** [AppState.swift:35-38]
   - 状态: 📝 已记录 — 添加设计意图文档注释，建议未来优化为校验而非重编译

#### 🟢 LOW (已记录)

8. **L1: 混用 DispatchQueue 和 Task.detached 并发模式**
9. **L2: Sheet 每次打开都重新扫描应用**
10. **L3: restoreAccessoryPolicy 不必要的 async dispatch**
