# Story 7.2: 错误展示与恢复建议

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户,
I want 打开 rcmm 时看到之前的执行错误和恢复建议,
So that 我可以自助解决"点了没反应"的问题。

## Acceptance Criteria

1. **主应用读取错误队列** — Extension 之前记录了执行错误到错误队列，用户打开主应用（点击菜单栏图标或激活应用），主应用从 SharedErrorQueue 读取未处理的错误记录，在弹出窗口顶部展示最近的错误信息。（FR-ERROR-002）

2. **错误详情与恢复建议** — 错误信息展示中，用户查看错误详情，显示错误原因（如"VS Code 未找到"、"脚本执行失败"），显示恢复建议（如"请在设置中移除此菜单项或安装应用"、"请重新打开应用以修复脚本"），提供操作按钮（如"打开设置"跳转到菜单管理）。（FR-ERROR-002, FR-ERROR-003）

3. **错误记录清除** — 用户处理完错误，关闭错误提示或执行了恢复操作，对应的错误记录从队列中移除，弹出窗口恢复正常视图。（FR-ERROR-002）

4. **脚本文件自动修复** — 脚本文件缺失的错误，用户下次打开主应用，ScriptInstallerService 自动检测并重新生成缺失的 .scpt 文件，显示提示"已自动修复脚本文件"。（FR-ERROR-003）

## Tasks / Subtasks

- [x] Task 1: AppState 错误队列集成 (AC: #1)
  - [x] 1.1 在 `RCMMApp/AppState.swift` 中添加 `var errorRecords: [ErrorRecord] = []` 属性
  - [x] 1.2 添加 `loadErrors()` 方法，调用 `SharedErrorQueue().loadAll()` 读取错误记录，更新 `errorRecords`
  - [x] 1.3 添加 `dismissAllErrors()` 方法，调用 `SharedErrorQueue().removeAll()` 并清空 `errorRecords`
  - [x] 1.4 在 `PopoverContainerView.swift` 的 `.onAppear` 中调用 `appState.loadErrors()`

- [x] Task 2: 错误展示 UI 组件 (AC: #1, #2)
  - [x] 2.1 创建 `RCMMApp/Views/MenuBar/ErrorBannerView.swift`，展示错误列表
  - [x] 2.2 每条错误显示：上下文（菜单项名称）+ 错误原因 + 恢复建议文字
  - [x] 2.3 根据 `ErrorRecord.message` 内容推导恢复建议：
    - 包含"脚本文件不存在"→ "已自动修复，请重试"
    - 包含"脚本执行失败"→ "请检查应用是否已安装，或在设置中移除"
    - 包含"脚本目录不可用"→ "请重新安装应用"
    - 其他 → "请在设置中检查菜单配置"
  - [x] 2.4 提供"打开设置"按钮（使用 SettingsLink）和"忽略全部"按钮
  - [x] 2.5 所有交互元素添加 `.accessibilityLabel`

- [x] Task 3: NormalPopoverView 集成错误展示 (AC: #1, #3)
  - [x] 3.1 在 `NormalPopoverView.swift` 中，`HealthStatusPanel` 之后、`Divider` 之前，条件展示 `ErrorBannerView`
  - [x] 3.2 当 `appState.errorRecords` 非空时显示错误区域，为空时不显示
  - [x] 3.3 用户点击"忽略全部"后调用 `appState.dismissAllErrors()`，错误区域消失

- [x] Task 4: 脚本文件自动修复 (AC: #4)
  - [x] 4.1 在 `AppState.swift` 中添加 `var autoRepairMessage: String? = nil` 属性
  - [x] 4.2 在 `loadErrors()` 中，检测是否有脚本文件相关错误（message 包含"脚本文件不存在"或"脚本文件无法加载"）
  - [x] 4.3 如有脚本文件错误，调用 `syncScriptsInBackground()` 重新生成脚本，设置 `autoRepairMessage = "已自动修复脚本文件"`
  - [x] 4.4 在 `ErrorBannerView` 中展示 `autoRepairMessage`（如果有），5 秒后自动淡出

- [x] Task 5: 编译验证与测试 (AC: 全部)
  - [x] 5.1 `swift build --package-path RCMMShared` 编译成功
  - [x] 5.2 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [ ] 5.3 手动测试：Extension 记录错误 → 点击菜单栏图标 → 弹出窗口顶部显示错误信息和恢复建议
  - [ ] 5.4 手动测试：点击"忽略全部" → 错误记录清除 → 弹出窗口恢复正常视图
  - [ ] 5.5 手动测试：删除某个 .scpt 文件 → 打开主应用 → 自动修复脚本 → 显示"已自动修复脚本文件"

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 7（错误处理与用户反馈）的第二个也是最后一个 Story。Epic 7 包含两个 Story：**检测+捕获（7.1，已完成）→ 展示+恢复（7.2）**。本 Story 负责"展示+恢复"层，消费 Story 7.1 建立的 SharedErrorQueue 错误数据，在主应用弹出窗口中向用户展示错误信息和恢复建议。

**FRs 覆盖：** FR-ERROR-002（错误提示含原因和建议）、FR-ERROR-003（恢复建议）

**跨 Story 依赖：**
- 依赖 Story 1.2：ErrorRecord 模型、SharedErrorQueue 服务（已实现）
- 依赖 Story 1.3：ScriptExecutor 脚本执行与错误捕获（已实现）
- 依赖 Story 5.1：PopoverContainerView、NormalPopoverView（已实现）
- 依赖 Story 6.2：HealthStatusPanel 组件（已实现）
- 依赖 Story 6.3：RecoveryGuidePanel 组件（已实现，作为 UI 模式参考）
- **直接依赖 Story 7.1**：SharedErrorQueue 错误写入、AppListRow 警告标记（已实现）

### 关键发现：已实现的基础设施

**重要：错误捕获和存储基础设施已在前序 Story 中完整实现，本 Story 聚焦于"消费端" — 读取、展示和恢复。**

**已实现（不需要修改）：**

1. **ErrorRecord.swift** — 完整的错误记录模型（id, timestamp, source, message, context）
2. **SharedErrorQueue.swift** — 完整的错误队列服务（append, loadAll, removeAll, 20 条 FIFO）
3. **ScriptExecutor.swift** — Extension 侧三种错误场景的捕获和记录
4. **ScriptInstallerService.swift** — `syncScripts(with:)` 已有缺失脚本重新生成能力
5. **HealthStatusPanel.swift** — 可复用的状态指示组件
6. **RecoveryGuidePanel.swift** — UI 模式参考（布局、按钮样式、动画、无障碍）
7. **PopoverContainerView.swift** — 视图路由容器（`.onAppear` 是激活钩子）
8. **NormalPopoverView.swift** — 正常状态弹出窗口视图

**需要新增/修改的代码：**

1. **AppState.swift** — 添加 `errorRecords` 属性、`loadErrors()` 方法、`dismissAllErrors()` 方法、`autoRepairMessage` 属性
2. **PopoverContainerView.swift** — 在 `.onAppear` 中添加 `appState.loadErrors()` 调用
3. **NormalPopoverView.swift** — 条件展示错误区域
4. **ErrorBannerView.swift** — 新增错误展示组件

### 关键技术决策

**1. 错误展示位置：NormalPopoverView 内联，非独立 PopoverState**

选择在 NormalPopoverView 内部条件展示错误，而非添加新的 PopoverState 枚举值。原因：
- AC 明确要求"在弹出窗口顶部展示" — 错误与正常内容共存，不是替代
- `healthWarning` 状态（扩展未启用）优先级更高 — 如果扩展都不可用，执行错误无意义
- 保持 PopoverState 枚举简洁，避免状态组合爆炸
- 用户仍能看到正常的设置入口和退出按钮

**2. 使用 removeAll() 而非逐条删除**

错误展示 UI 提供"忽略全部"按钮清除所有错误，而非逐条删除。原因：
- SharedErrorQueue 已有 `removeAll()` API，无需新增 `remove(id:)` 方法
- 错误通常是批量产生的（例如多个菜单项的脚本同时缺失），逐条删除体验繁琐
- 最小化对 RCMMShared 的修改（该 Package 被 Extension 和 App 共同依赖，变更需谨慎）
- 用户关注的是恢复操作（打开设置、重新安装应用），不是逐条管理错误记录

**3. 恢复建议基于错误 message 内容推导**

不扩展 ErrorRecord 模型添加 `recoveryAdvice` 字段，而是在 UI 层根据 `message` 字符串内容推导恢复建议。原因：
- ErrorRecord 模型已完整，无需变更（避免影响 Extension 侧的序列化兼容性）
- ScriptExecutor 写入的三种错误 message 格式已确定且稳定：
  - `"脚本目录不可用"` → 恢复建议："请重新安装应用"
  - `"脚本文件不存在或无法加载: ..."` → 恢复建议："已自动修复，请重试"（如果自动修复成功）
  - `"脚本执行失败: ..."` → 恢复建议："请检查应用是否已安装，或在设置中移除"
- 恢复建议是 UI 关注点，放在 View 层更合适

**4. 自动修复触发时机：loadErrors() 中检测脚本文件错误**

在 `loadErrors()` 方法中，如果检测到错误队列中存在脚本文件相关的错误，自动触发 `syncScriptsInBackground()` 重新生成脚本。原因：
- `syncScripts(with:)` 已有完整的缺失脚本检测和重新生成逻辑
- 在 loadErrors() 中触发，确保每次用户打开弹出窗口时自动修复
- 修复结果通过 `autoRepairMessage` 属性反馈到 UI（5 秒后淡出）
- 不需要添加额外的修复检测入口

**5. ErrorBannerView 提取为独立文件**

遵循 Story 6.3 code review 的模式建议 — 提取独立 View 文件。ErrorBannerView 作为错误展示组件，包含错误列表、恢复建议和操作按钮，具有独立的逻辑和状态，适合独立文件管理。

### 现有代码变更分析

**AppState.swift — 修改（3 处新增）：**

```swift
// 新增属性
var errorRecords: [ErrorRecord] = []
var autoRepairMessage: String? = nil

// 新增方法
func loadErrors() {
    let queue = SharedErrorQueue()
    errorRecords = queue.loadAll()

    // 自动修复：检测脚本文件相关错误
    let hasScriptFileErrors = errorRecords.contains { record in
        record.message.contains("脚本文件不存在") || record.message.contains("脚本文件无法加载")
    }
    if hasScriptFileErrors {
        syncScriptsInBackground()
        autoRepairMessage = "已自动修复脚本文件"
    }
}

func dismissAllErrors() {
    let queue = SharedErrorQueue()
    queue.removeAll()
    errorRecords = []
}
```

**PopoverContainerView.swift — 修改（1 处）：**

在 `.onAppear` 中添加 `loadErrors()` 调用：

```swift
.onAppear {
    appState.checkExtensionStatus()
    appState.loadErrors()  // 新增
}
```

**NormalPopoverView.swift — 修改（1 处）：**

在 `HealthStatusPanel` 之后条件展示错误区域：

```swift
VStack(spacing: 12) {
    HealthStatusPanel(status: appState.extensionStatus)

    // 新增：条件展示错误信息
    if !appState.errorRecords.isEmpty || appState.autoRepairMessage != nil {
        Divider()
        ErrorBannerView()
    }

    Divider()
    // ... 原有的设置和退出按钮
}
```

**ErrorBannerView.swift — 新增文件：**

```
RCMMApp/Views/MenuBar/ErrorBannerView.swift
```

遵循 RecoveryGuidePanel 的 UI 模式：
- VStack 布局，spacing: 8
- 错误列表使用 ForEach（最多展示最近 3 条，避免弹出窗口过高）
- 每条错误：图标 + 上下文（菜单项名称）+ 错误原因 + 恢复建议
- 底部操作栏："打开设置"按钮 + "忽略全部"按钮
- autoRepairMessage 横幅（如有，5 秒后淡出）
- 所有交互元素添加 `.accessibilityLabel`

### 前序 Story 经验总结

**来自 Story 7.1（直接前序 — 最近完成）：**
- 大部分基础设施已在前序 Story 实现 — 本 Story 同样代码改动量可控
- 提取独立 View 文件是 code review 推荐模式 — ErrorBannerView 应独立文件
- `#Preview` 宏覆盖所有状态变体 — ErrorBannerView 需覆盖"有错误"、"有自动修复消息"、"无错误"状态
- AC1 行为澄清：Extension 侧错误被程序化捕获写入 SharedErrorQueue，不会显示系统对话框。本 Story 实现的 UI 就是用户看到错误信息的入口

**来自 Story 6.3（RecoveryGuidePanel — UI 模式参考）：**
- VStack(spacing: 12) + padding(12) 布局模式
- 主要操作按钮 `.buttonStyle(.borderedProminent)` + `.frame(maxWidth: .infinity)`
- 次要操作按钮 `.buttonStyle(.bordered)`
- `.foregroundStyle(.secondary)` 用于说明文字
- `.font(.subheadline)` 用于辅助信息
- Timer 淡出模式（用于 autoRepairMessage 5 秒淡出）
- `.transition(.opacity)` + `.animation(.easeInOut(duration: 0.3))` 动画模式
- `.accessibilityElement(children: .contain)` 容器无障碍

**来自 Story 5.1（NormalPopoverView 创建者）：**
- VStack(spacing: 12) + padding(12) 布局
- SettingsLink + SettingsAccess 打开设置窗口
- `.buttonStyle(.plain)` 用于列表操作按钮
- 键盘快捷键 `.keyboardShortcut` 模式

**来自 Story 1.2（SharedErrorQueue 创建者）：**
- SharedErrorQueue 的 append 方法非原子操作（跨进程） — 读取时可能遇到部分写入，但概率极低
- ErrorRecord 字段完整，无需扩展
- `removeAll()` 使用 `userDefaults?.removeObject(forKey:)` 完全清除

### Git 近期提交分析

最近 5 个提交：
1. `4e64539` feat: implement app existence check and execution error capture with code review fixes (Story 7.1)
2. `83ce15e` feat: implement recovery guide panel with code review fixes (Story 6.3)
3. `333de3e` feat: implement menubar icon health status indicator with code review fixes (Story 6.2)
4. `346da6a` fix: update menubar icon health status to ready-for-dev in sprint status
5. `2195c6a` feat: implement extension status detection service with code review fixes (Story 6.1)

模式观察：
- 提交消息格式：`feat: implement [描述] (Story X.Y)`
- 每个 Story 一个提交（有时包含 code review 修复）
- 当前编译成功（Story 7.1 提交确认）
- Story 7.1 修改了 2 个源文件（AppListRow.swift + ScriptInstallerService.swift），本 Story 预计修改 3 个 + 新增 1 个

### 反模式清单（禁止）

- ❌ 修改 ErrorRecord 模型（已完整，无需变更）
- ❌ 修改 ScriptExecutor.swift（Extension 侧错误捕获已完整）
- ❌ 修改 FinderSync.swift（Extension 入口不涉及）
- ❌ 添加新的 PopoverState 枚举值（错误在 NormalPopoverView 内联展示）
- ❌ 在 Extension 中弹自定义窗口或 Alert
- ❌ 使用 ObservableObject/@Published（统一用 @Observable）
- ❌ 硬编码 App Group ID 或通知名字符串
- ❌ 使用 try! 或 force unwrap
- ❌ 在错误展示中使用自定义弹窗/Alert（内联在弹出窗口中展示）
- ❌ 为 ErrorRecord 添加 recoveryAdvice 字段（在 UI 层推导）
- ❌ 逐条删除错误（使用 removeAll 批量清除）

### 范围边界说明

**本 Story 范围内：**
- AppState 添加 errorRecords 属性和 loadErrors/dismissAllErrors 方法
- PopoverContainerView 添加 loadErrors 调用
- NormalPopoverView 条件展示错误区域
- ErrorBannerView 新组件：错误列表 + 恢复建议 + 操作按钮
- 脚本文件自动修复触发和反馈
- autoRepairMessage 5 秒淡出

**本 Story 范围外（明确排除）：**
- 错误记录的逐条删除 API（使用批量清除）
- ErrorRecord 模型变更
- Extension 侧任何修改
- SharedErrorQueue 的 remove(id:) 方法
- 错误记录的持久化标记（如"已读"状态）
- 错误通知推送（仅在弹出窗口中展示）

### Project Structure Notes

**本 Story 修改的文件：**

```
rcmm/
├── RCMMApp/
│   ├── AppState.swift                         # [修改] 添加 errorRecords、loadErrors()、dismissAllErrors()、autoRepairMessage
│   └── Views/
│       └── MenuBar/
│           ├── PopoverContainerView.swift      # [修改] onAppear 添加 loadErrors() 调用
│           ├── NormalPopoverView.swift         # [修改] 条件展示 ErrorBannerView
│           └── ErrorBannerView.swift           # [新增] 错误展示与恢复建议组件
```

**不变的文件（已验证无需修改）：**

```
rcmm/
├── RCMMShared/
│   └── Sources/
│       ├── Models/
│       │   ├── ErrorRecord.swift              # 不变 — 模型已完整
│       │   ├── MenuItemConfig.swift           # 不变
│       │   └── PopoverState.swift             # 不变 — 不添加新枚举值
│       ├── Services/
│       │   ├── SharedErrorQueue.swift         # 不变 — API 已完整（loadAll + removeAll）
│       │   └── SharedConfigService.swift      # 不变
│       └── Constants/
│           ├── SharedKeys.swift               # 不变 — errorQueue 键名已定义
│           └── AppGroupConstants.swift        # 不变
├── RCMMFinderExtension/
│   ├── FinderSync.swift                       # 不变
│   └── ScriptExecutor.swift                   # 不变 — 错误捕获已完整
├── RCMMApp/
│   ├── rcmmApp.swift                          # 不变
│   ├── Services/
│   │   └── ScriptInstallerService.swift       # 不变 — syncScripts 已有修复能力
│   └── Views/
│       ├── MenuBar/
│       │   ├── HealthStatusPanel.swift        # 不变 — 可复用
│       │   ├── RecoveryGuidePanel.swift        # 不变 — UI 模式参考
│       │   └── MenuBarStatusIcon.swift        # 不变
│       └── Settings/
│           ├── AppListRow.swift               # 不变
│           └── MenuConfigTab.swift            # 不变
```

**与架构文档的对齐：**
- FR-ERROR-002/003 → 架构文档定义："Extension 写入 App Group 错误队列（最多 20 条 FIFO），主 App 激活时读取展示"
- 错误队列消费链路：SharedErrorQueue.loadAll() → AppState.errorRecords → NormalPopoverView → ErrorBannerView
- 错误队列清除链路：用户点击"忽略全部" → AppState.dismissAllErrors() → SharedErrorQueue.removeAll()
- 自动修复链路：loadErrors() 检测脚本错误 → syncScriptsInBackground() → autoRepairMessage
- 弹出窗口状态优先级：healthWarning（扩展异常）> normal + errors（有错误）> normal（正常）

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.2] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 7] — Epic 7 整体目标：错误处理与用户反馈
- [Source: _bmad-output/planning-artifacts/architecture.md#Error Handling & Logging] — "Extension 写入 App Group 错误队列；主 App 激活时读取展示"
- [Source: _bmad-output/planning-artifacts/architecture.md#Data Architecture] — 错误队列存储为 JSON Data 数组，键名 rcmm.error.queue，最多 20 条 FIFO
- [Source: _bmad-output/planning-artifacts/architecture.md#UI Architecture] — MenuBarExtra 弹出窗口状态驱动 View 路由
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns] — ErrorRecord 结构定义、错误处理流程模式
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Feedback Patterns] — 错误-内部：下次打开主 App 时在弹出窗口顶部展示，用户操作后消失
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 4: Error Handling] — 脚本文件缺失：下次打开主 App 时提示重新安装脚本
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Status Indication Patterns] — 应用列表项状态展示模式
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] — 三级按钮层级规范
- [Source: _bmad-output/planning-artifacts/prd.md#错误处理] — FR-ERROR-002/003 需求定义
- [Source: RCMMShared/Sources/Models/ErrorRecord.swift] — 错误记录模型
- [Source: RCMMShared/Sources/Services/SharedErrorQueue.swift] — 错误队列服务（loadAll, removeAll）
- [Source: RCMMFinderExtension/ScriptExecutor.swift] — Extension 错误捕获（三种场景 + recordError()）
- [Source: RCMMApp/AppState.swift] — 主应用状态管理（@Observable, popoverState, syncScriptsInBackground）
- [Source: RCMMApp/Views/MenuBar/PopoverContainerView.swift] — 弹出窗口视图路由（switch PopoverState + .onAppear）
- [Source: RCMMApp/Views/MenuBar/NormalPopoverView.swift] — 正常状态弹出窗口（HealthStatusPanel + 设置 + 退出）
- [Source: RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift] — UI 模式参考（布局、按钮、动画、无障碍）
- [Source: RCMMApp/Services/ScriptInstallerService.swift] — 脚本同步服务（syncScripts 已有修复能力）
- [Source: _bmad-output/implementation-artifacts/7-1-app-existence-check-and-execution-error-capture.md] — 前序 Story：基础设施完整性验证、图标灰化、路径检测

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

- `swift build --package-path RCMMShared` — 编译成功 (0.11s)
- `xcodebuild -scheme rcmm -destination 'platform=macOS' build` — BUILD SUCCEEDED（零错误）

### Completion Notes List

- ✅ Task 1: 在 AppState.swift 中添加了 `errorRecords`、`autoRepairMessage` 属性，实现了 `loadErrors()` 和 `dismissAllErrors()` 方法，在 PopoverContainerView 的 `.onAppear` 中调用 `loadErrors()`
- ✅ Task 2: 创建 ErrorBannerView.swift，包含错误列表展示（最多 3 条）、基于 message 内容推导的恢复建议、"打开设置"和"忽略全部"按钮、autoRepairMessage 5 秒淡出横幅、完整的 accessibilityLabel
- ✅ Task 3: 在 NormalPopoverView 中条件展示 ErrorBannerView，当 errorRecords 非空或 autoRepairMessage 有值时显示
- ✅ Task 4: 在 loadErrors() 中检测脚本文件错误并自动触发 syncScriptsInBackground() 修复，autoRepairMessage 通过 Task.sleep + 状态变量实现 5 秒淡出
- ✅ Task 5: RCMMShared 编译成功，rcmm 主项目编译成功（零错误）。手动测试项（5.3-5.5）需用户验证。
- 遵循 RecoveryGuidePanel UI 模式：VStack 布局、borderedProminent/bordered 按钮样式、opacity transition 动画、accessibilityElement 容器
- 未修改任何 RCMMShared 模型或 Extension 侧代码

### File List

- RCMMApp/AppState.swift — 修改（添加 errorRecords、autoRepairMessage 属性，loadErrors()、dismissAllErrors() 方法）
- RCMMApp/Views/MenuBar/PopoverContainerView.swift — 修改（onAppear 添加 loadErrors() 调用）
- RCMMApp/Views/MenuBar/NormalPopoverView.swift — 修改（条件展示 ErrorBannerView，添加 import RCMMShared，添加错误状态 Preview）
- RCMMApp/Views/MenuBar/ErrorBannerView.swift — 新增（错误展示与恢复建议组件）

### Change Log

- 2026-02-24: 实现 Story 7.2 — 错误展示与恢复建议。AppState 集成错误队列读取与清除，ErrorBannerView 展示错误详情和恢复建议，脚本文件自动修复触发，编译验证通过。
- 2026-02-24: Code Review 修复（2 HIGH, 4 MEDIUM, 1 LOW）— autoRepairMessage 生命周期管理（fadeout 后清除 + dismissAllErrors 重置）、自动修复防重复触发（hasTriggeredAutoRepair 标志）、autoRepairMessage 改为修复完成后异步设置、SharedErrorQueue 改为存储属性、.onAppear+Task 改为 .task 修饰符、错误行添加警告图标、Preview source 字段修正。
