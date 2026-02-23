# Story 6.2: 菜单栏图标健康状态指示

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户,
I want 通过菜单栏图标颜色和样式一眼看出扩展是否正常工作,
So that 我不需要打开任何界面就能知道右键菜单是否可用。

## Acceptance Criteria

1. **正常状态图标** — Extension 状态为 `.enabled` 时，菜单栏显示默认图标，跟随系统菜单栏色（Light/Dark Mode 自适应）。（FR-HEALTH-003）

2. **警告状态图标** — Extension 状态为 `.unknown` 时，菜单栏显示感叹号变体 SF Symbol，黄色警告色。图标变体与颜色同时传达状态（色盲友好）。（FR-HEALTH-003）

3. **异常状态图标** — Extension 状态为 `.disabled` 时，菜单栏显示斜杠/错误变体 SF Symbol，红色异常色。图标变体与颜色同时传达状态（色盲友好）。（FR-HEALTH-003）

4. **VoiceOver 可访问性** — 菜单栏图标显示任意状态时，VoiceOver 聚焦到图标时读出 `.accessibilityLabel("rcmm")` 和 `.accessibilityValue("[当前状态描述]")`。（NFR-ACC-001）

5. **状态变化实时反映** — `AppState.extensionStatus` 变化时，菜单栏图标自动更新为对应状态的图标和颜色，无需手动刷新或重启应用。（FR-HEALTH-003）

## Tasks / Subtasks

- [ ] Task 1: 修改 MenuBarExtra 使用 label: 闭包实现动态图标 (AC: #1, #2, #3, #5)
  - [ ] 1.1 在 `rcmmApp.swift` 中将 `MenuBarExtra("rcmm", systemImage: "contextualmenu.and.cursorarrow")` 改为 `MenuBarExtra { content } label: { ... }` 闭包形式
  - [ ] 1.2 创建 `menuBarIcon` 计算属性（`@ViewBuilder`），根据 `appState.extensionStatus` 返回对应状态的 `Image`：
    - `.enabled` → `Image(systemName: "contextualmenu.and.cursorarrow")`（默认模板渲染，跟随系统菜单栏色）
    - `.unknown` → 感叹号变体 SF Symbol（如 `exclamationmark.triangle.fill`），黄色/橙色
    - `.disabled` → 斜杠/错误变体 SF Symbol（如 `xmark.circle.fill`），红色
  - [ ] 1.3 确保 `appState.extensionStatus` 变化时 label 闭包自动重新渲染（`@Observable` + `@State` 机制保证）

- [ ] Task 2: 添加 VoiceOver 无障碍支持 (AC: #4)
  - [ ] 2.1 为每个状态的 `Image` 添加 `.accessibilityLabel("rcmm")`
  - [ ] 2.2 为每个状态的 `Image` 添加 `.accessibilityValue(...)` 传达当前状态描述：
    - `.enabled` → "Finder 扩展已启用"
    - `.unknown` → "扩展状态未知"
    - `.disabled` → "Finder 扩展未启用"

- [ ] Task 3: 编译验证与测试 (AC: 全部)
  - [ ] 3.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [ ] 3.2 `swift test --package-path RCMMShared` 全部测试通过，无回归
  - [ ] 3.3 手动测试：启动应用 → 菜单栏图标显示默认图标（正常状态）
  - [ ] 3.4 手动测试：在系统设置中禁用 Extension → 等待下次健康检测或点击菜单栏图标触发检测 → 菜单栏图标变为红色异常图标
  - [ ] 3.5 手动测试：在系统设置中重新启用 Extension → 触发检测 → 菜单栏图标恢复默认
  - [ ] 3.6 手动测试：VoiceOver 聚焦菜单栏图标 → 读出 "rcmm" 和当前状态描述
  - [ ] 3.7 手动测试：切换系统 Light/Dark Mode → 正常状态图标正确跟随系统菜单栏色

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 6（扩展健康检测与恢复引导）的第二个 Story，构建在 Story 6.1（扩展状态检测服务）之上。Epic 6 的三个 Story 形成递进关系：**检测（6.1）→ 指示（6.2）→ 恢复（6.3）**。

本 Story 负责"指示"层 — 将 6.1 检测到的 `extensionStatus` 以视觉方式反映在菜单栏图标上，让用户无需打开任何界面就能感知扩展状态。

**FRs 覆盖：** FR-HEALTH-003（系统通过菜单栏图标或状态指示器显示扩展健康状态）

**跨 Story 依赖：**
- 依赖 Story 5.1：MenuBarExtra + PopoverContainerView 基础设施
- 依赖 Story 6.1：`AppState.extensionStatus` 属性和 `PluginKitService.checkHealth()` 检测服务
- Story 6.3 依赖本 Story：RecoveryGuidePanel 的菜单栏图标状态与本 Story 的图标状态一致

### 关键技术决策

**1. MenuBarExtra 从 systemImage: 切换到 label: 闭包**

当前 `rcmmApp.swift` 使用静态 SF Symbol：
```swift
// ❌ 当前 — 静态图标，无法根据状态变化
MenuBarExtra("rcmm", systemImage: "contextualmenu.and.cursorarrow") {
    PopoverContainerView()
        .environment(appState)
}
```

需要改为 `label:` 闭包形式以支持动态图标：
```swift
// ✅ 目标 — 动态图标，响应 extensionStatus 变化
MenuBarExtra {
    PopoverContainerView()
        .environment(appState)
} label: {
    menuBarIcon
}
```

`MenuBarExtra(content:label:)` 初始化器从 macOS 13 起可用，项目目标 macOS 15+，无兼容性问题。

**2. SF Symbol 选择策略**

UX 设计规范要求菜单栏图标状态同时使用 **图标变体** 和 **颜色** 传达（色盲友好）。具体映射：

| 状态 | SF Symbol | 颜色 | 色盲辅助 |
|---|---|---|---|
| `.enabled` | `contextualmenu.and.cursorarrow` | 系统菜单栏色（模板渲染） | 默认形状 |
| `.unknown` | `exclamationmark.triangle.fill` | 黄色/橙色 | 三角形 + 感叹号形状 |
| `.disabled` | `xmark.circle.fill` | 红色 | 圆形 + X 形状 |

选择不同的 SF Symbol 而非同一图标的颜色变化，原因：
1. `contextualmenu.and.cursorarrow` 没有 `.slash` 或 `.exclamationmark` 变体
2. 不同形状的 SF Symbol 即使在单色渲染下也能传达状态（色盲友好）
3. 与 `HealthStatusPanel` 中已建立的图标映射保持一致（同样使用 `exclamationmark.triangle.fill` 和 `xmark.circle.fill`）

**3. 菜单栏图标颜色渲染**

macOS 菜单栏图标默认使用模板渲染（单色，跟随系统菜单栏色）。要在警告/异常状态显示颜色，需要使用 `.symbolRenderingMode()` 或 `.foregroundStyle()` 覆盖默认的模板行为。

正常状态保持模板渲染（自适应 Light/Dark Mode），警告/异常状态使用显式颜色打破模板渲染，使其在菜单栏中醒目突出。

```swift
// 正常 — 模板渲染，跟随系统色
Image(systemName: "contextualmenu.and.cursorarrow")

// 警告 — 显式黄色
Image(systemName: "exclamationmark.triangle.fill")
    .symbolRenderingMode(.multicolor)

// 异常 — 显式红色
Image(systemName: "xmark.circle.fill")
    .foregroundStyle(.red)
```

**注意：** macOS MenuBarExtra 的 label 闭包在 macOS 14+ 支持 `.symbolRenderingMode()` 和 `.foregroundStyle()` 颜色渲染。macOS 15+ 目标版本下无兼容问题。如果在实际测试中发现颜色不显示，备选方案是保持不同 SF Symbol 形状变化（色盲友好设计已经保证了状态可识别性）。

**4. @Observable 自动 UI 更新机制**

`AppState` 使用 `@Observable` 宏，`extensionStatus` 是其属性。在 `rcmmApp` 中，`appState` 是 `@State` 属性。当 `appState.extensionStatus` 变化时，SwiftUI 自动追踪读取了该属性的 View（包括 `label:` 闭包中的 `menuBarIcon`），触发重新渲染。无需手动通知或额外的绑定机制。

```swift
@main
struct rcmmApp: App {
    @State private var appState = AppState()  // @Observable + @State

    var body: some Scene {
        MenuBarExtra {
            // ...
        } label: {
            menuBarIcon  // 读取 appState.extensionStatus → SwiftUI 自动追踪
        }
    }

    @ViewBuilder
    private var menuBarIcon: some View {
        switch appState.extensionStatus {  // 当此值变化，label 闭包自动重渲染
        // ...
        }
    }
}
```

### 现有代码变更分析

**rcmmApp.swift — 修改（核心变更）：**

当前代码：
```swift
MenuBarExtra("rcmm", systemImage: "contextualmenu.and.cursorarrow") {
    PopoverContainerView()
        .environment(appState)
}
.menuBarExtraStyle(.window)
```

目标代码结构：
```swift
MenuBarExtra {
    PopoverContainerView()
        .environment(appState)
} label: {
    menuBarIcon
}
.menuBarExtraStyle(.window)
```

加上新增的 `menuBarIcon` 计算属性。

**其他文件 — 无变更：**
- `AppState.swift` — 不变，`extensionStatus` 已就绪
- `PluginKitService.swift` — 不变，`checkHealth()` 已就绪
- `HealthStatusPanel.swift` — 不变，弹出窗口内状态面板独立于菜单栏图标
- `ExtensionStatus.swift` — 不变，三态枚举已足够
- `PopoverState.swift` — 不变
- `PopoverContainerView.swift` — 不变
- `NormalPopoverView.swift` — 不变

### 前序 Story 经验总结

**来自 Story 6.1（直接前序）：**
- `PluginKitService.checkHealth()` 返回 `ExtensionStatus`（`.enabled` 或 `.disabled`），`.unknown` 仅作为 `AppState.extensionStatus` 初始默认值
- `checkExtensionStatus()` 在状态变化时才更新 `popoverState`，使用 `guard early return` 避免无效更新 — 同样的机制保证菜单栏图标只在状态实际变化时重渲染
- `PopoverContainerView.onAppear` 触发即时检测 — 用户点击菜单栏图标时先更新状态，再渲染弹出窗口内容
- `healthCheckTimer` 每 30 分钟检测一次 — 状态变化会自动反映到菜单栏图标
- `#Preview` 宏是 HIGH 优先级 — 但 `MenuBarExtra` 是 Scene 而非 View，无法使用 `#Preview`。`menuBarIcon` 计算属性是 `rcmmApp` 的私有属性，也不方便独立预览。本 Story 主要通过手动测试验证。

**来自 Story 5.1（MenuBarExtra 先例）：**
- `MenuBarExtra` + `.menuBarExtraStyle(.window)` 是已建立的菜单栏实现模式
- `SettingsAccess` 库的 `SettingsLink` 与 `ActivationPolicyManager` workaround 已在 `NormalPopoverView` 中正常工作
- `.environment(appState)` 传递方式已验证可靠

**来自 Story 5.2（Logger 模式）：**
- Logger 使用 `Logger(subsystem: "com.sunven.rcmm", category: "...")` — 本 Story 无新增日志需求
- `.accessibilityLabel` / `.accessibilityValue` 使用模式已确立

### Git 近期提交分析

最近 5 个提交：
1. `2195c6a` feat: implement extension status detection service with code review fixes (Story 6.1)
2. `94cb802` feat: implement launch at login management with code review fixes (Story 5.2)
3. `cb8eb6b` feat: implement menubar resident app and popover with code review fixes (Story 5.1)
4. `427a1cb` feat: implement command preview and validation with code review fixes (Story 4.3)
5. `5e1ac9d` feat: implement custom command editor with template placeholders (Story 4.2)

模式观察：
- 提交消息格式：`feat: implement [描述] (Story X.Y)`
- 每个 Story 一个提交（有时包含 code review 修复）
- 当前编译成功 + 42 个单元测试全部通过
- Story 6.1 刚完成，`AppState.extensionStatus` 和健康监控基础设施已就绪

### 反模式清单（禁止）

- ❌ 保持 `MenuBarExtra("rcmm", systemImage: ...)` 静态图标初始化器 — 必须切换到 `label:` 闭包形式
- ❌ 仅依赖颜色传达状态（必须同时使用不同 SF Symbol 形状 — 色盲友好）
- ❌ 在 `rcmmApp.swift` 中添加新的状态监听或通知机制 — `@Observable` + `@State` 自动处理 UI 更新
- ❌ 修改 `AppState.extensionStatus` 的类型或行为 — 本 Story 仅消费已有数据
- ❌ 修改 `HealthStatusPanel` — 弹出窗口内的状态面板独立于菜单栏图标
- ❌ 使用 `ObservableObject/@Published`（统一用 `@Observable`）
- ❌ 在 `label:` 闭包中执行健康检测或任何副作用 — label 是纯渲染
- ❌ 使用自定义 NSImage 或 Assets.xcassets 图标资源 — SF Symbols 足够
- ❌ 缺少 `.accessibilityLabel` 和 `.accessibilityValue`

### 范围边界说明

**本 Story 范围内：**
- 修改 `rcmmApp.swift`：将 `MenuBarExtra` 从静态 `systemImage:` 切换到动态 `label:` 闭包
- 添加 `menuBarIcon` 计算属性：根据 `appState.extensionStatus` 返回对应状态的 SF Symbol
- 添加 VoiceOver 无障碍支持：`.accessibilityLabel` + `.accessibilityValue`

**本 Story 范围外（明确排除）：**
- HealthWarningView / RecoveryGuidePanel 的实现（Story 6.3 范围）
- PopoverContainerView 中 `.healthWarning` 路由到真实恢复面板（Story 6.3 范围）
- 修改 `AppState` 状态检测逻辑（Story 6.1 已完成）
- 修改 `HealthStatusPanel` 组件（弹出窗口内状态面板独立）
- 修改 `ExtensionStatus` 或 `PopoverState` 枚举
- 添加自定义菜单栏图标资源到 Assets.xcassets
- 新增单元测试（纯 UI 变更，通过手动测试验证）
- 修改 Finder Extension 代码

### Project Structure Notes

**本 Story 修改的文件：**

```
rcmm/
├── RCMMApp/
│   └── rcmmApp.swift                           # [修改] MenuBarExtra 改为 label: 闭包 + menuBarIcon 计算属性
```

**不变的文件（已验证无需修改）：**

```
rcmm/
├── RCMMApp/
│   ├── AppState.swift                           # 不变 — extensionStatus 已就绪
│   ├── Services/
│   │   └── PluginKitService.swift               # 不变 — checkHealth() 已就绪
│   └── Views/
│       └── MenuBar/
│           ├── PopoverContainerView.swift        # 不变
│           ├── NormalPopoverView.swift           # 不变
│           └── HealthStatusPanel.swift           # 不变 — 弹出窗口内面板独立
├── RCMMFinderExtension/                          # 不变
└── RCMMShared/
    └── Sources/
        └── Models/
            ├── ExtensionStatus.swift             # 不变 — 三态枚举已足够
            └── PopoverState.swift                # 不变
```

**与架构文档的对齐：**
- `rcmmApp.swift` 对应 architecture.md 中的 `RCMMApp/rcmmApp.swift` — "@main 入口，MenuBarExtra + Settings + 隐藏 Window"
- FR-HEALTH-003 → 菜单栏图标状态指示在 architecture.md 中定义为"状态 UI 联动"
- 菜单栏图标状态映射在 ux-design-specification.md 中详细定义：正常（默认色）/ 警告（黄色 + 感叹号）/ 异常（红色 + 斜杠）

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.2] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 6] — Epic 6 整体目标：扩展健康检测与恢复引导
- [Source: _bmad-output/planning-artifacts/architecture.md#Core Architectural Decisions] — "FR-HEALTH (扩展健康): 主 App 进程内 pluginkit 调用；定期/启动时检测；状态 UI 联动"
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure] — rcmmApp.swift 位置和职责
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns] — 状态管理模式、反模式清单
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Status Indication Patterns] — 菜单栏图标状态：正常（默认色）/ 警告（黄色 + 感叹号）/ 异常（红色 + 斜杠）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Color System] — 健康-正常(.green)、健康-警告(.yellow)、健康-异常(.red)
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Accessibility Strategy] — VoiceOver: accessibilityLabel + accessibilityValue
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Custom Components#HealthStatusPanel] — 状态到图标/颜色映射参考
- [Source: _bmad-output/implementation-artifacts/6-1-extension-status-detection-service.md] — 前序 Story：extensionStatus 属性、checkHealth()、健康监控定时器
- [Source: _bmad-output/implementation-artifacts/5-1-menubar-resident-app-and-popover.md] — MenuBarExtra + .menuBarExtraStyle(.window) 实现
- [Source: RCMMApp/rcmmApp.swift] — 当前 MenuBarExtra 静态图标实现
- [Source: RCMMApp/AppState.swift] — extensionStatus @Observable 属性
- [Source: RCMMApp/Views/MenuBar/HealthStatusPanel.swift] — 三态图标/颜色映射参考
- [Source: RCMMShared/Sources/Models/ExtensionStatus.swift] — .enabled/.disabled/.unknown 三态枚举

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
