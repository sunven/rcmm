---
stepsCompleted: ["step-01-init", "step-02-discovery", "step-03-success", "step-04-journeys", "step-05-domain", "step-06-innovation", "step-07-project-type", "step-08-scoping", "step-09-functional", "step-10-nonfunctional", "step-11-polish"]
inputDocuments:
  - product-brief-rcmm-2026-02-12.md
  - domain-macos-finder-context-menu-tool-research-2026-02-12.md
  - market-macos-finder-context-menu-tool-research-2026-02-12.md
  - technical-macos-finder-context-menu-tool-research-2026-02-12.md
date: 2026-02-14
author: Sunven
classification:
  projectType: desktop_app
  domain: developer_tool
  complexity: low
  projectContext: greenfield
---

# Product Requirements Document - rcmm

**Author:** Sunven
**Date:** 2026-02-14

---

## 执行摘要

rcmm（Right Click Menu Manager）是一个 macOS Finder 右键菜单配置中心，让用户在 Finder 中右键目录或空白背景，用任意应用打开当前路径。

### 核心差异化

| 维度 | OpenInTerminal | rcmm |
|---|---|---|
| 首次体验 | 安装后需额外配置才生效 | 首次打开即引导，引导完即可用 |
| 应用支持 | 硬编码 40+ 应用枚举 | 自动发现 + 自定义命令，任意应用 |
| 稳定性 | 无健康检测，macOS 升级后可能默默失效 | 内置扩展健康检测 + 恢复引导 |
| 架构复杂度 | 6 个构建目标 | 3 个构建目标 |
| UI 框架 | Cocoa + Storyboard | SwiftUI（macOS 15+） |

### 目标用户

**小明** — 全栈/前端开发者。日常在 Finder、VS Code、终端之间高频切换。曾用 OpenInTerminal，但 macOS 升级后失效。

**阿强** — DevOps 工程师。使用 Kitty 等非主流终端，需要特殊参数才能正确打开目录。

---

## 成功标准

### 用户成功

| 指标 | 定义 | 目标 |
|---|---|---|
| **首次引导完成率** | 用户首次打开 app 后，能顺利完成引导流程并成功使用右键菜单 | ≥ 80% |
| **右键菜单响应时间** | 点击菜单项后，目标应用在合理时间内打开 | ≤ 2 秒 |
| **跨版本稳定性** | macOS 大版本升级后，扩展健康检测能正确识别异常并引导恢复 | 检测准确率 ≥ 95% |

### 业务成功

当前阶段聚焦产品质量，业务指标和开源策略待后续制定。

- GitHub stars 作为社区认可度指标
- Homebrew 安装量作为用户获取指标
- 用户口碑和推荐作为自然增长指标

### 技术成功

| 指标 | 定义 | 目标 |
|---|---|---|
| **双版本兼容性** | macOS 15 Sequoia 和 macOS 26 Tahoe 双版本验证通过 | 100% 功能正常 |
| **扩展健康检测** | 能正确识别 Extension 注册状态异常 | 准确识别并引导恢复 |
| **启动性能** | 主应用启动时间 | ≤ 3 秒 |
| **资源占用** | 菜单栏常驻时的内存占用 | ≤ 50MB |

---

## 产品范围

### MVP - 最小可行产品

**核心功能：**

1. **Finder Sync Extension 右键菜单** — 右键目录或空白背景，一级菜单项点击即打开目标应用
2. **统一菜单配置** — 添加/删除/拖拽排序菜单项，第一项即默认
3. **自动应用发现** — 扫描 /Applications 展示已安装应用
4. **手动添加应用** — 通过 NSOpenPanel 选择任意 .app
5. **自定义打开命令** — 高级用户可编辑命令模板（`open -a {app} {path}`）
6. **内置特殊命令映射** — kitty、Alacritty、WezTerm 等自动使用正确参数
7. **首次引导流程** — 选应用 → 授权 → 确认扩展启用
8. **扩展健康检测** — 检测 Extension 注册状态，异常时引导恢复
9. **菜单栏常驻** — LSUIElement，无 Dock 图标
10. **开机自启** — SMAppService.mainApp

**技术约束：**
- SwiftUI（macOS 15+）
- 3 个构建目标架构（App + Extension + 共享 Package）
- App Group 数据共享

### Growth Features（发布后）

- App Intents / Spotlight 集成
- 多语言支持
- 主题适配（macOS 26 Liquid Glass）

### Vision（未来）

- Sparkle 自动更新集成
- Foundation Models AI 智能推荐
- 社区命令配置分享

---

## 技术架构

### 构建目标

| Target | 类型 | 描述 |
|---|---|---|
| rcmm | 主应用 | 菜单栏常驻，SwiftUI UI，非沙盒 |
| RCMMFinderExtension | Finder Sync Extension | 右键菜单提供，沙盒化 |
| RCMMShared | Swift Package | 共享代码（模型、服务、常量） |

### 技术栈

- **语言**: Swift 6
- **UI 框架**: SwiftUI（macOS 15+）
- **状态管理**: @Observable
- **数据共享**: App Group + UserDefaults
- **进程通信**: Darwin Notifications
- **命令执行**: NSUserAppleScriptTask + 预装 .scpt
- **开机自启**: SMAppService.mainApp

---

## 用户旅程

### 用户画像

| 用户 | 角色 | 描述 |
|---|---|---|
| **小明** | 全栈/前端开发者 | 日常在 Finder、VS Code、终端之间高频切换 |
| **阿强** | DevOps 工程师 | 使用 Kitty 等非主流终端，需要特殊参数 |

### 旅程一：首次使用（小明）

小明在 Finder 中找到项目目录，期待右键看到"用 VS Code 打开"。但什么也没有。他只能手动：右键 → 显示简介 → 复制路径 → 打开 VS Code → 打开... → 粘贴路径。

同事推荐了 rcmm。他安装后打开，菜单栏出现图标。引导流程自动启动：

1. **选择应用**：扫描 /Applications，列出 VS Code、iTerm2、Warp
2. **一键添加**：小明勾选应用
3. **授权提示**：点击按钮，弹出系统设置窗口
4. **启用扩展**：勾选 rcmm
5. **验证成功**：引导提示"右键 Finder 试试看！"

小明回到 Finder，右键目录。一级菜单出现"用 VS Code 打开"。点击后，VS Code 在1秒内打开，项目已加载。

*"就是这个。"*

### 旅程二：特殊终端（阿强）

阿强使用 Kitty 终端，需要特殊参数才能正确打开目录（SSH 脚本加载）。OpenInTerminal 的硬编码支持在 macOS 更新后经常失效。

他安装了 rcmm，打开设置页面。在终端列表中找到 Kitty，默认命令是 `open -a kitty`，这会在新窗口打开而不是切换到正确目录。

他点击"自定义"按钮，编辑命令模板：

```
/Applications/kitty.app/Contents/MacOS/kitty --single-instance --directory "{path}"
```

保存后测试。右键项目目录 → 点击 Kitty。Kitty 启动并直接进入项目目录，SSH 脚本自动加载。

*完美。*

### 旅程三：跨版本稳定性（macOS 升级）

macOS 15.2 发布，小明更新后重启。习惯性地右键 Finder... 菜单项消失了。

他想起 OpenInTerminal 的阴影 — 上次花了2小时排查。

点击 rcmm 菜单栏图标。状态指示器显示红色，提示"Finder 扩展未启用"。

点击"查看详情"，rcmm 解释情况并提供"修复"按钮。点击后打开系统设置页面，引导重新勾选扩展。

30秒后，扩展启用成功。右键菜单恢复正常。

*比 OpenInTerminal 强太多了。*

### 旅程四：错误恢复（应用不存在）

小明分享项目文件夹给阿强。阿强的电脑没有安装 VS Code。

阿强右键项目目录，看到"用 VS Code 打开"。点击... 没有任何反应。

rcmm 检测到应用启动失败，弹出通知："VS Code 未找到。请在设置中移除此菜单项或安装应用。"

阿强打开 rcmm 设置，找到"VS Code"菜单项，删除。然后添加了 Neovim 作为替代。

### 旅程需求总结

| 旅程 | 揭示的功能需求 |
|---|---|
| 首次使用 | 首次引导流程、自动应用发现、系统设置集成、状态反馈 |
| 特殊终端 | 自定义命令模板、占位符支持 |
| macOS 升级恢复 | 扩展健康检测、状态指示器、一键恢复引导 |
| 错误恢复 | 启动失败检测、错误提示、菜单项管理 |

---

## 功能需求

### 右键菜单

- **FR-MENU-001**: 用户可以在 Finder 中右键目录或空白背景时，看到一级菜单项"用 [应用名] 打开"
- **FR-MENU-002**: 用户点击菜单项后，系统使用正确的方式打开目标应用
- **FR-MENU-003**: 系统支持用户添加多个应用到右键菜单，每个应用对应一个菜单项
- **FR-MENU-004**: 用户可以拖拽排序菜单项，顺序决定在菜单中的显示位置
- **FR-MENU-005**: 用户可以将某个应用设为第一项，作为默认打开方式

### 应用发现

- **FR-APP-DISCOVERY-001**: 系统自动扫描 /Applications 目录，发现已安装的应用
- **FR-APP-DISCOVERY-002**: 系统展示每个应用的名称、图标、路径
- **FR-APP-DISCOVERY-003**: 用户可以通过文件选择器选择任意 .app 文件添加到菜单
- **FR-APP-DISCOVERY-004**: 系统识别应用类型（终端、编辑器、其他），便于分类展示

### 命令模板

- **FR-COMMAND-001**: 对于大多数应用，系统使用 `open -a "{appPath}" "{path}"` 打开目录
- **FR-COMMAND-002**: 系统内置 kitty、Alacritty、WezTerm 等特殊终端的正确打开命令
- **FR-COMMAND-003**: 用户可以为应用编辑自定义命令模板，支持 `{app}` 和 `{path}` 占位符
- **FR-COMMAND-004**: 用户在编辑自定义命令时，可以预览命令效果

### 首次引导

- **FR-ONBOARDING-001**: 用户首次打开应用时，系统自动启动引导流程
- **FR-ONBOARDING-002**: 引导流程中，用户可以从扫描结果中选择要添加的应用
- **FR-ONBOARDING-003**: 引导流程检测扩展状态，引导用户到系统设置启用扩展
- **FR-ONBOARDING-004**: 引导完成后，系统提示用户测试右键菜单是否正常工作

### 扩展健康

- **FR-HEALTH-001**: 系统定期或启动时检测 Finder Sync Extension 的注册状态
- **FR-HEALTH-002**: 系统能识别扩展未启用、被禁用、状态未知等异常情况
- **FR-HEALTH-003**: 系统通过菜单栏图标或状态指示器显示扩展健康状态
- **FR-HEALTH-004**: 当检测到扩展异常时，系统提供一键恢复功能，引导用户到系统设置页面

### 用户界面

- **FR-UI-MENUBAR-001**: 应用在菜单栏显示图标，点击可弹出设置界面
- **FR-UI-MENUBAR-002**: 应用运行时不在 Dock 中显示图标
- **FR-UI-SETTINGS-001**: 应用提供独立的设置窗口管理所有配置
- **FR-UI-SETTINGS-002**: 设置窗口展示所有已配置的菜单项，支持添加、删除、编辑操作
- **FR-UI-SETTINGS-003**: 设置窗口中支持拖拽重新排序菜单项

### 系统集成

- **FR-SYSTEM-001**: 用户可以启用开机自动启动功能
- **FR-SYSTEM-002**: 系统显示当前开机自启的状态

### 错误处理

- **FR-ERROR-001**: 系统检测目标应用是否已安装/存在
- **FR-ERROR-002**: 当应用启动失败时，系统显示包含错误原因和操作建议的错误提示
- **FR-ERROR-003**: 错误提示中包含恢复建议（如移除菜单项、安装应用）

### 数据管理

- **FR-DATA-001**: 用户的菜单配置持久保存，重启后保持
- **FR-DATA-002**: 主应用的配置变更在 1 秒内同步到 Finder Extension

---

## 非功能需求

### 性能

| 指标 | 要求 | 测量方式 |
|---|---|---|
| 右键菜单响应时间 | ≤ 2秒 | 从点击菜单项到应用启动 |
| 主应用启动时间 | ≤ 3秒 | 从点击图标到设置窗口显示 |
| 内存占用 | ≤ 50MB | 菜单栏常驻时 |
| 应用扫描时间 | ≤ 5秒 | 首次扫描 /Applications |

### 可靠性

| 指标 | 要求 | 测量方式 |
|---|---|---|
| macOS 15 兼容性 | 100% 功能正常 | 测试套件验证 |
| macOS 26 兼容性 | 100% 功能正常 | 测试套件验证 |
| 扩展健康检测准确率 | ≥ 95% | 异常状态正确识别率 |
| 崩溃率 | ≤ 0.1% | 每千次启动 |

### 安全性

| 指标 | 要求 |
|---|---|
| 数据收集 | 零遥测，零用户数据收集 |
| 权限最小化 | 仅请求必要系统权限 |
| 代码签名 | 必须（Developer ID） |
| 公证 | 必须（Apple Notarization） |

### 可访问性

| 指标 | 要求 |
|---|---|
| 基础可访问性 | VoiceOver 可读取所有交互元素 |
| 键盘导航 | 设置窗口支持键盘操作 |
| 动态字体 | 支持系统字体大小设置 |

---

## 项目范围总结

### MVP 功能清单

| 序号 | 功能 | 优先级 | 所属旅程 |
|---|---|---|---|
| 1 | Finder Sync Extension 右键菜单 | P0 | 所有 |
| 2 | 自动应用发现 | P0 | 首次使用 |
| 3 | 菜单配置（增删改排序） | P0 | 所有 |
| 4 | 首次引导流程 | P0 | 首次使用 |
| 5 | 扩展健康检测 | P0 | macOS 升级 |
| 6 | 开机自启 | P0 | 所有 |
| 7 | 菜单栏常驻 | P0 | 所有 |
| 8 | 手动添加应用 | P1 | 特殊终端 |
| 9 | 自定义命令模板 | P1 | 特殊终端 |
| 10 | 特殊终端内置映射 | P1 | 特殊终端 |

### 技术风险

| 风险 | 缓解策略 |
|---|---|
| macOS 26 ARM FinderSync bug | 跟踪 Apple 修复；Phase 5 实现 App Intents 备选入口 |
| Finder Sync API 废弃 | 架构隔离 Extension 依赖；关注 WWDC |
| UserDefaults 跨进程同步 | 备选方案：App Group 容器 JSON 文件 |
