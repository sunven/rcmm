# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目简介

**rcmm**（Right Click Menu Manager）是一个 macOS Finder 右键菜单管理器，允许用户在 Finder 中直接用自定义应用程序打开任意目录，支持自定义启动命令。使用 Swift 6 + SwiftUI 开发，最低支持 macOS 15+。

## 构建与开发

本项目为 Xcode 工程，依赖通过 SPM 自动管理，无需额外安装包管理器。

```bash
# 打开项目
open rcmm.xcodeproj

# 命令行构建
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build
xcodebuild -project rcmm.xcodeproj -scheme RCMMFinderExtension -configuration Debug build

# 运行测试（使用 Swift Testing 框架，非 XCTest）
cd RCMMShared && swift test
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test

# 在终端查看扩展日志
log stream --predicate 'subsystem == "com.sunven.rcmm.FinderExtension"'
log stream --predicate 'subsystem == "com.sunven.rcmm.debug.FinderExtension"'

# 检查扩展注册状态
pluginkit -m -i com.sunven.rcmm.FinderExtension
pluginkit -m -i com.sunven.rcmm.debug.FinderExtension
```

**测试 Finder 扩展：** 在 Xcode 中选择 `RCMMFinderExtension` scheme，在 scheme editor 中将 Host Application 设置为 Finder，然后运行。在 Finder 中右键即可看到上下文菜单。

**Debug/Release 共存：** Release 使用 `com.sunven.rcmm`、`com.sunven.rcmm.FinderExtension`、`group.com.sunven.rcmm`。Debug 使用 `com.sunven.rcmm.debug`、`com.sunven.rcmm.debug.FinderExtension`、`group.com.sunven.rcmm.debug`，显示名为 `rcmm Debug`。首次签名 Debug build 需要 Apple Developer 里存在对应 App IDs、App Group 和 provisioning profiles；可让 Xcode 自动管理 signing，或在命令行构建时允许 provisioning updates。

**未配置 Linter。** 并发安全由 Xcode 内置警告在 Swift 6 模式下自动检查。

## 架构：三个 Target

```
rcmm.xcodeproj
├── RCMMApp/                    # 菜单栏应用（非沙盒，LSUIElement=YES）
├── RCMMFinderExtension/        # Finder Sync 扩展（沙盒）
└── RCMMShared/                 # SPM 静态库（共享业务逻辑）
```

### 进程边界（关键）

应用与扩展运行在**独立的沙盒进程**中，能力不同：

| 能力 | RCMMApp | RCMMFinderExtension |
|---|---|---|
| 沙盒 | 否 | 是 |
| UserDefaults 读写 | 读写 | 只读 |
| AppleScript 编译（`osacompile`） | 是 | 否（只能用 `NSUserAppleScriptTask`） |
| NSTask / Process | 是 | 否 |
| UI 窗口 | 是 | 否 |
| Darwin Notifications | 是 | 是 |

**进程间通信：** App Group UserDefaults 传递数据 + Darwin Notifications 通知配置变更。Release 使用 `group.com.sunven.rcmm`；Debug 使用 `group.com.sunven.rcmm.debug`，避免与已安装版本串扰。

### 包依赖规则

- **RCMMShared** → 只能依赖 Foundation（禁止依赖 SwiftUI、AppKit、FinderSync）
- **RCMMApp** → RCMMShared + SwiftUI + AppKit + ServiceManagement
- **RCMMFinderExtension** → RCMMShared + FinderSync + Foundation

### 数据流

1. 用户在设置中修改菜单 → `AppCoordinator.saveAndSync()`
2. `SharedConfigService.saveEntries()` 将 JSON 写入 App Group UserDefaults
3. `ScriptCompilationPipeline.publishCurrentConfiguration()` 读取已保存配置并发布脚本
4. `ScriptInstallerService.syncScripts()` 编译 AppleScript `.scpt` 文件至 `~/Library/Application Scripts/{extension-bundle-id}/`
5. `DarwinNotificationCenter.post(.configChanged)` 通知扩展
6. 下次右键 → `FinderSync.menu(for:)` 读取 UserDefaults，生成 `NSMenu`
7. 用户点击菜单项 → `ScriptExecutor` 通过 `NSUserAppleScriptTask` 加载并执行 `.scpt`

### 关键文件

| 文件 | 职责 |
|---|---|
| `RCMMApp/rcmmApp.swift` | `@main` 入口，定义 `MenuBarExtra` 和 `Settings` scene |
| `RCMMApp/AppState.swift` | `@Observable @MainActor` 全局状态；健康监控、错误队列、配置同步 |
| `RCMMFinderExtension/FinderSync.swift` | 上下文菜单生成与执行路由 |
| `RCMMFinderExtension/ScriptExecutor.swift` | `NSUserAppleScriptTask` 封装，含错误队列记录 |
| `RCMMApp/Services/ScriptCompilationPipeline.swift` | 已保存菜单配置到脚本发布状态的深模块；串行队列、通知、结果快照 |
| `RCMMApp/Services/ScriptInstallerService.swift` | AppleScript 生成、`osacompile` 封装、脚本生命周期管理 |
| `RCMMShared/Sources/Services/SharedConfigService.swift` | App Group UserDefaults 的 JSON 编解码，存取 `[MenuEntry]` |
| `RCMMShared/Sources/Constants/` | App Group ID、`SharedKeys`、`NotificationNames` 的集中定义——禁止硬编码 |

### 并发模型

- `AppState` 为 `@Observable @MainActor`，所有状态变更必须在主线程
- Darwin Notifications 在后台线程接收，访问 `AppState` 前须派发到主线程
- 脚本编译管线使用专用串行队列（`com.sunven.rcmm.scriptCompilation`）防止竞争
- Swift 6 + `SWIFT_STRICT_CONCURRENCY=targeted`，跨进程共享类型须标注 `@Sendable`

### 已知问题与绕过方案

- **MenuBarExtra → Settings 窗口：** `ActivationPolicyManager` 通过切换 `NSApplication.activationPolicy` 解决 SwiftUI 的 bug（从 MenuBarExtra 应用打开 Settings 窗口无法聚焦）。
- **扩展菜单状态：** 每次右键都从 UserDefaults 重新读取菜单项（不缓存），以应对扩展多实例问题。
- **脚本编译超时：** `osacompile` 包裹了 10 秒异步超时保护，防止挂起。

## 架构参考文档

完整的架构决策、平台限制与反模式记录在：
`_bmad-output/planning-artifacts/architecture.md`

进行结构性改动前请先阅读，内容涵盖 macOS 沙盒限制、FinderSync API 约束、命名规范和架构不变量。

## Design System

Always read `DESIGN.md` before making visual or UI decisions.
All font choices, colors, spacing, status treatments, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that does not match `DESIGN.md`.
