---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - product-brief-rcmm-2026-02-12.md
  - prd.md
  - prd-validation.md
  - ux-design-specification.md
  - domain-macos-finder-context-menu-tool-research-2026-02-12.md
  - market-macos-finder-context-menu-tool-research-2026-02-12.md
  - technical-macos-finder-context-menu-tool-research-2026-02-12.md
workflowType: 'architecture'
project_name: 'rcmm'
user_name: 'Sunven'
date: '2026-02-15'
lastStep: 8
status: 'complete'
completedAt: '2026-02-15'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**

33 条功能需求，9 个能力域：

| 能力域 | FR 数量 | 架构影响 |
|---|---|---|
| FR-MENU (右键菜单) | 5 | Extension 进程内菜单构建；App Group 配置读取；排序逻辑 |
| FR-APP-DISCOVERY (应用发现) | 4 | 主 App 进程内 FileManager 扫描 /Applications；NSWorkspace 应用信息查询 |
| FR-COMMAND (命令模板) | 4 | 共享 Package 内命令映射服务；特殊终端内置映射字典；自定义命令持久化 |
| FR-ONBOARDING (首次引导) | 4 | 主 App 进程内引导流程；Extension 状态检测（pluginkit）；系统设置跳转 |
| FR-HEALTH (扩展健康) | 4 | 主 App 进程内 pluginkit 调用；定期/启动时检测；状态 UI 联动 |
| FR-UI (用户界面) | 5 | MenuBarExtra + Settings scene；LSUIElement 配置；拖拽排序 |
| FR-SYSTEM (系统集成) | 2 | SMAppService.mainApp 登录项管理 |
| FR-ERROR (错误处理) | 3 | 应用存在性检测；错误提示与恢复建议 |
| FR-DATA (数据管理) | 2 | App Group UserDefaults 持久化；Darwin Notification 实时同步（≤ 1s） |

**Non-Functional Requirements:**

| NFR 类别 | 关键指标 | 架构影响 |
|---|---|---|
| 性能 | 右键菜单响应 ≤ 2s；启动 ≤ 3s；内存 ≤ 50MB；扫描 ≤ 5s | Extension 内菜单构建必须轻量；配置缓存策略 |
| 可靠性 | macOS 15 + 26 双版本兼容；健康检测准确率 ≥ 95%；崩溃率 ≤ 0.1% | 版本条件编译；pluginkit 状态解析准确性 |
| 安全性 | 零遥测；权限最小化；代码签名 + 公证 | 无网络层；Entitlements 最小化；Hardened Runtime |
| 可访问性 | VoiceOver 可读；键盘导航；动态字体 | SwiftUI 原生组件 + accessibilityLabel |

**Scale & Complexity:**

- Primary domain: macOS 原生桌面应用（Finder Sync Extension）
- Complexity level: 低-中等
- Estimated architectural components: 3 个构建目标（App + Extension + 共享 Package）+ 预装脚本

### Technical Constraints & Dependencies

| 约束/依赖 | 类型 | 影响范围 |
|---|---|---|
| Finder Sync Extension 必须沙盒化 | 平台强制 | 命令执行链路必须通过 NSUserAppleScriptTask |
| 主 App 非沙盒 | 架构决策 | 可调用 pluginkit、扫描 /Applications、写入脚本目录 |
| App Group 共享 | 平台机制 | 两个 target 的 entitlements 必须一致配置 |
| macOS 15+ 最低版本 | 产品决策 | 可使用 @Observable、MenuBarExtra、SMAppService |
| Swift 6 / Xcode 26 | 工具链 | 严格并发检查影响 Extension 回调标注 |
| Apple Developer Program ($99/年) | 分发依赖 | 代码签名 + 公证的前提条件 |
| MenuBarExtra → Settings 窗口 bug | 已知平台 bug | 需要隐藏 Window + ActivationPolicy 切换 workaround |
| macOS 26.1 ARM FinderSync bug | 已知平台 bug | Extension 在 Apple Silicon 上可能完全不工作 |
| UserDefaults 跨进程同步问题 | 已知平台问题 | 备选方案：App Group 容器 JSON 文件 |

### Cross-Cutting Concerns Identified

| 关注点 | 影响的组件 | 架构策略 |
|---|---|---|
| **App Group 数据共享** | App ↔ Extension | UserDefaults suite + Darwin Notifications；备选 JSON 文件 |
| **沙盒边界管理** | Extension 命令执行 | NSUserAppleScriptTask + 预装 .scpt；主 App 负责脚本安装 |
| **macOS 版本兼容** | 全部组件 | 条件编译；系统设置跳转 URL 版本适配；Extension 设置入口引导 |
| **扩展生命周期** | Extension + 健康检测 | pluginkit 状态检测；Extension 可能被多实例化（Open/Save 对话框） |
| **进程间通信** | App → Extension 配置同步 | Darwin Notifications（信号）+ App Group（数据）；单向写入模型 |
| **错误传播** | Extension → 用户 | Extension 内不弹自定义窗口；利用系统错误对话框；延迟到主 App 处理 |
| **FinderSync API 风险** | 整个产品 | 架构隔离 Extension 依赖；核心逻辑在共享 Package；App Intents 备选 |

## Starter Template Evaluation

### Primary Technology Domain

macOS 原生桌面应用（Swift + SwiftUI + Finder Sync Extension）。不适用 Web/Mobile 领域的 CLI 脚手架工具。

### Starter Options Considered

| 方案 | 描述 | 评估 |
|---|---|---|
| Xcode 手动创建 | 通过 Xcode 逐步创建 App + Extension + Package | ✅ 唯一可行方案 |
| 第三方 macOS 模板 | GitHub 上的 macOS 项目模板 | ❌ 无适合 FinderSync + MenuBarExtra 的模板 |
| cookiecutter/tuist | 项目生成工具 | ❌ 过度设计，rcmm 结构简单明确 |

### Selected Starter: Xcode 手动项目创建

**Rationale for Selection:**

macOS Finder Sync Extension 项目结构高度特化，没有通用脚手架能覆盖 App + Extension + 共享 Package + App Group 的组合。Xcode 是唯一支持 Finder Sync Extension target 配置和 entitlements 管理的 IDE。技术研究报告已完整定义了项目结构和初始化步骤。

**Initialization Steps:**

1. Xcode → File → New → Project → macOS → App（Product Name: rcmm, Interface: SwiftUI, Language: Swift）
2. File → New → Target → macOS → Finder Sync Extension（Product Name: RCMMFinderExtension）
3. 项目根目录创建 RCMMShared/ 本地 Swift Package（platforms: .macOS(.v15), type: .static）
4. 两个 target 添加 RCMMShared 依赖
5. 两个 target 配置 App Group: group.com.sunven.rcmm
6. Extension target 启用 App Sandbox
7. 主 App 配置 Info.plist: Application is agent (UIElement) = YES
8. 设置 DISABLE_DIAMOND_PROBLEM_DIAGNOSTIC = YES（避免静态库重复链接错误）

**Architectural Decisions Provided by Project Setup:**

**Language & Runtime:**
- Swift 6.x（Xcode 26），初期使用 Swift 5 语言模式（SWIFT_STRICT_CONCURRENCY=targeted）
- macOS 15+ deployment target

**UI Framework:**
- SwiftUI — MenuBarExtra、Settings scene、@Observable 状态管理

**Build Tooling:**
- Xcode 26 + Swift Package Manager
- 3 个构建目标：RCMMApp（主应用）+ RCMMFinderExtension（Finder Sync Extension）+ RCMMShared（本地 Swift Package, static）

**Testing Framework:**
- Swift Testing（@Test 宏）用于 RCMMShared 单元测试
- XCUITest 用于 UI 测试（设置界面交互）
- 手动测试用于 Extension 右键菜单交互

**Code Organization:**
- RCMMShared/Sources/Models/ — 数据模型（MenuItemConfig, AppInfo, ExtensionStatus）
- RCMMShared/Sources/Services/ — 业务服务（SharedConfigService, CommandMappingService, DarwinNotificationCenter）
- RCMMShared/Sources/Constants/ — 共享常量（App Group ID, 通知名称）
- RCMMApp/ — 主应用 UI 和业务逻辑
- RCMMFinderExtension/ — Extension 入口和菜单构建
- Scripts/ — 预装 AppleScript 文件

**Development Experience:**
- Xcode Preview 验证 SwiftUI 组件
- Extension 调试：选择 Extension scheme → Run → 选择 Finder 作为宿主应用
- os_log() 作为 Extension 内主要调试手段
- pluginkit -m -i <bundle-id> 验证 Extension 注册状态

**Note:** 项目初始化（上述 8 步）应作为第一个实现 Story。

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**

1. 数据持久化：UserDefaults + JSON Data
2. 脚本管理：按应用生成专用 .scpt 文件
3. Extension 配置读取：每次直接读 UserDefaults，不缓存

**Important Decisions (Shape Architecture):**

4. MenuBarExtra 弹出窗口：状态驱动的 View 路由
5. Settings 窗口：TabView 分页
6. 错误处理：os_log + App Group 错误队列
7. 应用发现：启动时扫描 + 手动刷新

**Deferred Decisions (Post-MVP):**

8. 代码签名：开发阶段 Development 签名，分发阶段注册 Developer Program

### Data Architecture

| 决策 | 选择 | 理由 |
|---|---|---|
| 配置持久化 | UserDefaults(suiteName:) + JSON Data | 配置量极小（~4KB）；原子写入；API 简单。如遇 Sequoia 同步问题，降级到 App Group 容器 JSON 文件 |
| Extension 配置读取 | 每次直接读 UserDefaults | 配置量小，读取开销可忽略（< 1ms）；避免多实例缓存一致性问题 |
| 错误队列 | App Group UserDefaults 中的错误数组 | Extension 写入错误记录；主 App 激活时读取并展示；帮助用户排查"什么都没发生"的问题 |

### Script & Command Execution

| 决策 | 选择 | 理由 |
|---|---|---|
| 脚本管理 | 按应用生成专用 .scpt | 每个菜单项对应一个 .scpt 文件；主 App 配置变更时重新生成；Extension 按菜单项 ID 定位脚本执行。统一执行路径，无分支判断，完整支持自定义命令 |
| 脚本命名 | `<menuItemId>.scpt` | 按菜单项 UUID 命名，存放于 ~/Library/Application Scripts/<extension-bundle-id>/ |
| 脚本生命周期 | 配置增删改 → 同步增删改 .scpt | 主 App 负责脚本文件的创建、更新、删除 |

### UI Architecture

| 决策 | 选择 | 理由 |
|---|---|---|
| MenuBarExtra 弹出窗口 | 状态驱动 View 路由 | AppState 持有状态枚举（normal/healthWarning/onboarding）；switch 渲染对应 View；清晰的职责分离 |
| Settings 窗口 | TabView 分页 | macOS 标准设置窗口模式；3 个 Tab（菜单配置/通用/关于）；应用发现和自定义命令通过渐进式披露内嵌在菜单配置 Tab；系统集成归入通用 Tab |

### Application Discovery

| 决策 | 选择 | 理由 |
|---|---|---|
| 扫描时机 | 启动时扫描 + 手动刷新按钮 | "设置后遗忘"型使用模式；无需实时监听 /Applications 变化；简单可靠 |
| 扫描范围 | /Applications + ~/Applications | 覆盖系统级和用户级安装的应用 |

### Error Handling & Logging

| 决策 | 选择 | 理由 |
|---|---|---|
| 日志 | os_log（Extension + App） | 系统原生；Console.app 可查看；零依赖 |
| Extension 错误传播 | App Group 错误队列 | Extension 将执行失败写入 App Group 共享存储；主 App 下次激活时读取展示；解决 Extension 内无法弹窗的问题 |

### Distribution & Signing

| 决策 | 选择 | 理由 |
|---|---|---|
| 开发阶段签名 | Development 证书（免费） | 零成本验证 MVP；本机调试足够 |
| 分发阶段签名 | Developer ID Application（$99/年） | 延迟到分发准备阶段（Phase 4）再注册 |

### Decision Impact Analysis

**Implementation Sequence:**

1. 数据持久化（UserDefaults + JSON）→ 所有组件的基础
2. 脚本管理（专用 .scpt 生成）→ Extension 命令执行的前提
3. Extension 配置读取 → 右键菜单功能的前提
4. UI 架构（状态路由 + TabView）→ 用户交互层
5. 应用发现 → 菜单配置的数据来源
6. 错误队列 → 用户体验增强
7. 代码签名 → 分发阶段

**Cross-Component Dependencies:**

- 脚本管理依赖数据持久化（读取配置生成脚本）
- Extension 配置读取依赖数据持久化（读取菜单项列表）
- 错误队列复用数据持久化的 App Group 通道
- UI 架构依赖所有后端决策（展示配置、状态、错误）

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**Critical Conflict Points Identified:** 8 个领域需要统一规范，防止 AI agent 实现冲突

### Naming Patterns

**Swift Naming Conventions (Apple API Design Guidelines):**

| 类别 | 规范 | 示例 | 反例 |
|---|---|---|---|
| 类型 | UpperCamelCase | `MenuItemConfig` | `menuItemConfig`, `Menu_Item_Config` |
| 函数/方法 | lowerCamelCase，动词开头 | `loadMenuItems()` | `MenuItemsLoad()`, `get_menu_items()` |
| 变量/属性 | lowerCamelCase | `menuItems` | `MenuItems`, `menu_items` |
| 枚举 case | lowerCamelCase | `.enabled` | `.Enabled`, `.ENABLED` |
| 协议 | UpperCamelCase，名词或 -able/-ible | `ConfigPersisting` | `IConfigService`, `ConfigProtocol` |
| 文件名 | 与主类型同名 | `MenuItemConfig.swift` | `models.swift`, `menu-item-config.swift` |
| 布尔属性 | is/has/should 前缀 | `isLoginItemEnabled` | `loginItemEnabled`, `enabled` |

**App Group Keys:**

- 格式：`rcmm.<domain>.<key>`（lowerCamelCase，点号分隔）
- 示例：`rcmm.menu.items`, `rcmm.error.queue`, `rcmm.settings.loginItemEnabled`
- 所有键名定义为 `SharedKeys` 枚举的静态常量（RCMMShared/Constants/SharedKeys.swift）

**Darwin Notification Names:**

- 格式：`com.sunven.rcmm.<eventName>`（camelCase 过去式）
- 示例：`com.sunven.rcmm.configChanged`, `com.sunven.rcmm.scriptUpdated`
- 所有通知名定义为 `NotificationNames` 枚举的静态常量（RCMMShared/Constants/NotificationNames.swift）

**Script File Naming:**

- 格式：`<menuItemUUID>.scpt`
- 位置：`~/Library/Application Scripts/<extension-bundle-id>/`
- 示例：`550e8400-e29b-41d4-a716-446655440000.scpt`

**os_log Categories:**

- subsystem：target 的 bundle ID（`com.sunven.rcmm` 或 `com.sunven.rcmm.FinderExtension`）
- category：功能域字符串 — `"config"`, `"script"`, `"health"`, `"discovery"`, `"ui"`

### Structure Patterns

**Project Organization:**

- RCMMShared 内按 Models/ Services/ Constants/ 分目录
- RCMMApp 内按 Views/ 功能域分目录：Settings/, MenuBar/, Onboarding/
- 每个 View 文件只包含一个主 View struct
- 子视图提取到同目录下独立文件
- 测试文件在 RCMMShared/Tests/RCMMSharedTests/，按被测类型命名：`SharedConfigServiceTests.swift`

**File Organization Rules:**

| 位置 | 内容 |
|---|---|
| `RCMMShared/Sources/Models/` | 纯数据模型（struct, enum），Codable，无业务逻辑 |
| `RCMMShared/Sources/Services/` | 业务服务，协议 + 实现，可测试 |
| `RCMMShared/Sources/Constants/` | 共享常量（键名、通知名、App Group ID） |
| `RCMMApp/Views/<Domain>/` | SwiftUI View 文件，按功能域分组 |
| `RCMMApp/Services/` | 主 App 专用服务（PluginKitService, ScriptInstaller） |
| `RCMMFinderExtension/` | Extension 入口（FinderSync.swift）+ Extension 专用逻辑 |
| `Scripts/Templates/` | AppleScript 模板文件（开发参考，实际脚本由主 App 运行时生成） |

### Format Patterns

**Codable Model Rules:**

- JSON 字段名默认使用 Swift 属性名（camelCase），不自定义 CodingKeys 除非必要
- 新增字段必须为可选类型或提供默认值，确保旧版本数据可解码
- 所有模型实现 `Codable`, `Identifiable`, `Hashable`
- UUID 作为 `id` 字段，由创建方生成

**Error Queue Format:**

```swift
struct ErrorRecord: Codable {
    let id: UUID
    let timestamp: Date
    let source: String      // "extension" 或 "app"
    let message: String
    let context: String?    // 可选的额外上下文
}
```

- 错误队列存储为 JSON Data 数组，键名 `rcmm.error.queue`
- 最多保留最近 20 条记录，FIFO 淘汰

### Communication Patterns

**Darwin Notification Protocol:**

- 纯信号，不携带数据
- 数据通过 App Group UserDefaults 传递
- 观察者回调不在主线程，UI 更新需 `DispatchQueue.main.async`
- 单向通信：主 App → Extension（配置变更）

**State Management:**

- 单一 `AppState`（`@Observable`）作为主 App 的 source of truth
- `@State var appState = AppState()` 在 `@main App` 入口创建
- 子 View 通过 `.environment()` 接收
- 状态修改只在 `@MainActor` 上下文
- Extension 不持有长期状态，每次从 UserDefaults 读取

### Process Patterns

**Error Handling:**

- 自定义 `enum RCMMError: LocalizedError` 覆盖所有已知错误场景
- Extension 内：捕获错误 → 写入 App Group 错误队列 → os_log 记录
- 主 App 内：捕获错误 → Alert 或内联展示 → os_log 记录
- 不使用 `try!` 或 `fatalError()`（除非是编程错误的断言）

**Script Generation Process:**

1. 主 App 配置变更触发
2. 读取 MenuItemConfig
3. 根据 bundleId 查找命令映射（CommandMappingService）
4. 生成 AppleScript 源码字符串
5. 编译为 .scpt 或直接写入 .applescript 文本
6. 写入 Extension 脚本目录
7. 发送 Darwin Notification

### Enforcement Guidelines

**All AI Agents MUST:**

- 遵循 Swift API Design Guidelines 命名规范
- 所有共享键名/通知名使用 RCMMShared/Constants/ 中的常量，禁止硬编码字符串
- 新增 Codable 字段必须可选或有默认值
- Extension 内禁止使用 Process/NSTask，只能通过 NSUserAppleScriptTask
- 主 App 内禁止直接操作 Finder（不使用 ScriptingBridge 或 tell application "Finder"）
- 所有 os_log 调用必须指定 subsystem 和 category
- UI 状态修改必须在 @MainActor 上下文

**Anti-Patterns (禁止):**

- ❌ 在 Extension 内弹自定义窗口或 Alert
- ❌ 硬编码 App Group ID 或通知名字符串
- ❌ 使用 ObservableObject/@Published（统一用 @Observable）
- ❌ 在 RCMMShared 中引入 SwiftUI 或 AppKit 依赖
- ❌ 使用 try! 或 force unwrap（除非有明确的编程错误断言注释）
- ❌ 在 Darwin Notification 回调中直接更新 UI（必须调度到主线程）

## Project Structure & Boundaries

### Complete Project Directory Structure

```
rcmm/
├── rcmm.xcodeproj                          # Xcode 项目文件
├── .gitignore
├── README.md
├── LICENSE                                  # MIT
│
├── RCMMApp/                                 # 主 App target（非沙盒）
│   ├── rcmmApp.swift                        # @main 入口，MenuBarExtra + Settings + 隐藏 Window
│   ├── AppState.swift                       # @Observable 主状态，PopoverState 枚举
│   ├── Info.plist                           # LSUIElement = YES
│   ├── rcmm.entitlements                    # App Group + Automation Apple Events
│   ├── Assets.xcassets/                     # 菜单栏图标、App 图标
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   ├── PopoverContainerView.swift   # 状态路由容器（switch PopoverState）
│   │   │   ├── NormalPopoverView.swift      # 正常状态：菜单项列表 + 快捷操作
│   │   │   ├── HealthWarningView.swift      # 异常状态：健康警告 + 恢复引导
│   │   │   └── OnboardingPopoverView.swift  # 首次引导状态
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift           # TabView 容器（3 Tab）
│   │   │   ├── MenuConfigTab.swift          # 菜单配置（应用列表/添加/删除/拖拽排序/内联自定义命令编辑）
│   │   │   ├── GeneralTab.swift             # 通用（开机自启、扩展状态）
│   │   │   └── AboutTab.swift               # 关于、版本信息
│   │   └── Onboarding/
│   │       ├── OnboardingFlowView.swift     # 引导流程容器
│   │       ├── WelcomeStepView.swift        # 欢迎步骤
│   │       ├── SelectAppsStepView.swift     # 选择应用步骤
│   │       └── EnableExtensionStepView.swift # 启用扩展步骤
│   └── Services/
│       ├── PluginKitService.swift           # pluginkit 调用，扩展健康检测
│       ├── ScriptInstallerService.swift     # .scpt 文件生成与安装
│       ├── AppDiscoveryService.swift        # /Applications 扫描
│       └── ActivationPolicyManager.swift    # NSApplication.ActivationPolicy 切换 workaround
│
├── RCMMFinderExtension/                     # Finder Sync Extension target（沙盒）
│   ├── FinderSync.swift                     # FIFinderSync 子类，右键菜单入口
│   ├── Info.plist                           # NSExtension 配置
│   ├── RCMMFinderExtension.entitlements     # App Sandbox + App Group
│   └── ScriptExecutor.swift                 # NSUserAppleScriptTask 封装
│
├── RCMMShared/                              # 本地 Swift Package（static library）
│   ├── Package.swift                        # platforms: .macOS(.v15), type: .static
│   ├── Sources/
│   │   ├── Models/
│   │   │   ├── MenuItemConfig.swift         # 菜单项配置模型
│   │   │   ├── AppInfo.swift                # 应用信息模型
│   │   │   ├── ExtensionStatus.swift        # 扩展状态枚举
│   │   │   ├── ErrorRecord.swift            # 错误记录模型
│   │   │   └── PopoverState.swift           # 弹出窗口状态枚举
│   │   ├── Services/
│   │   │   ├── SharedConfigService.swift    # App Group UserDefaults 读写
│   │   │   ├── CommandMappingService.swift  # bundleId → 命令映射
│   │   │   ├── DarwinNotificationCenter.swift # 跨进程通知封装
│   │   │   └── SharedErrorQueue.swift       # 错误队列读写
│   │   └── Constants/
│   │       ├── AppGroupConstants.swift      # App Group ID
│   │       ├── SharedKeys.swift             # UserDefaults 键名常量
│   │       └── NotificationNames.swift      # Darwin Notification 名称常量
│   └── Tests/
│       └── RCMMSharedTests/
│           ├── MenuItemConfigTests.swift    # 模型编解码测试
│           ├── CommandMappingServiceTests.swift # 命令映射测试
│           ├── SharedConfigServiceTests.swift   # 配置读写测试
│           └── SharedErrorQueueTests.swift      # 错误队列测试
│
└── Scripts/
    └── Templates/
        ├── open_default.applescript         # 默认命令模板（开发参考）
        └── open_kitty.applescript           # kitty 专用模板（开发参考）
```

### Architectural Boundaries

**进程边界（最关键的架构边界）：**

```
┌─────────────────────────────┐     ┌──────────────────────────────┐
│       主 App 进程（非沙盒）    │     │    Extension 进程（沙盒）      │
│                              │     │                               │
│  AppState (@Observable)      │     │  FinderSync (FIFinderSync)    │
│  PluginKitService            │     │  ScriptExecutor               │
│  ScriptInstallerService      │     │                               │
│  AppDiscoveryService         │     │  ✅ NSUserAppleScriptTask     │
│  ActivationPolicyManager     │     │  ✅ App Group UserDefaults 读  │
│                              │     │  ✅ SharedErrorQueue 写        │
│  ✅ Process (pluginkit)      │     │  ❌ Process/NSTask            │
│  ✅ FileManager (/Apps)      │     │  ❌ 自定义窗口/Alert          │
│  ✅ App Group UserDefaults 写 │     │  ❌ 文件系统直接访问          │
│  ✅ 脚本目录写入              │     │                               │
└──────────────┬───────────────┘     └──────────────┬────────────────┘
               │                                     │
               └──────────── App Group ──────────────┘
                    UserDefaults + Darwin Notifications
```

**Package 依赖边界：**

| 模块 | 可依赖 | 禁止依赖 |
|---|---|---|
| RCMMShared | Foundation | SwiftUI, AppKit, FinderSync |
| RCMMApp | RCMMShared, SwiftUI, AppKit, ServiceManagement | FinderSync |
| RCMMFinderExtension | RCMMShared, FinderSync, Foundation | SwiftUI, AppKit |

**数据流边界：**

```
用户操作（主 App UI）
  → AppState 状态更新
  → SharedConfigService.save() → App Group UserDefaults
  → ScriptInstallerService.install() → Extension 脚本目录
  → DarwinNotificationCenter.post(.configChanged)
  → Extension 收到通知
  → SharedConfigService.load() → 读取最新配置
  → 下次右键菜单使用新配置
  → ScriptExecutor.execute() → NSUserAppleScriptTask
  → 目标应用打开
```

### Requirements to Structure Mapping

**FR-MENU (右键菜单) →**
- `RCMMFinderExtension/FinderSync.swift` — 菜单构建、路径获取
- `RCMMFinderExtension/ScriptExecutor.swift` — 脚本执行
- `RCMMShared/Sources/Services/SharedConfigService.swift` — 配置读取

**FR-APP-DISCOVERY (应用发现) →**
- `RCMMApp/Services/AppDiscoveryService.swift` — /Applications 扫描
- `RCMMApp/Views/Settings/MenuConfigTab.swift` — 应用列表 UI（内嵌应用发现）
- `RCMMShared/Sources/Models/AppInfo.swift` — 应用信息模型

**FR-COMMAND (命令模板) →**
- `RCMMShared/Sources/Services/CommandMappingService.swift` — bundleId → 命令映射
- `RCMMApp/Services/ScriptInstallerService.swift` — .scpt 生成与安装
- `RCMMApp/Views/Settings/MenuConfigTab.swift` — 自定义命令编辑 UI（DisclosureGroup 内联）

**FR-ONBOARDING (首次引导) →**
- `RCMMApp/Views/Onboarding/` — 引导流程全部 View
- `RCMMApp/Services/PluginKitService.swift` — Extension 状态检测

**FR-HEALTH (扩展健康) →**
- `RCMMApp/Services/PluginKitService.swift` — pluginkit 调用
- `RCMMApp/Views/MenuBar/HealthWarningView.swift` — 健康警告 UI

**FR-UI (用户界面) →**
- `RCMMApp/Views/MenuBar/` — MenuBarExtra 弹出窗口
- `RCMMApp/Views/Settings/` — Settings TabView
- `RCMMApp/AppState.swift` — 状态管理

**FR-SYSTEM (系统集成) →**
- `RCMMApp/Views/Settings/GeneralTab.swift` — 开机自启 UI
- `RCMMApp/rcmmApp.swift` — SMAppService 调用

**FR-ERROR (错误处理) →**
- `RCMMShared/Sources/Models/ErrorRecord.swift` — 错误模型
- `RCMMShared/Sources/Services/SharedErrorQueue.swift` — 错误队列
- `RCMMFinderExtension/ScriptExecutor.swift` — 错误捕获与写入

**FR-DATA (数据管理) →**
- `RCMMShared/Sources/Services/SharedConfigService.swift` — 配置持久化
- `RCMMShared/Sources/Services/DarwinNotificationCenter.swift` — 实时同步
- `RCMMShared/Sources/Constants/` — 所有共享常量

### Cross-Cutting Concerns Mapping

| 关注点 | 涉及文件 |
|---|---|
| App Group 数据共享 | SharedConfigService, SharedErrorQueue, SharedKeys, AppGroupConstants |
| Darwin Notifications | DarwinNotificationCenter, NotificationNames, FinderSync.swift, AppState.swift |
| 沙盒边界 | ScriptExecutor (Extension 侧), ScriptInstallerService (App 侧) |
| os_log 日志 | 所有 Service 文件，使用统一 subsystem + category |
| macOS 版本兼容 | ActivationPolicyManager, PluginKitService（系统设置 URL 适配） |

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**
所有技术选型互相兼容：Swift 6.x + SwiftUI + @Observable（macOS 14+）+ MenuBarExtra（macOS 13+）+ SMAppService（macOS 13+），统一在 macOS 15+ 最低版本下无冲突。App Group + UserDefaults + Darwin Notifications 的 IPC 方案经过技术研究验证可行。

**Pattern Consistency:**
命名规范统一遵循 Swift API Design Guidelines；所有共享常量集中在 RCMMShared/Constants/；App Group 键名和 Darwin Notification 名称有明确的命名格式和常量定义。

**Structure Alignment:**
3 个构建目标（App + Extension + 共享 Package）的项目结构完整支持进程隔离、沙盒边界、数据共享的架构需求。Package 依赖边界明确（RCMMShared 不依赖 SwiftUI/AppKit/FinderSync）。

### Requirements Coverage Validation ✅

**Functional Requirements Coverage:**
33/33 FR 全部有架构支持和结构映射。每个 FR 能力域都有明确的文件/目录对应关系。

**Non-Functional Requirements Coverage:**
- 性能：✅ 轻量配置读取（~4KB UserDefaults），无缓存层开销
- 可靠性：✅ 扩展健康检测（pluginkit）+ 错误队列 + macOS 版本适配
- 安全性：✅ 零遥测、无网络层、Entitlements 最小化、沙盒隔离
- 可访问性：✅ SwiftUI 原生组件 + 命名规范中包含 accessibilityLabel 要求

### Implementation Readiness Validation ✅

**Decision Completeness:**
8 项核心架构决策全部记录，含选择、理由、影响分析。实现顺序和跨组件依赖已定义。

**Structure Completeness:**
完整的目录树包含所有文件和目录，每个文件有注释说明用途。进程边界图、Package 依赖边界表、数据流图均已定义。

**Pattern Completeness:**
8 个冲突领域全部有统一规范。包含正例和反例（Anti-Patterns）。强制规则和禁止规则明确列出。

### Gap Analysis Results

| 级别 | Gap | 影响 | 处理 |
|---|---|---|---|
| ⚠️ 重要 | Sparkle 自动更新未在结构中体现 | Phase 4 分发阶段 | 延迟到 Phase 4 添加 |
| ⚠️ 重要 | App Intents 备选入口未在结构中体现 | Phase 5 未来增强 | 延迟到 Phase 5 添加 |
| 💡 建议 | 缺少 CI/CD 配置（GitHub Actions） | 分发阶段 | 延迟到 Phase 4 添加 |
| 💡 建议 | 缺少多语言本地化结构 | Phase 5 | 延迟到 Phase 5 添加 |

所有 Gap 均为 Post-MVP，不阻塞当前实现。

### Architecture Completeness Checklist

**✅ Requirements Analysis**

- [x] 项目上下文全面分析（33 FR + NFR + 技术约束）
- [x] 规模与复杂度评估（低-中等）
- [x] 技术约束识别（9 项约束/依赖）
- [x] 跨切面关注点映射（7 项）

**✅ Architectural Decisions**

- [x] 8 项核心决策记录（含选择、理由）
- [x] 技术栈完整指定（Swift 6 + SwiftUI + macOS 15+）
- [x] 集成模式定义（App Group + Darwin Notifications）
- [x] 性能考量（直接读 UserDefaults，无缓存）

**✅ Implementation Patterns**

- [x] 命名规范（Swift/App Group Keys/Darwin Notifications/脚本/os_log）
- [x] 结构模式（目录组织、文件规则）
- [x] 通信模式（Darwin Notification 协议、状态管理）
- [x] 流程模式（错误处理、脚本生成）

**✅ Project Structure**

- [x] 完整目录结构（所有文件和目录）
- [x] 组件边界（进程边界、Package 依赖边界、数据流边界）
- [x] 集成点映射（App Group、Darwin Notifications、脚本目录）
- [x] 需求到结构的映射（9 个 FR 能力域 → 具体文件）

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** 高 — 基于完整的技术研究验证 + 8 项协作决策 + 全面的模式定义

**Key Strengths:**

- 进程隔离和沙盒边界清晰，职责分明
- 共享 Package 隔离了 FinderSync 依赖，为未来 API 替换做好准备
- TCC 友好的命令执行链路（`do shell script "open -a ..."` 不触发权限弹窗）
- 统一的实现模式和反模式定义，确保 AI agent 一致性

**Areas for Future Enhancement:**

- Phase 4：Sparkle 自动更新、代码签名 + 公证、Homebrew Cask、CI/CD
- Phase 5：App Intents Spotlight 入口、多语言支持、Liquid Glass 适配

### Implementation Handoff

**AI Agent Guidelines:**

- 严格遵循本文档的所有架构决策和实现模式
- 使用 RCMMShared/Constants/ 中的常量，禁止硬编码共享字符串
- 尊重进程边界：Extension 内只用 NSUserAppleScriptTask，主 App 内不引入 FinderSync
- 所有新增 Codable 字段必须可选或有默认值
- 参考技术研究报告处理已知平台 bug（MenuBarExtra Settings workaround、UserDefaults 同步问题）

**First Implementation Priority:**

1. Xcode 项目创建（8 步初始化流程，见 Starter Template Evaluation）
2. RCMMShared Package 搭建（Models + Constants）
3. Extension 右键菜单硬编码验证（FinderSync.swift + 单个 .scpt）
4. 验证完整链路：右键 → 菜单 → 脚本执行 → Terminal.app 打开
