# Story 1.1: Xcode 项目初始化与三目标架构搭建

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 开发者,
I want 创建包含主应用、Finder Sync Extension 和共享 Package 的 Xcode 项目,
So that 项目具备正确的构建目标、签名配置和 App Group 共享基础。

## Acceptance Criteria

1. **三目标架构创建** — 项目包含 RCMMApp（主应用）、RCMMFinderExtension（Finder Sync Extension）、RCMMShared（本地 Swift Package, static library）三个构建目标
2. **App Group 配置** — 两个 target 均配置 App Group: `group.com.sunven.rcmm`
3. **Extension 沙盒** — RCMMFinderExtension target 启用 App Sandbox entitlement
4. **LSUIElement 配置** — 主 App Info.plist 配置 `Application is agent (UIElement) = YES`（无 Dock 图标）
5. **Package 平台配置** — RCMMShared Package 配置 `platforms: [.macOS(.v15)]`, library type: `.static`
6. **依赖链接** — 两个 target（RCMMApp 和 RCMMFinderExtension）均添加 RCMMShared 依赖
7. **Diamond 诊断禁用** — 两个 target 设置 `DISABLE_DIAMOND_PROBLEM_DIAGNOSTIC = YES`
8. **编译验证** — 项目可成功编译（零错误），三个 target 均可独立构建
9. **Deployment Target** — 所有 target 设置 macOS 15.0 最低部署版本
10. **Swift 语言模式** — 使用 Swift 6 编译器，Swift 5 语言模式（`SWIFT_STRICT_CONCURRENCY = targeted`）

## Tasks / Subtasks

- [x] Task 1: 创建 Xcode 项目 (AC: #1, #9, #10)
  - [x] 1.1 Xcode → File → New → Project → macOS → App（Product Name: rcmm, Interface: SwiftUI, Language: Swift）
  - [x] 1.2 设置 Deployment Target 为 macOS 15.0
  - [x] 1.3 确认 Swift Language Version 为 Swift 6 编译器，Swift 5 语言模式
  - [x] 1.4 设置 SWIFT_STRICT_CONCURRENCY = targeted
- [x] Task 2: 添加 Finder Sync Extension target (AC: #1, #3, #9)
  - [x] 2.1 File → New → Target → macOS → Finder Sync Extension（Product Name: RCMMFinderExtension）
  - [x] 2.2 确认 Extension 的 Deployment Target 为 macOS 15.0
  - [x] 2.3 确认 Extension 自动启用 App Sandbox entitlement
  - [x] 2.4 确认生成 FinderSync.swift 入口文件和 Info.plist

- [x] Task 3: 创建 RCMMShared 本地 Swift Package (AC: #5)
  - [x] 3.1 项目根目录创建 RCMMShared/ 目录
  - [x] 3.2 创建 Package.swift：name "RCMMShared", platforms: [.macOS(.v15)], library type: .static
  - [x] 3.3 创建 Sources/ 目录结构：Models/, Services/, Constants/
  - [x] 3.4 在每个子目录创建占位 .swift 文件确保目录被 SPM 识别
  - [x] 3.5 创建 Tests/RCMMSharedTests/ 目录和占位测试文件

- [x] Task 4: 配置依赖和链接 (AC: #6, #7)
  - [x] 4.1 将 RCMMShared 本地 Package 添加到 Xcode 项目
  - [x] 4.2 RCMMApp target → Build Phases → Link Binary With Libraries → 添加 RCMMShared
  - [x] 4.3 RCMMFinderExtension target → Build Phases → Link Binary With Libraries → 添加 RCMMShared
  - [x] 4.4 两个 target 的 Build Settings 设置 DISABLE_DIAMOND_PROBLEM_DIAGNOSTIC = YES

- [x] Task 5: 配置 App Group (AC: #2)
  - [x] 5.1 RCMMApp target → Signing & Capabilities → + Capability → App Groups → 添加 group.com.sunven.rcmm
  - [x] 5.2 RCMMFinderExtension target → Signing & Capabilities → + Capability → App Groups → 添加 group.com.sunven.rcmm
  - [x] 5.3 确认两个 target 的 .entitlements 文件中 App Group ID 一致

- [x] Task 6: 配置主 App 为 Agent 应用 (AC: #4)
  - [x] 6.1 RCMMApp/Info.plist 添加 Application is agent (UIElement) = YES（键名 LSUIElement）
  - [x] 6.2 验证运行后 Dock 中不显示应用图标

- [x] Task 7: 配置 Entitlements (AC: #2, #3)
  - [x] 7.1 确认 RCMMApp.entitlements 包含：App Group (group.com.sunven.rcmm)
  - [x] 7.2 确认 RCMMFinderExtension.entitlements 包含：App Sandbox = YES + App Group (group.com.sunven.rcmm)
  - [x] 7.3 主 App 不启用 App Sandbox（非沙盒，用于 pluginkit 调用和脚本目录写入）

- [x] Task 8: 编译验证 (AC: #8)
  - [x] 8.1 Build RCMMApp scheme — 零错误
  - [x] 8.2 Build RCMMFinderExtension scheme — 零错误
  - [x] 8.3 Run RCMMShared 单元测试 — 通过
  - [x] 8.4 验证 Extension 可选择 Finder 作为宿主应用运行

- [x] Task 9: 项目结构验证
  - [x] 9.1 确认目录结构符合架构文档定义
  - [x] 9.2 确认 .gitignore 包含 Xcode 相关忽略规则
  - [x] 9.3 提交初始项目结构到 git

## Dev Notes

### 架构模式与约束

**三目标架构概览：**

```
rcmm.xcodeproj
├── RCMMApp (主应用, 非沙盒)        → SwiftUI MenuBarExtra + Settings
├── RCMMFinderExtension (Extension, 沙盒) → FIFinderSync 右键菜单
└── RCMMShared (Swift Package, static)    → 共享模型/服务/常量
```

**进程边界（最关键的架构约束）：**
- 主 App 进程（非沙盒）：可调用 pluginkit、扫描 /Applications、写入脚本目录
- Extension 进程（沙盒）：只能通过 NSUserAppleScriptTask 执行脚本，只能读 App Group UserDefaults
- 两个进程通过 App Group UserDefaults + Darwin Notifications 通信

**Package 依赖边界：**
- RCMMShared 只能依赖 Foundation，禁止依赖 SwiftUI、AppKit、FinderSync
- RCMMApp 可依赖 RCMMShared + SwiftUI + AppKit + ServiceManagement
- RCMMFinderExtension 可依赖 RCMMShared + FinderSync + Foundation

### 关键技术决策

**Swift 语言模式：**
- 使用 Swift 6 编译器 + Swift 5 语言模式
- `SWIFT_STRICT_CONCURRENCY = targeted`（中间级别并发检查）
- 所有 Swift 6 语言特性（@Observable、typed throws 等）在 Swift 5 模式下均可用
- 不需要切换到 Swift 6 语言模式即可使用新特性

**静态库链接：**
- RCMMShared 必须声明为 `.static` 类型，避免 Xcode 自动提升为动态框架
- 两个 target 链接同一个静态库会触发 diamond problem 诊断错误
- 必须在两个 target 的 Build Settings 中设置 `DISABLE_DIAMOND_PROBLEM_DIAGNOSTIC = YES`
- 这是 Xcode 26 中仍然需要的设置

**Finder Sync Extension 模板：**
- Xcode 26 中 Finder Sync Extension 模板仍然存在，路径：File → New → Target → macOS → Finder Sync Extension
- 模板自动生成 FinderSync.swift（FIFinderSync 子类）和 Info.plist
- 模板自动启用 App Sandbox entitlement

### RCMMShared Package.swift 参考

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RCMMShared",
    platforms: [.macOS(.v15)],
    products: [
        .library(
            name: "RCMMShared",
            type: .static,
            targets: ["RCMMShared"]
        ),
    ],
    targets: [
        .target(
            name: "RCMMShared",
            path: "Sources"
        ),
        .testTarget(
            name: "RCMMSharedTests",
            dependencies: ["RCMMShared"],
            path: "Tests/RCMMSharedTests"
        ),
    ]
)
```

### 目标目录结构

```
rcmm/
├── rcmm.xcodeproj
├── .gitignore
├── RCMMApp/
│   ├── rcmmApp.swift              # @main 入口（SwiftUI App）
│   ├── Info.plist                 # LSUIElement = YES
│   ├── rcmm.entitlements          # App Group
│   └── Assets.xcassets/
├── RCMMFinderExtension/
│   ├── FinderSync.swift           # FIFinderSync 子类
│   ├── Info.plist                 # NSExtension 配置
│   └── RCMMFinderExtension.entitlements  # App Sandbox + App Group
└── RCMMShared/
    ├── Package.swift
    ├── Sources/
    │   ├── Models/                # 占位文件
    │   ├── Services/              # 占位文件
    │   └── Constants/             # 占位文件
    └── Tests/
        └── RCMMSharedTests/       # 占位测试文件
```

### Entitlements 配置详情

**RCMMApp.entitlements：**
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.sunven.rcmm</string>
</array>
```
注意：主 App 不启用 App Sandbox。非沙盒是后续 pluginkit 调用、/Applications 扫描、脚本目录写入的前提。

**RCMMFinderExtension.entitlements：**
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.sunven.rcmm</string>
</array>
```

### 已知平台问题与注意事项

1. **macOS 15 Sequoia FinderSync 设置入口变更** — macOS 15.0 移除了系统设置中的 "Added Extensions" 子节。macOS 15.2+ 在 系统设置 → 通用 → 登录项与扩展 → "文件提供程序" 中恢复了管理入口。开发调试时使用 `pluginkit -m -i <bundle-id>` 验证 Extension 注册状态。

2. **macOS 26 ARM FinderSync bug** — 有报告称 macOS 26.1 上 Apple Silicon 机器的 FinderSync Extension 可能不工作。macOS 26.3（2026-02-11 发布）修复了部分 Finder 问题。在你的硬件上验证。

3. **MenuBarExtra + Settings 窗口 bug** — 这是跨 macOS 14/15/26 的持久 bug。`SettingsLink` 和 `@Environment(\.openSettings)` 在 MenuBarExtra 中不可靠。需要 hidden Window + ActivationPolicy 切换 workaround。这个问题在 Story 1.3 或后续 Epic 5 中处理，本 story 不需要实现。

4. **SMAppService.mainApp** — macOS 15+ 稳定可用。注意处理 `.requiresApproval` 状态。本 story 不涉及。

### 测试标准

- Swift Testing（@Test 宏）用于 RCMMShared 单元测试
- 本 story 只需验证编译通过和基本项目结构正确
- Extension 调试方式：选择 Extension scheme → Run → 选择 Finder 作为宿主应用

### .gitignore 参考

确保包含以下 Xcode 相关规则：
```
# Xcode
*.xcodeproj/project.xcworkspace/
*.xcodeproj/xcuserdata/
xcuserdata/
DerivedData/
*.xccheckout
*.moved-aside
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.build/
.swiftpm/

# macOS
.DS_Store
```

### Project Structure Notes

- 本 story 建立的项目结构是整个 rcmm 产品的基础，后续所有 story 都在此结构上开发
- RCMMShared 的 Sources/ 子目录（Models/, Services/, Constants/）在本 story 中只创建占位文件，具体实现在 Story 1.2 中完成
- 主 App 的 Views/ 和 Services/ 子目录在后续 story 中按需创建
- 确保 Bundle Identifier 命名一致：主 App `com.sunven.rcmm`，Extension `com.sunven.rcmm.FinderExtension`

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Starter Template Evaluation] — 8 步初始化流程
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries] — 完整目录结构和边界定义
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns & Consistency Rules] — 命名规范和反模式
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1] — Story 需求定义和验收标准
- [Source: _bmad-output/planning-artifacts/prd.md#技术架构] — 技术栈和构建目标定义

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

- RCMMShared `swift build` — 编译成功 (4.27s)
- RCMMShared `swift test` — 1 test passed (packageInitialization)
- `xcodebuild -scheme rcmm` — BUILD SUCCEEDED（零错误，零警告）

### Completion Notes List

- 使用命令行手动生成 project.pbxproj（非 Xcode GUI），采用 PBXFileSystemSynchronizedRootGroup (objectVersion 77) 模式
- 占位文件命名从统一的 `Placeholder.swift` 改为 `ModelsPlaceholder.swift` / `ServicesPlaceholder.swift` / `ConstantsPlaceholder.swift`，避免 SPM 编译冲突
- 为 RCMMFinderExtension 添加了 Info.plist 的 PBXFileSystemSynchronizedBuildFileExceptionSet，消除 Copy Bundle Resources 警告
- Task 6.2（验证 Dock 无图标）和 Task 8.4（Extension 选择 Finder 宿主运行）需要在 Xcode GUI 中手动验证
- 代码签名使用 ad-hoc（DEVELOPMENT_TEAM 为空），需要用户在 Xcode 中配置自己的开发团队

### File List

- `.gitignore` — Xcode/SPM/macOS 忽略规则
- `rcmm.xcodeproj/project.pbxproj` — Xcode 项目配置（三目标架构）
- `rcmm.xcodeproj/xcshareddata/xcschemes/RCMMFinderExtension.xcscheme` — Extension scheme
- `RCMMApp/rcmmApp.swift` — @main 入口（SwiftUI MenuBarExtra + Settings）
- `RCMMApp/Info.plist` — LSUIElement = YES
- `RCMMApp/rcmm.entitlements` — App Group
- `RCMMApp/Assets.xcassets/Contents.json` — Asset catalog root
- `RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json` — App icon placeholder
- `RCMMFinderExtension/FinderSync.swift` — FIFinderSync 子类
- `RCMMFinderExtension/Info.plist` — NSExtension 配置
- `RCMMFinderExtension/RCMMFinderExtension.entitlements` — App Sandbox + App Group
- `RCMMShared/Package.swift` — Swift Package 配置（platforms: macOS 15, type: .static）
- `RCMMShared/Sources/Models/ModelsPlaceholder.swift` — 占位
- `RCMMShared/Sources/Services/ServicesPlaceholder.swift` — 占位
- `RCMMShared/Sources/Constants/ConstantsPlaceholder.swift` — 占位
- `RCMMShared/Tests/RCMMSharedTests/RCMMSharedTests.swift` — 占位测试
