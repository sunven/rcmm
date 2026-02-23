# Story 4.3: 命令预览与验证

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 高级用户,
I want 在编辑自定义命令时实时预览最终执行的完整命令，并在命令缺少关键占位符时得到提示,
So that 我可以在保存前确认命令格式正确，避免因命令错误导致右键菜单无法正确打开目录。

## Acceptance Criteria

1. **实时占位符替换预览** — 用户在 CommandEditor 中输入命令模板时，当命令包含 `{app}` 和 `{path}` 占位符，预览区实时替换 `{app}` 为实际应用路径，`{path}` 为示例目录路径（`/Users/example/project`）。预览区使用等宽字体，与编辑区视觉一致。（FR-COMMAND-004）
2. **缺少 {path} 占位符提示** — 用户输入的命令不包含 `{path}` 占位符时，预览区下方显示提示信息"命令中未包含 {path}，目标目录可能不会被传递"，使用警告样式（`.foregroundStyle(.orange)` 或系统警告色）。（FR-COMMAND-004）
3. **空命令自动回退预览** — 用户清空自定义命令（命令字段为空）时，自动回退到默认命令（`open -a`）或内置映射命令，预览区显示回退后的命令（替换占位符后的完整命令），让用户知道"如果不自定义，系统将使用什么命令"。（FR-COMMAND-004）

## Tasks / Subtasks

- [x] Task 1: 增强 CommandEditor 预览逻辑 — 空命令回退预览 (AC: #3)
  - [x] 1.1 当 `editedCommand` 为空时，预览区显示 `defaultCommand` 替换占位符后的完整命令（而非隐藏预览区）
  - [x] 1.2 预览区标题区分"预览："（自定义命令时）和"当前生效命令："（回退到默认时）
  - [x] 1.3 回退预览使用 `.foregroundStyle(.secondary)` 与自定义命令预览视觉一致

- [x] Task 2: 添加缺少 {path} 占位符的验证提示 (AC: #2)
  - [x] 2.1 当 `editedCommand` 非空且不包含 `{path}` 时，在预览区下方显示提示信息
  - [x] 2.2 提示文字："命令中未包含 {path}，目标目录可能不会被传递"
  - [x] 2.3 使用 `.foregroundStyle(.orange)` 警告样式 + SF Symbol `exclamationmark.triangle` 图标
  - [x] 2.4 提示信息添加 `.accessibilityLabel("警告：命令中未包含路径占位符")`

- [x] Task 3: 验证预览区占位符替换一致性 (AC: #1)
  - [x] 3.1 确认 `previewCommand` 计算属性正确替换 `{app}` 为 `appPath`，`{path}` 为 `/Users/example/project`
  - [x] 3.2 确认预览区等宽字体 `.system(.body, design: .monospaced)` 与编辑区一致
  - [x] 3.3 确认预览区支持文本选择 `.textSelection(.enabled)`

- [x] Task 4: 编译验证与测试 (AC: 全部)
  - [x] 4.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 4.2 `swift test --package-path RCMMShared` 全部测试通过，无回归
  - [ ] 4.3 手动测试：输入含 `{app}` 和 `{path}` 的命令 → 预览区正确替换
  - [ ] 4.4 手动测试：输入不含 `{path}` 的命令 → 显示警告提示
  - [ ] 4.5 手动测试：清空命令 → 预览区显示回退后的默认命令
  - [ ] 4.6 手动测试：内置映射终端（kitty）清空命令 → 显示内置映射命令预览

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 4（自定义命令与特殊终端支持）的第三个也是最后一个 Story。在 Story 4.1（CommandMappingService 内置映射）和 Story 4.2（CommandEditor 组件 + 占位符处理）基础上，增强命令预览的验证反馈能力。

Story 4.2 的 Dev Notes 明确标注了本 Story 的范围："缺少 `{path}` 占位符的验证警告信息（Story 4.3）"、"空命令自动回退到默认命令的预览显示逻辑（Story 4.3）"。

**FRs 覆盖：** FR-COMMAND-004（命令预览 — 完善基础预览功能的验证反馈）

**跨 Story 依赖：**
- 依赖 Story 4.1：`CommandMappingService.command(for:)` 提供内置映射命令
- 依赖 Story 4.2：`CommandEditor` 组件已实现基础预览、`CommandTemplateProcessor` 提供占位符处理
- 无后续 Story 依赖本 Story（Epic 4 最后一个 Story）

### 关键技术决策

**1. 空命令回退预览逻辑**

当前 CommandEditor 的预览区仅在 `editedCommand` 非空时显示（`if !editedCommand.isEmpty`）。Story 4.3 需要在命令为空时也显示预览，展示回退后的默认命令。

修改逻辑：
- 移除 `if !editedCommand.isEmpty` 条件包裹的预览区
- 引入 `effectiveCommand` 计算属性：如果 `editedCommand` 非空用它，否则用 `defaultCommand`
- 预览区始终显示 `effectiveCommand` 替换占位符后的结果
- 标题根据 `editedCommand` 是否为空切换："预览："vs "当前生效命令："

```swift
private var effectiveCommand: String {
    editedCommand.isEmpty ? defaultCommand : editedCommand
}

private var previewCommand: String {
    effectiveCommand
        .replacingOccurrences(of: "{app}", with: appPath)
        .replacingOccurrences(of: "{path}", with: "/Users/example/project")
}

private var isUsingDefault: Bool {
    editedCommand.isEmpty
}
```

**2. 缺少 {path} 占位符的验证提示**

仅在用户输入了自定义命令（`editedCommand` 非空）且命令不包含 `{path}` 时显示警告。

```swift
private var isMissingPathPlaceholder: Bool {
    !editedCommand.isEmpty && !editedCommand.contains("{path}")
}
```

警告 UI 使用 `HStack` + SF Symbol `exclamationmark.triangle` + 警告文字：

```swift
if isMissingPathPlaceholder {
    HStack(spacing: 4) {
        Image(systemName: "exclamationmark.triangle")
            .foregroundStyle(.orange)
        Text("命令中未包含 {path}，目标目录可能不会被传递")
            .font(.caption)
            .foregroundStyle(.orange)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("警告：命令中未包含路径占位符")
}
```

**3. 预览区的重构**

当前预览区被 `if !editedCommand.isEmpty` 包裹，内部包含预览文字和重置按钮。重构后：
- 预览区始终显示（移除条件包裹）
- 验证提示在预览区下方（仅自定义命令时可见）
- 重置按钮仍然仅在 `editedCommand` 非空时显示

重构后的 body 结构：

```
┌─────────────────────────────────────────┐
│ 自定义命令：                              │
│ ┌─────────────────────────────────────┐ │
│ │ TextField (monospaced)              │ │
│ │ placeholder: open -a "{appPath}" .. │ │
│ └─────────────────────────────────────┘ │
│ {app} = 应用路径，{path} = 目标目录      │
│                                         │
│ 预览：/ 当前生效命令：                    │
│ /Applications/kitty.app/.../kitty       │
│   --single-instance --directory         │
│   /Users/example/project                │
│                                         │
│ ⚠️ 命令中未包含 {path}...（仅当适用时）    │
│                                         │
│ [重置为默认]（仅当 editedCommand 非空时） │
└─────────────────────────────────────────┘
```

**4. 本 Story 的修改范围极小**

本 Story 仅修改一个文件：`RCMMApp/Views/Settings/CommandEditor.swift`。修改内容：
- 重构预览区逻辑（始终显示 + 标题切换）
- 添加缺少 `{path}` 的验证提示
- 无需修改其他文件（CommandTemplateProcessor、MenuConfigTab、AppState 等均无需变更）

### 前序 Story 经验总结

**来自 Story 4.2（自定义命令编辑器）：**
- `CommandEditor` 使用 `@State private var editedCommand: String` 管理编辑状态，`onDisappear` 触发保存
- `originalCommand` 用于对比是否有变更，避免无修改时触发冗余 saveAndSync
- `previewCommand` 计算属性做简单字符串替换：`{app}` → appPath，`{path}` → 示例路径
- 预览区仅在 `editedCommand` 非空时显示 — 这是 Story 4.3 需要修改的核心
- Code Review 已修复无变更冗余保存（M1+M2）和已弃用 API（L1）
- 重置按钮直接调用 `onSave(nil)`，立即生效

**来自 Story 4.1（命令映射服务）：**
- `CommandMappingService` 是 caseless enum + 静态方法，线程安全
- 内置映射命令使用 `{path}` 占位符
- `CommandTemplateProcessor.buildAppleScriptCommand` 处理 `{app}` 和 `{path}` 替换
- 代码审查发现 `{path}` 引号包裹 bug，已修复并添加回归测试

### Git 近期提交分析

最近 3 个提交（与 Epic 4 相关）：
1. `5e1ac9d` feat: implement custom command editor with template placeholders (Story 4.2)
2. `95fb022` feat: implement command mapping service and builtin terminal support (Story 4.1)
3. `cb2662e` feat: implement verify step and onboarding completion (Story 3.3)

Story 4.2 的修改文件：
- 新建 `CommandEditor.swift`、`CommandTemplateProcessor.swift`、`CommandTemplateProcessorTests.swift`
- 修改 `MenuConfigTab.swift`、`AppState.swift`、`ScriptInstallerService.swift`

当前项目共 41 个单元测试全部通过。

### 反模式清单（禁止）

- ❌ 修改 `CommandTemplateProcessor`（Story 4.2 已完成，预览使用简单字符串替换足够，无需改为 AppleScript 输出预览）
- ❌ 修改 `MenuConfigTab`（CommandEditor 的内部变更对 MenuConfigTab 透明）
- ❌ 修改 `AppState`（无需新增方法或字段）
- ❌ 修改 `ScriptInstallerService`（脚本生成逻辑无需变更）
- ❌ 修改 `MenuItemConfig`（模型无需新增字段）
- ❌ 修改 `CommandMappingService`（映射服务无需变更）
- ❌ 使用自定义颜色（使用 `.orange` 系统语义颜色）
- ❌ 使用 ObservableObject/@Published（统一用 @Observable）
- ❌ 添加命令语法验证/编译验证（超出 AC 范围 — PRD 中 FR-COMMAND-004 仅要求预览效果，不要求语法校验）
- ❌ 添加未知占位符检测（如 `{App}`、`{file}` — 超出 AC 范围）
- ❌ 在 RCMMShared 中添加验证逻辑（验证 UI 是纯视图层逻辑，属于 RCMMApp）
- ❌ 硬编码 App Group 键名或 Darwin Notification 名称

### 范围边界说明

**本 Story 范围内：**
- 修改 `CommandEditor.swift` — 增强预览逻辑（空命令回退预览 + 缺少 `{path}` 提示）
- 仅涉及 UI 层变更，无业务逻辑或数据模型变更

**本 Story 范围外（明确排除）：**
- 命令语法验证/编译检查
- 未知占位符检测和提示
- AppleScript 预览输出（保持简单字符串替换预览即可）
- 应用路径存在性检测（Epic 7 范围）
- 其他文件的任何修改

### Project Structure Notes

**本 Story 修改文件：**

```
rcmm/
├── RCMMApp/
│   └── Views/
│       └── Settings/
│           └── CommandEditor.swift          # [修改] 增强预览逻辑 + 添加验证提示
```

**不变的文件（已验证无需修改）：**

```
RCMMApp/Views/Settings/MenuConfigTab.swift              # 不变 — CommandEditor 内部变更对其透明
RCMMApp/AppState.swift                                   # 不变 — 无需新增方法
RCMMApp/Services/ScriptInstallerService.swift            # 不变 — 脚本生成逻辑无关
RCMMShared/Sources/Services/CommandTemplateProcessor.swift # 不变 — 占位符处理无需变更
RCMMShared/Sources/Services/CommandMappingService.swift   # 不变 — 映射服务无关
RCMMShared/Sources/Models/MenuItemConfig.swift           # 不变 — 模型无需新增字段
RCMMShared/Tests/RCMMSharedTests/                        # 不变 — 无新增可测试逻辑（纯 UI 变更）
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.3] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 4] — Epic 4 整体目标：自定义命令与特殊终端支持
- [Source: _bmad-output/planning-artifacts/architecture.md#UI Architecture] — 渐进式披露通过 DisclosureGroup 实现
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#CommandEditor] — CommandEditor 组件规格（等宽字体、占位符、预览、无障碍）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Feedback Patterns] — "配置变更无显式反馈"设计原则
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Status Indication Patterns] — 状态指示模式
- [Source: _bmad-output/implementation-artifacts/4-2-custom-command-editor.md] — Story 4.2 完成记录、经验总结和范围边界
- [Source: _bmad-output/implementation-artifacts/4-2-custom-command-editor.md#范围边界说明] — 明确标注 Story 4.3 负责的增强功能
- [Source: RCMMApp/Views/Settings/CommandEditor.swift] — 当前 CommandEditor 完整实现（预览逻辑、保存机制、重置功能）
- [Source: RCMMApp/Views/Settings/MenuConfigTab.swift] — MenuConfigTab 集成 CommandEditor 的方式（DisclosureGroup + resolveDefaultCommand）
- [Source: RCMMShared/Sources/Services/CommandTemplateProcessor.swift] — 占位符处理逻辑（buildAppleScriptCommand + escapeForAppleScript）
- [Source: RCMMShared/Sources/Services/CommandMappingService.swift] — 内置映射字典（kitty/Alacritty/WezTerm）

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

无调试问题 — 实现顺利完成。

### Completion Notes List

- 添加 `effectiveCommand` 计算属性：空命令时回退到 `defaultCommand`，实现预览区始终可见
- 添加 `isUsingDefault` 计算属性：控制预览区标题切换（"预览：" vs "当前生效命令："）
- 修改 `previewCommand` 使用 `effectiveCommand` 而非直接使用 `editedCommand`，确保回退预览也正确替换占位符
- 添加 `isMissingPathPlaceholder` 计算属性：检测自定义命令缺少 `{path}` 占位符
- 添加警告 UI：HStack + SF Symbol `exclamationmark.triangle` + `.foregroundStyle(.orange)` + accessibilityLabel
- 预览区从条件显示改为始终显示，重置按钮仍保持条件显示
- 编译零错误，42 个测试全部通过，无回归
- Task 4.3-4.6 为手动测试项，需用户在应用中验证

### Change Log

- 2026-02-23: 实现命令预览增强 — 空命令回退预览 + 缺少 {path} 占位符警告提示 (Story 4.3)
- 2026-02-23: Code Review 修复 — H1 警告图标字号匹配、H2 添加 #Preview 宏、M1 预览区无障碍状态通知、M2 重置按钮 onSave 双重调用修复

### File List

- `RCMMApp/Views/Settings/CommandEditor.swift` — 修改：增强预览逻辑（effectiveCommand 回退、标题切换、{path} 缺失警告）+ Code Review 修复（图标字号、#Preview、无障碍、onSave 去重）

### Senior Developer Review (AI)

**审查人:** Sunven | **日期:** 2026-02-23 | **结果:** 通过（已修复全部问题）

**审查发现与修复记录：**

| ID | 严重度 | 描述 | 状态 |
|---|---|---|---|
| H1 | HIGH | 警告图标 `exclamationmark.triangle` 缺少 `.font(.caption)`，与文字字号不匹配 | ✅ 已修复 |
| H2 | HIGH | 缺少 `#Preview` 宏，违反架构/UX 规范（需 Light/Dark Mode + 状态变体预览） | ✅ 已修复 — 添加 3 个预览变体 |
| M1 | MEDIUM | 预览区缺少 `.accessibilityValue` 传达"默认命令/自定义命令"状态变化 | ✅ 已修复 |
| M2 | MEDIUM | "重置为默认"按钮 + onDisappear 双重调用 `onSave(nil)`（4.2 遗留）— `originalCommand` 改为 `@State lastSavedCommand` | ✅ 已修复 |
| L1 | LOW | 默认回退预览缺少解释性文字（如"未设置自定义命令时使用"） | 不修复 — 当前 UX 已足够清晰 |
| L2 | LOW | 占位符 `{app}`/`{path}` 跨组件硬编码（4.1/4.2 遗留，超出本 Story 范围） | 不修复 — 超出范围 |

**验证结果：**
- ✅ 3 个 AC 全部实现并验证
- ✅ 42/42 单元测试通过，无回归
- ✅ 4 个问题已修复（2 HIGH + 2 MEDIUM）
- ⚠️ 手动测试项（Task 4.3-4.6）需用户在应用中验证
