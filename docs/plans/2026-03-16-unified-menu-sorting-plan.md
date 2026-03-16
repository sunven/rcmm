# 统一菜单排序实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 让系统内置功能（拷贝路径等）与自定义命令统一参与菜单排序，通过 `MenuEntry` 枚举实现。

**架构：** 在 RCMMShared 中引入 `BuiltInType` 枚举 + `BuiltInMenuItem` 结构体 + `MenuEntry` 枚举。用单一的 `[MenuEntry]` JSON 数组替代原来分离的 `[MenuItemConfig]` + `copyPathEnabled` 持久化方案。更新 AppState、FinderSync 和设置界面以使用统一模型。

**技术栈：** Swift 6、SwiftUI、FinderSync、Swift Testing 框架、App Group UserDefaults

---

### 任务 1：创建 BuiltInType 枚举

**文件：**
- 新建：`RCMMShared/Sources/Models/BuiltInType.swift`
- 测试：`RCMMShared/Tests/RCMMSharedTests/BuiltInTypeTests.swift`

**步骤 1：编写失败测试**

新建 `RCMMShared/Tests/RCMMSharedTests/BuiltInTypeTests.swift`：

```swift
import Foundation
import Testing
@testable import RCMMShared

@Suite("BuiltInType 编解码测试")
struct BuiltInTypeTests {

    @Test("copyPath rawValue 为 copyPath")
    func copyPathRawValue() {
        #expect(BuiltInType.copyPath.rawValue == "copyPath")
    }

    @Test("Round-trip 编解码保持值一致")
    func roundTrip() throws {
        let original = BuiltInType.copyPath
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BuiltInType.self, from: data)
        #expect(decoded == original)
    }
}
```

**步骤 2：运行测试，验证失败**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20`
预期：失败 — `BuiltInType` 未定义

**步骤 3：编写最小实现**

新建 `RCMMShared/Sources/Models/BuiltInType.swift`：

```swift
import Foundation

public enum BuiltInType: String, Codable, Sendable, CaseIterable {
    case copyPath
}
```

**步骤 4：运行测试，验证通过**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20`
预期：通过

**步骤 5：提交**

```bash
git add RCMMShared/Sources/Models/BuiltInType.swift RCMMShared/Tests/RCMMSharedTests/BuiltInTypeTests.swift
git commit -m "feat: add BuiltInType enum for system menu features"
```

---

### 任务 2：创建 BuiltInMenuItem 结构体

**文件：**
- 新建：`RCMMShared/Sources/Models/BuiltInMenuItem.swift`
- 测试：`RCMMShared/Tests/RCMMSharedTests/BuiltInMenuItemTests.swift`

**步骤 1：编写失败测试**

新建 `RCMMShared/Tests/RCMMSharedTests/BuiltInMenuItemTests.swift`：

```swift
import Foundation
import Testing
@testable import RCMMShared

@Suite("BuiltInMenuItem 编解码测试")
struct BuiltInMenuItemTests {

    @Test("copyPath displayName 为 拷贝路径")
    func copyPathDisplayName() {
        let item = BuiltInMenuItem(type: .copyPath, isEnabled: true)
        #expect(item.displayName == "拷贝路径")
    }

    @Test("Round-trip 编解码保持值一致")
    func roundTrip() throws {
        let item = BuiltInMenuItem(type: .copyPath, isEnabled: true)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BuiltInMenuItem.self, from: data)
        #expect(decoded == item)
    }

    @Test("禁用状态正确编解码")
    func disabledRoundTrip() throws {
        let item = BuiltInMenuItem(type: .copyPath, isEnabled: false)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BuiltInMenuItem.self, from: data)
        #expect(decoded.isEnabled == false)
    }
}
```

**步骤 2：运行测试，验证失败**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20`
预期：失败 — `BuiltInMenuItem` 未定义

**步骤 3：编写最小实现**

新建 `RCMMShared/Sources/Models/BuiltInMenuItem.swift`：

```swift
import Foundation

public struct BuiltInMenuItem: Codable, Hashable, Sendable {
    public let type: BuiltInType
    public var isEnabled: Bool

    public init(type: BuiltInType, isEnabled: Bool) {
        self.type = type
        self.isEnabled = isEnabled
    }

    public var displayName: String {
        switch type {
        case .copyPath: return "拷贝路径"
        }
    }

    public var iconName: String {
        switch type {
        case .copyPath: return "doc.on.clipboard"
        }
    }
}
```

**步骤 4：运行测试，验证通过**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20`
预期：通过

**步骤 5：提交**

```bash
git add RCMMShared/Sources/Models/BuiltInMenuItem.swift RCMMShared/Tests/RCMMSharedTests/BuiltInMenuItemTests.swift
git commit -m "feat: add BuiltInMenuItem struct with displayName and iconName"
```

---

### 任务 3：创建 MenuEntry 枚举

**文件：**
- 新建：`RCMMShared/Sources/Models/MenuEntry.swift`
- 测试：`RCMMShared/Tests/RCMMSharedTests/MenuEntryTests.swift`

**步骤 1：编写失败测试**

新建 `RCMMShared/Tests/RCMMSharedTests/MenuEntryTests.swift`：

```swift
import Foundation
import Testing
@testable import RCMMShared

@Suite("MenuEntry 编解码测试")
struct MenuEntryTests {

    @Test("builtIn entry id 格式正确")
    func builtInId() {
        let entry = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))
        #expect(entry.id == "builtIn.copyPath")
    }

    @Test("custom entry id 使用 UUID")
    func customId() {
        let uuid = UUID()
        let config = MenuItemConfig(id: uuid, appName: "Test", appPath: "/test")
        let entry = MenuEntry.custom(config)
        #expect(entry.id == uuid.uuidString)
    }

    @Test("builtIn entry isEnabled 正确")
    func builtInIsEnabled() {
        let enabled = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))
        let disabled = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: false))
        #expect(enabled.isEnabled == true)
        #expect(disabled.isEnabled == false)
    }

    @Test("custom entry isEnabled 正确")
    func customIsEnabled() {
        let enabled = MenuEntry.custom(MenuItemConfig(appName: "T", appPath: "/t", isEnabled: true))
        let disabled = MenuEntry.custom(MenuItemConfig(appName: "T", appPath: "/t", isEnabled: false))
        #expect(enabled.isEnabled == true)
        #expect(disabled.isEnabled == false)
    }

    @Test("builtIn displayName 正确")
    func builtInDisplayName() {
        let entry = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))
        #expect(entry.displayName == "拷贝路径")
    }

    @Test("custom displayName 使用 appName")
    func customDisplayName() {
        let entry = MenuEntry.custom(MenuItemConfig(appName: "Terminal", appPath: "/t"))
        #expect(entry.displayName == "Terminal")
    }

    @Test("Round-trip 编解码 builtIn entry")
    func roundTripBuiltIn() throws {
        let entry = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(MenuEntry.self, from: data)
        #expect(decoded == entry)
    }

    @Test("Round-trip 编解码 custom entry")
    func roundTripCustom() throws {
        let config = MenuItemConfig(appName: "Terminal", appPath: "/Applications/Utilities/Terminal.app")
        let entry = MenuEntry.custom(config)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(MenuEntry.self, from: data)
        #expect(decoded == entry)
    }

    @Test("混合数组编解码保持顺序和类型")
    func mixedArrayRoundTrip() throws {
        let entries: [MenuEntry] = [
            .custom(MenuItemConfig(appName: "Terminal", appPath: "/t")),
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
            .custom(MenuItemConfig(appName: "iTerm", appPath: "/i")),
        ]
        let data = try JSONEncoder().encode(entries)
        let decoded = try JSONDecoder().decode([MenuEntry].self, from: data)
        #expect(decoded.count == 3)
        #expect(decoded[0].id == entries[0].id)
        #expect(decoded[1].id == "builtIn.copyPath")
        #expect(decoded[2].id == entries[2].id)
    }

    @Test("isBuiltIn 判断正确")
    func isBuiltIn() {
        let builtIn = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))
        let custom = MenuEntry.custom(MenuItemConfig(appName: "T", appPath: "/t"))
        #expect(builtIn.isBuiltIn == true)
        #expect(custom.isBuiltIn == false)
    }
}
```

**步骤 2：运行测试，验证失败**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20`
预期：失败 — `MenuEntry` 未定义

**步骤 3：编写最小实现**

新建 `RCMMShared/Sources/Models/MenuEntry.swift`：

```swift
import Foundation

public enum MenuEntry: Codable, Identifiable, Hashable, Sendable {
    case builtIn(BuiltInMenuItem)
    case custom(MenuItemConfig)

    public var id: String {
        switch self {
        case .builtIn(let item):
            return "builtIn.\(item.type.rawValue)"
        case .custom(let config):
            return config.id.uuidString
        }
    }

    public var isEnabled: Bool {
        switch self {
        case .builtIn(let item): return item.isEnabled
        case .custom(let config): return config.isEnabled
        }
    }

    public var displayName: String {
        switch self {
        case .builtIn(let item): return item.displayName
        case .custom(let config): return config.appName
        }
    }

    public var isBuiltIn: Bool {
        if case .builtIn = self { return true }
        return false
    }
}
```

**步骤 4：运行测试，验证通过**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20`
预期：通过

**步骤 5：提交**

```bash
git add RCMMShared/Sources/Models/MenuEntry.swift RCMMShared/Tests/RCMMSharedTests/MenuEntryTests.swift
git commit -m "feat: add MenuEntry enum unifying builtIn and custom menu items"
```

---

### 任务 4：从 MenuItemConfig 中移除 sortOrder

**文件：**
- 修改：`RCMMShared/Sources/Models/MenuItemConfig.swift`
- 修改：`RCMMShared/Tests/RCMMSharedTests/MenuItemConfigTests.swift`

**步骤 1：更新测试，移除所有 sortOrder 引用**

替换 `RCMMShared/Tests/RCMMSharedTests/MenuItemConfigTests.swift` 整个文件：

```swift
import Foundation
import Testing
@testable import RCMMShared

@Suite("MenuItemConfig 编解码测试")
struct MenuItemConfigTests {

    @Test("Round-trip 编解码保持值一致")
    func roundTrip() throws {
        let item = MenuItemConfig(
            appName: "Terminal",
            appPath: "/Applications/Utilities/Terminal.app",
            isEnabled: true
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MenuItemConfig.self, from: data)
        #expect(decoded == item)
        #expect(decoded.isEnabled == true)
    }

    @Test("禁用项编解码正确")
    func disabledItem() throws {
        let item = MenuItemConfig(
            appName: "Disabled App",
            appPath: "/Applications/Disabled.app",
            isEnabled: false
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MenuItemConfig.self, from: data)
        #expect(decoded.isEnabled == false)
    }

    @Test("解码时缺失 isEnabled 默认为 true")
    func missingIsEnabledField() throws {
        let json = """
        {"id":"550E8400-E29B-41D4-A716-446655440000","appName":"Test","appPath":"/test"}
        """
        let item = try JSONDecoder().decode(MenuItemConfig.self, from: Data(json.utf8))
        #expect(item.isEnabled == true)
    }

    @Test("解码时缺失可选字段使用 nil")
    func missingOptionalFields() throws {
        let json = """
        {"id":"550E8400-E29B-41D4-A716-446655440000","appName":"Test","appPath":"/test"}
        """
        let item = try JSONDecoder().decode(MenuItemConfig.self, from: Data(json.utf8))
        #expect(item.bundleId == nil)
        #expect(item.customCommand == nil)
    }

    @Test("多实例编解码保持一致")
    func multipleItems() throws {
        let items = [
            MenuItemConfig(appName: "Terminal", appPath: "/Applications/Utilities/Terminal.app"),
            MenuItemConfig(appName: "iTerm", bundleId: "com.googlecode.iterm2", appPath: "/Applications/iTerm.app", customCommand: "open -a iTerm"),
        ]
        let data = try JSONEncoder().encode(items)
        let decoded = try JSONDecoder().decode([MenuItemConfig].self, from: data)
        #expect(decoded == items)
    }

    @Test("包含所有字段的完整编解码")
    func fullFields() throws {
        let item = MenuItemConfig(
            appName: "VS Code",
            bundleId: "com.microsoft.VSCode",
            appPath: "/Applications/Visual Studio Code.app",
            customCommand: "code",
            isEnabled: false
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MenuItemConfig.self, from: data)
        #expect(decoded == item)
        #expect(decoded.bundleId == "com.microsoft.VSCode")
        #expect(decoded.customCommand == "code")
        #expect(decoded.isEnabled == false)
    }
}
```

**步骤 2：运行测试，验证失败**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20`
预期：失败 — `MenuItemConfig.init` 仍需要 `sortOrder` 参数

**步骤 3：更新 MenuItemConfig，移除 sortOrder**

替换 `RCMMShared/Sources/Models/MenuItemConfig.swift` 整个文件：

```swift
import Foundation

public struct MenuItemConfig: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var appName: String
    public var bundleId: String?
    public var appPath: String
    public var customCommand: String?
    public var isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, appName, bundleId, appPath, customCommand, isEnabled
    }

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleId: String? = nil,
        appPath: String,
        customCommand: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.appPath = appPath
        self.customCommand = customCommand
        self.isEnabled = isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        appName = try container.decode(String.self, forKey: .appName)
        bundleId = try container.decodeIfPresent(String.self, forKey: .bundleId)
        appPath = try container.decode(String.self, forKey: .appPath)
        customCommand = try container.decodeIfPresent(String.self, forKey: .customCommand)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}
```

**步骤 4：运行测试，验证通过**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20`
预期：通过（注意：RCMMApp/FinderExtension 的构建错误是预期的——它们仍引用 `sortOrder`，后续任务会修复）

**步骤 5：提交**

```bash
git add RCMMShared/Sources/Models/MenuItemConfig.swift RCMMShared/Tests/RCMMSharedTests/MenuItemConfigTests.swift
git commit -m "refactor: remove sortOrder from MenuItemConfig, ordering now by array position"
```

---

### 任务 5：更新 SharedConfigService 和 SharedKeys

**文件：**
- 修改：`RCMMShared/Sources/Constants/SharedKeys.swift`
- 修改：`RCMMShared/Sources/Services/SharedConfigService.swift`
- 修改：`RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift`

**步骤 1：更新测试**

替换 `RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift` 整个文件：

```swift
import Foundation
import Testing
@testable import RCMMShared

@Suite("SharedConfigService 读写测试", .serialized)
struct SharedConfigServiceTests {
    let defaults: UserDefaults
    let service: SharedConfigService
    let suiteName: String

    init() {
        suiteName = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        service = SharedConfigService(defaults: defaults)
    }

    private func cleanup() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test("保存后可正确读取 entries")
    func saveAndLoadEntries() throws {
        let entries: [MenuEntry] = [
            .custom(MenuItemConfig(appName: "Terminal", appPath: "/Applications/Utilities/Terminal.app")),
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
        ]
        service.saveEntries(entries)
        let loaded = service.loadEntries()
        #expect(loaded.count == 2)
        #expect(loaded[0].displayName == "Terminal")
        #expect(loaded[1].displayName == "拷贝路径")
        cleanup()
    }

    @Test("无数据时返回空数组")
    func emptyDefaults() {
        let loaded = service.loadEntries()
        #expect(loaded.isEmpty)
        cleanup()
    }

    @Test("覆盖写入替换旧数据")
    func overwrite() {
        service.saveEntries([.custom(MenuItemConfig(appName: "Old", appPath: "/old"))])
        service.saveEntries([.custom(MenuItemConfig(appName: "New", appPath: "/new"))])
        let loaded = service.loadEntries()
        #expect(loaded.count == 1)
        #expect(loaded[0].displayName == "New")
        cleanup()
    }

    @Test("混合数组保持顺序")
    func mixedOrderPreserved() {
        let entries: [MenuEntry] = [
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
            .custom(MenuItemConfig(appName: "Terminal", appPath: "/t")),
            .custom(MenuItemConfig(appName: "iTerm", appPath: "/i")),
        ]
        service.saveEntries(entries)
        let loaded = service.loadEntries()
        #expect(loaded[0].id == "builtIn.copyPath")
        #expect(loaded[1].displayName == "Terminal")
        #expect(loaded[2].displayName == "iTerm")
        cleanup()
    }
}
```

**步骤 2：运行测试，验证失败**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20`
预期：失败 — `saveEntries`/`loadEntries` 未定义

**步骤 3：更新 SharedKeys**

替换 `RCMMShared/Sources/Constants/SharedKeys.swift`：

```swift
import Foundation

public enum SharedKeys {
    public static let menuEntries = "rcmm.menu.entries"
    public static let errorQueue = "rcmm.error.queue"
    public static let onboardingCompleted = "rcmm.settings.onboardingCompleted"
    public static let loginItemEnabled = "rcmm.settings.loginItemEnabled"
}
```

变更：`menuItems` → `menuEntries`（新 key 值），移除 `copyPathEnabled`。

**步骤 4：更新 SharedConfigService**

替换 `RCMMShared/Sources/Services/SharedConfigService.swift`：

```swift
import Foundation

public final class SharedConfigService: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: AppGroupConstants.appGroupID)!
    }

    public func saveEntries(_ entries: [MenuEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        defaults.set(data, forKey: SharedKeys.menuEntries)
    }

    public func loadEntries() -> [MenuEntry] {
        guard let data = defaults.data(forKey: SharedKeys.menuEntries) else {
            return []
        }
        return (try? JSONDecoder().decode([MenuEntry].self, from: data)) ?? []
    }
}
```

**步骤 5：运行测试，验证通过**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20`
预期：通过

**步骤 6：提交**

```bash
git add RCMMShared/Sources/Constants/SharedKeys.swift RCMMShared/Sources/Services/SharedConfigService.swift RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift
git commit -m "refactor: replace separate menuItems/copyPathEnabled with unified MenuEntry persistence"
```

---

### 任务 6：更新 AppState

**文件：**
- 修改：`RCMMApp/AppState.swift`

**步骤 1：替换 menuItems 和 copyPathEnabled 为 menuEntries**

这是一个较大的变更。需要替换 AppState 的多个部分。以下是完整的变更清单：

**第 9 行：** `var menuItems: [MenuItemConfig] = []` → `var menuEntries: [MenuEntry] = []`

**第 15-20 行：** 删除整个 `copyPathEnabled` 属性。

**第 46 行：** 删除 `copyPathEnabled = forPreview ? false : configService.loadCopyPathEnabled()`

**第 50 行：** `loadMenuItems()` → `loadMenuEntries()`

**第 82-85 行：** 在 `loadErrors()` 中，自动修复引用了 `menuItems`。改为：
```swift
let items = menuEntries.compactMap { entry -> MenuItemConfig? in
    if case .custom(let config) = entry { return config }
    return nil
}
```

**第 200-217 行：** 替换 `loadMenuItems()` 为：
```swift
func loadMenuEntries() {
    let existing = configService.loadEntries()

    if existing.isEmpty {
        let terminalConfig = MenuItemConfig(
            appName: "Terminal",
            bundleId: "com.apple.Terminal",
            appPath: "/System/Applications/Utilities/Terminal.app"
        )
        menuEntries = [
            .custom(terminalConfig),
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
        ]
        configService.saveEntries(menuEntries)
        syncScriptsInBackground()
    } else {
        menuEntries = existing
        syncScriptsInBackground()
    }
}
```

**第 220-229 行：** 替换 `addMenuItem(from:)` 为：
```swift
func addMenuItem(from appInfo: AppInfo) {
    let newItem = MenuItemConfig(
        appName: appInfo.name,
        bundleId: appInfo.bundleId,
        appPath: appInfo.path
    )
    menuEntries.append(.custom(newItem))
    saveAndSync()
}
```

**第 232-245 行：** 替换 `addMenuItems(from:)` 为：
```swift
func addMenuItems(from appInfos: [AppInfo]) {
    for appInfo in appInfos {
        let newItem = MenuItemConfig(
            appName: appInfo.name,
            bundleId: appInfo.bundleId,
            appPath: appInfo.path
        )
        menuEntries.append(.custom(newItem))
    }
    if !appInfos.isEmpty {
        saveAndSync()
    }
}
```

**第 248-258 行：** 替换 `containsApp` 以搜索 `menuEntries`：
```swift
func containsApp(bundleId: String?, appPath: String) -> Bool {
    for entry in menuEntries {
        if case .custom(let item) = entry {
            if let bundleId = bundleId, item.bundleId == bundleId {
                return true
            }
            if item.appPath == appPath {
                return true
            }
        }
    }
    return false
}
```

**第 261-265 行：** 替换 `moveMenuItem` 为：
```swift
func moveEntry(from source: IndexSet, to destination: Int) {
    menuEntries.move(fromOffsets: source, toOffset: destination)
    saveAndSync()
}
```

**第 268-272 行：** 替换 `removeMenuItem` 为：
```swift
func removeEntry(at offsets: IndexSet) {
    let onlyCustomOffsets = offsets.filter { index in
        if case .custom = menuEntries[index] { return true }
        return false
    }
    menuEntries.remove(atOffsets: IndexSet(onlyCustomOffsets))
    saveAndSync()
}
```

**第 275-279 行：** 替换 `updateCustomCommand`：
```swift
func updateCustomCommand(for itemId: UUID, command: String?) {
    guard let index = menuEntries.firstIndex(where: {
        if case .custom(let config) = $0 { return config.id == itemId }
        return false
    }) else { return }
    if case .custom(var config) = menuEntries[index] {
        config.customCommand = command
        menuEntries[index] = .custom(config)
    }
    saveAndSync()
}
```

**第 282-286 行：** 替换 `toggleMenuItem` 为统一的 `toggleEntry`：
```swift
func toggleEntry(for entryId: String, isEnabled: Bool) {
    guard let index = menuEntries.firstIndex(where: { $0.id == entryId }) else { return }
    switch menuEntries[index] {
    case .builtIn(var item):
        item.isEnabled = isEnabled
        menuEntries[index] = .builtIn(item)
    case .custom(var config):
        config.isEnabled = isEnabled
        menuEntries[index] = .custom(config)
    }
    saveAndSync()
}
```

**第 289-293 行：** 删除 `recalculateSortOrders()` — 不再需要。

**第 296-299 行：** 替换 `saveAndSync`：
```swift
func saveAndSync() {
    configService.saveEntries(menuEntries)
    syncScriptsInBackground()
}
```

**第 304-311 行：** 替换 `syncScriptsInBackground`：
```swift
private func syncScriptsInBackground() {
    let items = menuEntries.compactMap { entry -> MenuItemConfig? in
        if case .custom(let config) = entry { return config }
        return nil
    }
    Self.syncQueue.async {
        let installer = ScriptInstallerService()
        installer.syncScripts(with: items)
        DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
    }
}
```

**步骤 2：构建验证**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | tail -30`
预期：其他文件仍引用旧 API 会有构建错误 — 这是预期的。

**步骤 3：提交**

```bash
git add RCMMApp/AppState.swift
git commit -m "refactor: replace menuItems + copyPathEnabled with unified menuEntries in AppState"
```

---

### 任务 7：更新 FinderSync 扩展

**文件：**
- 修改：`RCMMFinderExtension/FinderSync.swift`

**步骤 1：替换菜单构建逻辑**

替换 `menu(for:)` 方法（第 30-71 行）为：

```swift
override func menu(for menuKind: FIMenuKind) -> NSMenu {
    let menu = NSMenu(title: "")
    let entries = configService.loadEntries()
        .filter { $0.isEnabled }

    guard !entries.isEmpty else {
        logger.warning("无菜单配置项")
        return menu
    }

    for entry in entries {
        switch entry {
        case .builtIn(let item):
            switch item.type {
            case .copyPath:
                let copyPathItem = NSMenuItem(
                    title: "拷贝路径",
                    action: #selector(copyPath(_:)),
                    keyEquivalent: ""
                )
                copyPathItem.target = self
                menu.addItem(copyPathItem)
            }
        case .custom(let config):
            let menuItem = NSMenuItem(
                title: "用 \(config.appName) 打开",
                action: #selector(openWithApp(_:)),
                keyEquivalent: ""
            )
            menuItem.representedObject = config.id.uuidString
            menuItem.target = self

            let icon = NSWorkspace.shared.icon(forFile: config.appPath)
            icon.size = NSSize(width: 16, height: 16)
            menuItem.image = icon

            menu.addItem(menuItem)
        }
    }

    return menu
}
```

**步骤 2：更新 openWithApp 使用 loadEntries**

替换 `openWithApp(_:)`（第 73-103 行），将配置查找改为提取 custom 项：

```swift
@objc func openWithApp(_ sender: NSMenuItem) {
    let title = sender.title
    let prefix = "用 "
    let suffix = " 打开"
    guard title.hasPrefix(prefix) && title.hasSuffix(suffix) else {
        logger.error("无效的菜单标题格式: \(title)")
        return
    }
    let appName = String(title.dropFirst(prefix.count).dropLast(suffix.count))

    let customItems = configService.loadEntries().compactMap { entry -> MenuItemConfig? in
        if case .custom(let config) = entry { return config }
        return nil
    }
    guard let item = customItems.first(where: { $0.appName == appName }) else {
        logger.error("找不到菜单项配置: \(appName)")
        return
    }

    guard let targetPath = resolveTargetPath() else {
        logger.error("无法解析目标路径")
        return
    }

    logger.info("执行: \(item.appName) → \(targetPath)")

    scriptExecutor.execute(
        scriptId: item.id.uuidString,
        targetPath: targetPath,
        menuItemName: item.appName
    )
}
```

**步骤 3：构建 FinderExtension scheme**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMFinderExtension -configuration Debug build 2>&1 | tail -20`
预期：构建成功

**步骤 4：提交**

```bash
git add RCMMFinderExtension/FinderSync.swift
git commit -m "refactor: use unified MenuEntry for FinderSync menu building"
```

---

### 任务 8：更新 MenuConfigTab

**文件：**
- 修改：`RCMMApp/Views/Settings/MenuConfigTab.swift`

**步骤 1：替换为统一列表**

替换整个文件：

```swift
import RCMMShared
import SwiftUI

struct MenuConfigTab: View {
    @Environment(AppState.self) private var appState

    @State private var showingAppSelection = false
    @State private var expandedItems: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            if appState.menuEntries.isEmpty {
                Spacer()
                Text("暂无菜单项")
                    .foregroundStyle(.secondary)
                Text("点击下方按钮添加应用")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                List {
                    ForEach(Array(appState.menuEntries.enumerated()), id: \.element.id) { index, entry in
                        switch entry {
                        case .builtIn(let item):
                            BuiltInListRow(
                                item: item,
                                onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                                onMoveDown: index < appState.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                                onToggle: { isEnabled in
                                    appState.toggleEntry(for: entry.id, isEnabled: isEnabled)
                                },
                                position: index + 1,
                                total: appState.menuEntries.count
                            )
                        case .custom(let config):
                            DisclosureGroup(isExpanded: expandedBinding(for: entry.id)) {
                                CommandEditor(
                                    editedCommand: config.customCommand ?? "",
                                    defaultCommand: resolveDefaultCommand(for: config),
                                    appPath: config.appPath,
                                    onSave: { command in
                                        appState.updateCustomCommand(for: config.id, command: command)
                                    }
                                )
                            } label: {
                                AppListRow(
                                    menuItem: config,
                                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                                    onMoveDown: index < appState.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                                    onDelete: { appState.removeEntry(at: IndexSet(integer: index)) },
                                    onToggle: { isEnabled in
                                        appState.toggleEntry(for: entry.id, isEnabled: isEnabled)
                                    },
                                    position: index + 1,
                                    total: appState.menuEntries.count
                                )
                            }
                        }
                    }
                    .onMove { source, destination in
                        appState.moveEntry(from: source, to: destination)
                    }
                }
            }

            Divider()

            HStack {
                Button("添加应用") {
                    showingAppSelection = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("添加应用到右键菜单")

                Button("手动添加") {
                    selectManually()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("手动选择应用文件")

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingAppSelection) {
            AppSelectionSheet()
        }
    }

    private func selectManually() {
        Task { @MainActor in
            let discoveryService = AppDiscoveryService()
            if let appInfo = await discoveryService.selectApplicationManually() {
                guard !appState.containsApp(bundleId: appInfo.bundleId, appPath: appInfo.path) else {
                    return
                }
                appState.addMenuItem(from: appInfo)
            }
        }
    }

    private func moveItem(at index: Int, direction: Int) {
        let destination = direction < 0 ? index - 1 : index + 2
        appState.moveEntry(from: IndexSet(integer: index), to: destination)
    }

    private func expandedBinding(for id: String) -> Binding<Bool> {
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

    private func resolveDefaultCommand(for item: MenuItemConfig) -> String {
        if let builtIn = CommandMappingService.command(for: item.bundleId) {
            return builtIn
        }
        return "open -a \"\(item.appPath)\" {path}"
    }
}
```

主要变更：
- 移除顶部独立的拷贝路径开关和 `Divider`
- `expandedItems: Set<UUID>` → `Set<String>`（MenuEntry 的 ID 是字符串）
- `ForEach` 根据 entry 类型切换：`.builtIn` 渲染 `BuiltInListRow`，`.custom` 渲染带 `AppListRow` 的 `DisclosureGroup`
- 所有方法调用使用新的 AppState API（`moveEntry`、`removeEntry`、`toggleEntry`）
- 移除 `isDefault: index == 0` — 在统一列表中不再需要

**步骤 2：构建**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | tail -20`
预期：失败 — `BuiltInListRow` 尚未定义。下一个任务处理。

**步骤 3：提交**

```bash
git add RCMMApp/Views/Settings/MenuConfigTab.swift
git commit -m "refactor: update MenuConfigTab to use unified menuEntries list"
```

---

### 任务 9：创建 BuiltInListRow 并更新 AppListRow

**文件：**
- 新建：`RCMMApp/Views/Settings/BuiltInListRow.swift`
- 修改：`RCMMApp/Views/Settings/AppListRow.swift`

**步骤 1：创建 BuiltInListRow**

新建 `RCMMApp/Views/Settings/BuiltInListRow.swift`：

```swift
import RCMMShared
import SwiftUI

struct BuiltInListRow: View {
    let item: BuiltInMenuItem
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onToggle: ((Bool) -> Void)?
    var position: Int?
    var total: Int?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(item.isEnabled ? .primary : .secondary)
                .frame(width: 32, height: 32)

            Text(item.displayName)
                .font(.body)
                .foregroundStyle(item.isEnabled ? .primary : .secondary)

            Text("系统")
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )

            Spacer()

            if !item.isEnabled {
                Text("已停用")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let onToggle = onToggle {
                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .help(item.isEnabled ? "停用此菜单项" : "启用此菜单项")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName)，系统功能")
        .ifLet(position) { view, pos in
            view.accessibilityValue("第 \(pos) 项，共 \(total ?? 1) 项")
        }
        .accessibilityHint("系统内置菜单功能")
        .ifLet(onMoveUp) { view, action in
            view.accessibilityAction(named: "上移", action)
        }
        .ifLet(onMoveDown) { view, action in
            view.accessibilityAction(named: "下移", action)
        }
    }
}
```

**步骤 2：更新 AppListRow — 移除 isDefault 和预览中的 sortOrder**

编辑 `RCMMApp/Views/Settings/AppListRow.swift`：

移除 `isDefault` 属性及所有星标 UI。移除所有 `#Preview` 中的 `sortOrder`。

替换第 5-13 行（属性）：
```swift
struct AppListRow: View {
    let menuItem: MenuItemConfig
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggle: ((Bool) -> Void)?
    var position: Int?
    var total: Int?
```

移除第 31-38 行（星标徽章 `if isDefault` 代码块）。

替换第 81 行无障碍标签：
```swift
.accessibilityLabel(menuItem.appName)
```

更新全部三个 `#Preview`，移除 `sortOrder` 和 `isDefault` 参数：

预览 1：
```swift
#Preview("启用状态") {
    AppListRow(
        menuItem: MenuItemConfig(
            appName: "Terminal",
            bundleId: "com.apple.Terminal",
            appPath: "/System/Applications/Utilities/Terminal.app",
            isEnabled: true
        ),
        onToggle: { _ in },
        position: 1,
        total: 3
    )
    .padding()
}
```

预览 2：
```swift
#Preview("禁用状态") {
    AppListRow(
        menuItem: MenuItemConfig(
            appName: "iTerm",
            appPath: "/Applications/iTerm.app",
            isEnabled: false
        ),
        onToggle: { _ in },
        position: 2,
        total: 3
    )
    .padding()
}
```

预览 3：
```swift
#Preview("应用未找到") {
    AppListRow(
        menuItem: MenuItemConfig(
            appName: "不存在的应用",
            appPath: "/Applications/NonExistent.app",
            isEnabled: true
        ),
        onToggle: { _ in },
        position: 3,
        total: 3
    )
    .padding()
}
```

**步骤 3：构建**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | tail -20`
预期：构建成功（或接近成功 — 检查是否有其他遗留引用）

**步骤 4：提交**

```bash
git add RCMMApp/Views/Settings/BuiltInListRow.swift RCMMApp/Views/Settings/AppListRow.swift
git commit -m "feat: add BuiltInListRow for system menu items, simplify AppListRow"
```

---

### 任务 10：修复全代码库剩余构建错误

**文件：**
- 可能涉及：所有仍引用 `menuItems`、`copyPathEnabled`、`sortOrder`、`moveMenuItem`、`removeMenuItem`、`toggleMenuItem`、`.save(`、`.load()`、`saveCopyPathEnabled`、`loadCopyPathEnabled` 的文件

**步骤 1：搜索所有剩余引用**

运行：`grep -rn 'menuItems\|copyPathEnabled\|sortOrder\|moveMenuItem\|removeMenuItem\|toggleMenuItem\|\.save(\|\.load()\|saveCopyPathEnabled\|loadCopyPathEnabled' --include='*.swift' RCMMApp/ RCMMFinderExtension/ RCMMShared/`

修复所有匹配项。常见替换模式：
- `appState.menuItems` → `appState.menuEntries`
- `appState.moveMenuItem` → `appState.moveEntry`
- `appState.removeMenuItem` → `appState.removeEntry`
- `appState.toggleMenuItem` → `appState.toggleEntry`
- `configService.save(...)` → `configService.saveEntries(...)`
- `configService.load()` → `configService.loadEntries()`

**步骤 2：构建全部三个 scheme**

分别运行：
```bash
xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | tail -20
xcodebuild -project rcmm.xcodeproj -scheme RCMMFinderExtension -configuration Debug build 2>&1 | tail -20
xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20
```
预期：全部构建成功，全部测试通过

**步骤 3：提交**

```bash
git add -A
git commit -m "fix: resolve all remaining references to old menuItems/copyPathEnabled APIs"
```

---

### 任务 11：最终验证与清理

**步骤 1：运行完整测试套件**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -30`
预期：全部测试通过

**步骤 2：构建两个应用 target**

```bash
xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | tail -10
xcodebuild -project rcmm.xcodeproj -scheme RCMMFinderExtension -configuration Debug build 2>&1 | tail -10
```
预期：两个都构建成功

**步骤 3：清理废弃的 UserDefaults key（可选）**

如需清理，在 `AppState.init` 中添加：
```swift
// 清理废弃的 key
let groupDefaults = UserDefaults(suiteName: AppGroupConstants.appGroupID)
groupDefaults?.removeObject(forKey: "rcmm.menu.items")
groupDefaults?.removeObject(forKey: "rcmm.copyPath.enabled")
```

**步骤 4：最终提交**

```bash
git add -A
git commit -m "chore: final cleanup for unified menu sorting"
```
