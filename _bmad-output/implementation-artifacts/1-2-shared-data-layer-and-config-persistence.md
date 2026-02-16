# Story 1.2: 共享数据层与配置持久化

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 开发者,
I want 实现 App Group 共享数据层，包括数据模型、配置服务和共享常量,
So that 主应用和 Extension 可以通过 App Group UserDefaults 共享菜单配置数据。

## Acceptance Criteria

1. **MenuItemConfig 数据模型** — `MenuItemConfig` 实现 `Codable`, `Identifiable`, `Hashable`，包含 `id`(UUID)、`appName`(String)、`bundleId`(String?)、`appPath`(String)、`customCommand`(String?, 可选)、`sortOrder`(Int) 字段
2. **SharedConfigService 配置读写** — `SharedConfigService` 可通过 `UserDefaults(suiteName:)` 保存和读取 `[MenuItemConfig]` 数组，数据以 JSON Data 格式存储
3. **SharedKeys 常量定义** — 所有 App Group 键名定义为 `SharedKeys` 枚举的静态常量，格式 `rcmm.<domain>.<key>`
4. **NotificationNames 常量定义** — 所有 Darwin Notification 名称定义为 `NotificationNames` 枚举的静态常量，格式 `com.sunven.rcmm.<eventName>`
5. **DarwinNotificationCenter 跨进程通知** — `DarwinNotificationCenter` 可发送和监听跨进程通知，使用 `CFNotificationCenterGetDarwinNotifyCenter`，回调标记 `@Sendable`
6. **RCMMShared 无 UI 依赖** — RCMMShared 不依赖 SwiftUI、AppKit 或 FinderSync，仅依赖 Foundation
7. **单元测试验证** — 单元测试验证 `MenuItemConfig` 编解码（含缺失可选字段场景）和 `SharedConfigService` 读写（含空数据、覆盖写入场景），使用 Swift Testing 框架（`@Test` 宏）

## Tasks / Subtasks

- [x] Task 1: 创建共享常量 (AC: #3, #4, #6)
  - [x] 1.1 替换 `RCMMShared/Sources/Constants/ConstantsPlaceholder.swift` 为 `AppGroupConstants.swift`，定义 `appGroupID` 常量
  - [x] 1.2 创建 `RCMMShared/Sources/Constants/SharedKeys.swift`，定义所有 UserDefaults 键名静态常量
  - [x] 1.3 创建 `RCMMShared/Sources/Constants/NotificationNames.swift`，定义所有 Darwin Notification 名称静态常量
  - [x] 1.4 删除 `ConstantsPlaceholder.swift`

- [x] Task 2: 创建数据模型 (AC: #1, #6)
  - [x] 2.1 替换 `RCMMShared/Sources/Models/ModelsPlaceholder.swift` 为 `MenuItemConfig.swift`
  - [x] 2.2 实现 `MenuItemConfig` struct：`Codable`, `Identifiable`, `Hashable`，包含 `id`, `appName`, `bundleId`, `appPath`, `customCommand`, `sortOrder` 字段
  - [x] 2.3 创建 `RCMMShared/Sources/Models/AppInfo.swift`，定义应用信息模型（用于应用发现，本 story 仅创建结构占位）
  - [x] 2.4 创建 `RCMMShared/Sources/Models/ExtensionStatus.swift`，定义扩展状态枚举 `.enabled` / `.disabled` / `.unknown`
  - [x] 2.5 创建 `RCMMShared/Sources/Models/ErrorRecord.swift`，定义错误记录模型
  - [x] 2.6 创建 `RCMMShared/Sources/Models/PopoverState.swift`，定义弹出窗口状态枚举
  - [x] 2.7 删除 `ModelsPlaceholder.swift`

- [x] Task 3: 实现 SharedConfigService (AC: #2, #6)
  - [x] 3.1 替换 `RCMMShared/Sources/Services/ServicesPlaceholder.swift` 为 `SharedConfigService.swift`
  - [x] 3.2 实现 `save(_ items: [MenuItemConfig])` — 使用 `JSONEncoder` 编码为 Data，写入 `UserDefaults(suiteName:)`
  - [x] 3.3 实现 `load() -> [MenuItemConfig]` — 从 UserDefaults 读取 Data，使用 `JSONDecoder` 解码，无数据时返回空数组
  - [x] 3.4 构造器接受 `UserDefaults` 参数以支持测试注入
  - [x] 3.5 删除 `ServicesPlaceholder.swift`

- [x] Task 4: 实现 DarwinNotificationCenter (AC: #5, #6)
  - [x] 4.1 创建 `RCMMShared/Sources/Services/DarwinNotificationCenter.swift`
  - [x] 4.2 实现 `post(_ name: String)` — 通过 `CFNotificationCenterPostNotification` 发送通知
  - [x] 4.3 实现 `addObserver(name:callback:) -> DarwinObservation` — 通过 `CFNotificationCenterAddObserver` 注册观察
  - [x] 4.4 实现 `DarwinObservation` token 类，支持 `cancel()` 和 `deinit` 自动取消
  - [x] 4.5 确保回调使用 `@Sendable` 闭包，观察者回调不在主线程

- [x] Task 5: 实现 SharedErrorQueue（占位结构）(AC: #6)
  - [x] 5.1 创建 `RCMMShared/Sources/Services/SharedErrorQueue.swift`
  - [x] 5.2 实现基础的错误队列读写（`append(_ error: ErrorRecord)`, `loadAll() -> [ErrorRecord]`, `removeAll()`）
  - [x] 5.3 错误队列最多保留 20 条记录，FIFO 淘汰

- [x] Task 6: 编写单元测试 (AC: #7)
  - [x] 6.1 替换 `RCMMShared/Tests/RCMMSharedTests/RCMMSharedTests.swift` 为具体测试文件
  - [x] 6.2 创建 `MenuItemConfigTests.swift` — 测试 round-trip 编解码、缺失可选字段解码、多实例编解码
  - [x] 6.3 创建 `SharedConfigServiceTests.swift` — 测试保存/读取、空数据返回空数组、覆盖写入
  - [x] 6.4 创建 `SharedErrorQueueTests.swift` — 测试追加/读取/FIFO 淘汰
  - [x] 6.5 删除占位测试文件 `RCMMSharedTests.swift`
  - [x] 6.6 运行 `swift test` 验证全部通过

- [x] Task 7: 编译验证 (AC: #6)
  - [x] 7.1 `swift build` RCMMShared — 零错误
  - [x] 7.2 `xcodebuild -scheme rcmm` — 零错误（验证主 App 和 Extension 均可链接 RCMMShared）
  - [x] 7.3 确认 RCMMShared 无 SwiftUI/AppKit/FinderSync import

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 实现的共享数据层是 rcmm 所有功能的基础设施。后续 Story 1.3（Finder 右键菜单端到端验证）依赖本 Story 的 `SharedConfigService` 读取菜单配置，`DarwinNotificationCenter` 接收配置变更通知。Epic 2-7 的所有功能都建立在本 Story 创建的数据模型和服务之上。

**进程边界（最关键的架构约束）：**

```
┌─────────────────────────────┐     ┌──────────────────────────────┐
│     主 App 进程（非沙盒）      │     │    Extension 进程（沙盒）      │
│                              │     │                               │
│  SharedConfigService.save()  │     │  SharedConfigService.load()   │
│  DarwinNotificationCenter    │     │  DarwinNotificationCenter     │
│    .post(configChanged)      │     │    .addObserver(configChanged)│
│                              │     │                               │
│  ✅ 写入 App Group UD        │     │  ✅ 读取 App Group UD         │
│  ✅ 写入错误队列              │     │  ✅ 写入错误队列              │
└──────────────┬───────────────┘     └──────────────┬────────────────┘
               │                                     │
               └──────────── App Group ──────────────┘
                    UserDefaults + Darwin Notifications
```

**数据流设计：**

1. 主 App 配置变更 → `SharedConfigService.save()` → App Group UserDefaults
2. `DarwinNotificationCenter.post(.configChanged)` → 跨进程信号
3. Extension 收到通知 → `SharedConfigService.load()` → 读取最新配置

**Package 依赖边界（强制）：**
- RCMMShared 只能 `import Foundation`
- 禁止 `import SwiftUI`、`import AppKit`、`import FinderSync`
- 本 Story 创建的所有文件都在 `RCMMShared/Sources/` 下

### 关键技术决策

**App Group UserDefaults 使用：**

- App Group ID: `group.com.sunven.rcmm`
- **重要：macOS 15 Sequoia 已知问题** — App Group UserDefaults 存在跨进程 plist 文件路径不一致的问题。如果主 App 和 Extension 写入的 plist 文件不同，会导致数据无法共享。当前使用 `UserDefaults(suiteName: "group.com.sunven.rcmm")` 格式。如果测试中发现跨进程读写失败，需要检查是否需要添加 Team ID 前缀（如 `"<TEAMID>.group.com.sunven.rcmm"`）。
- **不要调用 `synchronize()`** — Apple 明确文档说明不需要手动调用，系统自动管理。
- 配置数据量极小（~4KB），读取开销可忽略（< 1ms），Extension 每次直接读不缓存。

**JSON 编解码策略：**

- 使用 Swift 默认 camelCase 字段映射，不自定义 `CodingKeys`
- 新增字段必须为可选类型或提供默认值，确保向前兼容
- 数据存储为 `Data` 类型写入 UserDefaults，键名 `rcmm.menu.items`

**Darwin Notification 实现：**

- 使用 `CFNotificationCenterGetDarwinNotifyCenter()` — 唯一可靠的跨沙盒通知方式
- Darwin 通知是纯信号，不携带数据。数据通过 App Group UserDefaults 传递。
- 回调发生在任意后台线程，UI 更新必须 `DispatchQueue.main.async`
- 回调必须是 C 函数指针（`@convention(c)`），不能使用捕获上下文的闭包
- 使用 `Unmanaged` 指针模式桥接 observer 身份到回调
- `DarwinNotificationCenter` 标记为 `Sendable`（无可变状态）
- `DarwinObservation` token 使用 `@unchecked Sendable`

**Darwin Notification 完整实现参考：**

```swift
import Foundation

// 顶层 C 函数回调（必须：@convention(c)，无捕获）
private func darwinCallback(
    center: CFNotificationCenter?,
    observer: UnsafeMutableRawPointer?,
    name: CFNotificationName?,
    object: UnsafeRawPointer?,
    userInfo: CFDictionary?
) {
    guard let pointer = observer else { return }
    let closure = Unmanaged<DarwinObservation.Closure>
        .fromOpaque(pointer)
        .takeUnretainedValue()
    closure.invoke()
}

public final class DarwinNotificationCenter: Sendable {
    public static let shared = DarwinNotificationCenter()
    private init() {}

    private var center: CFNotificationCenter {
        CFNotificationCenterGetDarwinNotifyCenter()
    }

    public func post(_ name: String) {
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(name as CFString),
            nil, nil, true
        )
    }

    public func addObserver(
        name: String,
        callback: @escaping @Sendable () -> Void
    ) -> DarwinObservation {
        let observation = DarwinObservation(callback: callback)
        let pointer = UnsafeRawPointer(
            Unmanaged.passUnretained(observation.closure).toOpaque()
        )
        CFNotificationCenterAddObserver(
            center, pointer, darwinCallback,
            name as CFString, nil, .deliverImmediately
        )
        return observation
    }
}

public final class DarwinObservation: @unchecked Sendable {
    fileprivate final class Closure: @unchecked Sendable {
        let invoke: @Sendable () -> Void
        init(_ fn: @escaping @Sendable () -> Void) { self.invoke = fn }
    }

    fileprivate let closure: Closure

    init(callback: @escaping @Sendable () -> Void) {
        self.closure = Closure(callback)
    }

    deinit { cancel() }

    public func cancel() {
        let closureRef = closure
        DispatchQueue.main.async {
            let pointer = UnsafeRawPointer(
                Unmanaged.passUnretained(closureRef).toOpaque()
            )
            CFNotificationCenterRemoveObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                pointer, nil, nil
            )
        }
    }
}
```

**SharedConfigService 构造器注入模式：**

```swift
public final class SharedConfigService {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: AppGroupConstants.appGroupID)!
    }

    public func save(_ items: [MenuItemConfig]) {
        let data = try? JSONEncoder().encode(items)
        defaults.set(data, forKey: SharedKeys.menuItems)
    }

    public func load() -> [MenuItemConfig] {
        guard let data = defaults.data(forKey: SharedKeys.menuItems) else {
            return []
        }
        return (try? JSONDecoder().decode([MenuItemConfig].self, from: data)) ?? []
    }
}
```

### 命名规范参考

| 类别 | 规范 | 本 Story 示例 |
|---|---|---|
| 类型 | UpperCamelCase | `MenuItemConfig`, `SharedConfigService`, `DarwinNotificationCenter` |
| 枚举 case | lowerCamelCase | `.enabled`, `.disabled`, `.unknown` |
| 属性 | lowerCamelCase | `appName`, `bundleId`, `sortOrder` |
| App Group 键 | `rcmm.<domain>.<key>` | `rcmm.menu.items`, `rcmm.error.queue` |
| Darwin 通知 | `com.sunven.rcmm.<event>` | `com.sunven.rcmm.configChanged` |
| 文件名 | 与主类型同名 | `MenuItemConfig.swift`, `SharedConfigService.swift` |

### SharedKeys 常量参考

```swift
public enum SharedKeys {
    public static let menuItems = "rcmm.menu.items"
    public static let errorQueue = "rcmm.error.queue"
    public static let onboardingCompleted = "rcmm.settings.onboardingCompleted"
    public static let loginItemEnabled = "rcmm.settings.loginItemEnabled"
}
```

### NotificationNames 常量参考

```swift
public enum NotificationNames {
    public static let configChanged = "com.sunven.rcmm.configChanged"
    public static let scriptUpdated = "com.sunven.rcmm.scriptUpdated"
}
```

### MenuItemConfig 模型参考

```swift
public struct MenuItemConfig: Codable, Identifiable, Hashable {
    public let id: UUID
    public var appName: String
    public var bundleId: String?
    public var appPath: String
    public var customCommand: String?
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleId: String? = nil,
        appPath: String,
        customCommand: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.appPath = appPath
        self.customCommand = customCommand
        self.sortOrder = sortOrder
    }
}
```

### ExtensionStatus 枚举参考

```swift
public enum ExtensionStatus: String, Codable, Sendable {
    case enabled
    case disabled
    case unknown
}
```

### ErrorRecord 模型参考

```swift
public struct ErrorRecord: Codable, Identifiable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let source: String      // "extension" 或 "app"
    public let message: String
    public let context: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: String,
        message: String,
        context: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.message = message
        self.context = context
    }
}
```

### PopoverState 枚举参考

```swift
public enum PopoverState: Sendable {
    case normal
    case healthWarning
    case onboarding
}
```

### 测试模式参考

```swift
import Testing
@testable import RCMMShared

@Suite("MenuItemConfig 编解码测试")
struct MenuItemConfigTests {

    @Test("Round-trip 编解码保持值一致")
    func roundTrip() throws {
        let item = MenuItemConfig(
            appName: "Terminal",
            appPath: "/Applications/Utilities/Terminal.app",
            sortOrder: 0
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MenuItemConfig.self, from: data)
        #expect(decoded == item)
    }

    @Test("解码时缺失可选字段使用 nil")
    func missingOptionalFields() throws {
        let json = """
        {"id":"550E8400-E29B-41D4-A716-446655440000","appName":"Test","appPath":"/test","sortOrder":0}
        """
        let item = try JSONDecoder().decode(MenuItemConfig.self, from: Data(json.utf8))
        #expect(item.bundleId == nil)
        #expect(item.customCommand == nil)
    }
}

@Suite("SharedConfigService 读写测试", .serialized)
struct SharedConfigServiceTests {
    let defaults: UserDefaults
    let service: SharedConfigService

    init() {
        let suiteName = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        service = SharedConfigService(defaults: defaults)
    }

    @Test("保存后可正确读取")
    func saveAndLoad() throws {
        let items = [MenuItemConfig(appName: "Terminal", appPath: "/Applications/Utilities/Terminal.app", sortOrder: 0)]
        service.save(items)
        let loaded = service.load()
        #expect(loaded == items)
    }

    @Test("无数据时返回空数组")
    func emptyDefaults() {
        let loaded = service.load()
        #expect(loaded.isEmpty)
    }

    @Test("覆盖写入替换旧数据")
    func overwrite() {
        service.save([MenuItemConfig(appName: "Old", appPath: "/old", sortOrder: 0)])
        service.save([MenuItemConfig(appName: "New", appPath: "/new", sortOrder: 0)])
        let loaded = service.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.appName == "New")
    }
}
```

### 前序 Story 1.1 关键经验

- 占位文件命名需按目录区分（`ModelsPlaceholder.swift` 等），避免 SPM 编译冲突 — 本 Story 需要删除这些占位文件并替换为实际实现
- RCMMShared 源码路径为 `Sources/`（不是 `Sources/RCMMShared/`），在 Package.swift 中 `path: "Sources"` 已配置
- Swift 6 编译器 + Swift 5 语言模式 — `@Sendable` 闭包标注是必要的，但不需要完整的 Swift 6 严格并发模式
- 测试使用 Swift Testing 框架（`import Testing`），不是 XCTest
- Git commit 风格：`feat: 功能描述 (Story X.X)`

### Git 分析（最近提交）

```
99e31fd feat: initialize Xcode project with triple-target architecture (Story 1.1)
21e5e87 docs: incorporate additional user feedback into product brief and clarify MVP feature set
4f7d124 docs: update product brief with user feedback and refine MVP features
ba02d2d docs: add product brief and technical research report
e400814 feat: init
```

Story 1.1 的实现创建了完整的三目标项目骨架。本 Story 在此基础上替换占位文件为实际实现。

### 最新技术信息

**macOS 15 Sequoia UserDefaults 已知问题：**
- App Group UserDefaults 在 macOS 15 上存在跨进程 plist 路径不一致的 bug。主 App 和 Extension 可能默默读写不同的 plist 文件。
- 当前使用 `UserDefaults(suiteName: "group.com.sunven.rcmm")` 标准格式。如果跨进程共享失败，可能需要在 suiteName 中加入 Team ID 前缀。
- **不要调用 `synchronize()`** — Apple 文档明确不需要。

**Darwin Notification Swift 6 兼容性：**
- `CFNotificationCenterAddObserver` 回调必须是 C 函数指针（`@convention(c)`），不能是 Swift 闭包。
- 使用 `Unmanaged` 指针桥接模式传递 observer 上下文。
- 回调在任意线程触发，UI 更新需要调度到主线程。

**Swift Testing 框架：**
- `@Suite` + `struct` 模式提供值语义，每个 `@Test` 函数获得独立的 suite 实例。
- `init()` 作为 per-test setup，无需 `tearDown`。
- `.serialized` trait 强制 suite 内测试串行执行（共享外部状态时必要）。
- 测试参数必须符合 `Sendable`。

**NSUserAppleScriptTask（Story 1.3 预备知识）：**
- Extension 脚本目录：`~/Library/Application Scripts/com.sunven.rcmm.FinderExtension/`
- 主 App 脚本目录：`~/Library/Application Scripts/com.sunven.rcmm/`
- 脚本通过 XPC 在沙盒外执行，因此可以调用 `open -a` 等系统命令。
- 实例只能执行一次，每次执行需创建新实例。

### 反模式清单（禁止）

- ❌ 在 RCMMShared 中 `import SwiftUI` 或 `import AppKit`
- ❌ 硬编码 App Group ID 字符串（必须使用 `AppGroupConstants.appGroupID`）
- ❌ 硬编码 UserDefaults 键名字符串（必须使用 `SharedKeys` 常量）
- ❌ 硬编码 Darwin Notification 名称（必须使用 `NotificationNames` 常量）
- ❌ 调用 `UserDefaults.synchronize()`
- ❌ 使用 `ObservableObject` / `@Published`（本 Story 不涉及 UI，但注意后续 Story 统一使用 `@Observable`）
- ❌ 使用 `try!` 或 force unwrap（除非有编程错误断言注释）
- ❌ 在 Darwin Notification 回调中直接更新 UI（必须调度到主线程）
- ❌ 自定义 `CodingKeys`（使用 Swift 默认 camelCase 映射）
- ❌ 在 `MenuItemConfig` 中使用非可选新字段（未来新增字段必须可选或有默认值）

### Project Structure Notes

**本 Story 完成后的 RCMMShared 结构：**

```
RCMMShared/
├── Package.swift
├── Sources/
│   ├── Models/
│   │   ├── MenuItemConfig.swift         # 菜单项配置模型
│   │   ├── AppInfo.swift                # 应用信息模型（结构占位）
│   │   ├── ExtensionStatus.swift        # 扩展状态枚举
│   │   ├── ErrorRecord.swift            # 错误记录模型
│   │   └── PopoverState.swift           # 弹出窗口状态枚举
│   ├── Services/
│   │   ├── SharedConfigService.swift    # App Group UserDefaults 读写
│   │   ├── DarwinNotificationCenter.swift # 跨进程通知封装
│   │   └── SharedErrorQueue.swift       # 错误队列读写
│   └── Constants/
│       ├── AppGroupConstants.swift      # App Group ID
│       ├── SharedKeys.swift             # UserDefaults 键名常量
│       └── NotificationNames.swift      # Darwin Notification 名称常量
└── Tests/
    └── RCMMSharedTests/
        ├── MenuItemConfigTests.swift    # 模型编解码测试
        ├── SharedConfigServiceTests.swift # 配置读写测试
        └── SharedErrorQueueTests.swift  # 错误队列测试
```

**删除的文件（Story 1.1 占位文件）：**
- `RCMMShared/Sources/Models/ModelsPlaceholder.swift`
- `RCMMShared/Sources/Services/ServicesPlaceholder.swift`
- `RCMMShared/Sources/Constants/ConstantsPlaceholder.swift`
- `RCMMShared/Tests/RCMMSharedTests/RCMMSharedTests.swift`

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Data Architecture] — 数据持久化决策（UserDefaults + JSON Data）
- [Source: _bmad-output/planning-artifacts/architecture.md#Communication Patterns] — Darwin Notification 协议和状态管理
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns & Consistency Rules] — 命名规范、结构模式、反模式
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries] — 完整目录结构和边界定义
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.2] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/prd.md#数据管理] — FR-DATA-001 配置持久保存
- [Source: _bmad-output/planning-artifacts/architecture.md#Error Handling & Logging] — 错误队列设计
- [Source: _bmad-output/implementation-artifacts/1-1-xcode-project-init-and-triple-target-setup.md] — 前序 Story 项目结构和经验

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- 测试文件初始缺少 `import Foundation`，导致 Swift 6 测试目标无法找到 `UserDefaults`、`JSONEncoder` 等类型。添加 `import Foundation` 后修复。
- `SharedConfigService` 和 `SharedErrorQueue` 标记为 `Sendable` 时，Swift 6 严格并发模式下 `UserDefaults` 非 Sendable 导致编译警告。改用 `@unchecked Sendable`（`UserDefaults` 内部是线程安全的，且实例在 `init` 后不可变）。
- `xcodebuild -scheme rcmm` 首次失败因代码签名问题（需要开发证书），非代码问题。使用 `CODE_SIGNING_REQUIRED=NO` 后成功编译。

### Completion Notes List

- ✅ Task 1: 创建了 `AppGroupConstants.swift`、`SharedKeys.swift`、`NotificationNames.swift`，删除了 `ConstantsPlaceholder.swift`
- ✅ Task 2: 创建了 `MenuItemConfig.swift`（含完整 Codable/Identifiable/Hashable/Sendable 协议）、`AppInfo.swift`（结构占位）、`ExtensionStatus.swift`、`ErrorRecord.swift`、`PopoverState.swift`，删除了 `ModelsPlaceholder.swift`
- ✅ Task 3: 实现了 `SharedConfigService`，支持 UserDefaults 注入测试，save/load 使用 JSON 编解码
- ✅ Task 4: 实现了 `DarwinNotificationCenter`（单例）和 `DarwinObservation` token，使用 C 函数指针回调模式和 `Unmanaged` 桥接
- ✅ Task 5: 实现了 `SharedErrorQueue`，支持 append/loadAll/removeAll，FIFO 淘汰限制 20 条
- ✅ Task 6: 编写了 11 个单元测试（3 个 Suite），全部通过
- ✅ Task 7: `swift build` 零错误，`xcodebuild` 编译成功，确认无 SwiftUI/AppKit/FinderSync 导入

### File List

**新增文件：**
- `RCMMShared/Sources/Constants/AppGroupConstants.swift`
- `RCMMShared/Sources/Constants/SharedKeys.swift`
- `RCMMShared/Sources/Constants/NotificationNames.swift`
- `RCMMShared/Sources/Models/MenuItemConfig.swift`
- `RCMMShared/Sources/Models/AppInfo.swift`
- `RCMMShared/Sources/Models/ExtensionStatus.swift`
- `RCMMShared/Sources/Models/ErrorRecord.swift`
- `RCMMShared/Sources/Models/PopoverState.swift`
- `RCMMShared/Sources/Services/SharedConfigService.swift`
- `RCMMShared/Sources/Services/DarwinNotificationCenter.swift`
- `RCMMShared/Sources/Services/SharedErrorQueue.swift`
- `RCMMShared/Tests/RCMMSharedTests/MenuItemConfigTests.swift`
- `RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift`
- `RCMMShared/Tests/RCMMSharedTests/SharedErrorQueueTests.swift`

**删除文件：**
- `RCMMShared/Sources/Constants/ConstantsPlaceholder.swift`
- `RCMMShared/Sources/Models/ModelsPlaceholder.swift`
- `RCMMShared/Sources/Services/ServicesPlaceholder.swift`
- `RCMMShared/Tests/RCMMSharedTests/RCMMSharedTests.swift`

**修改文件：**
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/1-2-shared-data-layer-and-config-persistence.md`

## Change Log

- 2026-02-16: 完成 Story 1.2 全部实现 — 共享数据层（常量、模型、服务）和配置持久化，含 11 个单元测试全部通过
- 2026-02-16: Code Review 修复 — (1) DarwinObservation 添加 isCancelled 防重复取消保护和存储 observerPointer；(2) SharedConfigService.save() 编码失败时不清除现有数据；(3) SharedErrorQueue.append() 编码失败时不清除现有数据，添加竞态条件文档注释；(4) 测试添加 UserDefaults suite 清理
