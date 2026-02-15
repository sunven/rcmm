---
stepsCompleted: ["step-01-validate-prerequisites", "step-02-design-epics", "step-03-create-stories", "step-04-final-validation"]
inputDocuments:
  - prd.md
  - architecture.md
  - ux-design-specification.md
---

# rcmm - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for rcmm, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR-MENU-001: 用户可以在 Finder 中右键目录或空白背景时，看到一级菜单项"用 [应用名] 打开"
FR-MENU-002: 用户点击菜单项后，系统使用正确的方式打开目标应用
FR-MENU-003: 系统支持用户添加多个应用到右键菜单，每个应用对应一个菜单项
FR-MENU-004: 用户可以拖拽排序菜单项，顺序决定在菜单中的显示位置
FR-MENU-005: 用户可以将某个应用设为第一项，作为默认打开方式
FR-APP-DISCOVERY-001: 系统自动扫描 /Applications 目录，发现已安装的应用
FR-APP-DISCOVERY-002: 系统展示每个应用的名称、图标、路径
FR-APP-DISCOVERY-003: 用户可以通过文件选择器选择任意 .app 文件添加到菜单
FR-APP-DISCOVERY-004: 系统识别应用类型（终端、编辑器、其他），便于分类展示
FR-COMMAND-001: 对于大多数应用，系统使用 `open -a "{appPath}" "{path}"` 打开目录
FR-COMMAND-002: 系统内置 kitty、Alacritty、WezTerm 等特殊终端的正确打开命令
FR-COMMAND-003: 用户可以为应用编辑自定义命令模板，支持 `{app}` 和 `{path}` 占位符
FR-COMMAND-004: 用户在编辑自定义命令时，可以预览命令效果
FR-ONBOARDING-001: 用户首次打开应用时，系统自动启动引导流程
FR-ONBOARDING-002: 引导流程中，用户可以从扫描结果中选择要添加的应用
FR-ONBOARDING-003: 引导流程检测扩展状态，引导用户到系统设置启用扩展
FR-ONBOARDING-004: 引导完成后，系统提示用户测试右键菜单是否正常工作
FR-HEALTH-001: 系统定期或启动时检测 Finder Sync Extension 的注册状态
FR-HEALTH-002: 系统能识别扩展未启用、被禁用、状态未知等异常情况
FR-HEALTH-003: 系统通过菜单栏图标或状态指示器显示扩展健康状态
FR-HEALTH-004: 当检测到扩展异常时，系统提供一键恢复功能，引导用户到系统设置页面
FR-UI-MENUBAR-001: 应用在菜单栏显示图标，点击可弹出设置界面
FR-UI-MENUBAR-002: 应用运行时不在 Dock 中显示图标
FR-UI-SETTINGS-001: 应用提供独立的设置窗口管理所有配置
FR-UI-SETTINGS-002: 设置窗口展示所有已配置的菜单项，支持添加、删除、编辑操作
FR-UI-SETTINGS-003: 设置窗口中支持拖拽重新排序菜单项
FR-SYSTEM-001: 用户可以启用开机自动启动功能
FR-SYSTEM-002: 系统显示当前开机自启的状态
FR-ERROR-001: 系统检测目标应用是否已安装/存在
FR-ERROR-002: 当应用启动失败时，系统显示包含错误原因和操作建议的错误提示
FR-ERROR-003: 错误提示中包含恢复建议（如移除菜单项、安装应用）
FR-DATA-001: 用户的菜单配置持久保存，重启后保持
FR-DATA-002: 主应用的配置变更在 1 秒内同步到 Finder Extension

### NonFunctional Requirements

NFR-PERF-001: 右键菜单响应时间 ≤ 2秒（从点击菜单项到应用启动）
NFR-PERF-002: 主应用启动时间 ≤ 3秒（从点击图标到设置窗口显示）
NFR-PERF-003: 菜单栏常驻时内存占用 ≤ 50MB
NFR-PERF-004: 首次扫描 /Applications 时间 ≤ 5秒
NFR-REL-001: macOS 15 Sequoia 100% 功能正常
NFR-REL-002: macOS 26 Tahoe 100% 功能正常
NFR-REL-003: 扩展健康检测准确率 ≥ 95%
NFR-REL-004: 崩溃率 ≤ 0.1%（每千次启动）
NFR-SEC-001: 零遥测，零用户数据收集
NFR-SEC-002: 仅请求必要系统权限（权限最小化）
NFR-SEC-003: 代码签名（Developer ID）
NFR-SEC-004: Apple Notarization 公证
NFR-ACC-001: VoiceOver 可读取所有交互元素
NFR-ACC-002: 设置窗口支持键盘导航操作
NFR-ACC-003: 支持系统动态字体大小设置

### Additional Requirements

**来自 Architecture：**

- **Starter Template**: Xcode 手动项目创建，8 步初始化流程（App + Extension + 共享 Package + App Group + Entitlements）
- 3 个构建目标架构：RCMMApp（主应用，非沙盒）+ RCMMFinderExtension（Finder Sync Extension，沙盒）+ RCMMShared（本地 Swift Package, static）
- 数据持久化使用 UserDefaults(suiteName:) + JSON Data，如遇 Sequoia 同步问题降级到 App Group 容器 JSON 文件
- Extension 每次直接读 UserDefaults，不缓存（配置量小 ~4KB，读取 < 1ms）
- 脚本管理：按应用生成专用 .scpt 文件（`<menuItemUUID>.scpt`），主 App 配置变更时重新生成
- 脚本执行：Extension 通过 NSUserAppleScriptTask 执行预装脚本
- 进程间通信：Darwin Notifications（信号）+ App Group UserDefaults（数据），单向写入模型
- 状态管理：单一 AppState（@Observable）作为主 App source of truth
- 错误处理：Extension 写入 App Group 错误队列（最多 20 条 FIFO），主 App 激活时读取展示
- 日志：os_log（subsystem = bundle ID, category = 功能域）
- 命名规范：Swift API Design Guidelines；App Group 键名 `rcmm.<domain>.<key>`；Darwin Notification `com.sunven.rcmm.<eventName>`
- 所有共享常量集中在 RCMMShared/Constants/（SharedKeys, NotificationNames, AppGroupConstants）
- 禁止在 Extension 内弹自定义窗口/Alert
- 禁止使用 ObservableObject/@Published（统一用 @Observable）
- RCMMShared 禁止依赖 SwiftUI/AppKit/FinderSync
- Swift 6.x，初期使用 Swift 5 语言模式（SWIFT_STRICT_CONCURRENCY=targeted）
- 开发阶段 Development 签名，分发阶段注册 Developer Program

**来自 UX Design：**

- MenuBarExtra 弹出窗口：状态驱动（正常/异常/引导），宽度 ~280-320pt，高度自适应
- Settings 窗口：TabView 分页（菜单配置/通用/关于），~480×400pt
- 引导流程 3 步：启用扩展 → 选择应用 → 验证右键
- 5 个自定义组件需实现：OnboardingStepIndicator、AppListRow、HealthStatusPanel、RecoveryGuidePanel、CommandEditor
- 渐进式披露：默认简单列表，DisclosureGroup 展开自定义命令编辑
- 菜单栏图标状态：正常（默认色）/ 警告（黄色 + 感叹号）/ 异常（红色 + 斜杠）
- 色盲友好：健康状态同时使用 SF Symbol 变体和颜色
- 所有交互元素添加 .accessibilityLabel
- 拖拽排序同时提供 .accessibilityAction 替代方案
- 配置变更无显式反馈（实时生效即最好的反馈）
- 错误处理利用系统默认对话框，不重复造轮子
- 完全使用 macOS 系统语义颜色，不定义自定义品牌色
- 完全使用 SwiftUI 系统字体，命令编辑器使用 .monospaced

### FR Coverage Map

| FR | Epic | 描述 |
|---|---|---|
| FR-MENU-001 | Epic 1 | 右键菜单一级菜单项显示 |
| FR-MENU-002 | Epic 1 | 点击菜单项打开目标应用 |
| FR-MENU-003 | Epic 2 | 多应用多菜单项 |
| FR-MENU-004 | Epic 2 | 拖拽排序菜单项 |
| FR-MENU-005 | Epic 2 | 设置默认（第一项） |
| FR-APP-DISCOVERY-001 | Epic 2 | 自动扫描 /Applications |
| FR-APP-DISCOVERY-002 | Epic 2 | 展示应用名称、图标、路径 |
| FR-APP-DISCOVERY-003 | Epic 2 | 手动添加任意 .app |
| FR-APP-DISCOVERY-004 | Epic 2 | 识别应用类型 |
| FR-COMMAND-001 | Epic 4 | 默认 open -a 命令 |
| FR-COMMAND-002 | Epic 4 | 内置特殊终端命令映射 |
| FR-COMMAND-003 | Epic 4 | 自定义命令模板编辑 |
| FR-COMMAND-004 | Epic 4 | 命令预览 |
| FR-ONBOARDING-001 | Epic 3 | 首次打开自动引导 |
| FR-ONBOARDING-002 | Epic 3 | 引导中选择应用 |
| FR-ONBOARDING-003 | Epic 3 | 引导启用扩展 |
| FR-ONBOARDING-004 | Epic 3 | 引导后验证测试 |
| FR-UI-MENUBAR-001 | Epic 5 | 菜单栏图标 + 弹出窗口 |
| FR-UI-MENUBAR-002 | Epic 5 | 无 Dock 图标 |
| FR-HEALTH-001 | Epic 6 | 定期/启动时检测扩展状态 |
| FR-HEALTH-002 | Epic 6 | 识别异常情况 |
| FR-HEALTH-003 | Epic 6 | 菜单栏图标状态指示 |
| FR-HEALTH-004 | Epic 6 | 一键恢复引导 |
| FR-UI-SETTINGS-001 | Epic 2 | 独立设置窗口 |
| FR-UI-SETTINGS-002 | Epic 2 | 菜单项增删改 |
| FR-UI-SETTINGS-003 | Epic 2 | 拖拽排序 |
| FR-SYSTEM-001 | Epic 5 | 开机自启 |
| FR-SYSTEM-002 | Epic 5 | 开机自启状态显示 |
| FR-ERROR-001 | Epic 7 | 检测应用是否存在 |
| FR-ERROR-002 | Epic 7 | 错误提示含原因和建议 |
| FR-ERROR-003 | Epic 7 | 恢复建议 |
| FR-DATA-001 | Epic 1 | 配置持久保存 |
| FR-DATA-002 | Epic 2 | 配置变更实时同步 |

## Epic List

### Epic 1: 项目基础与右键菜单核心链路
用户可以在 Finder 中右键目录，通过硬编码菜单项打开 Terminal.app，验证完整链路（右键 → 菜单 → 脚本执行 → 应用打开）。
**FRs covered:** FR-MENU-001, FR-MENU-002, FR-DATA-001

### Epic 2: 应用发现与菜单配置管理
用户可以从已安装应用列表中选择应用添加到右键菜单，也可以手动添加任意 .app，并通过拖拽排序管理菜单项的显示顺序。
**FRs covered:** FR-APP-DISCOVERY-001, FR-APP-DISCOVERY-002, FR-APP-DISCOVERY-003, FR-APP-DISCOVERY-004, FR-MENU-003, FR-MENU-004, FR-MENU-005, FR-UI-SETTINGS-001, FR-UI-SETTINGS-002, FR-UI-SETTINGS-003, FR-DATA-002

### Epic 3: 首次引导体验
用户首次打开 rcmm 时，系统自动引导完成应用选择和扩展启用，引导结束后用户在 Finder 中验证右键菜单正常工作。
**FRs covered:** FR-ONBOARDING-001, FR-ONBOARDING-002, FR-ONBOARDING-003, FR-ONBOARDING-004

### Epic 4: 自定义命令与特殊终端支持
高级用户可以为应用编辑自定义打开命令，系统内置 kitty/Alacritty/WezTerm 等特殊终端的正确命令映射，编辑时可实时预览命令效果。
**FRs covered:** FR-COMMAND-001, FR-COMMAND-002, FR-COMMAND-003, FR-COMMAND-004

### Epic 5: 系统集成与菜单栏体验
应用以菜单栏常驻形态运行（无 Dock 图标），用户可以启用开机自启，菜单栏弹出窗口展示状态概览和快捷操作。
**FRs covered:** FR-UI-MENUBAR-001, FR-UI-MENUBAR-002, FR-SYSTEM-001, FR-SYSTEM-002

### Epic 6: 扩展健康检测与恢复引导
系统自动检测 Finder Extension 的健康状态，通过菜单栏图标实时反映状态，异常时提供一键恢复引导。
**FRs covered:** FR-HEALTH-001, FR-HEALTH-002, FR-HEALTH-003, FR-HEALTH-004

### Epic 7: 错误处理与用户反馈
系统检测应用是否存在，启动失败时提供包含原因和恢复建议的错误提示，帮助用户自助解决问题。
**FRs covered:** FR-ERROR-001, FR-ERROR-002, FR-ERROR-003

## Epic 1: 项目基础与右键菜单核心链路

用户可以在 Finder 中右键目录，通过硬编码菜单项打开 Terminal.app，验证完整链路（右键 → 菜单 → 脚本执行 → 应用打开）。

### Story 1.1: Xcode 项目初始化与三目标架构搭建

As a 开发者,
I want 创建包含主应用、Finder Sync Extension 和共享 Package 的 Xcode 项目,
So that 项目具备正确的构建目标、签名配置和 App Group 共享基础。

**Acceptance Criteria:**

**Given** 开发者在 Xcode 中创建新项目
**When** 按照 8 步初始化流程完成配置
**Then** 项目包含 RCMMApp（主应用）、RCMMFinderExtension（Finder Sync Extension）、RCMMShared（本地 Swift Package）三个构建目标
**And** 两个 target 均配置 App Group: group.com.sunven.rcmm
**And** Extension target 启用 App Sandbox
**And** 主 App Info.plist 配置 LSUIElement = YES
**And** RCMMShared Package 配置 platforms: .macOS(.v15), type: .static
**And** 两个 target 均添加 RCMMShared 依赖
**And** DISABLE_DIAMOND_PROBLEM_DIAGNOSTIC = YES 已设置
**And** 项目可成功编译（零错误）

### Story 1.2: 共享数据层与配置持久化

As a 开发者,
I want 实现 App Group 共享数据层，包括数据模型、配置服务和共享常量,
So that 主应用和 Extension 可以通过 App Group UserDefaults 共享菜单配置数据。

**Acceptance Criteria:**

**Given** RCMMShared Package 已创建
**When** 实现 Models（MenuItemConfig, AppInfo, ExtensionStatus, ErrorRecord, PopoverState）、Services（SharedConfigService, DarwinNotificationCenter）和 Constants（AppGroupConstants, SharedKeys, NotificationNames）
**Then** MenuItemConfig 实现 Codable, Identifiable, Hashable，包含 id(UUID)、appName、bundleId、appPath、customCommand(可选)、sortOrder 字段
**And** SharedConfigService 可通过 UserDefaults(suiteName:) 保存和读取 [MenuItemConfig] 数组
**And** 所有 App Group 键名定义为 SharedKeys 枚举的静态常量
**And** 所有 Darwin Notification 名称定义为 NotificationNames 枚举的静态常量
**And** DarwinNotificationCenter 可发送和监听跨进程通知
**And** RCMMShared 不依赖 SwiftUI、AppKit 或 FinderSync
**And** 单元测试验证 MenuItemConfig 编解码和 SharedConfigService 读写

### Story 1.3: Finder 右键菜单与脚本执行端到端验证

As a 用户,
I want 在 Finder 中右键目录时看到"用 Terminal 打开"菜单项，点击后 Terminal.app 打开并定位到该目录,
So that 我可以验证右键菜单到应用打开的完整链路正常工作。

**Acceptance Criteria:**

**Given** Extension 已在系统设置中启用
**When** 用户在 Finder 中右键一个目录
**Then** 出现一级菜单项"用 Terminal 打开"（硬编码配置）
**And** 菜单项显示 Terminal.app 的系统图标

**Given** 用户看到右键菜单中的"用 Terminal 打开"
**When** 用户点击该菜单项
**Then** Extension 通过 NSUserAppleScriptTask 执行对应的 .scpt 脚本
**And** Terminal.app 在 ≤ 2 秒内打开并 cd 到用户右键的目录路径
**And** 右键窗口空白背景时，使用当前窗口的目录路径

**Given** 主应用启动
**When** 应用初始化时
**Then** ScriptInstallerService 在 Extension 脚本目录生成对应的 .scpt 文件
**And** 脚本文件命名为 `<menuItemUUID>.scpt`
**And** 脚本内容使用 `do shell script "open -a Terminal {path}"` 格式

## Epic 2: 应用发现与菜单配置管理

用户可以从已安装应用列表中选择应用添加到右键菜单，也可以手动添加任意 .app，并通过拖拽排序管理菜单项的显示顺序。

### Story 2.1: 应用发现服务与应用信息模型

As a 用户,
I want 系统自动扫描已安装的应用并展示名称、图标和类型信息,
So that 我可以快速找到想添加到右键菜单的应用。

**Acceptance Criteria:**

**Given** 用户打开应用发现界面
**When** AppDiscoveryService 扫描 /Applications 和 ~/Applications
**Then** 返回已安装应用列表，每个应用包含名称、图标（NSWorkspace.shared.icon(forFile:)）、bundleId、路径
**And** 扫描时间 ≤ 5 秒
**And** 系统识别应用类型（终端、编辑器、其他），基于 bundleId 匹配已知列表
**And** 应用列表按类型分组展示（终端类优先、编辑器次之、其他最后）

**Given** 用户想添加不在 /Applications 中的应用
**When** 用户点击"手动添加"按钮
**Then** 弹出 NSOpenPanel 文件选择器，过滤 .app 文件
**And** 选择后应用信息正确提取并加入列表

### Story 2.2: 设置窗口与菜单项管理

As a 用户,
I want 通过设置窗口添加、删除和管理右键菜单中的应用,
So that 我可以自由控制右键菜单显示哪些应用。

**Acceptance Criteria:**

**Given** 用户打开设置窗口
**When** 设置窗口加载
**Then** 显示 TabView 分页设置界面，菜单配置为默认 Tab
**And** 菜单配置 Tab 展示当前已配置的所有菜单项列表（AppListRow 组件：图标 + 名称 + 状态）

**Given** 用户在设置窗口中
**When** 用户点击"添加应用"按钮
**Then** 展示应用发现列表，用户可勾选应用添加到菜单
**And** 添加后菜单项立即出现在配置列表中

**Given** 用户在菜单配置列表中
**When** 用户点击某个菜单项的删除按钮
**Then** 该菜单项从列表中移除
**And** 对应的 .scpt 脚本文件被删除

**Given** 用户完成菜单项增删操作
**When** 配置保存
**Then** SharedConfigService 将配置写入 App Group UserDefaults
**And** 所有交互元素具有 .accessibilityLabel，支持 VoiceOver 读取
**And** 设置窗口支持键盘 Tab 导航

### Story 2.3: 菜单项拖拽排序与默认项

As a 用户,
I want 通过拖拽调整菜单项顺序，第一项自动成为默认打开方式,
So that 我最常用的应用始终在右键菜单的最顶部。

**Acceptance Criteria:**

**Given** 用户在菜单配置列表中有多个菜单项
**When** 用户拖拽某个菜单项到新位置
**Then** 列表顺序实时更新，使用 SwiftUI List + .onMove
**And** 排在第一位的菜单项自动标记为默认项
**And** sortOrder 字段按新顺序更新并持久化

**Given** 使用 VoiceOver 的用户
**When** 用户通过辅助功能操作排序
**Then** 提供 .accessibilityAction 替代拖拽操作（上移/下移）
**And** VoiceOver 读出当前位置信息

### Story 2.4: 配置实时同步与动态右键菜单

As a 用户,
I want 在设置窗口中修改菜单配置后，下次右键 Finder 立即看到更新后的菜单,
So that 配置变更无需重启即可生效。

**Acceptance Criteria:**

**Given** 用户在设置窗口中添加/删除/排序了菜单项
**When** 配置保存完成
**Then** 主应用通过 DarwinNotificationCenter 发送 configChanged 通知
**And** ScriptInstallerService 根据最新配置同步增删改 .scpt 文件
**And** 配置变更到 Extension 可用的延迟 ≤ 1 秒

**Given** Extension 收到 configChanged 通知
**When** 用户下次在 Finder 中右键
**Then** Extension 从 App Group UserDefaults 读取最新配置
**And** 右键菜单显示更新后的菜单项列表（正确的名称、图标、顺序）
**And** 每个菜单项对应正确的 .scpt 脚本，点击后打开对应应用

## Epic 3: 首次引导体验

用户首次打开 rcmm 时，系统自动引导完成应用选择和扩展启用，引导结束后用户在 Finder 中验证右键菜单正常工作。

### Story 3.1: 引导流程框架与扩展启用引导

As a 首次用户,
I want 打开 rcmm 后自动进入引导流程，第一步引导我启用 Finder Extension,
So that 我不需要自己摸索如何让右键菜单生效。

**Acceptance Criteria:**

**Given** 用户首次打开 rcmm（无已保存配置）
**When** 应用启动
**Then** 自动进入引导流程，显示 OnboardingFlowView
**And** 顶部显示 OnboardingStepIndicator（步骤 1/3，当前高亮）
**And** 如果 Extension 已启用（pluginkit 检测），自动跳过此步进入步骤 2

**Given** 用户在引导步骤 1（启用扩展）
**When** 用户点击"前往系统设置"按钮
**Then** 通过 NSWorkspace.open(URL) 跳转到系统设置中 Extension 管理页面
**And** 页面显示适配当前 macOS 版本的正确路径说明（macOS 15 vs macOS 26）

**Given** 用户从系统设置返回
**When** 引导界面检测扩展状态
**Then** 提供"重新检测"按钮，点击后通过 PluginKitService 检测 Extension 注册状态
**And** 检测到已启用时，自动进入步骤 2
**And** 提供"跳过"选项，用户可选择稍后启用

### Story 3.2: 应用选择引导步骤

As a 首次用户,
I want 在引导流程中从已安装应用列表中快速选择要添加到右键菜单的应用,
So that 我不需要手动逐个配置。

**Acceptance Criteria:**

**Given** 用户进入引导步骤 2（选择应用）
**When** 步骤加载
**Then** OnboardingStepIndicator 更新为步骤 2/3
**And** 自动调用 AppDiscoveryService 扫描已安装应用
**And** 展示紧凑模式的 AppListRow 列表（图标 + 名称 + 勾选框）
**And** 预选常见开发工具（VS Code、Terminal、iTerm2，基于 bundleId 匹配）

**Given** 用户在应用选择列表中
**When** 用户勾选/取消勾选应用
**Then** 选择状态实时更新
**And** 底部显示已选数量

**Given** 用户完成应用选择
**When** 用户点击"下一步"
**Then** 选中的应用保存为 MenuItemConfig 写入 App Group UserDefaults
**And** ScriptInstallerService 为每个选中应用生成 .scpt 文件
**And** 发送 Darwin Notification 通知 Extension

### Story 3.3: 验证步骤与引导完成

As a 首次用户,
I want 引导最后一步提示我去 Finder 测试右键菜单，确认一切正常,
So that 我在引导结束时就能体验到产品价值。

**Acceptance Criteria:**

**Given** 用户进入引导步骤 3（验证）
**When** 步骤加载
**Then** OnboardingStepIndicator 更新为步骤 3/3
**And** 显示提示文字"现在去 Finder 试试右键！"
**And** 显示简要操作指引（右键目录 → 点击菜单项）

**Given** 用户测试完成后返回引导界面
**When** 用户点击"完成"按钮
**Then** 显示引导完成确认
**And** 提供开机自启选项（Toggle，默认开启）
**And** 引导状态标记为已完成，下次启动不再触发引导
**And** 关闭引导窗口，应用进入正常菜单栏常驻状态

## Epic 4: 自定义命令与特殊终端支持

高级用户可以为应用编辑自定义打开命令，系统内置 kitty/Alacritty/WezTerm 等特殊终端的正确命令映射，编辑时可实时预览命令效果。

### Story 4.1: 命令映射服务与内置特殊终端支持

As a 用户,
I want 系统自动为大多数应用使用正确的打开命令，特殊终端（kitty/Alacritty/WezTerm）自动使用专用参数,
So that 我添加应用后无需手动配置命令就能正确打开目录。

**Acceptance Criteria:**

**Given** 用户添加一个普通应用（如 VS Code）到菜单
**When** ScriptInstallerService 生成 .scpt 脚本
**Then** 使用默认命令模板 `do shell script "open -a \"{appPath}\" \"{path}\""` 生成脚本

**Given** 用户添加 kitty 到菜单
**When** CommandMappingService 查找 bundleId 对应的命令映射
**Then** 返回 kitty 专用命令：`/Applications/kitty.app/Contents/MacOS/kitty --single-instance --directory "{path}"`
**And** 生成的 .scpt 使用专用命令而非默认 open -a

**Given** CommandMappingService 初始化
**When** 加载内置映射字典
**Then** 包含 kitty、Alacritty、WezTerm 的正确打开命令
**And** 映射字典以 bundleId 为键，可扩展
**And** 单元测试验证所有内置映射的命令格式正确

### Story 4.2: 自定义命令编辑器

As a 高级用户,
I want 为应用编辑自定义打开命令，使用 `{app}` 和 `{path}` 占位符,
So that 我可以让特殊终端或自定义工具以正确的方式打开目录。

**Acceptance Criteria:**

**Given** 用户在菜单配置列表中查看某个应用
**When** 用户点击"自定义"或展开 DisclosureGroup
**Then** 内联展开 CommandEditor 组件
**And** 编辑器使用等宽字体（.system(.body, design: .monospaced)）
**And** 显示当前命令模板（默认或内置映射）
**And** 占位符 `{app}` 和 `{path}` 有视觉提示

**Given** 用户在 CommandEditor 中编辑命令
**When** 用户修改命令文本
**Then** 实时预览区显示替换占位符后的完整命令（使用示例路径如 /Users/example/project）
**And** 编辑器支持标准文本编辑键盘快捷键

**Given** 用户保存自定义命令
**When** 点击保存或关闭编辑器
**Then** customCommand 字段更新到 MenuItemConfig 并持久化
**And** ScriptInstallerService 使用自定义命令重新生成 .scpt 文件
**And** Darwin Notification 通知 Extension 配置已变更
**And** CommandEditor 具有 .accessibilityLabel("自定义命令编辑器") 和 .accessibilityHint

### Story 4.3: 命令预览与验证

As a 高级用户,
I want 在编辑自定义命令时实时预览最终执行的完整命令,
So that 我可以在保存前确认命令格式正确。

**Acceptance Criteria:**

**Given** 用户在 CommandEditor 中输入命令模板
**When** 命令包含 `{app}` 和 `{path}` 占位符
**Then** 预览区实时替换 `{app}` 为实际应用路径，`{path}` 为示例目录路径
**And** 预览区使用等宽字体，与编辑区视觉一致

**Given** 用户输入的命令不包含 `{path}` 占位符
**When** 预览区更新
**Then** 显示提示信息"命令中未包含 {path}，目标目录可能不会被传递"

**Given** 用户清空自定义命令
**When** 命令字段为空
**Then** 自动回退到默认命令（open -a）或内置映射命令
**And** 预览区显示回退后的命令

## Epic 5: 系统集成与菜单栏体验

应用以菜单栏常驻形态运行（无 Dock 图标），用户可以启用开机自启，菜单栏弹出窗口展示状态概览和快捷操作。

### Story 5.1: 菜单栏常驻应用与弹出窗口

As a 用户,
I want rcmm 以菜单栏图标常驻运行，点击图标弹出状态概览和快捷操作,
So that 我可以随时查看状态和访问设置，同时不占用 Dock 空间。

**Acceptance Criteria:**

**Given** rcmm 启动
**When** 应用加载完成
**Then** 菜单栏显示 rcmm 图标（MenuBarExtra + .menuBarExtraStyle(.window)）
**And** Dock 中不显示 rcmm 图标（Info.plist LSUIElement = YES）

**Given** 用户点击菜单栏图标
**When** 弹出窗口打开
**Then** PopoverContainerView 根据 AppState 的 PopoverState 枚举路由到对应视图
**And** 正常状态显示 NormalPopoverView：简洁状态行（HealthStatusPanel）+ "打开设置"按钮 + "退出"按钮
**And** 弹出窗口宽度 ~280-320pt，高度自适应内容

**Given** 用户在弹出窗口中点击"打开设置"
**When** 触发设置窗口打开
**Then** 通过 ActivationPolicyManager 切换 ActivationPolicy 打开 Settings 窗口
**And** 正确处理 MenuBarExtra → Settings 窗口的跨版本兼容 workaround

**Given** 用户在弹出窗口中点击"退出"
**When** 触发退出操作
**Then** 应用正常退出（NSApplication.shared.terminate）

### Story 5.2: 开机自启管理

As a 用户,
I want 启用开机自动启动 rcmm，并在设置中查看当前状态,
So that 每次开机后右键菜单自动可用，无需手动打开应用。

**Acceptance Criteria:**

**Given** 用户在设置窗口的通用 Tab 中
**When** 查看开机自启选项
**Then** 显示 Toggle 开关和当前状态文字（"已启用"/"未启用"）
**And** 状态通过 SMAppService.mainApp.status 实时读取

**Given** 用户切换开机自启 Toggle 为开启
**When** Toggle 状态变更
**Then** 调用 SMAppService.mainApp.register() 注册登录项
**And** 状态文字更新为"已启用"
**And** os_log 记录操作（category: "system"）

**Given** 用户切换开机自启 Toggle 为关闭
**When** Toggle 状态变更
**Then** 调用 SMAppService.mainApp.unregister() 取消登录项
**And** 状态文字更新为"未启用"

**Given** SMAppService 注册/取消失败
**When** 操作抛出错误
**Then** Toggle 回退到操作前状态
**And** 显示内联错误提示说明原因

## Epic 6: 扩展健康检测与恢复引导

系统自动检测 Finder Extension 的健康状态，通过菜单栏图标实时反映状态，异常时提供一键恢复引导。

### Story 6.1: 扩展状态检测服务

As a 用户,
I want 系统在启动时和定期自动检测 Finder Extension 的注册状态,
So that 扩展异常时我能被及时告知。

**Acceptance Criteria:**

**Given** 主应用启动
**When** PluginKitService 执行健康检测
**Then** 通过 `pluginkit -m -i <extension-bundle-id>` 查询 Extension 注册状态
**And** 正确解析输出，识别三种状态：已启用（.enabled）、未启用（.disabled）、状态未知（.unknown）
**And** 检测结果更新到 AppState 的 extensionStatus 属性
**And** 使用 os_log 记录检测结果（subsystem: bundle ID, category: "health"）

**Given** 应用已在后台运行
**When** 达到定期检测间隔（如每 30 分钟）
**Then** 自动执行一次健康检测
**And** 状态变化时更新 AppState

**Given** PluginKitService 执行检测
**When** pluginkit 命令执行失败或超时
**Then** 状态设为 .unknown（不误报为异常）
**And** os_log 记录错误详情

### Story 6.2: 菜单栏图标健康状态指示

As a 用户,
I want 通过菜单栏图标颜色和样式一眼看出扩展是否正常工作,
So that 我不需要打开任何界面就能知道右键菜单是否可用。

**Acceptance Criteria:**

**Given** Extension 状态为 .enabled
**When** 菜单栏图标渲染
**Then** 显示默认图标，跟随系统菜单栏色（Light/Dark Mode 自适应）

**Given** Extension 状态为 .unknown
**When** 菜单栏图标渲染
**Then** 显示图标 + 感叹号变体（SF Symbol），黄色警告色
**And** 图标变体与颜色同时传达状态（色盲友好）

**Given** Extension 状态为 .disabled
**When** 菜单栏图标渲染
**Then** 显示图标 + 斜杠变体（SF Symbol），红色异常色
**And** 图标变体与颜色同时传达状态（色盲友好）

**Given** 菜单栏图标显示任意状态
**When** VoiceOver 聚焦到图标
**Then** 读出 .accessibilityLabel("rcmm") 和 .accessibilityValue("[当前状态描述]")

### Story 6.3: 异常恢复引导面板

As a 用户,
I want 扩展异常时在菜单栏弹出窗口中看到原因说明和一键修复按钮,
So that 我可以在 30 秒内恢复右键菜单功能。

**Acceptance Criteria:**

**Given** Extension 状态为 .disabled
**When** 用户点击菜单栏图标
**Then** 弹出窗口显示 RecoveryGuidePanel
**And** 面板包含：HealthStatusPanel（红色异常图标 + "Finder 扩展未启用"）+ 原因说明文字 + "修复"按钮 + "稍后"按钮

**Given** 用户在恢复引导面板中
**When** 用户点击"修复"按钮
**Then** 通过 NSWorkspace.open(URL) 跳转到系统设置中 Extension 管理页面
**And** 跳转 URL 适配当前 macOS 版本（macOS 15 vs macOS 26）

**Given** 用户从系统设置返回后
**When** 应用重新检测扩展状态
**Then** 如果状态恢复为 .enabled，弹出窗口切换回正常视图，菜单栏图标恢复默认
**And** 显示短暂的恢复成功确认（5 秒后淡出）

**Given** 用户在恢复引导面板中
**When** 用户点击"稍后"按钮
**Then** 关闭弹出窗口
**And** 菜单栏图标保持异常状态指示，不强制用户立即修复

**Given** RecoveryGuidePanel 显示
**When** VoiceOver 聚焦
**Then** 读出 .accessibilityLabel("扩展需要修复") 和各按钮独立标签

## Epic 7: 错误处理与用户反馈

系统检测应用是否存在，启动失败时提供包含原因和恢复建议的错误提示，帮助用户自助解决问题。

### Story 7.1: 应用存在性检测与执行错误捕获

As a 用户,
I want 系统在点击菜单项时检测目标应用是否存在，执行失败时记录错误信息,
So that 我能知道为什么点击菜单项后没有反应。

**Acceptance Criteria:**

**Given** 用户点击右键菜单中的某个菜单项
**When** Extension 执行对应的 .scpt 脚本
**Then** 如果目标应用已安装且路径有效，应用正常打开
**And** 如果目标应用未安装或路径无效，macOS 系统错误对话框自动弹出（`open` 命令默认行为）

**Given** Extension 执行脚本失败（脚本文件缺失、权限错误等）
**When** NSUserAppleScriptTask 回调返回错误
**Then** Extension 将错误信息写入 App Group 错误队列（SharedErrorQueue）
**And** ErrorRecord 包含 id、timestamp、source("extension")、message、context（菜单项名称）
**And** 错误队列最多保留 20 条记录，FIFO 淘汰
**And** os_log 记录错误详情（subsystem: extension bundle ID, category: "script"）

**Given** 主应用配置变更时
**When** ScriptInstallerService 生成 .scpt 前
**Then** 检测目标应用路径是否有效（FileManager.default.fileExists）
**And** 应用不存在时在菜单配置列表中标记警告状态（图标灰化 + 警告标签）

### Story 7.2: 错误展示与恢复建议

As a 用户,
I want 打开 rcmm 时看到之前的执行错误和恢复建议,
So that 我可以自助解决"点了没反应"的问题。

**Acceptance Criteria:**

**Given** Extension 之前记录了执行错误到错误队列
**When** 用户打开主应用（点击菜单栏图标或激活应用）
**Then** 主应用从 SharedErrorQueue 读取未处理的错误记录
**And** 在弹出窗口顶部展示最近的错误信息

**Given** 错误信息展示中
**When** 用户查看错误详情
**Then** 显示错误原因（如"VS Code 未找到"、"脚本执行失败"）
**And** 显示恢复建议（如"请在设置中移除此菜单项或安装应用"、"请重新打开应用以修复脚本"）
**And** 提供操作按钮（如"打开设置"跳转到菜单管理）

**Given** 用户处理完错误
**When** 用户关闭错误提示或执行了恢复操作
**Then** 对应的错误记录从队列中移除
**And** 弹出窗口恢复正常视图

**Given** 脚本文件缺失的错误
**When** 用户下次打开主应用
**Then** ScriptInstallerService 自动检测并重新生成缺失的 .scpt 文件
**And** 显示提示"已自动修复脚本文件"
