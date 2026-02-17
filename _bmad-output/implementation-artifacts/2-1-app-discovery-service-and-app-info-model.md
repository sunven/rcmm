# Story 2.1: 应用发现服务与应用信息模型

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户,
I want 系统自动扫描已安装的应用并展示名称、图标和类型信息,
So that 我可以快速找到想添加到右键菜单的应用。

## Acceptance Criteria

1. **扫描 /Applications 和 ~/Applications** — `AppDiscoveryService` 扫描两个目录，返回已安装应用列表，每个应用包含名称（`CFBundleDisplayName` 或 `CFBundleName`）、图标（`NSWorkspace.shared.icon(forFile:)`）、bundleId、路径，扫描时间 ≤ 5 秒
2. **识别应用类型** — 系统通过 bundleId 匹配已知列表，识别应用类型（终端 `.terminal`、编辑器 `.editor`、其他 `.other`），应用列表按类型分组展示（终端类优先、编辑器次之、其他最后）
3. **手动添加应用** — 用户点击"手动添加"按钮，弹出 `NSOpenPanel` 文件选择器，过滤 `.app` 文件（`allowedContentTypes = [.application]`），选择后应用信息正确提取并加入列表
4. **AppInfo 模型扩展** — `AppInfo` 模型新增 `category: AppCategory` 字段（可选，默认 `.other`），新增 `icon` 计算属性（不持久化，运行时通过 `NSWorkspace` 获取），保持 `Codable, Identifiable, Hashable, Sendable`
5. **AppCategory 枚举** — 新增 `AppCategory` 枚举（`.terminal`, `.editor`, `.other`），实现 `Codable, Sendable, CaseIterable, Comparable`，定义排序权重（terminal=0, editor=1, other=2）
6. **AppDiscoveryService 放在 RCMMApp** — 因为需要 `NSWorkspace`（AppKit），服务放在 `RCMMApp/Services/` 下而非 RCMMShared（RCMMShared 禁止依赖 AppKit）

## Tasks / Subtasks

- [x] Task 1: 新增 AppCategory 枚举 (AC: #5)
  - [x] 1.1 在 `RCMMShared/Sources/Models/` 创建 `AppCategory.swift`
  - [x] 1.2 实现 `AppCategory` 枚举：`.terminal`, `.editor`, `.other`，遵循 `Codable, Sendable, CaseIterable, Comparable`
  - [x] 1.3 实现 `sortWeight` 属性用于排序（terminal=0, editor=1, other=2）

- [x] Task 2: 扩展 AppInfo 模型 (AC: #4)
  - [x] 2.1 在 `AppInfo` 中新增 `category: AppCategory?` 可选字段（默认 `nil`，保证旧数据可解码）
  - [x] 2.2 确认 AppInfo 保持 `Codable, Identifiable, Hashable, Sendable`
  - [x] 2.3 更新 init 方法，增加 `category` 参数（默认值 `nil`）

- [x] Task 3: 创建 AppCategorizer (AC: #2)
  - [x] 3.1 在 `RCMMShared/Sources/Services/` 创建 `AppCategorizer.swift`
  - [x] 3.2 实现静态 `terminalBundleIds: Set<String>`（Terminal, iTerm2, kitty, Alacritty, WezTerm, Warp, Hyper, Ghostty）
  - [x] 3.3 实现静态 `editorBundleIds: Set<String>`（VS Code, Cursor, Xcode, Sublime Text, Nova, BBEdit, TextMate, CotEditor, Zed）
  - [x] 3.4 实现 `static func categorize(bundleId: String?) -> AppCategory`

- [x] Task 4: 创建 AppDiscoveryService (AC: #1, #2, #3, #6)
  - [x] 4.1 在 `RCMMApp/Services/` 创建 `AppDiscoveryService.swift`
  - [x] 4.2 实现 `scanApplications() -> [AppInfo]` — 扫描 /Applications 和 ~/Applications
  - [x] 4.3 使用 `FileManager.contentsOfDirectory(at:includingPropertiesForKeys:options:)` 扫描
  - [x] 4.4 使用 `Bundle(url:)` 提取 `CFBundleDisplayName`/`CFBundleName` 和 `bundleIdentifier`
  - [x] 4.5 使用 `AppCategorizer.categorize()` 对每个应用分类
  - [x] 4.6 返回结果按 category 排序（terminal > editor > other），同类内按名称字母序
  - [x] 4.7 使用 `os.Logger`（subsystem: `com.sunven.rcmm`, category: `"discovery"`）记录扫描日志
  - [x] 4.8 实现 `selectApplicationManually() async -> AppInfo?` — 弹出 NSOpenPanel 选择任意 .app

- [x] Task 5: 单元测试 (AC: #2, #4, #5)
  - [x] 5.1 `AppCategoryTests.swift` — 测试已知 bundleId 分类正确（终端、编辑器、其他）
  - [x] 5.2 `AppCategoryTests.swift` — 测试 nil bundleId 返回 `.other`
  - [x] 5.3 `AppInfoTests.swift` — 测试 AppInfo 新增 category 字段的编解码（含向后兼容：无 category 字段的旧数据可解码）
  - [x] 5.4 `AppCategoryTests.swift` — 测试 Comparable 排序（terminal < editor < other）

- [x] Task 6: 编译验证 (AC: 全部)
  - [x] 6.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 6.2 RCMMShared 全部测试通过（含新增测试），无回归
  - [x] 6.3 确认 RCMMShared 无 AppKit/SwiftUI 依赖引入

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 2（应用发现与菜单配置管理）的第一个 Story，为后续 Story 2.2（设置窗口与菜单项管理）、2.3（拖拽排序）、2.4（配置实时同步）提供数据基础。Epic 1 建立了硬编码的 Terminal 配置和完整执行链路，本 Story 开始将"硬编码"替换为"动态发现"。

**跨 Story 依赖：**
- Story 2.2 将使用 `AppDiscoveryService.scanApplications()` 在设置窗口中展示可添加应用
- Story 2.2 将使用 `AppDiscoveryService.selectApplicationManually()` 实现手动添加
- Story 3.2（引导流程选择应用）也将复用 `AppDiscoveryService`
- `AppCategory` 和 `AppCategorizer` 将被引导流程（预选常见开发工具）和 CommandMappingService（Epic 4）使用

**关键边界约束：**

| 模块 | 可依赖 | 禁止依赖 |
|---|---|---|
| `AppCategory` (RCMMShared) | Foundation | SwiftUI, AppKit |
| `AppCategorizer` (RCMMShared) | Foundation | SwiftUI, AppKit |
| `AppInfo` (RCMMShared) | Foundation | SwiftUI, AppKit |
| `AppDiscoveryService` (RCMMApp) | Foundation, AppKit, RCMMShared | FinderSync, SwiftUI |

`AppDiscoveryService` 必须放在 `RCMMApp/Services/` 下，因为它需要 `NSWorkspace`（AppKit API）。`AppCategorizer` 和 `AppCategory` 放在 RCMMShared 中，因为它们是纯 Foundation 类型，可被 Extension 或其他模块复用。

### 关键技术决策

**应用扫描方案：FileManager 浅层遍历**

```swift
let prefetchKeys: [URLResourceKey] = [.localizedNameKey, .isApplicationKey]
let contents = try FileManager.default.contentsOfDirectory(
    at: URL(fileURLWithPath: "/Applications"),
    includingPropertiesForKeys: prefetchKeys,
    options: [.skipsHiddenFiles]
)
let apps = contents.filter { $0.pathExtension == "app" }
```

- 使用 `includingPropertiesForKeys` 批量预取元数据，避免逐文件 IO
- 浅层遍历（不递归），/Applications 下的 .app 都是顶层项
- `.skipsHiddenFiles` 过滤 `.DS_Store` 等
- /Applications 通常 50-200 个项目，毫秒级完成

**应用名称解析优先级：**

```swift
let bundle = Bundle(url: appURL)
let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
    ?? appURL.deletingPathExtension().lastPathComponent
```

1. `CFBundleDisplayName`（本地化显示名）
2. `CFBundleName`（短名称）
3. 文件名去掉 .app 后缀（兜底）

使用 `object(forInfoDictionaryKey:)` 而非 `infoDictionary[key]`，前者返回本地化值。

**应用图标：运行时获取，不持久化**

`NSWorkspace.shared.icon(forFile:)` 始终返回有效 `NSImage`（无自定义图标时返回通用应用图标）。图标不存入 AppInfo 模型（NSImage 不可 Codable），在 UI 层按需获取。

**NSOpenPanel 手动添加应用：**

```swift
let panel = NSOpenPanel()
panel.allowedContentTypes = [.application]  // 需要 import UniformTypeIdentifiers
panel.treatsFilePackagesAsDirectories = false  // .app 视为不可打开的整体
panel.directoryURL = URL(fileURLWithPath: "/Applications")
```

- 使用 `allowedContentTypes`（macOS 11+）替代已废弃的 `allowedFileTypes`
- `treatsFilePackagesAsDirectories = false` 确保 .app 被视为可选择的文件而非可进入的文件夹
- 使用 `await panel.begin()` 异步 API（macOS 12+）

**AppCategory Comparable 排序：**

```swift
public enum AppCategory: String, Codable, Sendable, CaseIterable, Comparable {
    case terminal
    case editor
    case other

    public var sortWeight: Int {
        switch self {
        case .terminal: return 0
        case .editor: return 1
        case .other: return 2
        }
    }

    public static func < (lhs: AppCategory, rhs: AppCategory) -> Bool {
        lhs.sortWeight < rhs.sortWeight
    }
}
```

**已知 Bundle ID 列表：**

终端类：
| 应用 | Bundle ID |
|---|---|
| Terminal.app | `com.apple.Terminal` |
| iTerm2 | `com.googlecode.iterm2` |
| kitty | `net.kovidgoyal.kitty` |
| Alacritty | `org.alacritty` |
| WezTerm | `com.github.wez.wezterm` |
| Warp | `dev.warp.Warp-Stable` |
| Hyper | `co.zeit.hyper` |
| Ghostty | `com.mitchellh.ghostty` |

编辑器/IDE：
| 应用 | Bundle ID |
|---|---|
| VS Code | `com.microsoft.VSCode` |
| Cursor | `com.todesktop.230313mzl4w4u92` |
| Xcode | `com.apple.dt.Xcode` |
| Sublime Text 4 | `com.sublimetext.4` |
| Sublime Text 3 | `com.sublimetext.3` |
| Nova | `com.panic.Nova` |
| BBEdit | `com.barebones.bbedit` |
| TextMate | `com.macromates.TextMate` |
| CotEditor | `com.coteditor.CotEditor` |
| Zed | `dev.zed.Zed` |

### Swift 6 并发注意事项

- `AppDiscoveryService` 中的 `NSWorkspace` 调用需在主线程。建议 FileManager 扫描放在后台线程，`NSWorkspace.shared.icon(forFile:)` 和 `Bundle(url:)` 调用在主线程
- `AppInfo`、`AppCategory`、`AppCategorizer` 都是 `Sendable`，可安全跨线程使用
- 项目使用 Swift 5 语言模式（`SWIFT_STRICT_CONCURRENCY=targeted`），`@Sendable` 闭包标注必要时需添加
- `NSOpenPanel.begin()` 是 `@MainActor` API

### 命名规范参考

| 类别 | 规范 | 本 Story 示例 |
|---|---|---|
| 服务类 | UpperCamelCase | `AppDiscoveryService`, `AppCategorizer` |
| 枚举 | UpperCamelCase | `AppCategory` |
| 枚举 case | lowerCamelCase | `.terminal`, `.editor`, `.other` |
| 方法 | lowerCamelCase，动词开头 | `scanApplications()`, `categorize(bundleId:)` |
| os_log category | 功能域字符串 | `"discovery"` |
| 测试文件 | 被测类型 + Tests | `AppCategoryTests.swift`, `AppInfoTests.swift` |

### 向后兼容性

`AppInfo` 新增 `category: AppCategory?` 字段必须为可选类型（默认 `nil`），确保 Story 1.2 写入的旧数据可正常解码。测试必须验证无 `category` 字段的 JSON 可成功解码为 `AppInfo`。

### 前序 Story 经验总结

**来自 Story 1.1：**
- `RCMMApp/Services/` 目录已存在（Story 1.3 创建）
- 代码签名使用 ad-hoc，`xcodebuild` 需要 `CODE_SIGNING_REQUIRED=NO`

**来自 Story 1.2：**
- Swift 6 编译器 + Swift 5 语言模式 — `@Sendable` 闭包标注必要
- 测试使用 Swift Testing 框架（`import Testing`, `@Test` 宏）
- `SharedConfigService` 和模型类已标记 `@unchecked Sendable` 或 `Sendable`
- Git commit 风格：`feat: 功能描述 (Story X.X)`

**来自 Story 1.3：**
- `ScriptInstallerService` 已实现，放在 `RCMMApp/Services/`（可参考同目录布局）
- `os.Logger` 使用模式：`Logger(subsystem: "com.sunven.rcmm", category: "xxx")`
- Code Review 中修复了字符串转义和线程安全问题，本 Story 应从设计阶段就注意

**Git 分析（最近 3 个提交）：**

```
14ba08f feat: enhance rcmmApp and FinderSync with initial configuration and menu integration
43eec6b feat: implement shared data layer and config persistence (Story 1.2)
99e31fd feat: initialize Xcode project with triple-target architecture (Story 1.1)
```

### 反模式清单（禁止）

- ❌ 在 RCMMShared 中引入 AppKit 或 SwiftUI 依赖（AppDiscoveryService 只能放 RCMMApp）
- ❌ 在 AppInfo 中存储 NSImage（NSImage 不可 Codable/Sendable，图标在 UI 层运行时获取）
- ❌ 硬编码应用路径用于分类（使用 bundleId 匹配，不依赖文件路径）
- ❌ 递归扫描 /Applications（浅层遍历即可，.app 是顶层包）
- ❌ 使用已废弃的 `allowedFileTypes`（使用 `allowedContentTypes = [.application]`）
- ❌ 使用已废弃的 `absolutePathForApplication(withBundleIdentifier:)`（使用 `urlForApplication(withBundleIdentifier:)`）
- ❌ 使用 `try!` 或 force unwrap（使用 `try?` 或 do-catch）
- ❌ 新增 Codable 字段为非可选类型（必须为可选或有默认值，保证旧数据可解码）
- ❌ 在 AppCategory/AppCategorizer 中引入运行时动态分类逻辑（MVP 阶段只需静态 bundleId 列表）
- ❌ 使用 `ObservableObject/@Published`（统一用 `@Observable`）

### Project Structure Notes

**本 Story 完成后的新增/修改文件：**

```
rcmm/
├── RCMMShared/Sources/
│   ├── Models/
│   │   ├── AppInfo.swift              # [修改] 新增 category: AppCategory? 字段
│   │   └── AppCategory.swift          # [新增] 应用类型枚举
│   └── Services/
│       └── AppCategorizer.swift       # [新增] bundleId → AppCategory 映射
│
├── RCMMApp/Services/
│   └── AppDiscoveryService.swift      # [新增] 应用扫描与手动添加服务
│
└── RCMMShared/Tests/RCMMSharedTests/
    ├── AppCategoryTests.swift         # [新增] AppCategory + AppCategorizer 测试
    └── AppInfoTests.swift             # [新增] AppInfo 向后兼容编解码测试
```

**不变的文件（之前 Story 已实现）：**

```
RCMMShared/Sources/
├── Models/MenuItemConfig.swift        # 菜单项配置模型（不变）
├── Models/ErrorRecord.swift           # 错误记录模型（不变）
├── Models/ExtensionStatus.swift       # 扩展状态枚举（不变）
├── Models/PopoverState.swift          # 弹出窗口状态枚举（不变）
├── Services/SharedConfigService.swift # App Group UserDefaults 读写（不变）
├── Services/DarwinNotificationCenter.swift # 跨进程通知（不变）
├── Services/SharedErrorQueue.swift    # 错误队列（不变）
└── Constants/                         # 共享常量（不变）

RCMMApp/
├── rcmmApp.swift                      # 主入口（不变）
└── Services/ScriptInstallerService.swift # 脚本安装（不变）

RCMMFinderExtension/                   # Extension（不变）
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.1] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/architecture.md#Application Discovery] — 应用发现架构决策（启动时扫描 + 手动刷新）
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries] — Package 依赖边界（RCMMShared 禁止依赖 AppKit）
- [Source: _bmad-output/planning-artifacts/architecture.md#Naming Patterns] — 命名规范
- [Source: _bmad-output/planning-artifacts/architecture.md#FR-APP-DISCOVERY mapping] — FR-APP-DISCOVERY → AppDiscoveryService + AppInfo 文件映射
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Component Strategy] — AppListRow 组件定义（图标 32x32 + 名称 + 状态标签）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#User Journey Flows] — 引导流程应用选择步骤（预选常见开发工具）
- [Source: _bmad-output/planning-artifacts/prd.md#应用发现] — FR-APP-DISCOVERY-001 到 004 需求
- [Source: _bmad-output/implementation-artifacts/1-3-finder-context-menu-and-script-execution-e2e.md] — 前序 Story 的 dev notes 和经验
- [Apple: FileManager.contentsOfDirectory(at:includingPropertiesForKeys:options:)](https://developer.apple.com/documentation/foundation/filemanager/1413768-contentsofdirectory) — 目录扫描 API
- [Apple: NSWorkspace.icon(forFile:)](https://developer.apple.com/documentation/appkit/nsworkspace/1528158-icon) — 应用图标获取
- [Apple: NSOpenPanel](https://developer.apple.com/documentation/appkit/nsopenpanel) — 文件选择器
- [Apple: UTType.application](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/application) — 应用文件类型

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

无异常，所有编译和测试一次通过。

### Completion Notes List

- ✅ Task 1: 创建 `AppCategory` 枚举，实现 `Codable, Sendable, CaseIterable, Comparable`，包含 `sortWeight` 排序属性
- ✅ Task 2: 扩展 `AppInfo` 模型，新增 `category: AppCategory?` 可选字段，保持向后兼容性（旧数据无 category 可正常解码）
- ✅ Task 3: 创建 `AppCategorizer`，包含 8 个终端和 10 个编辑器的 bundleId 静态映射，实现 `categorize(bundleId:)` 方法
- ✅ Task 4: 创建 `AppDiscoveryService`，实现 `/Applications` 和 `~/Applications` 扫描、按类型+名称排序、bundleId 去重、NSOpenPanel 手动添加
- ✅ Task 5: 新增 14 个单元测试（9 个 AppCategory/AppCategorizer 测试 + 5 个 AppInfo 测试），覆盖编解码、分类、排序和向后兼容
- ✅ Task 6: xcodebuild 编译零错误，25 个测试全部通过，RCMMShared 无 AppKit/SwiftUI 依赖

### Change Log

- 2026-02-17: Story 2.1 实现完成 — 应用发现服务与应用信息模型
- 2026-02-17: Code Review — 修复 6 个问题（3 HIGH + 3 MEDIUM），详见 Senior Developer Review

### Senior Developer Review (AI)

**Reviewer:** Sunven — 2026-02-17
**Outcome:** Changes Requested → Fixed

**Findings (8 total: 3H / 3M / 2L):**

1. **[H1][FIXED]** AC#4 要求的 `icon` 计算属性未实现 — 新增 `RCMMApp/Extensions/AppInfo+Icon.swift`，通过 extension 在 RCMMApp 层提供（避免 RCMMShared 引入 AppKit）
2. **[H2][FIXED]** Dev Agent Record 测试数量虚报：声称 16 个（11+5），实际 14 个（9+5）— 已修正 Completion Notes
3. **[H3][FIXED]** `AppDiscoveryService` 缺少 `Sendable` 合规 — 已添加 `@unchecked Sendable`
4. **[M1][FIXED]** `scanApplications()` 同步方法可能阻塞主线程 — 已添加文档注释说明调用者应在后台线程调用
5. **[M2][FIXED]** 去重逻辑对无 bundleId 的应用不去重 — 已增加基于应用名称的去重逻辑
6. **[M3][FIXED]** `selectApplicationManually()` 缺少日志记录 — 已添加选择/取消的日志
7. **[L1]** 损坏的 .app bundle 无特别日志 — 低优先级，不阻塞
8. **[L2]** AppDiscoveryService 本身无单元测试（依赖 NSWorkspace，架构限制）— 低优先级，不阻塞

### File List

- RCMMShared/Sources/Models/AppCategory.swift [新增]
- RCMMShared/Sources/Models/AppInfo.swift [修改]
- RCMMShared/Sources/Services/AppCategorizer.swift [新增]
- RCMMApp/Services/AppDiscoveryService.swift [新增]
- RCMMApp/Extensions/AppInfo+Icon.swift [新增][Review 修复]
- RCMMShared/Tests/RCMMSharedTests/AppCategoryTests.swift [新增]
- RCMMShared/Tests/RCMMSharedTests/AppInfoTests.swift [新增]
