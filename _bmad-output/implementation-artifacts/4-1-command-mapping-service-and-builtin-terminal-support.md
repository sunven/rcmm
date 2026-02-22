# Story 4.1: 命令映射服务与内置特殊终端支持

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户,
I want 系统自动为大多数应用使用正确的打开命令，特殊终端（kitty/Alacritty/WezTerm）自动使用专用参数,
So that 我添加应用后无需手动配置命令就能正确打开目录。

## Acceptance Criteria

1. **默认命令模板** — 用户添加一个普通应用（如 VS Code）到菜单时，`ScriptInstallerService` 生成的 `.scpt` 脚本使用默认命令模板 `do shell script "open -a \"{appPath}\" \"{path}\""` 生成脚本。（FR-COMMAND-001）
2. **kitty 内置命令映射** — 用户添加 kitty 到菜单时，`CommandMappingService` 通过 bundleId (`net.kovidgoyal.kitty`) 查找命令映射，返回专用命令 `/Applications/kitty.app/Contents/MacOS/kitty --single-instance --directory "{path}"`，生成的 `.scpt` 使用专用命令而非默认 `open -a`。（FR-COMMAND-002）
3. **Alacritty 内置命令映射** — 用户添加 Alacritty 时，`CommandMappingService` 通过 bundleId (`org.alacritty`) 返回专用命令 `/Applications/Alacritty.app/Contents/MacOS/alacritty --working-directory "{path}"`。（FR-COMMAND-002）
4. **WezTerm 内置命令映射** — 用户添加 WezTerm 时，`CommandMappingService` 通过 bundleId (`com.github.wez.wezterm`) 返回专用命令 `/Applications/WezTerm.app/Contents/MacOS/wezterm start --cwd "{path}"`。（FR-COMMAND-002）
5. **内置映射字典初始化** — `CommandMappingService` 初始化时包含 kitty、Alacritty、WezTerm 的正确打开命令，映射字典以 bundleId 为键，可扩展。（FR-COMMAND-002）
6. **命令优先级** — 脚本生成时的命令优先级为：`customCommand`（用户自定义）> 内置映射（CommandMappingService）> 默认 `open -a`。即用户自定义命令始终优先于内置映射。
7. **单元测试验证** — 单元测试验证所有内置映射的命令格式正确，包括 bundleId 查找、命令模板格式、占位符替换逻辑。

## Tasks / Subtasks

- [x] Task 1: 创建 CommandMappingService (AC: #2, #3, #4, #5)
  - [x] 1.1 在 `RCMMShared/Sources/Services/` 创建 `CommandMappingService.swift`
  - [x] 1.2 实现内置命令映射字典（bundleId → 命令模板），包含 kitty、Alacritty、WezTerm
  - [x] 1.3 实现 `command(for bundleId: String?) -> String?` 查找方法
  - [x] 1.4 命令模板使用 `{path}` 占位符，与 ScriptInstallerService 集成

- [x] Task 2: 修改 ScriptInstallerService 集成 CommandMappingService (AC: #1, #6)
  - [x] 2.1 修改 `generateAppleScript(for:)` 方法，在 customCommand 和默认 open -a 之间插入 CommandMappingService 查找逻辑
  - [x] 2.2 命令优先级：customCommand > 内置映射 > 默认 open -a
  - [x] 2.3 移除现有 TODO 注释（Epic 4 相关）
  - [x] 2.4 内置映射命令中的 `{path}` 占位符在脚本生成时正确替换为 AppleScript 变量

- [x] Task 3: 编写单元测试 (AC: #7)
  - [x] 3.1 创建 `RCMMShared/Tests/RCMMSharedTests/CommandMappingServiceTests.swift`
  - [x] 3.2 测试 kitty bundleId 返回正确命令
  - [x] 3.3 测试 Alacritty bundleId 返回正确命令
  - [x] 3.4 测试 WezTerm bundleId 返回正确命令
  - [x] 3.5 测试未知 bundleId 返回 nil
  - [x] 3.6 测试 nil bundleId 返回 nil

- [x] Task 4: 编译验证与测试 (AC: 全部)
  - [x] 4.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 4.2 `swift test --package-path RCMMShared` 全部测试通过，无回归
  - [ ] 4.3 手动测试：添加普通应用 → 生成的脚本使用 open -a 默认命令
  - [ ] 4.4 手动测试：添加 kitty → 生成的脚本使用 kitty 专用命令
  - [ ] 4.5 手动测试：设置 customCommand 的应用 → 生成的脚本使用自定义命令（优先级最高）

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 4（自定义命令与特殊终端支持）的第一个 Story，为 Epic 4 奠定命令映射基础。它在 Epic 1-3 建立的完整链路（右键 → 菜单 → 脚本执行 → 应用打开）基础上，增强脚本生成逻辑，使特殊终端能正确接收目录参数。Story 4.2（自定义命令编辑器 UI）和 Story 4.3（命令预览与验证）依赖本 Story 提供的 CommandMappingService。

**FRs 覆盖：** FR-COMMAND-001（默认 open -a 命令）、FR-COMMAND-002（内置特殊终端命令映射）

**跨 Story 依赖：**
- 依赖 Story 1.2：`MenuItemConfig` 模型（`bundleId` 和 `customCommand` 字段）
- 依赖 Story 1.3 / 2.4：`ScriptInstallerService`（脚本生成与安装）
- Story 4.2 依赖本 Story：`CommandMappingService` 将用于 UI 显示内置映射命令
- Story 4.3 依赖本 Story：命令预览需要 CommandMappingService 解析命令

### 关键技术决策

**1. CommandMappingService 放置在 RCMMShared 中**

按架构文档要求，`CommandMappingService` 放在 `RCMMShared/Sources/Services/`。原因：
- 命令映射是纯数据+逻辑，不依赖 SwiftUI/AppKit/FinderSync
- 未来 Extension 可能需要读取映射信息（如显示命令类型）
- 与 `AppCategorizer`（已包含终端 bundleId 列表）同层

```swift
public struct CommandMappingService {
    /// 内置命令映射字典：bundleId → 命令模板
    /// 命令模板中使用 {path} 占位符表示目标目录
    private static let builtInMappings: [String: String] = [
        "net.kovidgoyal.kitty": "/Applications/kitty.app/Contents/MacOS/kitty --single-instance --directory \"{path}\"",
        "org.alacritty": "/Applications/Alacritty.app/Contents/MacOS/alacritty --working-directory \"{path}\"",
        "com.github.wez.wezterm": "/Applications/WezTerm.app/Contents/MacOS/wezterm start --cwd \"{path}\""
    ]

    /// 查找 bundleId 对应的内置命令模板
    /// - Returns: 命令模板字符串（含 {path} 占位符），无匹配则返回 nil
    public static func command(for bundleId: String?) -> String? {
        guard let bundleId else { return nil }
        return builtInMappings[bundleId]
    }
}
```

使用 `struct` + 静态方法，因为：
- 内置映射是编译时常量，无需实例化
- 无状态，线程安全
- 简单直接，符合项目风格

**2. ScriptInstallerService 命令优先级逻辑**

修改 `generateAppleScript(for:)` 中的命令决策逻辑：

```swift
private func generateAppleScript(for item: MenuItemConfig) -> String {
    let command: String

    if let customCommand = item.customCommand, !customCommand.isEmpty {
        // 优先级 1: 用户自定义命令
        command = customCommand.replacingOccurrences(of: "{path}", with: "\" & quoted form of thePath & \"")
    } else if let builtInCommand = CommandMappingService.command(for: item.bundleId) {
        // 优先级 2: 内置命令映射（特殊终端）
        command = builtInCommand.replacingOccurrences(of: "{path}", with: "\" & quoted form of thePath & \"")
    } else {
        // 优先级 3: 默认 open -a
        command = "open -a \"\(item.appPath)\" \" & quoted form of thePath & \""
    }

    return """
    on openApp(thePath)
        do shell script "\(command)"
    end openApp
    """
}
```

注意：`{path}` 占位符需要在 AppleScript 中被替换为 `" & quoted form of thePath & "`，以确保目录路径中的空格和特殊字符被正确处理。

**3. 特殊终端命令使用二进制路径而非 open -a**

三个特殊终端（kitty、Alacritty、WezTerm）在 macOS 上通过 `open -a` 打开时无法正确传递目录参数。必须直接调用应用内的二进制文件：

| 终端 | bundleId | 正确命令 | 为什么不能用 open -a |
|---|---|---|---|
| kitty | `net.kovidgoyal.kitty` | `/Applications/kitty.app/Contents/MacOS/kitty --single-instance --directory "{path}"` | open -a 不支持 --directory 参数传递 |
| Alacritty | `org.alacritty` | `/Applications/Alacritty.app/Contents/MacOS/alacritty --working-directory "{path}"` | open -a 不支持 --working-directory 参数传递 |
| WezTerm | `com.github.wez.wezterm` | `/Applications/WezTerm.app/Contents/MacOS/wezterm start --cwd "{path}"` | open -a 会打开应用但忽略目录参数，且可能立即关闭 |

**4. AppleScript 中路径引用安全**

当前 `ScriptInstallerService` 使用 `quoted form of thePath` 处理路径（AppleScript 内置函数，自动添加单引号转义）。内置映射命令中的 `{path}` 需要同样使用 `quoted form of thePath` 替换，确保路径中的空格、括号等特殊字符不会导致命令失败。

**5. 不硬编码应用路径到映射字典**

内置映射使用 `/Applications/` 前缀的路径。这是 macOS 的标准安装位置。如果用户将应用安装在非标准位置（如 `~/Applications/`），应通过 `customCommand` 覆盖。这个设计权衡是有意为之：
- 覆盖 95% 的标准安装场景
- 非标准安装用户属于高级用户，有能力使用 Story 4.2 的自定义命令
- 避免在 CommandMappingService 中引入文件系统依赖

### 前序 Story 经验总结

**来自 Story 3.3（验证步骤与引导完成）：**
- 使用闭包模式传递事件（`onComplete`）
- SMAppService 注册/取消的 try/catch 模式
- 代码审查修复模式：补全分支、移除死代码、改善无障碍
- 编译和测试一次通过
- 所有 @State 和 @Binding 都有明确的初始值

**来自 Story 2.4（配置实时同步）：**
- ScriptInstallerService 的 `syncScripts(with:)` 方法已实现完整同步逻辑（删除孤立脚本 + 重新生成）
- Darwin Notification 通知模式已建立
- 配置变更触发的完整流程：AppState → SharedConfigService → ScriptInstallerService → DarwinNotificationCenter

**Git 提交模式：**
- 格式：`feat: implement [feature description] (Story X.Y)`
- 每个 Story 一个 commit

### Git 近期提交分析

最近 5 个提交：
1. `cb2662e` feat: implement verify step and onboarding completion (Story 3.3)
2. `af2b2e5` feat: implement onboarding flow and state management in AppState
3. `1c6c301` feat: implement config realtime sync and dynamic context menu (Story 2.4)
4. `e85d7d8` feat: implement menu item drag sort and default marking (Story 2.3)
5. `3d589e7` feat: implement settings window and menu item management (Story 2.2)

所有提交遵循一致的 `feat: implement ...` 格式。最近修改的文件包括 OnboardingFlowView、AppState、ScriptInstallerService 等。当前 `ScriptInstallerService.swift` 有 175 行，最近一次修改是 Story 2.4/3.3 期间的小改动。

### 最新技术信息

**kitty 终端（最新稳定版）：**
- `--single-instance` (`-1`)：如果已有 kitty 实例运行，在已有实例中创建新窗口而非启动新进程，降低内存占用和启动时间
- `--directory` (`-d`)：设置初始工作目录，默认为 `.`
- `--instance-group`：可选分组，同组的 kitty 调用共享实例
- macOS 上 `--single-instance` 已知在 Catalina 及之后版本可能有问题，但 macOS 15+ 应正常工作
- [Source: sw.kovidgoyal.net/kitty/invocation/](https://sw.kovidgoyal.net/kitty/invocation/)

**Alacritty 终端：**
- `--working-directory` (`-W`)：设置初始工作目录
- macOS 上必须直接调用二进制 `/Applications/Alacritty.app/Contents/MacOS/alacritty`，从 .app bundle 启动时 `working_directory` 配置选项可能不生效
- 新版本配置文件已从 `.yml` 迁移到 `.toml` 格式
- [Source: man.archlinux.org/man/alacritty.1](https://man.archlinux.org/man/alacritty.1.en)

**WezTerm 终端：**
- `wezterm start --cwd "{path}"` 是打开指定目录的标准方式
- `--always-new-process` 可强制启动新实例
- `--new-tab` 可在现有窗口中打开新标签
- macOS 上 `open -a WezTerm` 不能正确传递目录参数（会打开然后立即关闭）
- [Source: wezterm.org/cli/start.html](https://wezterm.org/cli/start.html)

### 反模式清单（禁止）

- ❌ 使用 `open -a` 打开 kitty/Alacritty/WezTerm（无法正确传递目录参数）
- ❌ 在 CommandMappingService 中引入文件系统依赖（检查应用是否存在）
- ❌ 在 RCMMShared 中引入 SwiftUI/AppKit/FinderSync 依赖
- ❌ 硬编码 bundleId 字符串在 ScriptInstallerService 中（使用 CommandMappingService 常量）
- ❌ 使用 ObservableObject/@Published（统一用 @Observable）
- ❌ 使用 try! 或 force unwrap
- ❌ 修改 MenuItemConfig 模型结构（模型已包含所需的 bundleId 和 customCommand 字段）
- ❌ 修改 FinderSync.swift 或 ScriptExecutor.swift（Extension 端不需要变更）

### 范围边界说明

**本 Story 范围内：**
- 创建 `CommandMappingService`（RCMMShared，纯静态方法 + 映射字典）
- 修改 `ScriptInstallerService.generateAppleScript(for:)` 方法，集成 CommandMappingService
- 创建 `CommandMappingServiceTests` 单元测试
- 编译验证和单元测试

**本 Story 范围外（明确排除）：**
- 自定义命令编辑器 UI（Epic 4, Story 4.2：CommandEditor 组件、DisclosureGroup 内联编辑）
- 命令预览与验证（Epic 4, Story 4.3：预览区、占位符提示、空命令回退）
- `{app}` 占位符替换逻辑（Story 4.2 实现，本 Story 的内置映射不使用 `{app}` 占位符）
- 菜单栏弹出窗口改动（Epic 5）
- 扩展状态检测改动（Epic 6）
- 任何 UI 变更

### Project Structure Notes

**本 Story 新建文件：**

```
rcmm/
├── RCMMShared/
│   ├── Sources/
│   │   └── Services/
│   │       └── CommandMappingService.swift       # [新建] 内置命令映射服务
│   └── Tests/
│       └── RCMMSharedTests/
│           └── CommandMappingServiceTests.swift   # [新建] 命令映射单元测试
```

**本 Story 修改文件：**

```
RCMMApp/Services/ScriptInstallerService.swift      # [修改] 集成 CommandMappingService 命令查找
```

**不变的文件（已验证无需修改）：**

```
RCMMShared/Sources/Models/MenuItemConfig.swift          # 不变 — bundleId 和 customCommand 已存在
RCMMShared/Sources/Services/SharedConfigService.swift    # 不变 — 配置读写不受影响
RCMMShared/Sources/Services/AppCategorizer.swift         # 不变 — 终端 bundleId 列表已包含目标终端
RCMMShared/Sources/Constants/SharedKeys.swift            # 不变 — CommandMappingService 纯内存，无需持久化键
RCMMFinderExtension/FinderSync.swift                     # 不变 — Extension 端对脚本内容无感知
RCMMFinderExtension/ScriptExecutor.swift                 # 不变 — 脚本执行器对脚本内容无感知
RCMMApp/AppState.swift                                   # 不变
RCMMApp/Views/Settings/SettingsView.swift                # 不变
RCMMApp/Views/Settings/MenuConfigTab.swift               # 不变（UI 变更属于 Story 4.2）
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.1] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 4] — Epic 4 整体目标和 FRs 覆盖
- [Source: _bmad-output/planning-artifacts/architecture.md#Script & Command Execution] — 脚本管理架构决策
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries] — 项目目录结构和 Package 依赖边界
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns] — 命名规范、结构模式、反模式清单
- [Source: _bmad-output/planning-artifacts/architecture.md#Core Architectural Decisions] — CommandMappingService 在共享 Package 中的定位
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 2: Custom Command Setup] — 自定义命令用户旅程
- [Source: _bmad-output/planning-artifacts/prd.md#FR-COMMAND-001] — 默认 open -a 命令需求
- [Source: _bmad-output/planning-artifacts/prd.md#FR-COMMAND-002] — 内置特殊终端命令映射需求
- [Source: _bmad-output/implementation-artifacts/3-3-verification-step-and-onboarding-completion.md] — 前序 Story 经验（闭包模式、编译验证流程）
- [Source: RCMMApp/Services/ScriptInstallerService.swift:55-77] — 当前 generateAppleScript 方法（含 TODO 注释）
- [Source: RCMMApp/Services/ScriptInstallerService.swift:58] — TODO: Epic 4 (CommandMappingService) 占位符替换
- [Source: RCMMApp/Services/ScriptInstallerService.swift:65] — TODO: Epic 4 特殊终端命令映射
- [Source: RCMMShared/Sources/Models/MenuItemConfig.swift] — bundleId（可选）和 customCommand（可选）字段
- [Source: RCMMShared/Sources/Services/AppCategorizer.swift] — 已有终端 bundleId 列表（net.kovidgoyal.kitty, org.alacritty, com.github.wez.wezterm）
- [Source: RCMMFinderExtension/ScriptExecutor.swift] — 脚本执行（NSUserAppleScriptTask，不需修改）
- [Source: sw.kovidgoyal.net/kitty/invocation/] — kitty CLI 文档（--single-instance, --directory）
- [Source: man.archlinux.org/man/alacritty.1] — Alacritty CLI 文档（--working-directory）
- [Source: wezterm.org/cli/start.html] — WezTerm CLI 文档（start --cwd）

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

无 — 编译和测试均一次通过，无需调试。

### Completion Notes List

- 创建 `CommandMappingService`（enum + 静态方法），包含 kitty、Alacritty、WezTerm 三个内置命令映射
- 映射字典以 bundleId 为键，命令模板使用 `{path}` 占位符
- 修改 `ScriptInstallerService.generateAppleScript(for:)` 实现三级命令优先级：customCommand > 内置映射 > 默认 open -a
- 内置映射命令中的 `{path}` 占位符在脚本生成时通过 `components(separatedBy:)` 拆分并使用 AppleScript `& quoted form of thePath` 拼接（路径安全处理）
- 移除两处 Epic 4 相关 TODO 注释
- 添加 `!customCommand.isEmpty` 检查，防止空字符串自定义命令阻断内置映射
- 创建 7 个单元测试覆盖所有 bundleId 查找场景（kitty、Alacritty、WezTerm、未知、nil、占位符验证、占位符引号回归测试）
- xcodebuild 编译成功（零错误），32 个测试全部通过（无回归）
- Task 4.3-4.5 为手动测试项，需用户在 Xcode 中运行应用验证

### File List

- `RCMMShared/Sources/Services/CommandMappingService.swift` — 新建：内置命令映射服务
- `RCMMShared/Tests/RCMMSharedTests/CommandMappingServiceTests.swift` — 新建：命令映射单元测试
- `RCMMApp/Services/ScriptInstallerService.swift` — 修改：集成 CommandMappingService 命令查找逻辑
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 修改：epic-4 状态更新为 in-progress，story 4-1 状态更新为 review

### Change Log

- 2026-02-22: 实现 CommandMappingService 和 ScriptInstallerService 命令优先级集成，添加 6 个单元测试 (Story 4.1)
- 2026-02-22: [Code Review] 修复 CRITICAL bug：内置命令 {path} 占位符替换生成无效 AppleScript（`""` 转义导致路径变量未替换）；CommandMappingService 改为 caseless enum；模板移除 {path} 周围引号；ScriptInstallerService 使用 components(separatedBy:) + AppleScript 字符串拼接；新增回归测试防止引号包裹问题复现；测试增至 32 个全部通过
