# Story 4.2: 自定义命令编辑器

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 高级用户,
I want 为应用编辑自定义打开命令，使用 `{app}` 和 `{path}` 占位符,
So that 我可以让特殊终端或自定义工具以正确的方式打开目录。

## Acceptance Criteria

1. **CommandEditor 内联展开** — 用户在菜单配置列表中查看某个应用时，点击展开区域（DisclosureGroup 或等效渐进式披露控件），内联展开 CommandEditor 组件。（FR-COMMAND-003）
2. **等宽字体编辑器** — CommandEditor 使用等宽字体（`.system(.body, design: .monospaced)`），当 customCommand 为空时显示当前生效命令作为 placeholder（内置映射命令或默认 `open -a "{appPath}" {path}`）。（FR-COMMAND-003）
3. **占位符视觉提示** — 编辑器下方显示占位符说明：`{app}` 代替应用路径，`{path}` 代替目标目录路径。（FR-COMMAND-003）
4. **实时预览** — 用户编辑命令时，预览区实时显示替换占位符后的完整命令（`{app}` 替换为实际应用路径，`{path}` 替换为示例路径 `/Users/example/project`）。预览区使用等宽字体，`.foregroundStyle(.secondary)`。（FR-COMMAND-003, FR-COMMAND-004 部分）
5. **标准文本编辑** — 编辑器支持标准 macOS 文本编辑键盘快捷键（复制、粘贴、撤销等）。（FR-COMMAND-003）
6. **保存自定义命令** — 用户编辑完成后（收起编辑区触发保存），`customCommand` 字段更新到 `MenuItemConfig` 并通过 `SharedConfigService` 持久化。（FR-COMMAND-003）
7. **脚本重新生成** — 保存后 `ScriptInstallerService` 使用自定义命令重新生成 `.scpt` 文件，`DarwinNotificationCenter` 发送 `configChanged` 通知 Extension。（FR-COMMAND-003）
8. **{app} 和 {path} 占位符处理** — `ScriptInstallerService.generateAppleScript(for:)` 在处理 customCommand 时，正确替换 `{app}` 为实际应用路径，`{path}` 为 AppleScript 运行时路径变量（`quoted form of thePath`）。支持仅含 `{path}`、仅含 `{app}`、同时包含两者、或都不包含的命令。（FR-COMMAND-003）
9. **重置功能** — 提供"重置为默认"按钮，点击后清空 `customCommand`（设为 nil），回退到内置映射或默认 `open -a` 命令。（FR-COMMAND-003）
10. **无障碍支持** — CommandEditor 具有 `.accessibilityLabel("自定义命令编辑器")` 和 `.accessibilityHint("输入命令模板，支持 {app} 和 {path} 占位符")`。（NFR-ACC-001）

## Tasks / Subtasks

- [x] Task 1: 创建 CommandEditor 组件 (AC: #2, #3, #4, #5, #9, #10)
  - [x] 1.1 在 `RCMMApp/Views/Settings/` 创建 `CommandEditor.swift`
  - [x] 1.2 实现 TextField 使用等宽字体 `.system(.body, design: .monospaced)`，当 customCommand 为空时用 placeholder 显示当前生效命令
  - [x] 1.3 实现预览区，实时替换 `{app}` 为 appPath、`{path}` 为示例路径 `/Users/example/project`
  - [x] 1.4 显示占位符说明文字
  - [x] 1.5 添加"重置为默认"按钮，清空 customCommand
  - [x] 1.6 添加 `.accessibilityLabel("自定义命令编辑器")` 和 `.accessibilityHint`
  - [x] 1.7 使用 `@State var editedCommand: String` 管理编辑中的文本，避免每次按键触发持久化

- [x] Task 2: 修改 MenuConfigTab 集成 CommandEditor (AC: #1, #6, #7)
  - [x] 2.1 添加 `@State private var expandedItems: Set<UUID>` 跟踪每个列表项的展开状态
  - [x] 2.2 在 ForEach 中为每个列表项添加渐进式披露（DisclosureGroup 或等效条件展示），展开时显示 CommandEditor
  - [x] 2.3 确保 `.onMove` 和 `.onDelete` 在添加展开区域后仍正常工作
  - [x] 2.4 DisclosureGroup 收起或 CommandEditor 消失时触发保存

- [x] Task 3: 添加 AppState.updateCustomCommand 方法 (AC: #6, #7)
  - [x] 3.1 添加 `updateCustomCommand(for itemId: UUID, command: String?)` 方法
  - [x] 3.2 查找 `menuItems` 中匹配 `itemId` 的项，更新其 `customCommand` 字段
  - [x] 3.3 调用 `saveAndSync()` 持久化配置并同步脚本和 Darwin Notification

- [x] Task 4: 修改 ScriptInstallerService 支持 customCommand 占位符 (AC: #8)
  - [x] 4.1 在 customCommand 分支中，先将 `{app}` 替换为 `item.appPath`
  - [x] 4.2 检查处理后的命令是否包含 `{path}`：若包含，使用与内置映射相同的 `components(separatedBy: "{path}")` + `quoted form of thePath` 拼接逻辑
  - [x] 4.3 不包含 `{path}` 时，保持当前的静态命令嵌入行为
  - [x] 4.4 添加单元测试：customCommand 包含 `{app}` 和 `{path}` 的占位符替换
  - [x] 4.5 添加单元测试：customCommand 仅包含 `{path}` 的占位符替换
  - [x] 4.6 添加单元测试：customCommand 不包含任何占位符的静态命令

- [x] Task 5: 编译验证与测试 (AC: 全部)
  - [x] 5.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 5.2 `swift test --package-path RCMMShared` 全部测试通过，无回归
  - [ ] 5.3 手动测试：点击展开 → CommandEditor 正确显示
  - [ ] 5.4 手动测试：编辑自定义命令 → 预览区实时更新
  - [ ] 5.5 手动测试：收起编辑区 → 保存成功（右键菜单使用新命令）
  - [ ] 5.6 手动测试：点击"重置为默认" → customCommand 清空，回退到内置映射或默认命令
  - [ ] 5.7 手动测试：为 kitty 等特殊终端自定义命令 → 脚本使用自定义命令（优先级 1）

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 4（自定义命令与特殊终端支持）的第二个 Story，在 Story 4.1（CommandMappingService 内置映射）基础上构建命令编辑 UI。它实现了用户旅程 Journey 2（Custom Command Setup）中的核心交互：DisclosureGroup 展开命令编辑器 → 编辑 → 保存 → 实时生效。

Story 4.3（命令预览与验证）将在本 Story 基础上增强预览逻辑（缺少 `{path}` 警告提示、空命令自动回退显示等验证功能）。

**FRs 覆盖：** FR-COMMAND-003（自定义命令模板编辑）、FR-COMMAND-004（命令预览，部分基础预览）

**跨 Story 依赖：**
- 依赖 Story 4.1：`CommandMappingService.command(for:)` 用于显示内置映射命令作为 placeholder 参考
- 依赖 Story 1.2：`MenuItemConfig.customCommand` 字段已存在且 Codable
- 依赖 Story 2.2/2.4：`MenuConfigTab` 现有菜单配置列表 UI 和 `AppState.saveAndSync()` 流程
- Story 4.3 依赖本 Story：CommandEditor 组件将被增强添加验证逻辑

### 关键技术决策

**1. DisclosureGroup 在 macOS List 中的使用风险与对策**

⚠️ **已知问题：** macOS 上 DisclosureGroup 在 List 中有已知交互 bug：
- 动画相关的交互问题：控件内部点击可能无响应
- macOS 15 (Sequoia) 引入 NSOutlineView 崩溃回归
- 多个 DisclosureGroup 共享 binding 会导致联动展开

**推荐方案 A（首选）：** 在 ForEach 中使用 DisclosureGroup 包裹每个列表项。如果遇到交互问题，使用 `withAnimation(.none)` 禁用动画。每个 DisclosureGroup 使用独立 binding（通过 `expandedBinding(for: id)` 方法生成）。

```swift
ForEach(Array(appState.menuItems.enumerated()), id: \.element.id) { index, item in
    DisclosureGroup(isExpanded: expandedBinding(for: item.id)) {
        CommandEditor(
            editedCommand: item.customCommand ?? "",
            defaultCommand: resolveDefaultCommand(for: item),
            appPath: item.appPath,
            onSave: { command in
                appState.updateCustomCommand(for: item.id, command: command)
            }
        )
    } label: {
        AppListRow(menuItem: item, isDefault: index == 0, ...)
    }
}
.onMove { ... }
.onDelete { ... }
```

**备选方案 B：** 如果 DisclosureGroup 不稳定，改用 `VStack` + `if expandedItems.contains(item.id)` 条件展示 + 手动添加展开/收起按钮。视觉效果等效，且完全规避 DisclosureGroup bug。

**2. CommandEditor 组件设计**

CommandEditor 是 UX Design 中定义的 5 个自定义组件之一（[Source: ux-design-specification.md#Custom Components]）。

**组件接口设计：**

```swift
struct CommandEditor: View {
    /// 编辑中的命令文本（内部 @State）
    @State private var editedCommand: String

    /// 当前生效的默认命令（内置映射或 open -a），作为 placeholder 显示
    let defaultCommand: String

    /// 应用路径，用于预览中替换 {app}
    let appPath: String

    /// 保存回调
    let onSave: (String?) -> Void

    init(editedCommand: String, defaultCommand: String, appPath: String, onSave: @escaping (String?) -> Void) {
        self._editedCommand = State(initialValue: editedCommand)
        self.defaultCommand = defaultCommand
        self.appPath = appPath
        self.onSave = onSave
    }
}
```

**视觉布局：**

```
┌─────────────────────────────────────────┐
│ 自定义命令：                              │
│ ┌─────────────────────────────────────┐ │
│ │ TextField (monospaced)              │ │
│ │ placeholder: open -a "{appPath}" .. │ │
│ └─────────────────────────────────────┘ │
│ 💡 {app} = 应用路径，{path} = 目标目录    │
│                                         │
│ 预览：（仅当编辑内容非空时显示）            │
│ /Applications/kitty.app/.../kitty       │
│   --single-instance --directory         │
│   /Users/example/project                │
│                                         │
│ [重置为默认]                              │
└─────────────────────────────────────────┘
```

- 使用 `TextField`（单行命令足够）+ `.font(.system(.body, design: .monospaced))`
- 当 `editedCommand` 为空时，placeholder 显示 `defaultCommand`
- 预览区仅当 `editedCommand` 非空时显示
- 预览使用 `Text` + `.font(.system(.body, design: .monospaced))` + `.foregroundStyle(.secondary)`
- "重置为默认"按钮仅在 `editedCommand` 非空时显示
- 遵循系统语义颜色，不自定义品牌色

**3. 命令编辑的保存时机**

遵循 UX 原则"配置变更无显式反馈（实时生效即最好的反馈）"（[Source: ux-design-specification.md#Feedback Patterns]）：

- CommandEditor 内部维护 `@State var editedCommand: String`
- 组件初始化时从 `item.customCommand ?? ""` 拷贝
- 用户编辑时仅更新本地 state（不触发持久化和脚本同步）
- 在 `.onDisappear` 时调用 `onSave(editedCommand.isEmpty ? nil : editedCommand)`
- `onSave` 回调通过 `appState.updateCustomCommand(for:command:)` → `saveAndSync()`
- 避免每次按键都触发 osacompile 编译和 Darwin Notification

**4. ScriptInstallerService 占位符处理增强**

当前 customCommand 处理逻辑（Story 4.1 后）不支持 `{app}` 和 `{path}` 占位符替换。需要增强：

```swift
// 增强后的 customCommand 分支：
if let customCommand = item.customCommand, !customCommand.isEmpty {
    // Step 1: 替换 {app} 为实际应用路径（编译时替换）
    var processedCommand = customCommand.replacingOccurrences(of: "{app}", with: item.appPath)

    // Step 2: 处理 {path} 占位符（运行时通过 AppleScript 变量替换）
    if processedCommand.contains("{path}") {
        // 与内置映射相同的 split-and-join 逻辑
        let parts = processedCommand.components(separatedBy: "{path}")
        let prefix = escapeForAppleScript(parts[0])
        let suffix = parts.count > 1 ? escapeForAppleScript(parts[1]) : ""
        if suffix.isEmpty {
            command = "do shell script \"\(prefix)\" & quoted form of thePath"
        } else {
            command = "do shell script \"\(prefix)\" & quoted form of thePath & \"\(suffix)\""
        }
    } else {
        // 无 {path} — 静态命令（直接嵌入，不传递目录路径）
        let escapedCommand = escapeForAppleScript(processedCommand)
        command = "do shell script \"\(escapedCommand)\""
    }
}
```

**关键设计点：**
- `{app}` 在脚本编译时替换为 `item.appPath`（静态字符串）
- `{path}` 在脚本运行时通过 AppleScript 参数 `thePath` 替换（动态目录路径）
- 不包含 `{path}` 的命令仍然有效（某些工具可能不需要目录参数）
- 替换顺序：先 `{app}` 再 `{path}`，避免 appPath 中包含 "{path}" 字面量时的误替换

**5. 展开状态管理**

每个列表项的展开状态独立管理，使用 `Set<UUID>` 跟踪：

```swift
@State private var expandedItems: Set<UUID> = []

private func expandedBinding(for id: UUID) -> Binding<Bool> {
    Binding(
        get: { expandedItems.contains(id) },
        set: { isExpanded in
            if isExpanded {
                expandedItems.insert(id)
            } else {
                expandedItems.remove(id)
            }
        }
    )
}
```

展开状态不持久化 — 关闭窗口后恢复默认收起（[Source: ux-design-specification.md#Progressive Disclosure] "展开状态不持久化"）。

**6. 解析当前生效命令（placeholder 显示）**

CommandEditor 需要知道当前生效的命令作为 placeholder：

```swift
private func resolveDefaultCommand(for item: MenuItemConfig) -> String {
    if let builtIn = CommandMappingService.command(for: item.bundleId) {
        return builtIn  // 内置映射（如 kitty 专用命令）
    }
    return "open -a \"\(item.appPath)\" {path}"  // 默认命令
}
```

这让用户在展开 CommandEditor 时能看到"如果不自定义，系统将使用什么命令"。对于 kitty 用户，placeholder 会显示 `/Applications/kitty.app/Contents/MacOS/kitty --single-instance --directory {path}`，让用户了解内置映射已生效。

### 前序 Story 经验总结

**来自 Story 4.1（命令映射服务）：**
- `CommandMappingService` 是 caseless enum + 静态方法，线程安全，无需实例化
- 内置映射命令使用 `{path}` 占位符（不带引号），AppleScript 生成时通过 `components(separatedBy:)` + `quoted form of thePath` 拼接
- `ScriptInstallerService` 三级命令优先级已建立：customCommand > builtIn > default open -a
- 代码审查发现 `{path}` 引号包裹 bug（生成无效 AppleScript），已修复并添加回归测试
- `escapeForAppleScript()` 方法处理反斜杠和双引号转义
- xcodebuild 编译和 swift test 一次通过

**来自 Story 2.2（设置窗口与菜单项管理）：**
- `MenuConfigTab` 使用 `List` + `ForEach` + `.onMove` + `.onDelete` 模式
- `AppListRow` 组件是纯展示组件（图标 + 名称 + 状态 + 辅助操作）
- `sheet` 模式用于 `AppSelectionSheet`（应用选择弹窗）
- 所有交互元素有 `.accessibilityLabel`

**来自 Story 2.3（拖拽排序）：**
- `.onMove` 通过 `AppState.moveMenuItem(from:to:)` 处理
- `ifLet` View extension 用于条件性添加 VoiceOver 操作
- `position` 和 `total` 参数用于 VoiceOver 位置播报

**Git 提交模式：**
- 格式：`feat: implement [feature description] (Story X.Y)`
- 每个 Story 一个 commit

### Git 近期提交分析

最近 5 个提交：
1. `95fb022` feat: implement command mapping service and builtin terminal support (Story 4.1)
2. `cb2662e` feat: implement verify step and onboarding completion (Story 3.3)
3. `af2b2e5` feat: implement onboarding flow and state management in AppState
4. `1c6c301` feat: implement config realtime sync and dynamic context menu (Story 2.4)
5. `e85d7d8` feat: implement menu item drag sort and default marking (Story 2.3)

Story 4.1 修改了 3 个文件：`ScriptInstallerService.swift`（+21 -6 行）、新建 `CommandMappingService.swift`（+19 行）、新建 `CommandMappingServiceTests.swift`（+64 行）。当前项目共 32 个单元测试全部通过。

### 最新技术信息

**SwiftUI DisclosureGroup (macOS 15+)：**
- 在 macOS List 中有已知交互 bug（动画引起控件失效、macOS 15 NSOutlineView 崩溃回归）
- Workaround：使用 `withAnimation(.none)` 禁用动画，或改用简单条件展示
- 在 ForEach 中使用时，每个 DisclosureGroup 必须有独立的 `isExpanded` binding，不可共享
- 备选方案：使用 `VStack` + `if` 条件 + 手动展开按钮，规避 DisclosureGroup bug
- [参考: developer.apple.com/documentation/swiftui/disclosuregroup]

**SwiftUI TextField/TextEditor 等宽字体 (macOS)：**
- 最简方案：`.font(.system(.body, design: .monospaced))` 使用 SF Mono 字体
- 或 `.font(.body.monospaced())` 修饰符
- 命令编辑器应禁用自动引号替换：考虑使用 `.disableAutocorrection(true)`
- 对于单行命令输入，`TextField` 比 `TextEditor` 更轻量且交互更好
- [参考: developer.apple.com/documentation/swiftui/font/monospaced()]

### 反模式清单（禁止）

- ❌ 在 RCMMShared 中创建 CommandEditor（UI 组件属于 RCMMApp，RCMMShared 禁止依赖 SwiftUI）
- ❌ 使用 ObservableObject/@Published（统一用 @Observable）
- ❌ 使用 try! 或 force unwrap
- ❌ 在 CommandEditor 中直接调用 ScriptInstallerService（通过 AppState.saveAndSync 间接触发）
- ❌ 使用自定义颜色或自定义字体（使用系统语义颜色和系统字体）
- ❌ 在每次按键时触发 saveAndSync（使用 onDisappear 延迟保存，避免频繁 osacompile）
- ❌ 修改 CommandMappingService（Story 4.1 已完成，无需变更）
- ❌ 修改 MenuItemConfig 模型结构（customCommand 字段已存在）
- ❌ 修改 FinderSync.swift 或 ScriptExecutor.swift（Extension 端不需要变更）
- ❌ 硬编码 App Group 键名或 Darwin Notification 名称（使用 SharedKeys/NotificationNames 常量）
- ❌ 使用 `try!` 或 `fatalError()`
- ❌ 在 Darwin Notification 回调中直接更新 UI（必须调度到主线程）

### 范围边界说明

**本 Story 范围内：**
- 创建 `CommandEditor` 组件（RCMMApp/Views/Settings/CommandEditor.swift）
- 修改 `MenuConfigTab` 集成渐进式披露 + CommandEditor
- 添加 `AppState.updateCustomCommand(for:command:)` 方法
- 修改 `ScriptInstallerService.generateAppleScript(for:)` 支持 customCommand 中 `{app}` 和 `{path}` 占位符替换
- 基础命令预览（替换占位符显示完整命令）
- 相关单元测试（ScriptInstallerService 占位符替换）

**本 Story 范围外（明确排除）：**
- 缺少 `{path}` 占位符的验证警告信息（Story 4.3）
- 空命令自动回退到默认命令的预览显示逻辑（Story 4.3）
- 命令语法验证和错误提示（Story 4.3）
- `AppListRow` 组件本身的修改（通过 DisclosureGroup 在 MenuConfigTab 层包裹，AppListRow 作为 label）
- 菜单栏弹出窗口改动（Epic 5）
- 扩展状态检测改动（Epic 6）
- 错误处理改动（Epic 7）

### Project Structure Notes

**本 Story 新建文件：**

```
rcmm/
├── RCMMApp/
│   └── Views/
│       └── Settings/
│           └── CommandEditor.swift          # [新建] 自定义命令编辑器组件
```

**本 Story 修改文件：**

```
RCMMApp/Views/Settings/MenuConfigTab.swift    # [修改] 集成 DisclosureGroup/展开区域 + CommandEditor
RCMMApp/AppState.swift                        # [修改] 添加 updateCustomCommand(for:command:) 方法
RCMMApp/Services/ScriptInstallerService.swift  # [修改] customCommand 分支增加 {app}/{path} 占位符处理
```

**需要添加测试的文件：**

```
RCMMShared/Tests/RCMMSharedTests/             # 在现有测试文件中添加 customCommand 占位符替换测试
```

注意：占位符替换逻辑在 `ScriptInstallerService` 中（RCMMApp target），如果无法直接为 App target 编写单元测试，可以考虑将占位符替换逻辑提取为纯函数在 RCMMShared 中实现，或在 ScriptInstallerService 中添加 internal 可测试方法。

**不变的文件（已验证无需修改）：**

```
RCMMShared/Sources/Models/MenuItemConfig.swift          # 不变 — customCommand: String? 字段已存在
RCMMShared/Sources/Services/CommandMappingService.swift  # 不变 — 内置映射服务无需变更
RCMMShared/Sources/Services/SharedConfigService.swift    # 不变 — 配置读写不受影响
RCMMShared/Sources/Services/DarwinNotificationCenter.swift # 不变 — 通知发送不受影响
RCMMApp/Views/Settings/AppListRow.swift                 # 不变 — DisclosureGroup 在 MenuConfigTab 层包裹
RCMMApp/Views/Settings/AppSelectionSheet.swift          # 不变
RCMMFinderExtension/FinderSync.swift                     # 不变 — Extension 端对脚本内容无感知
RCMMFinderExtension/ScriptExecutor.swift                 # 不变 — 脚本执行器对脚本内容无感知
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.2] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 4] — Epic 4 整体目标：自定义命令与特殊终端支持
- [Source: _bmad-output/planning-artifacts/architecture.md#Script & Command Execution] — 脚本管理架构决策和命令优先级
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries] — CommandEditor 在 RCMMApp/Views/Settings/ 中的位置
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns] — 命名规范、结构模式、反模式清单
- [Source: _bmad-output/planning-artifacts/architecture.md#UI Architecture] — 渐进式披露通过 DisclosureGroup 实现
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#CommandEditor] — CommandEditor 组件规格（等宽字体、占位符、预览、无障碍）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Progressive Disclosure] — 渐进式披露规则（默认收起、展开状态不持久化）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 2: Custom Command Setup] — 自定义命令用户旅程
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Feedback Patterns] — "配置变更无显式反馈"设计原则
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] — 三级按钮层级规范
- [Source: _bmad-output/implementation-artifacts/4-1-command-mapping-service-and-builtin-terminal-support.md] — Story 4.1 完成记录和经验总结
- [Source: RCMMApp/Services/ScriptInstallerService.swift:55-86] — 当前 generateAppleScript 三级优先级逻辑
- [Source: RCMMApp/Views/Settings/MenuConfigTab.swift] — 当前菜单配置列表实现（List + ForEach + .onMove + .onDelete）
- [Source: RCMMApp/Views/Settings/AppListRow.swift] — 当前应用列表行组件（图标 + 名称 + 状态 + VoiceOver）
- [Source: RCMMApp/AppState.swift] — 当前 AppState 方法（addMenuItem, moveMenuItem, removeMenuItem, saveAndSync）
- [Source: RCMMShared/Sources/Models/MenuItemConfig.swift] — customCommand: String? 字段（Codable, var）
- [Source: RCMMShared/Sources/Services/CommandMappingService.swift] — CommandMappingService.command(for:) 静态方法

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

无调试问题。

### Completion Notes List

- ✅ Task 1: 创建 CommandEditor.swift — 实现等宽字体 TextField、实时预览（替换 {app}/{path}）、占位符说明、重置按钮、onDisappear 延迟保存、完整无障碍支持
- ✅ Task 2: MenuConfigTab 集成 DisclosureGroup — 每个列表项独立 expandedBinding，展开时内联显示 CommandEditor，.onMove/.onDelete 保持正常，收起时 onDisappear 触发保存
- ✅ Task 3: AppState.updateCustomCommand — 查找匹配 itemId 更新 customCommand 字段，调用 saveAndSync() 持久化+同步脚本+Darwin Notification
- ✅ Task 4: 将占位符替换逻辑提取为 CommandTemplateProcessor（RCMMShared），ScriptInstallerService 调用该处理器。支持 {app}+{path}、仅 {path}、无占位符三种模式。新增 9 个单元测试全部通过
- ✅ Task 5: xcodebuild 编译成功（零错误），swift test 41 个测试全部通过（含新增 9 个），无回归。手动测试项需用户验证

### Implementation Plan

- 使用方案 A（DisclosureGroup + expandedBinding），每个列表项独立 binding
- 将占位符替换逻辑提取为 RCMMShared 中的 CommandTemplateProcessor（caseless enum + 静态方法），使其可通过 swift test 测试
- ScriptInstallerService 的 customCommand 分支调用 CommandTemplateProcessor.buildAppleScriptCommand()
- CommandEditor 通过 onDisappear 触发 onSave 回调，避免每次按键触发 osacompile

### File List

- [新建] RCMMApp/Views/Settings/CommandEditor.swift — 自定义命令编辑器组件
- [新建] RCMMShared/Sources/Services/CommandTemplateProcessor.swift — 命令模板占位符处理器（纯函数）
- [新建] RCMMShared/Tests/RCMMSharedTests/CommandTemplateProcessorTests.swift — 占位符处理器单元测试（9 个测试）
- [修改] RCMMApp/Views/Settings/MenuConfigTab.swift — 集成 DisclosureGroup + CommandEditor + expandedBinding + resolveDefaultCommand
- [修改] RCMMApp/AppState.swift — 添加 updateCustomCommand(for:command:) 方法
- [修改] RCMMApp/Services/ScriptInstallerService.swift — customCommand 分支使用 CommandTemplateProcessor 处理占位符

## Change Log

- 2026-02-22: 实现自定义命令编辑器（Story 4.2）— CommandEditor 组件、DisclosureGroup 集成、占位符替换逻辑提取、9 个新增单元测试
- 2026-02-22: Code Review 修复 — 消除无变更时冗余 save/osacompile（M1+M2）、移除重复 escapeForAppleScript 改用 CommandTemplateProcessor（M3）、替换已弃用 disableAutocorrection API（L1）、新增 appPath 特殊字符边界测试（L2）
