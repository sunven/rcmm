# Story 1.3: Finder 右键菜单与脚本执行端到端验证

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户,
I want 在 Finder 中右键目录时看到"用 Terminal 打开"菜单项，点击后 Terminal.app 打开并定位到该目录,
So that 我可以验证右键菜单到应用打开的完整链路正常工作。

## Acceptance Criteria

1. **右键目录显示菜单项** — Extension 已在系统设置中启用后，用户在 Finder 中右键一个目录，出现一级菜单项"用 Terminal 打开"（硬编码配置），菜单项显示 Terminal.app 的系统图标
2. **点击菜单项执行脚本打开应用** — 用户点击"用 Terminal 打开"菜单项后，Extension 通过 `NSUserAppleScriptTask` 执行对应的 `.scpt` 脚本，Terminal.app 在 ≤ 2 秒内打开并 cd 到用户右键的目录路径
3. **空白背景右键使用当前目录** — 右键窗口空白背景时，使用当前窗口的目录路径（`FIFinderSyncController.default().targetedURL()`）
4. **主应用启动时生成脚本** — 主应用启动时，`ScriptInstallerService` 在 Extension 脚本目录（`~/Library/Application Scripts/<extension-bundle-id>/`）生成对应的 `.scpt` 文件，脚本文件命名为 `<menuItemUUID>.scpt`
5. **脚本内容格式正确** — 脚本内容包含 AppleScript handler，通过 Apple Event 接收路径参数，使用 `tell application "Terminal"` + `do script "cd " & quoted form of thePath` 格式打开 Terminal 并定位到目标目录
6. **硬编码配置写入共享存储** — 主应用启动时创建硬编码的 `MenuItemConfig`（appName: "Terminal", appPath: "/Applications/Utilities/Terminal.app"）并通过 `SharedConfigService` 保存到 App Group UserDefaults

## Tasks / Subtasks

- [x] Task 1: 创建 ScriptInstallerService (AC: #4, #5)
  - [x] 1.1 创建 `RCMMApp/Services/` 目录
  - [x] 1.2 创建 `RCMMApp/Services/ScriptInstallerService.swift`
  - [x] 1.3 实现 `installScripts(for items: [MenuItemConfig])` — 遍历配置项，为每个生成 `.scpt` 文件
  - [x] 1.4 实现脚本目录路径解析 — 构建 `~/Library/Application Scripts/<extension-bundle-id>/` 路径，确保目录存在
  - [x] 1.5 实现 AppleScript 源码生成 — 生成包含 `on openApp(thePath)` handler 的 AppleScript 源码
  - [x] 1.6 实现 `.scpt` 编译 — 使用 `Process` 调用 `/usr/bin/osacompile` 将源码编译为 `.scpt` 文件
  - [x] 1.7 实现 `removeScript(for itemId: UUID)` — 删除指定菜单项的 `.scpt` 文件
  - [x] 1.8 实现 `syncScripts(with items: [MenuItemConfig])` — 同步增删改脚本文件（删除多余的、新增缺失的、更新变更的）

- [x] Task 2: 创建 ScriptExecutor (AC: #2, #3)
  - [x] 2.1 创建 `RCMMFinderExtension/ScriptExecutor.swift`
  - [x] 2.2 实现 `execute(scriptName: String, directoryPath: String, completion:)` — 使用 `NSUserAppleScriptTask` 执行指定脚本
  - [x] 2.3 实现 Apple Event 构建 — 使用 `NSAppleEventDescriptor` 构建包含目录路径参数的 Apple Event，调用脚本中的 handler
  - [x] 2.4 实现错误处理 — 执行失败时通过 `SharedErrorQueue` 记录错误，使用 `os_log` 记录详情
  - [x] 2.5 确保每次执行创建新的 `NSUserAppleScriptTask` 实例（单次使用限制）

- [x] Task 3: 更新 FinderSync.swift (AC: #1, #2, #3)
  - [x] 3.1 添加 `import RCMMShared` 和 `import os.log`
  - [x] 3.2 添加 `os.Logger` 实例（subsystem: extension bundle ID, category: "menu"）
  - [x] 3.3 更新 `menu(for:)` — 从 `SharedConfigService` 读取菜单配置，为每个 `MenuItemConfig` 创建带图标的菜单项
  - [x] 3.4 硬编码菜单项"用 Terminal 打开"并设置 Terminal.app 的系统图标（`NSWorkspace.shared.icon(forFile:)`）
  - [x] 3.5 实现菜单项 action handler — 解析点击的菜单项对应的 `MenuItemConfig`，获取目标目录路径
  - [x] 3.6 实现路径解析逻辑 — `contextualMenuForItems` 时使用 `selectedItemURLs()` 获取目录路径，`contextualMenuForContainer` 时使用 `targetedURL()` 获取当前目录路径
  - [x] 3.7 调用 `ScriptExecutor` 执行对应的 `.scpt` 脚本

- [x] Task 4: 更新 rcmmApp.swift (AC: #4, #6)
  - [x] 4.1 在应用启动时创建硬编码的 `MenuItemConfig`（Terminal.app）
  - [x] 4.2 通过 `SharedConfigService` 检查是否已有配置，无配置时写入硬编码配置
  - [x] 4.3 调用 `ScriptInstallerService.installScripts()` 安装脚本
  - [x] 4.4 发送 Darwin Notification（`configChanged`）通知 Extension

- [x] Task 5: 编译与端到端验证 (AC: #1, #2, #3, #4, #5, #6)
  - [x] 5.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 5.2 确认 Extension target 可链接 RCMMShared（`import RCMMShared` 无错误）
  - [x] 5.3 验证 `.scpt` 文件在主应用启动后正确生成到 Extension 脚本目录
  - [x] 5.4 验证 Finder 右键目录出现"用 Terminal 打开"菜单项
  - [x] 5.5 验证点击菜单项后 Terminal.app 打开并 cd 到正确目录
  - [x] 5.6 验证右键空白背景时使用当前窗口的目录路径

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 1 的最后一个 Story，实现从右键菜单到应用打开的完整端到端链路。它依赖 Story 1.1（项目骨架）和 Story 1.2（共享数据层），是用户可以体验的第一个可交互功能。后续 Epic 2 的动态配置管理将替换本 Story 的硬编码配置。

**完整数据流（本 Story 实现）：**

```
主 App 启动
  → 创建硬编码 MenuItemConfig (Terminal.app)
  → SharedConfigService.save() → App Group UserDefaults
  → ScriptInstallerService.installScripts()
    → 生成 AppleScript 源码
    → osacompile 编译为 .scpt
    → 写入 ~/Library/Application Scripts/<ext-bundle-id>/<uuid>.scpt
  → DarwinNotificationCenter.post(.configChanged)

用户在 Finder 右键目录
  → Extension: menu(for:) 被调用
  → SharedConfigService.load() → 读取菜单配置
  → 构建 NSMenu（"用 Terminal 打开" + Terminal 图标）
  → 返回菜单

用户点击菜单项
  → Extension: action handler 触发
  → 解析目标路径（selectedItemURLs / targetedURL）
  → ScriptExecutor.execute(scriptName:directoryPath:)
    → NSUserAppleScriptTask(url:) 加载 .scpt
    → 构建 Apple Event（handler name + 路径参数）
    → execute(withAppleEvent:)
  → Terminal.app 打开并 cd 到目标目录
```

**进程边界（关键约束）：**

```
┌─────────────────────────────┐     ┌──────────────────────────────┐
│     主 App 进程（非沙盒）      │     │    Extension 进程（沙盒）      │
│                              │     │                               │
│  ScriptInstallerService      │     │  FinderSync (FIFinderSync)    │
│    → osacompile 编译 .scpt   │     │    → menu(for:) 构建菜单      │
│    → 写入 Extension 脚本目录  │     │    → action handler           │
│                              │     │  ScriptExecutor               │
│  SharedConfigService.save()  │     │    → NSUserAppleScriptTask    │
│  DarwinNotificationCenter    │     │    → execute(withAppleEvent:) │
│    .post(configChanged)      │     │                               │
│                              │     │  SharedConfigService.load()   │
│                              │     │  SharedErrorQueue.append()    │
└──────────────┬───────────────┘     └──────────────┬────────────────┘
               │                                     │
               └──────────── App Group ──────────────┘
                    UserDefaults + Darwin Notifications
                    + ~/Library/Application Scripts/
```

### 关键技术决策

**脚本执行方案：Apple Event 参数传递**

本 Story 使用 Apple Event 向 `.scpt` 脚本传递目录路径参数，而非在脚本中硬编码路径。这样每个菜单项只需一个 `.scpt` 文件，可对不同目录复用。

脚本结构：
```applescript
on openApp(thePath)
    tell application "Terminal"
        activate
        do script "cd " & quoted form of thePath
    end tell
end openApp
```

Apple Event 构建：
```swift
import Carbon  // 需要 kASAppleScriptSuite, kASSubroutineEvent 等常量

let parameters = NSAppleEventDescriptor.list()
parameters.insert(NSAppleEventDescriptor(string: directoryPath), at: 0)

let event = NSAppleEventDescriptor(
    eventClass: AEEventClass(kASAppleScriptSuite),
    eventID: AEEventID(kASSubroutineEvent),
    targetDescriptor: nil,
    returnID: AEReturnID(kAutoGenerateReturnID),
    transactionID: AETransactionID(kAnyTransactionID)
)
event.setDescriptor(
    NSAppleEventDescriptor(string: "openApp"),
    forKeyword: AEKeyword(keyASSubroutineName)
)
event.setDescriptor(parameters, forKeyword: AEKeyword(keyDirectObject))
```

**脚本编译方案：osacompile**

使用 `Process` 调用 `/usr/bin/osacompile` 将 AppleScript 源码编译为 `.scpt` 文件。这是标准系统工具，比 `NSAppleScript` 的 in-process 编译更可靠。

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/osacompile")
process.arguments = ["-o", outputURL.path, tempSourceURL.path]
try process.run()
process.waitUntilExit()
```

**脚本目录路径：**

- Extension 脚本目录：`~/Library/Application Scripts/com.sunven.rcmm.FinderExtension/`
- 主 App（非沙盒）直接写入此目录
- Extension 使用 `NSUserAppleScriptTask(url:)` 从此目录加载脚本
- Extension 通过 `FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)` 解析自己的脚本目录

**NSUserAppleScriptTask 关键行为：**

- 每个实例只能执行一次，每次执行需创建新实例
- 脚本通过 XPC 在沙盒外执行（`lsboxd`），因此可以调用 `open -a` 等系统命令
- completion handler 不在主线程回调
- 脚本文件必须位于 `~/Library/Application Scripts/<extension-bundle-id>/` 目录

**FIFinderSync 路径解析策略：**

| 场景 | `targetedURL()` | `selectedItemURLs()` | 使用策略 |
|---|---|---|---|
| 右键目录图标 | 当前窗口目录 | [选中的目录 URL] | 使用 `selectedItemURLs()` 的第一项 |
| 右键空白背景 | 当前窗口目录 | 空/nil | 使用 `targetedURL()` |
| 右键文件 | 当前窗口目录 | [选中的文件 URL] | 使用文件的父目录 |

**重要：** `targetedURL()` 和 `selectedItemURLs()` 仅在 `menu(for:)` 或菜单项 action handler 中返回有效值。

**菜单项图标设置：**

```swift
let icon = NSWorkspace.shared.icon(forFile: "/Applications/Utilities/Terminal.app")
icon.size = NSSize(width: 16, height: 16)
menuItem.image = icon
```

### 命名规范参考

| 类别 | 规范 | 本 Story 示例 |
|---|---|---|
| 服务类 | UpperCamelCase | `ScriptInstallerService`, `ScriptExecutor` |
| 方法 | lowerCamelCase，动词开头 | `installScripts()`, `execute(scriptName:directoryPath:)` |
| 脚本文件 | `<UUID>.scpt` | `550e8400-e29b-41d4-a716-446655440000.scpt` |
| os_log category | 功能域字符串 | `"script"`, `"menu"` |
| Extension bundle ID | reverse DNS | `com.sunven.rcmm.FinderExtension` |

### ScriptInstallerService 实现参考

```swift
import Foundation
import os.log
import RCMMShared

final class ScriptInstallerService {
    private let logger = Logger(
        subsystem: "com.sunven.rcmm",
        category: "script"
    )

    /// Extension 的 bundle ID，用于定位脚本目录
    private let extensionBundleID = "com.sunven.rcmm.FinderExtension"

    /// Extension 脚本目录
    private var scriptsDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/Application Scripts")
            .appendingPathComponent(extensionBundleID)
    }

    /// 为所有菜单项安装脚本
    func installScripts(for items: [MenuItemConfig]) {
        do {
            try FileManager.default.createDirectory(
                at: scriptsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("创建脚本目录失败: \(error.localizedDescription)")
            return
        }

        for item in items {
            installScript(for: item)
        }
    }

    /// 为单个菜单项安装脚本
    private func installScript(for item: MenuItemConfig) {
        let scriptSource = generateAppleScript(for: item)
        let outputURL = scriptsDirectory
            .appendingPathComponent(item.id.uuidString)
            .appendingPathExtension("scpt")

        do {
            try compileScript(source: scriptSource, outputURL: outputURL)
            logger.info("脚本安装成功: \(item.appName) → \(outputURL.lastPathComponent)")
        } catch {
            logger.error("脚本编译失败: \(item.appName): \(error.localizedDescription)")
        }
    }

    /// 生成 AppleScript 源码
    private func generateAppleScript(for item: MenuItemConfig) -> String {
        let command: String
        if let customCommand = item.customCommand {
            // 自定义命令：替换 {app} 和 {path} 占位符
            command = """
            do shell script "\(customCommand)"
            """
        } else {
            // 默认命令：使用 open -a
            command = """
            tell application "Terminal"
                activate
                do script "cd " & quoted form of thePath
            end tell
            """
        }

        return """
        on openApp(thePath)
            \(command)
        end openApp
        """
    }

    /// 使用 osacompile 编译 AppleScript 源码为 .scpt
    private func compileScript(source: String, outputURL: URL) throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("applescript")
        try source.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osacompile")
        process.arguments = ["-o", outputURL.path, tempURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "ScriptInstallerService",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorMsg]
            )
        }
    }

    /// 同步脚本文件：删除多余的、安装缺失的
    func syncScripts(with items: [MenuItemConfig]) {
        // 获取现有脚本文件
        let existingScripts = (try? FileManager.default.contentsOfDirectory(
            at: scriptsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        let existingIDs = Set(existingScripts
            .filter { $0.pathExtension == "scpt" }
            .map { $0.deletingPathExtension().lastPathComponent })
        let expectedIDs = Set(items.map { $0.id.uuidString })

        // 删除多余脚本
        for id in existingIDs.subtracting(expectedIDs) {
            let url = scriptsDirectory
                .appendingPathComponent(id)
                .appendingPathExtension("scpt")
            try? FileManager.default.removeItem(at: url)
            logger.info("删除多余脚本: \(id)")
        }

        // 安装缺失脚本
        for item in items where !existingIDs.contains(item.id.uuidString) {
            installScript(for: item)
        }
    }
}
```

### ScriptExecutor 实现参考

```swift
import Foundation
import os.log
import RCMMShared

final class ScriptExecutor {
    private let logger = Logger(
        subsystem: "com.sunven.rcmm.FinderExtension",
        category: "script"
    )
    private let errorQueue = SharedErrorQueue()

    /// 获取 Extension 脚本目录
    private var scriptsDirectory: URL? {
        try? FileManager.default.url(
            for: .applicationScriptsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
    }

    /// 执行指定脚本，传入目录路径
    func execute(
        scriptId: String,
        directoryPath: String,
        menuItemName: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let scriptsDir = scriptsDirectory else {
            let error = NSError(
                domain: "ScriptExecutor",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法获取脚本目录"]
            )
            logger.error("脚本目录不可用")
            recordError(message: "脚本目录不可用", context: menuItemName)
            completion?(error)
            return
        }

        let scriptURL = scriptsDir
            .appendingPathComponent(scriptId)
            .appendingPathExtension("scpt")

        do {
            let task = try NSUserAppleScriptTask(url: scriptURL)

            // 构建 Apple Event，传递目录路径作为参数
            let event = Self.buildAppleEvent(
                handlerName: "openApp",
                parameter: directoryPath
            )

            task.execute(withAppleEvent: event) { [weak self] _, error in
                if let error = error {
                    self?.logger.error("脚本执行失败: \(scriptId): \(error.localizedDescription)")
                    self?.recordError(
                        message: "脚本执行失败: \(error.localizedDescription)",
                        context: menuItemName
                    )
                } else {
                    self?.logger.info("脚本执行成功: \(scriptId) → \(directoryPath)")
                }
                completion?(error)
            }
        } catch {
            logger.error("脚本加载失败: \(scriptId): \(error.localizedDescription)")
            recordError(
                message: "脚本文件不存在或无法加载: \(error.localizedDescription)",
                context: menuItemName
            )
            completion?(error)
        }
    }

    /// 构建 Apple Event 调用脚本中的 handler
    private static func buildAppleEvent(
        handlerName: String,
        parameter: String
    ) -> NSAppleEventDescriptor {
        let parameters = NSAppleEventDescriptor.list()
        parameters.insert(NSAppleEventDescriptor(string: parameter), at: 0)

        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kASAppleScriptSuite),
            eventID: AEEventID(kASSubroutineEvent),
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        event.setDescriptor(
            NSAppleEventDescriptor(string: handlerName),
            forKeyword: AEKeyword(keyASSubroutineName)
        )
        event.setDescriptor(parameters, forKeyword: AEKeyword(keyDirectObject))

        return event
    }

    /// 记录错误到 App Group 错误队列
    private func recordError(message: String, context: String) {
        let record = ErrorRecord(
            source: "extension",
            message: message,
            context: context
        )
        errorQueue.append(record)
    }
}
```

### FinderSync.swift 更新参考

```swift
import FinderSync
import RCMMShared
import os.log

class FinderSync: FIFinderSync {
    private let logger = Logger(
        subsystem: "com.sunven.rcmm.FinderExtension",
        category: "menu"
    )
    private let configService = SharedConfigService()
    private let scriptExecutor = ScriptExecutor()

    override init() {
        super.init()
        // 监听整个文件系统
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        logger.info("FinderSync Extension 已初始化")
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let items = configService.load()

        guard !items.isEmpty else {
            logger.warning("无菜单配置项")
            return menu
        }

        for (index, item) in items.sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() {
            let menuItem = NSMenuItem(
                title: "用 \(item.appName) 打开",
                action: #selector(openWithApp(_:)),
                keyEquivalent: ""
            )
            menuItem.tag = index

            // 设置应用图标
            let icon = NSWorkspace.shared.icon(forFile: item.appPath)
            icon.size = NSSize(width: 16, height: 16)
            menuItem.image = icon

            menu.addItem(menuItem)
        }

        return menu
    }

    @objc func openWithApp(_ sender: NSMenuItem) {
        let items = configService.load().sorted(by: { $0.sortOrder < $1.sortOrder })
        guard sender.tag >= 0 && sender.tag < items.count else {
            logger.error("无效的菜单项索引: \(sender.tag)")
            return
        }

        let item = items[sender.tag]

        // 解析目标目录路径
        guard let directoryPath = resolveDirectoryPath() else {
            logger.error("无法解析目标目录路径")
            return
        }

        logger.info("执行: \(item.appName) → \(directoryPath)")

        scriptExecutor.execute(
            scriptId: item.id.uuidString,
            directoryPath: directoryPath,
            menuItemName: item.appName
        )
    }

    /// 解析右键点击的目标目录路径
    private func resolveDirectoryPath() -> String? {
        let controller = FIFinderSyncController.default()

        // 优先使用 selectedItemURLs（右键点击具体项目时）
        if let selectedItems = controller.selectedItemURLs(), !selectedItems.isEmpty {
            let firstItem = selectedItems[0]
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: firstItem.path, isDirectory: &isDir),
               isDir.boolValue {
                return firstItem.path
            } else {
                // 文件：使用其父目录
                return firstItem.deletingLastPathComponent().path
            }
        }

        // 回退：使用 targetedURL（右键空白背景时）
        return controller.targetedURL()?.path
    }
}
```

### rcmmApp.swift 更新参考

```swift
import SwiftUI
import RCMMShared

@main
struct rcmmApp: App {
    init() {
        setupInitialConfig()
    }

    var body: some Scene {
        MenuBarExtra("rcmm", systemImage: "contextualmenu.and.cursorarrow") {
            Text("rcmm is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            Text("Settings")
                .frame(width: 300, height: 200)
        }
    }

    /// 初始化硬编码配置和安装脚本
    private func setupInitialConfig() {
        let configService = SharedConfigService()
        let scriptInstaller = ScriptInstallerService()

        // 检查是否已有配置
        let existingItems = configService.load()
        let items: [MenuItemConfig]

        if existingItems.isEmpty {
            // 首次启动：创建硬编码 Terminal 配置
            let terminalConfig = MenuItemConfig(
                appName: "Terminal",
                bundleId: "com.apple.Terminal",
                appPath: "/Applications/Utilities/Terminal.app",
                sortOrder: 0
            )
            configService.save([terminalConfig])
            items = [terminalConfig]
        } else {
            items = existingItems
        }

        // 安装/同步脚本
        scriptInstaller.syncScripts(with: items)

        // 通知 Extension 配置可用
        DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
    }
}
```

### 前序 Story 经验总结

**来自 Story 1.1：**
- 使用命令行手动生成项目配置时，需要确保 Build Phases 正确链接 RCMMShared
- Extension 调试方式：选择 Extension scheme → Run → 选择 Finder 作为宿主应用
- 代码签名使用 ad-hoc，实际测试可能需要 Development 签名
- `RCMMApp/Services/` 目录不存在，需要手动创建

**来自 Story 1.2：**
- Swift 6 编译器 + Swift 5 语言模式 — `@Sendable` 闭包标注是必要的
- 测试使用 Swift Testing 框架（`import Testing`）
- `SharedConfigService` 和 `SharedErrorQueue` 已标记为 `@unchecked Sendable`
- `DarwinNotificationCenter` 回调在任意后台线程，UI 更新需调度到主线程
- `xcodebuild` 需要 `CODE_SIGNING_REQUIRED=NO` 才能在无签名环境编译
- Git commit 风格：`feat: 功能描述 (Story X.X)`

**Git 分析（最近提交）：**

```
43eec6b feat: implement shared data layer and config persistence (Story 1.2)
99e31fd feat: initialize Xcode project with triple-target architecture (Story 1.1)
```

Story 1.2 完成了所有共享数据层组件（模型、服务、常量），本 Story 在此基础上新增主 App 服务（ScriptInstallerService）和 Extension 逻辑（ScriptExecutor + FinderSync 更新）。

### 已知平台问题与注意事项

**macOS 15 Sequoia FinderSync 设置入口：**
- macOS 15.0-15.1 系统设置中 FinderSync Extension 管理入口缺失，已在 15.2+ 修复
- 开发调试使用 `pluginkit -m -i com.sunven.rcmm.FinderExtension` 验证 Extension 注册状态
- `FIFinderSyncController.showExtensionManagementInterface()` 在 Sequoia 上不可靠

**macOS 26 Tahoe ARM FinderSync bug：**
- macOS 26.1 上 Apple Silicon 机器的 FinderSync Extension 可能不工作（FB20947446）
- macOS 26.3（2026-02-11）修复了部分 Finder 问题
- 如遇此问题，需等待 Apple 修复

**macOS 26 AppleScript 超时回归：**
- Tahoe 存在系统级 AppleScript 超时问题（FB20174869）
- 简单的 Terminal 打开命令应不受影响，但错误处理路径可能较慢
- 使用 `tell application "Terminal"` + `do script` 方式比 `do shell script "open -a"` 更可靠

**NSUserAppleScriptTask 注意事项：**
- 每个实例只能执行一次
- 脚本通过 XPC 在沙盒外执行
- completion handler 不在主线程
- 需要 `import Carbon` 使用 Apple Event 常量

### 反模式清单（禁止）

- ❌ 在 Extension 内使用 `Process` 或 `NSTask`（沙盒禁止）
- ❌ 在 Extension 内弹自定义窗口或 Alert
- ❌ 硬编码脚本目录路径字符串（主 App 使用构建的路径，Extension 使用 `FileManager.url(for:)` API）
- ❌ 硬编码 App Group ID（使用 `AppGroupConstants.appGroupID`）
- ❌ 硬编码 UserDefaults 键名（使用 `SharedKeys` 常量）
- ❌ 硬编码 Darwin Notification 名称（使用 `NotificationNames` 常量）
- ❌ 在 Darwin Notification 回调中直接更新 UI
- ❌ 复用 `NSUserAppleScriptTask` 实例（必须每次创建新实例）
- ❌ 在 `menu(for:)` 或 action handler 之外调用 `targetedURL()` / `selectedItemURLs()`
- ❌ 使用 `NSAppleScript` 替代 `NSUserAppleScriptTask`（后者是沙盒内唯一合法途径）
- ❌ 在脚本中硬编码目录路径（使用 Apple Event 参数传递）
- ❌ 使用 `try!` 或 force unwrap（除非有明确断言注释）

### Project Structure Notes

**本 Story 完成后的新增/修改文件：**

```
rcmm/
├── RCMMApp/
│   ├── rcmmApp.swift                        # [修改] 添加初始配置和脚本安装
│   └── Services/
│       └── ScriptInstallerService.swift     # [新增] .scpt 脚本编译与安装
│
└── RCMMFinderExtension/
    ├── FinderSync.swift                     # [修改] 右键菜单构建 + 脚本执行调度
    └── ScriptExecutor.swift                 # [新增] NSUserAppleScriptTask 封装
```

**运行时生成的文件：**

```
~/Library/Application Scripts/com.sunven.rcmm.FinderExtension/
└── <menuItemUUID>.scpt                      # 编译后的 AppleScript 脚本
```

**不变的文件（Story 1.2 已实现）：**

```
RCMMShared/Sources/
├── Models/MenuItemConfig.swift              # 菜单项配置模型
├── Services/SharedConfigService.swift       # App Group UserDefaults 读写
├── Services/DarwinNotificationCenter.swift  # 跨进程通知
├── Services/SharedErrorQueue.swift          # 错误队列
└── Constants/                               # 共享常量
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.3] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/architecture.md#Script & Command Execution] — 脚本管理决策和执行链路
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries] — 进程边界和文件结构
- [Source: _bmad-output/planning-artifacts/architecture.md#Communication Patterns] — Darwin Notification 协议
- [Source: _bmad-output/planning-artifacts/architecture.md#Error Handling & Logging] — 错误传播策略
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Experience Mechanics] — 右键菜单交互机制（FIMenuKind、路径解析）
- [Source: _bmad-output/implementation-artifacts/1-2-shared-data-layer-and-config-persistence.md] — 前序 Story 共享数据层实现和经验
- [Source: _bmad-output/implementation-artifacts/1-1-xcode-project-init-and-triple-target-setup.md] — 前序 Story 项目结构和经验
- [Apple: NSUserAppleScriptTask](https://developer.apple.com/documentation/foundation/nsuserapplescripttask) — 脚本执行 API
- [Apple: FIFinderSyncProtocol](https://developer.apple.com/documentation/findersync/fifindersyncprotocol) — FinderSync 菜单 API
- [Apple: execute(withAppleEvent:completionHandler:)](https://developer.apple.com/documentation/foundation/nsuserapplescripttask/execute(withappleevent:completionhandler:)) — Apple Event 参数传递
- [Apple Developer Forums: FinderSync on macOS 26 ARM](https://developer.apple.com/forums/thread/806607) — 已知平台 bug

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- xcodebuild -scheme rcmm 编译成功 (BUILD SUCCEEDED, 零错误)
- RCMMShared 全部 11 个测试通过，无回归
- osacompile 集成测试通过：AppleScript 源码可正确编译为 .scpt 文件

### Completion Notes List

- ✅ Task 1: 创建 ScriptInstallerService — 实现了 installScripts、generateAppleScript、compileScript (osacompile)、removeScript、syncScripts 全部方法
- ✅ Task 2: 创建 ScriptExecutor — 实现了 NSUserAppleScriptTask 执行、Apple Event 构建 (kASAppleScriptSuite/kASSubroutineEvent)、SharedErrorQueue 错误记录
- ✅ Task 3: 更新 FinderSync.swift — 添加 RCMMShared/os.log 导入、SharedConfigService 菜单读取、NSWorkspace 图标设置、路径解析 (selectedItemURLs/targetedURL)、ScriptExecutor 调用
- ✅ Task 4: 更新 rcmmApp.swift — 添加 setupInitialConfig() 硬编码 Terminal 配置、SharedConfigService 持久化、ScriptInstallerService 脚本同步、DarwinNotificationCenter 通知
- ✅ Task 5.1-5.2: 编译成功，Extension 可链接 RCMMShared
- ✅ Task 5.3: 脚本文件正确生成到 ~/Library/Application Scripts/com.sunven.rcmm.FinderExtension/<UUID>.scpt，osadecompile 验证脚本内容正确
- ✅ AC#6 验证: 硬编码配置已写入 App Group UserDefaults (rcmm.menu.items)
- ✅ Task 5.4-5.6: 用户手动验证通过 — Finder 右键菜单显示正常，Terminal 打开并 cd 到正确目录，空白背景右键使用当前目录

### Change Log

- 2026-02-16: 实现 Story 1.3 全部代码 — ScriptInstallerService、ScriptExecutor、FinderSync 更新、rcmmApp 启动逻辑
- 2026-02-16: Code Review 修复 — [H1] AppleScript 字符串转义防注入、[H2] syncScripts 覆盖更新已有脚本、[H3] FinderSync 使用 representedObject 替代 tag 索引消除竞态、[M3] compileScript 修正 Pipe 读取顺序防死锁、[M4] osacompile 移至后台线程、[M1] File List 更新

### File List

- RCMMApp/Services/ScriptInstallerService.swift (新增)
- RCMMFinderExtension/ScriptExecutor.swift (新增)
- RCMMFinderExtension/FinderSync.swift (修改)
- RCMMApp/rcmmApp.swift (修改)
- rcmm.xcodeproj/project.pbxproj (修改 — 添加新文件到项目、PBXBuildFile 重排)
- rcmm.xcodeproj/xcshareddata/xcschemes/RCMMFinderExtension.xcscheme (修改 — scheme version 升级)
