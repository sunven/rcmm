# Story 2.4: 配置实时同步与动态右键菜单

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户,
I want 在设置窗口中修改菜单配置后，下次右键 Finder 立即看到更新后的菜单,
So that 配置变更无需重启即可生效。

## Acceptance Criteria

1. **配置变更通知发送** — 用户在设置窗口中添加/删除/排序菜单项后，配置保存完成时，主应用通过 `DarwinNotificationCenter` 发送 `configChanged` 通知，`ScriptInstallerService` 根据最新配置同步增删改 `.scpt` 文件。配置变更到 Extension 可用的延迟 ≤ 1 秒。
2. **Extension 通知监听** — `FinderSync` Extension 在初始化时注册 `DarwinNotificationCenter` 观察者，监听 `NotificationNames.configChanged` 通知。收到通知时通过 `os_log` 记录事件。`DarwinObservation` 句柄作为存储属性保留，防止提前释放。
3. **动态右键菜单** — Extension 收到 `configChanged` 通知后，用户下次在 Finder 中右键时，Extension 从 App Group UserDefaults 读取最新配置，右键菜单显示更新后的菜单项列表（正确的名称、图标、顺序）。
4. **脚本执行正确性** — 每个菜单项对应正确的 `.scpt` 脚本，点击后打开对应应用并定位到右键目录。默认命令使用 `open -a "{appPath}" "{path}"` 格式（通用 shell 命令），确保 Terminal、VS Code 等主流应用均可正确打开。
5. **端到端验证** — 添加应用 → 右键显示新菜单项 → 点击打开对应应用；删除应用 → 右键不再显示；重新排序 → 右键顺序与设置一致。全流程无需重启主应用或 Extension。

## Tasks / Subtasks

- [x] Task 1: 更新 ScriptInstallerService 默认命令为通用 `open -a` (AC: #1, #4)
  - [x] 1.1 修改 `generateAppleScript(for:)` 的默认分支（无 `customCommand` 时），将 Terminal 专用的 `tell application → do script "cd"` 替换为通用 `do shell script "open -a " & quoted form of "{appPath}" & " " & quoted form of thePath`
  - [x] 1.2 保留 `customCommand` 分支不变（Epic 4 将增强占位符替换能力）
  - [x] 1.3 验证生成的 AppleScript 语法正确（osacompile 编译通过）
  - [x] 1.4 更新 TODO 注释说明当前状态：默认 `open -a` 对大多数应用有效，Epic 4 将通过 CommandMappingService 提供特殊终端映射

- [x] Task 2: FinderSync Extension 注册 Darwin 通知监听 (AC: #2, #3)
  - [x] 2.1 在 `FinderSync` 类中添加 `private var configObservation: DarwinObservation?` 存储属性
  - [x] 2.2 在 `override init()` 中调用 `DarwinNotificationCenter.shared.addObserver(name: NotificationNames.configChanged)` 注册观察者
  - [x] 2.3 观察者回调中通过 `logger.info` 记录收到通知事件（如 `"收到配置变更通知，下次右键将使用最新配置"`）
  - [x] 2.4 确保 `configObservation` 作为实例属性持有，防止 `DarwinObservation` 被释放导致观察者自动取消

- [x] Task 3: 编译验证与端到端测试 (AC: 全部)
  - [x] 3.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 3.2 RCMMShared 全部现有测试通过，无回归
  - [ ] 3.3 手动测试：在设置窗口添加一个新应用（如 VS Code）→ 到 Finder 右键目录 → 菜单中显示"用 Visual Studio Code 打开" → 点击后 VS Code 打开并定位到该目录
  - [ ] 3.4 手动测试：在设置窗口删除一个应用 → 到 Finder 右键 → 菜单中不再显示该应用
  - [ ] 3.5 手动测试：在设置窗口拖拽调整顺序 → 到 Finder 右键 → 菜单项顺序与设置一致
  - [ ] 3.6 手动测试：验证配置变更到菜单更新延迟 ≤ 1 秒
  - [ ] 3.7 Console.app 验证：筛选 `com.sunven.rcmm.FinderExtension` subsystem，确认收到 `configChanged` 通知的 os_log 日志

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 2（应用发现与菜单配置管理）的最后一个 Story，实现配置变更的完整闭环：主应用配置修改 → App Group 持久化 → 脚本同步 → Darwin 通知 → Extension 读取新配置 → 右键菜单更新。前三个 Story 分别完成了应用发现（2.1）、菜单项管理 UI（2.2）、拖拽排序（2.3），本 Story 将验证整个链路端到端正常工作。

**FRs 覆盖：** FR-DATA-002（配置变更 ≤ 1 秒同步到 Extension）

**跨 Story 依赖：**
- 依赖 Story 1.2：`SharedConfigService`、`DarwinNotificationCenter`、`MenuItemConfig`、`SharedKeys`、`NotificationNames`
- 依赖 Story 1.3：`ScriptInstallerService`、`ScriptExecutor`、`FinderSync.swift`
- 依赖 Story 2.2：`AppState.saveAndSync()` 已实现写入 → 脚本同步 → 发送通知的完整流程
- 依赖 Story 2.3：拖拽排序和 sortOrder 重算逻辑已实现
- Epic 3（引导流程）将复用本 Story 建立的配置同步管道
- Epic 4（CommandMappingService）将在本 Story 的 `open -a` 默认命令基础上增加特殊终端映射

### 关键技术决策

**1. Extension 不缓存配置（架构决策）**

架构文档明确规定："Extension 每次直接读 UserDefaults，不缓存（配置量小 ~4KB，读取 < 1ms）"。

当前 `FinderSync.menu(for:)` 已经在每次右键时从 `configService.load()` 读取最新配置，这意味着只要 UserDefaults 数据已更新，下次右键自然使用新配置。Darwin 通知的作用是：
1. **可观测性** — 通过 os_log 记录同步事件，便于调试
2. **架构完整性** — 完成 Architecture 文档描述的"Darwin Notifications（信号）+ App Group UserDefaults（数据）"通信模型
3. **未来扩展** — 如果未来需要缓存或预加载，通知基础设施已就绪

**不需要**在通知回调中做任何数据刷新操作（因为不缓存），仅需 os_log 记录即可。

**2. 默认命令从 Terminal 专用改为通用 `open -a`**

当前 `ScriptInstallerService.generateAppleScript(for:)` 在无 `customCommand` 时生成 Terminal 专用 AppleScript（`tell application → do script "cd"`），这对非 Terminal 应用无效。Story 2.4 允许用户添加任意应用（Story 2.2 已实现 UI），因此需要通用的默认命令。

变更前（Terminal 专用）：
```applescript
on openApp(thePath)
    tell application "Terminal"
        activate
        do script "cd " & quoted form of thePath
    end tell
end openApp
```

变更后（通用 `open -a`）：
```applescript
on openApp(thePath)
    do shell script "open -a " & quoted form of "/Applications/Visual Studio Code.app" & " " & quoted form of thePath
end openApp
```

`open -a "{appPath}" "{directoryPath}"` 的行为：
- **Terminal.app** — 打开新窗口并 cd 到目录 ✓
- **VS Code** — 打开目录为工作区 ✓
- **Sublime Text** — 打开目录 ✓
- **特殊终端（kitty/Alacritty/WezTerm）** — `open -a` 可能不传递 cd 参数，Epic 4 CommandMappingService 将为它们提供专用命令映射

Swift 实现：
```swift
// ScriptInstallerService.swift — generateAppleScript(for:) 默认分支
let escapedAppPath = escapeForAppleScript(item.appPath)
command = """
    do shell script "open -a " & quoted form of "\(escapedAppPath)" & " " & quoted form of thePath
"""
```

`quoted form of` 是 AppleScript 内置函数，会将字符串包裹为单引号并转义特殊字符，确保含空格的路径（如 `/Applications/Visual Studio Code.app`）在 shell 中正确解析。

**3. 配置同步时序分析**

当前 `AppState.saveAndSync()` 的时序：

```
[主线程] configService.save(menuItems)     ← UserDefaults 同步写入（即时完成）
[主线程] syncScriptsInBackground()         ← 启动后台任务
           ↓
[后台线程] installer.syncScripts(with:)    ← osacompile 编译脚本（~100-500ms）
[后台线程] DarwinNotificationCenter.post() ← 通知 Extension
```

**关键时序保证：**
- UserDefaults 写入是同步的 → 主应用 UI 立即反映变更
- Darwin 通知在脚本同步**之后**发送 → Extension 收到通知时脚本文件已就绪
- UserDefaults 跨进程读取在 macOS 上是即时的（无需 `synchronize()`，macOS 10.12+ 自动同步）
- 极端情况：用户在脚本编译期间右键 → UserDefaults 已更新，菜单项正确显示，但新增项的脚本可能尚未编译完成 → 点击会触发"脚本文件不存在"错误 → `ScriptExecutor` 已有错误处理和 SharedErrorQueue 记录

**延迟估算：** UserDefaults 写入 < 1ms + osacompile 编译 ~100-500ms + Darwin 通知传递 < 10ms ≈ **总延迟 < 1 秒**（满足 FR-DATA-002）

**4. FinderSync 通知注册实现**

```swift
// FinderSync.swift — 新增
private var configObservation: DarwinObservation?

override init() {
    super.init()
    FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]

    configObservation = DarwinNotificationCenter.shared.addObserver(
        name: NotificationNames.configChanged
    ) { [weak self] in
        self?.logger.info("收到配置变更通知，下次右键将使用最新配置")
    }

    logger.info("FinderSync Extension 已初始化，已注册配置变更监听")
}
```

**线程安全说明：**
- Darwin 通知回调在任意线程触发
- 回调中仅调用 `logger.info()`，`os_log` 是线程安全的
- 不修改任何共享状态（因为不缓存配置）
- `[weak self]` 防止 FinderSync 实例循环引用（Extension 可能被系统多次实例化/销毁）

**关于 `[weak self]`：** FinderSync Extension 可能在 Finder 的不同窗口中被多次实例化（如 Open/Save 对话框），`[weak self]` 确保实例销毁时回调不会访问已释放的对象。

### Swift 6 并发注意事项

- `DarwinNotificationCenter.shared` 是 `Sendable`，可安全跨线程访问
- `DarwinObservation` 标记为 `@unchecked Sendable`，内部通过 CFNotificationCenter 管理生命周期
- 通知回调是 `@Sendable () -> Void`，满足 Swift 并发要求
- 本 Story 不引入新的并发模式，完全复用已有模式

### 命名规范参考

| 类别 | 规范 | 本 Story 示例 |
|---|---|---|
| 属性 | lowerCamelCase | `configObservation` |
| os_log category | 功能域字符串 | `"menu"`（Extension 已有） |
| Darwin Notification | 已定义常量 | `NotificationNames.configChanged` |

### 前序 Story 经验总结

**来自 Story 2.3（直接前序）：**
- `AppState.moveMenuItem(from:to:)` 已建立排序变更 → saveAndSync 模式
- `AppState.recalculateSortOrders()` 确保 sortOrder 始终与数组索引一致
- `MenuConfigTab` 已有 `.onMove` + `.onDelete` 完整拖拽排序
- Code Review 提醒：moveMenuItem 单元测试待添加（AI-Review action item，不阻塞本 Story）
- 所有 25 个 RCMMShared 测试通过，无回归

**来自 Story 2.2（核心依赖）：**
- `AppState.saveAndSync()` 是所有配置变更的统一出口：save → syncScripts → post notification
- `ScriptInstallerService` 每次调用新建实例（无可变状态，线程安全）
- 启动时重编译所有脚本（保持现状，未来优化）
- SettingsAccess 已集成解决 MenuBarExtra → Settings 窗口打开问题

**来自 Story 1.3（Extension 基础）：**
- `FinderSync.swift` 已有完整的菜单构建（`menu(for:)`）和脚本执行（`openWithApp(_:)`）逻辑
- `ScriptExecutor` 已有错误处理 → SharedErrorQueue → os_log 完整链路
- `resolveDirectoryPath()` 已正确处理右键目录和右键空白背景两种场景

**当前代码状态（核心文件修改清单）：**
- `ScriptInstallerService.swift:55-80`：`generateAppleScript(for:)` 默认分支使用 Terminal 专用命令 → **需修改为通用 `open -a`**
- `FinderSync.swift:14-18`：`init()` 无通知监听 → **需添加 Darwin 通知观察者**
- `AppState.swift:108-120`：`saveAndSync()` + `syncScriptsInBackground()` → **无需修改**（写入端已完整）

### 反模式清单（禁止）

- ❌ 在 FinderSync 中缓存 `[MenuItemConfig]`（架构明确禁止缓存，每次直接读 UserDefaults）
- ❌ 在 Darwin 通知回调中修改 UI 状态或进行复杂操作（回调在任意线程，仅做日志记录）
- ❌ 调用 `UserDefaults.synchronize()`（macOS 10.12+ 已废弃，自动同步）
- ❌ 使用 `ObservableObject/@Published`（统一用 `@Observable`）
- ❌ 在 Extension 中使用 `Process/NSTask`（沙盒禁止）
- ❌ 硬编码 App Group 键名或 Darwin Notification 名称（使用 `SharedKeys` 和 `NotificationNames` 常量）
- ❌ 使用 `try!` 或 force unwrap
- ❌ 在 RCMMShared 中引入 SwiftUI 或 AppKit 依赖
- ❌ 实现 CommandMappingService 或特殊终端映射（属于 Epic 4 范围）
- ❌ 修改 `MenuItemConfig` 模型结构（无需新字段）

### 范围边界说明

**本 Story 范围内：**
- FinderSync 注册 Darwin 通知监听
- ScriptInstallerService 默认命令改为通用 `open -a`
- 端到端验证配置同步流程

**本 Story 范围外（明确排除）：**
- CommandMappingService 命令映射服务（Epic 4, Story 4.1）
- 特殊终端（kitty/Alacritty/WezTerm）的专用打开命令（Epic 4, Story 4.1）
- 自定义命令中 `{app}` / `{path}` 占位符替换（Epic 4, Story 4.2）
- UI 变更（本 Story 无 UI 修改）
- 配置缓存优化（架构决策：不缓存）

### Project Structure Notes

**本 Story 修改文件：**

```
rcmm/
├── RCMMApp/
│   └── Services/
│       └── ScriptInstallerService.swift     # [修改] generateAppleScript 默认命令改为 open -a
│
└── RCMMFinderExtension/
    └── FinderSync.swift                     # [修改] 新增 configObservation 属性 + init() 注册 Darwin 通知监听
```

**不变的文件（已验证无需修改）：**

```
RCMMApp/AppState.swift                          # 不变 — saveAndSync() + syncScriptsInBackground() 已完整实现
RCMMApp/Views/Settings/MenuConfigTab.swift      # 不变 — UI 和交互逻辑已完成
RCMMApp/Views/Settings/AppListRow.swift         # 不变
RCMMShared/Sources/Models/MenuItemConfig.swift  # 不变 — 模型无需新字段
RCMMShared/Sources/Services/SharedConfigService.swift    # 不变
RCMMShared/Sources/Services/DarwinNotificationCenter.swift  # 不变 — addObserver API 已就绪
RCMMShared/Sources/Constants/NotificationNames.swift     # 不变 — configChanged 已定义
RCMMShared/Sources/Constants/SharedKeys.swift            # 不变
RCMMFinderExtension/ScriptExecutor.swift                 # 不变
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.4] — Story 需求定义和验收标准（配置实时同步 + 动态右键菜单）
- [Source: _bmad-output/planning-artifacts/architecture.md#Data Architecture] — "Extension 每次直接读 UserDefaults，不缓存（配置量小 ~4KB，读取 < 1ms）"
- [Source: _bmad-output/planning-artifacts/architecture.md#Script & Command Execution] — 脚本管理策略（按应用生成专用 .scpt，配置变更时同步增删改）
- [Source: _bmad-output/planning-artifacts/architecture.md#Communication Patterns] — Darwin Notification 协议（纯信号，不携带数据；观察者回调不在主线程）
- [Source: _bmad-output/planning-artifacts/architecture.md#Process Patterns] — 脚本生成流程（7 步）
- [Source: _bmad-output/planning-artifacts/architecture.md#Architectural Boundaries] — 进程边界图和数据流
- [Source: _bmad-output/planning-artifacts/prd.md#数据管理] — FR-DATA-002（配置变更 1 秒内同步到 Extension）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Effortless Interactions] — "Darwin Notification 实时同步，修改后下次右键立即生效"
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Feedback Patterns] — "配置变更无显式反馈（实时生效即最好的反馈）"
- [Source: _bmad-output/implementation-artifacts/2-3-menu-item-drag-sort-and-default.md] — 前序 Story dev notes、saveAndSync 模式、代码状态
- [Source: RCMMApp/AppState.swift:108-120] — saveAndSync() + syncScriptsInBackground() 实现
- [Source: RCMMFinderExtension/FinderSync.swift:14-18] — 当前 init() 无通知监听
- [Source: RCMMFinderExtension/FinderSync.swift:22-48] — menu(for:) 每次从 UserDefaults 加载配置
- [Source: RCMMApp/Services/ScriptInstallerService.swift:55-80] — generateAppleScript 当前 Terminal 专用实现
- [Source: RCMMShared/Sources/Services/DarwinNotificationCenter.swift:33-43] — addObserver API
- [Apple: open command](https://ss64.com/mac/open.html) — `open -a` shell 命令参考
- [Apple: CFNotificationCenter](https://developer.apple.com/documentation/corefoundation/cfnotificationcenter) — Darwin Notifications API

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- xcodebuild -scheme rcmm: BUILD SUCCEEDED（零错误）
- swift test (RCMMShared): 25/25 测试通过
- osacompile 编译验证: 通用 `open -a` AppleScript 语法正确

### Completion Notes List

- ✅ Task 1: ScriptInstallerService `generateAppleScript(for:)` 默认分支从 Terminal 专用 `tell application → do script "cd"` 改为通用 `do shell script "open -a " & quoted form of appPath & " " & quoted form of thePath`，customCommand 分支保持不变，TODO 注释已更新说明 Epic 4 后续规划
- ✅ Task 2: FinderSync Extension 新增 `configObservation: DarwinObservation?` 存储属性，在 `init()` 中注册 `NotificationNames.configChanged` Darwin 通知观察者，回调使用 `[weak self]` 并仅记录 os_log
- ✅ Task 3 (3.1-3.2): 编译零错误，25 个现有测试全部通过无回归
- ⏳ Task 3 (3.3-3.7): 手动端到端测试需用户在真实环境中执行

### File List

- `RCMMApp/Services/ScriptInstallerService.swift` — 修改: generateAppleScript 默认分支改为通用 open -a 命令；新增 osacompile 10秒超时保护
- `RCMMApp/AppState.swift` — 修改: syncScriptsInBackground 改用串行队列避免并发竞态
- `RCMMFinderExtension/FinderSync.swift` — 修改: 新增 configObservation 属性 + init() 注册 Darwin 通知监听
- `RCMMShared/Sources/Services/DarwinNotificationCenter.swift` — 修改: cancel() 改为同步移除观察者，修复 use-after-free

### Change Log

- 2026-02-19: Story 2.4 实现完成 — ScriptInstallerService 默认命令改为通用 `open -a`，FinderSync 注册 Darwin 通知监听，编译和自动化测试通过
- 2026-02-19: Code Review 修复 — [H2] DarwinObservation.cancel() use-after-free 修复为同步移除；[M1] syncScriptsInBackground 竞态修复为串行队列；[M2] osacompile 新增 10 秒超时保护

### Review Follow-ups (AI)

- [ ] [AI-Review][MEDIUM] `moveMenuItem` 和 `recalculateSortOrders` 缺少单元测试 — 需新建 RCMMApp test target 或提取逻辑到 RCMMShared [AppState.swift]
- [ ] [AI-Review][HIGH] Story 2.3 变更（AppState/AppListRow/MenuConfigTab）未提交，需先为 Story 2.3 创建独立 git commit 再提交 Story 2.4
