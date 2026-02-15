---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
inputDocuments:
  - product-brief-rcmm-2026-02-12.md
  - prd.md
  - prd-validation.md
  - domain-macos-finder-context-menu-tool-research-2026-02-12.md
  - market-macos-finder-context-menu-tool-research-2026-02-12.md
  - technical-macos-finder-context-menu-tool-research-2026-02-12.md
date: 2026-02-15
author: Sunven
---

# UX Design Specification rcmm

**Author:** Sunven
**Date:** 2026-02-15

---

## Executive Summary

### Project Vision

rcmm 是一个 macOS 菜单栏常驻应用，通过 Finder Sync Extension 在 Finder 右键菜单中注入一级菜单项，让用户一键用任意应用打开当前目录。

产品的核心 UX 承诺是"安装即可用"：首次打开 app 即触发引导流程，引导完成后右键菜单立即生效，零额外配置。这与竞品 OpenInTerminal "安装后需额外配置才生效"的体验形成鲜明对比。

产品形态为菜单栏常驻应用（LSUIElement，无 Dock 图标），日常使用中用户通过 Finder 右键菜单与产品交互，仅在配置变更或异常恢复时才需要打开设置界面。这是一个典型的"设置后遗忘"型工具。

### Target Users

**小明 — 全栈/前端开发者（核心用户，占目标用户 50-60%）**

- 日常在 Finder、VS Code/Cursor、Terminal/iTerm2/Warp 之间高频切换
- 技术能力中等，期望工具开箱即用，不愿花时间排查配置问题
- 曾用 OpenInTerminal，但 macOS 升级后失效，折腾配置后放弃
- UX 期望：安装 → 打开 → 引导完成 → 右键即可用，全程 < 2 分钟

**阿强 — DevOps 工程师（高级用户，占目标用户 20-25%）**

- 使用 Kitty、Alacritty、WezTerm 等非主流终端，需要特殊参数
- 技术能力强，愿意自定义配置，但不愿意写 AppleScript
- UX 期望：内置常见终端的正确命令，同时支持自定义命令模板

### Key Design Challenges

1. **引导流程的系统设置跳转断裂** — 启用 Finder Extension 需要跳转到 macOS 系统设置，这个跳转打断用户心流。macOS 15 和 macOS 26 的设置入口位置不同，引导必须适配多版本路径。
2. **菜单栏应用的交互空间局限** — MenuBarExtra 弹出窗口空间有限，Settings 窗口打开存在跨版本兼容问题。需要在有限空间内完成引导和日常配置。
3. **"隐形"产品的状态感知** — 用户日常不会主动打开 rcmm，但需要在扩展异常时被及时告知。需要在不打扰的前提下传达健康状态。
4. **渐进式复杂度管理** — 小明只需一键添加应用，阿强需要编辑命令模板。两种用户的需求复杂度差异大，界面需要渐进式披露（progressive disclosure）。

### Design Opportunities

1. **"引导即价值"体验** — 引导流程的最后一步直接让用户在 Finder 中右键测试，立即感受产品价值。竞品的引导止步于"配置完成"，rcmm 的引导延伸到"价值验证"。
2. **健康检测的主动关怀** — macOS 升级导致扩展失效时，rcmm 主动弹出恢复引导。这个"主动关怀"体验是竞品完全缺失的，可以成为口碑传播点（"比 OpenInTerminal 强太多了"）。
3. **渐进式界面复杂度** — 默认界面极简（应用列表 + 开关），高级用户点击"自定义"才展开命令编辑器。让 80% 的用户看到 20% 的界面，同时不限制高级用户的能力。

## Core User Experience

### Defining Experience

rcmm 的核心交互是一个三步循环：**右键 → 点击 → 应用打开**。

用户在 Finder 中右键目录或空白背景，看到一级菜单项（如"用 VS Code 打开"），点击后目标应用在 ≤ 2 秒内打开并定位到该目录。这个交互必须做到"无意识" — 像呼吸一样自然，成为肌肉记忆的一部分。

产品的日常使用面是 Finder 右键菜单，配置管理面是菜单栏弹出窗口和设置窗口。两个面的使用频率比约为 100:1 — 用户每天右键数十次，但可能数周才打开一次设置。

### Platform Strategy

| 维度 | 决策 |
|---|---|
| 平台 | macOS 桌面应用（macOS 15+） |
| 交互方式 | 鼠标/键盘，无触控 |
| 网络依赖 | 完全离线，零网络请求 |
| 应用形态 | 菜单栏常驻（LSUIElement），无 Dock 图标 |
| 交互面 | Finder 右键菜单（日常）+ MenuBarExtra 弹出窗口（快捷操作）+ Settings 窗口（完整配置） |

**平台能力利用：**
- Finder Sync Extension — 一级右键菜单（唯一 API）
- MenuBarExtra — 菜单栏常驻图标与弹出窗口
- SMAppService — 现代开机自启管理
- NSUserAppleScriptTask — 沙盒内命令执行
- App Group + Darwin Notifications — 跨进程数据共享与实时同步

**平台约束：**
- Extension 运行在独立沙盒进程中，无法直接执行命令
- MenuBarExtra 弹出窗口空间有限，不适合复杂交互
- Settings 窗口打开存在跨 macOS 版本兼容问题（需 workaround）
- 启用 Extension 需要用户跳转到系统设置手动操作

### Effortless Interactions

| 交互 | 无摩擦设计 |
|---|---|
| **右键菜单出现** | 从 App Group 缓存读取配置，零延迟渲染菜单项 |
| **引导流程** | 自动扫描 /Applications 并预选常见开发工具，用户确认即可 |
| **扩展启用** | 一键跳转到系统设置正确页面，引导界面提供清晰的返回路径 |
| **配置生效** | Darwin Notification 实时同步，修改后下次右键立即生效 |
| **异常恢复** | 主动检测 + 主动通知 + 一键修复，用户无需自行排查 |
| **开机自启** | 一个开关，SMAppService 处理所有细节 |

### Critical Success Moments

1. **"就是这个"时刻** — 引导完成后第一次右键，看到自己配置的应用列表并成功打开。这是产品价值的首次兑现，决定用户是否留存。
2. **"比 XX 强"时刻** — macOS 升级后扩展失效，rcmm 主动弹出恢复引导，30 秒内恢复正常。这是与竞品体验差距最大的时刻，也是口碑传播的触发点。
3. **"完美"时刻** — 高级用户编辑自定义命令后，特殊终端正确打开到目标目录。工具没有限制他的能力。
4. **"设置后遗忘"时刻** — 配置完成后数周，用户已将右键菜单视为系统原生功能。用户忘记 rcmm 的存在 — 这是最高赞美。

### Experience Principles

1. **隐形即成功** — rcmm 的最佳状态是用户忘记它的存在。右键菜单感觉像系统原生功能，而非第三方工具。所有设计决策都应朝"更隐形"的方向推进。
2. **引导即价值** — 引导流程不是"配置工具"的前置步骤，而是"体验产品价值"的第一幕。引导的终点不是"配置完成"，而是"第一次成功右键"。
3. **主动不打扰** — 正常时完全沉默，异常时主动出现。健康检测在后台运行，只在需要用户介入时才浮出水面，且提供明确的恢复路径。
4. **简单不简陋** — 默认体验极简（一键添加应用），但不牺牲高级用户的能力（自定义命令）。复杂度通过渐进式披露管理，而非功能阉割。

## Desired Emotional Response

### Primary Emotional Goals

rcmm 的情感设计围绕三个核心目标：

1. **掌控感** — "我的系统我做主"。用户完全控制右键菜单的内容和行为，工具不做任何用户未授权的事情。
2. **可靠感** — "它就是能用"。跨 macOS 版本稳定运行，异常时主动告知并提供恢复路径。
3. **轻松感** — "不用想就能用"。引导流程零决策负担，日常使用零认知负荷。

### Emotional Journey Mapping

| 阶段 | 期望情感 | 要避免的情感 | 设计支撑 |
|---|---|---|---|
| 发现 | 好奇 + 期待 | 怀疑 | 高质量 README + GIF 演示 |
| 安装 | 顺畅 | 焦虑 | 代码签名 + 公证，无 Gatekeeper 警告 |
| 首次打开 | 清晰 + 被引导 | 困惑 | 引导流程自动启动，每步只做一件事 |
| 扩展启用 | 信任 + 掌控 | 迷失 | 一键跳转正确的系统设置页面 |
| 第一次右键 | 满足 + "就是这个" | 失望 | 引导最后一步直接验证右键菜单 |
| 日常使用 | 无感（最佳状态） | 任何打断 | 零延迟菜单、零后台弹窗 |
| macOS 升级后 | 安心 + 被关怀 | 挫败 | 主动健康检测 + 恢复引导 |
| 异常恢复 | 掌控 + 轻松 | 无助 | 明确原因 + 一键修复 |
| 配置变更 | 高效 + 直接 | 繁琐 | 拖拽排序、实时生效 |

### Micro-Emotions

| 情感对 | 目标方向 | 实现方式 |
|---|---|---|
| 信任 vs 怀疑 | 信任 | 代码签名 + 公证；开源透明；零遥测 |
| 掌控 vs 无助 | 掌控 | 每个操作有明确反馈；异常提供具体原因和恢复路径 |
| 轻松 vs 焦虑 | 轻松 | 引导每步只做一件事；预选合理默认值；错误提示含操作建议 |
| 满足 vs 失望 | 满足 | 第一次右键必须成功；命令 ≤ 2 秒完成；视觉反馈确认操作 |

### Design Implications

| 情感目标 | UX 设计决策 |
|---|---|
| 掌控感 | 菜单项完全由用户配置；拖拽排序直观可控；自定义命令不设限制 |
| 可靠感 | 菜单栏图标颜色反映扩展健康状态；异常时主动通知；恢复步骤明确 |
| 轻松感 | 引导自动扫描并预选应用；一键跳转系统设置；配置变更实时生效 |
| 信任感 | 零遥测承诺；开源代码可审查；代码签名 + 公证 |
| 无感（日常） | 右键菜单瞬间出现；无后台弹窗；无更新打扰 |

### Emotional Design Principles

1. **工具的最高境界是无感** — 日常使用中不应唤起任何情感。情感设计的目标不是制造愉悦，而是消除摩擦。
2. **异常时刻是情感高光** — 唯一需要主动唤起情感的时刻是异常恢复。竞品用户花 2 小时排查，rcmm 用户 30 秒恢复 — 这个对比是最强的口碑驱动力。
3. **尊重开发者的智商** — 不过度解释，不弹无用提示，不用卡通化引导。界面简洁、直接、专业。

## UX Pattern Analysis & Inspiration

### Inspiring Products Analysis

**Raycast — 开发者工具 UX 标杆**

- 首次体验极致流畅，安装后立即可用
- 渐进式复杂度：新手和专家使用同一界面，看到不同深度
- 视觉设计克制，每个像素服务于效率
- 即时反馈，用户永远知道发生了什么

**Rectangle — "设置后遗忘"工具典范**

- 引导极简：首次打开只问一个问题，然后完成
- 菜单栏图标即入口，不需要独立设置窗口处理日常操作
- 配置完成后完全隐形，零打扰运行
- Homebrew 优先分发，开发者首选

**1Password — 系统权限引导标杆**

- 分步权限引导，不一次性要求所有权限
- 每个权限请求附带"为什么需要"的简短说明
- 状态仪表盘展示所有权限和集成状态
- 权限被撤销时提供清晰的重新授权路径

### Transferable UX Patterns

**交互模式：**

| 模式 | 来源 | rcmm 应用 |
|---|---|---|
| 菜单栏弹出窗口作为快捷入口 | Raycast/Rectangle | MenuBarExtra 展示核心状态和快捷操作 |
| 拖拽排序列表 | macOS 原生 | 菜单项排序使用拖拽模式 |
| 内联编辑 | Raycast 扩展设置 | 自定义命令在列表项内展开编辑 |

**引导模式：**

| 模式 | 来源 | rcmm 应用 |
|---|---|---|
| "一个问题"引导 | Rectangle | 核心问题："你想用哪些应用打开目录？" |
| 权限引导分步走 | 1Password | 先选应用，再启用扩展 |
| 引导末尾验证 | Raycast | 最后一步让用户在 Finder 中右键测试 |

**状态模式：**

| 模式 | 来源 | rcmm 应用 |
|---|---|---|
| 图标颜色即状态 | macOS 原生 Wi-Fi/蓝牙 | 菜单栏图标颜色反映扩展健康状态 |
| 状态仪表盘 | 1Password 安全检查 | 设置窗口展示扩展状态和配置概览 |

### Anti-Patterns to Avoid

| 反模式 | 来源 | 原因 |
|---|---|---|
| 安装后无引导 | OpenInTerminal | 用户不知道需手动启用 Extension |
| 权限弹窗轰炸 | OpenInTerminal #239 | 每次使用弹权限请求，打断工作流 |
| 硬编码应用列表 | OpenInTerminal | 无法覆盖新终端，依赖开发者手动添加 |
| 工具栏按钮 | OpenInTerminal/cdto | macOS 15+ 不稳定，已知 bug |
| 过度功能分裂 | OpenInTerminal 6 target | Lite/完整/Editor 版，用户选择困难 |
| 设置界面过度设计 | Electron 应用 | 开发者工具不需要花哨界面 |

### Design Inspiration Strategy

**采纳：**
- Rectangle 的"一个问题"引导模式 — 简化 rcmm 引导为核心问题
- 1Password 的分步权限引导 — 先选应用再启用扩展
- macOS 原生图标颜色状态模式 — 菜单栏图标反映健康状态

**适配：**
- Raycast 的渐进式复杂度 — 适配为"默认简单列表 + 展开自定义命令"
- 1Password 的状态仪表盘 — 简化为菜单栏弹出窗口中的状态行

**避免：**
- OpenInTerminal 的无引导安装体验
- OpenInTerminal 的硬编码应用策略
- 任何需要工具栏按钮的交互模式

## Design System Foundation

### Design System Choice

**HIG 基础 + 轻度定制** — 以 Apple Human Interface Guidelines 和 SwiftUI 原生组件为基础，在关键交互点加入轻度品牌元素。

这不是一个需要独特视觉风格的消费级产品，而是一个追求"隐形"的系统工具。设计系统的目标是让 rcmm 看起来像 macOS 的原生功能。

### Rationale for Selection

1. **体验原则驱动** — "隐形即成功"要求产品与系统视觉完全融合，自定义设计系统会破坏这一目标
2. **自动适配** — SwiftUI 原生组件自动适配 Dark Mode、Accessibility、Liquid Glass（macOS 26），零额外开发成本
3. **开发效率** — 独立开发者无专职设计师，原生组件是最高效的选择
4. **用户信任** — 开发者对原生风格的工具信任度更高，非原生风格会引发"这是 Electron 应用吗？"的怀疑

### Implementation Approach

| 组件 | 实现方式 |
|---|---|
| 菜单栏弹出窗口 | `MenuBarExtra` + `.menuBarExtraStyle(.window)` |
| 设置窗口 | `Settings` scene + `TabView` |
| 应用列表 | SwiftUI `List` + `ForEach` + `.onMove` 拖拽排序 |
| 应用图标 | `NSWorkspace.shared.icon(forFile:)` 获取系统图标 |
| 开关控件 | 原生 `Toggle` |
| 按钮 | 原生 `Button` + `.buttonStyle(.borderedProminent)` |
| 文本输入 | 原生 `TextField` / `TextEditor` |
| 状态指示 | `Circle().fill(.green/.yellow/.red)` 语义颜色 |
| 引导步骤 | 自定义 `View` + 原生组件组合 |

### Customization Strategy

**轻度定制区域：**

| 区域 | 定制内容 | 定制程度 |
|---|---|---|
| 菜单栏图标 | 自定义图标 + 健康状态颜色变化 | 低 |
| 引导流程 | 产品图标 + 步骤指示器 + 插图 | 中 |
| 应用列表项 | 应用图标 + 名称 + 状态标签 | 低 |
| 自定义命令编辑器 | 等宽字体 + 语法高亮提示 | 中 |
| 健康状态面板 | 图标 + 颜色 + 操作按钮组合 | 低 |

**设计令牌：**

| Token 类别 | 策略 |
|---|---|
| 颜色 | 系统语义颜色（`.primary`, `.secondary`, `.green`, `.red`），自动适配 Dark Mode |
| 字体 | 系统默认 + 命令编辑器使用 `.monospaced` |
| 间距/圆角 | SwiftUI 默认值，保持系统一致性 |
| 图标 | SF Symbols 为主，菜单栏图标自定义 |
| 动画 | SwiftUI 默认动画（`.default`, `.spring`），不使用自定义动画 |

## Defining Core Experience

### Defining Experience

> "右键目录，一键用任意应用打开。"

这是 rcmm 的定义性体验 — 用户会用这句话向朋友描述这个工具。核心交互只有一步：在 Finder 中右键，点击菜单项，目标应用打开。没有中间步骤，没有确认对话框，没有 loading 状态。

### User Mental Model

用户将 rcmm 理解为"系统的一部分"而非"一个应用"。右键菜单是 macOS 最基础的交互模式，用户已经知道怎么使用。

**心智模型转变目标：**
- 从"有个工具帮我做这件事" → "系统本来就能做这件事"
- 从"我需要记住用哪个工具" → "右键就有"
- 从"工具可能会坏" → "它就是系统的一部分"

**当前方案对比：**

| 方案 | 心智模型 | 步骤 | 摩擦 |
|---|---|---|---|
| 手动 cd | "我需要告诉终端去哪" | 4-5 步 | 复制路径、切换窗口 |
| macOS 原生 Service | "藏得很深的系统功能" | 3 步 | 二级菜单、快捷键冲突 |
| OpenInTerminal | "有个工具帮我做" | 1 步 | 经常坏，需要排查 |
| **rcmm** | **"右键就能打开"** | **1 步** | **无** |

### Success Criteria

| 标准 | 指标 | 说明 |
|---|---|---|
| 速度 | 菜单出现 < 100ms | 不能有可感知的延迟 |
| 可靠性 | 执行成功率 > 99% | 点击后目标应用必须打开 |
| 响应 | 应用打开 < 2s | 从点击到应用窗口出现 |
| 一致性 | 菜单内容稳定 | 不因 Extension 状态波动导致菜单消失 |
| 路径准确 | 100% 正确 | 打开的目录必须是用户右键的目录 |

### Novel UX Patterns

rcmm 的核心交互完全使用已建立的 macOS 模式（右键菜单），零学习成本。创新不在交互模式，而在三个维度：

1. **内容创新** — 菜单项由用户自定义，不是系统预设
2. **可靠性创新** — 健康检测 + 恢复引导，竞品完全缺失
3. **通用性创新** — 不限于终端和编辑器，任意应用都可以

### Experience Mechanics

**1. 触发（Initiation）**

| 触发方式 | Finder 菜单类型 | 路径来源 |
|---|---|---|
| 右键目录图标 | `FIMenuKindContextualMenuForItems` | `selectedItemURLs` |
| 右键窗口空白背景 | `FIMenuKindContextualMenuForContainer` | `targetedURL` |
| 右键侧边栏项 | `FIMenuKindContextualMenuForSidebar` | `targetedURL` |

Extension 从 App Group 缓存读取配置，构建 NSMenu 返回。用户感知：右键后菜单瞬间出现。

**2. 交互（Interaction）**

菜单项展示：应用图标 + 显示名称，按用户配置的顺序排列。用户鼠标移动到目标项，点击。

**3. 反馈（Feedback）**

点击后 Extension 获取目标路径，通过 NSUserAppleScriptTask 执行预装脚本，调用 `open -a` 打开目标应用。成功反馈是目标应用窗口出现在前台。无 loading、无确认框、无二次操作。

**4. 完成（Completion）**

用户已在目标应用中工作。无"完成"提示 — 应用打开本身就是最好的反馈。

## Visual Design Foundation

### Color System

rcmm 完全使用 macOS 系统语义颜色，不定义自定义品牌色。

| 用途 | SwiftUI API | 说明 |
|---|---|---|
| 主文本 | `.primary` | 自动适配 Light/Dark Mode |
| 次要文本 | `.secondary` | 标签、说明文字 |
| 强调/交互 | `.accentColor` / `.tint` | 按钮、开关、选中状态 |
| 健康-正常 | `.green` | 扩展已启用且正常 |
| 健康-警告 | `.yellow` | 扩展状态未知 |
| 健康-异常 | `.red` | 扩展未启用或失效 |
| 背景 | `.background` | 窗口背景 |

菜单栏图标跟随系统菜单栏风格，自动适配 Light/Dark Mode。健康状态同时使用图标变体和颜色传达（如 SF Symbol `.fill` vs `.slash`），确保色盲用户可识别。

### Typography System

完全使用 SwiftUI 系统字体，不引入自定义字体。

| 层级 | SwiftUI Font | 用途 |
|---|---|---|
| 大标题 | `.title` | 设置窗口标签页标题 |
| 标题 | `.headline` | 引导步骤标题、分组标题 |
| 正文 | `.body` | 列表项名称、说明文字 |
| 注释 | `.caption` | 状态信息、辅助说明 |
| 代码 | `.system(.body, design: .monospaced)` | 自定义命令编辑器、路径显示 |

### Spacing & Layout Foundation

| 维度 | 策略 |
|---|---|
| 基础间距 | SwiftUI 默认（8pt 系统） |
| 列表/分组间距 | SwiftUI `List` / `Section` 默认 |
| 窗口尺寸 | MenuBarExtra ~320pt 宽 / Settings ~480×360pt |
| 内边距 | SwiftUI `.padding()` 默认 |

**布局原则：**
- 紧凑但不拥挤 — 菜单栏弹出窗口信息密度高但不压迫
- 左对齐为主 — 应用图标 + 名称左对齐，操作按钮右对齐
- 垂直列表为主 — 符合 macOS 设置界面惯例

### Accessibility Considerations

| 维度 | 策略 |
|---|---|
| 对比度 | 系统语义颜色自动满足 WCAG AA |
| 色盲友好 | 健康状态同时使用图标变体和颜色，不仅依赖颜色 |
| 动态字体 | SwiftUI 系统字体自动支持 Dynamic Type |
| VoiceOver | 所有交互元素添加 `.accessibilityLabel` |
| 键盘导航 | SwiftUI 原生组件自动支持 Tab 键导航 |
| 减少动画 | 尊重系统"减少动态效果"设置 |

## Design Direction Decision

### Design Directions Explored

探索了三个设计方向：

- **方向 A 极简主义** — 所有配置在 MenuBarExtra 弹出窗口内完成，不需要独立设置窗口
- **方向 B 分层架构** — 弹出窗口展示状态概览，完整配置在 Settings 窗口中
- **方向 C 状态驱动** — 弹出窗口内容根据扩展状态动态变化，正常时极简，异常时变为恢复引导

### Chosen Direction

**方向 B + C 混合：分层架构 + 状态驱动弹出窗口**

两个交互层：
1. **MenuBarExtra 弹出窗口** — 状态驱动的轻量入口
   - 正常状态：简洁状态行 + "打开设置" + "退出"
   - 异常状态：恢复引导面板（原因说明 + 一键修复）
2. **Settings 窗口** — 完整配置中心
   - TabView 分页：菜单配置 / 通用 / 关于
   - 菜单配置：应用列表 + 拖拽排序 + 内联编辑自定义命令
   - 通用：开机自启、扩展状态、监控目录

### Design Rationale

1. **符合 macOS 惯例** — Bartender、Rectangle、1Password 等成熟菜单栏应用都采用"弹出窗口 + 设置窗口"分层模式
2. **最大化"隐形"** — 正常状态下弹出窗口几乎没有内容，用户不需要与 rcmm 交互
3. **异常时主动关怀** — 弹出窗口在异常时变为恢复引导，是竞品完全缺失的体验
4. **可扩展** — Settings 窗口有足够空间容纳未来功能（App Intents 配置、多语言等）
5. **实现可行** — SwiftUI MenuBarExtra + Settings scene 是成熟的技术方案

### Implementation Approach

**MenuBarExtra 弹出窗口：**
- `MenuBarExtra` + `.menuBarExtraStyle(.window)` 实现富 UI 弹出
- 根据 `ExtensionStatus` 枚举切换正常/异常视图
- 宽度 ~280-320pt，高度自适应内容

**Settings 窗口：**
- `Settings` scene + `TabView` 实现分页设置
- 菜单配置页：`List` + `.onMove` 拖拽排序 + `DisclosureGroup` 内联编辑
- 通用页：`Toggle` 开关 + 状态指示
- 窗口尺寸 ~480×400pt
- 通过隐藏 Window + ActivationPolicy 切换 workaround 解决 MenuBarExtra 打开 Settings 的兼容问题

## User Journey Flows

### Journey 1: First-Time Setup (小明)

**目标：** 安装 → 引导 → 第一次成功右键，全程 < 2 分钟

**流程：**

Step 1 — 启用扩展（如未启用）：
- 显示说明 + 系统设置截图指引
- 一键跳转到系统设置对应页面
- 自动检测启用状态，提供"重新检测"和"跳过"选项

Step 2 — 选择应用：
- 自动扫描 /Applications，展示已安装开发工具
- 预选常见工具（VS Code、Terminal、iTerm2）
- 用户确认/调整后保存到 App Group

Step 3 — 验证：
- 提示"现在去 Finder 试试右键！"
- 用户实际测试右键菜单
- 成功后显示完成确认 + 开机自启选项

**关键决策：** 每步只做一件事；Extension 已启用则跳过 Step 1；验证步骤让用户体验产品价值。

### Journey 2: Custom Command Setup (阿强)

**目标：** 添加特殊终端 → 自动/手动配置命令 → 验证生效

**流程：**

1. 设置窗口 → 菜单配置 Tab → "+ 添加应用"
2. 从已安装列表选择或通过 NSOpenPanel 手动添加
3. 系统自动检测内置命令映射（Kitty/Alacritty/WezTerm）
4. 如需自定义：DisclosureGroup 展开命令编辑器（等宽字体 + 实时预览）
5. 保存 → Darwin Notification 同步 → 下次右键立即生效

**关键决策：** 内置映射自动识别特殊终端；自定义命令内联编辑不跳转；实时预览完整命令。

### Journey 3: macOS Upgrade Recovery

**目标：** 升级后扩展失效 → 主动检测 → 30 秒内恢复

**流程：**

1. rcmm 开机自启 → 自动执行 pluginkit 健康检测
2. 检测到异常 → 菜单栏图标变为警告状态
3. 弹出恢复引导面板：原因说明 + "一键修复"按钮
4. 一键跳转系统设置 → 用户重新启用 Extension
5. 自动重新检测 → 恢复正常 → 图标恢复 + 确认提示

**关键决策：** 主动检测不等用户发现；提供"稍后"选项不强制；修复后明确确认。

### Journey 4: Error Handling

**目标：** 命令执行失败 → 合理错误提示 → 不打断工作流

**流程：**

- 应用未安装/路径无效：由 macOS 系统错误对话框处理（`open` 命令默认行为）
- 脚本文件缺失：下次打开主 App 时提示重新安装脚本
- 权限错误：下次打开主 App 时提示检查权限设置

**关键决策：** 不在 Extension 中弹自定义错误窗口；利用系统默认错误处理；延迟到主 App 中处理内部错误。

### Journey Patterns

| 模式 | 应用场景 | 实现 |
|---|---|---|
| 状态检测 → 条件引导 | 引导流程、升级恢复 | pluginkit + 条件分支 |
| 一键跳转系统设置 | 引导、恢复 | `NSWorkspace.open(URL)` |
| 配置变更 → 实时同步 | 添加应用、自定义命令 | App Group + Darwin Notification |
| 渐进式披露 | 自定义命令 | `DisclosureGroup` 内联展开 |
| 异常状态持久提示 | 升级恢复 | 菜单栏图标变体 + 弹出面板 |

### Flow Optimization Principles

1. **最短路径到价值** — 引导流程 3 步完成，每步只做一件事，可跳过
2. **利用系统能力** — 错误处理交给 macOS 系统对话框，不重复造轮子
3. **异步不阻塞** — 配置同步通过 Darwin Notification 异步完成，用户无需等待
4. **状态可见** — 菜单栏图标始终反映扩展健康状态，异常时主动浮出
5. **容错设计** — 每个流程都有"跳过"或"稍后"选项，不强制用户完成

## Component Strategy

### Design System Components

rcmm 基于 SwiftUI 原生组件构建，设计系统覆盖率约 70%。

| 组件需求 | SwiftUI 原生 | 覆盖状态 |
|---|---|---|
| 菜单栏图标与弹出窗口 | `MenuBarExtra` + `.menuBarExtraStyle(.window)` | ✅ 完全覆盖 |
| 设置窗口分页 | `Settings` scene + `TabView` | ✅ 完全覆盖 |
| 应用列表 | `List` + `ForEach` | ✅ 完全覆盖 |
| 拖拽排序 | `.onMove` modifier | ✅ 完全覆盖 |
| 开关控件 | `Toggle` | ✅ 完全覆盖 |
| 按钮 | `Button` + `.buttonStyle` | ✅ 完全覆盖 |
| 文本输入 | `TextField` / `TextEditor` | ✅ 完全覆盖 |
| 渐进式披露 | `DisclosureGroup` | ✅ 完全覆盖 |
| 文件选择器 | `NSOpenPanel`（AppKit 桥接） | ✅ 完全覆盖 |
| 引导步骤指示器 | — | ❌ 需自定义 |
| 应用列表行（图标+名称+状态） | — | ❌ 需自定义 |
| 健康状态面板 | — | ❌ 需自定义 |
| 恢复引导面板 | — | ❌ 需自定义 |
| 命令编辑器（等宽+预览） | — | ❌ 需自定义 |

### Custom Components

#### 1. OnboardingStepIndicator（引导步骤指示器）

**用途：** 引导流程中展示当前步骤进度（1/3、2/3、3/3）
**内容：** 步骤编号 + 步骤标题 + 进度指示
**交互：** 仅展示，不可点击跳转
**状态：** 已完成（绿色勾）/ 当前（高亮）/ 待完成（灰色）
**实现：** `HStack` + `Circle` + `Text`，使用系统语义颜色
**无障碍：** `.accessibilityLabel("步骤 X，共 Y 步，当前：[步骤名]")`

#### 2. AppListRow（应用列表行）

**用途：** 在菜单配置列表中展示单个应用的信息和操作
**内容：** 应用图标（32×32）+ 显示名称 + 状态标签（如"自定义命令"）+ 操作区
**交互：** 点击选中；拖拽排序；右侧删除按钮；展开自定义命令编辑
**状态：** 默认 / 选中 / 拖拽中 / 应用未安装（警告样式）
**变体：** 紧凑模式（引导流程中的选择列表）/ 完整模式（设置窗口中的配置列表）
**实现：** `HStack` + `Image(nsImage:)` + `Text` + `Spacer` + 操作按钮
**无障碍：** `.accessibilityLabel("[应用名]，[状态]")` + `.accessibilityHint("拖拽排序")`

#### 3. HealthStatusPanel（健康状态面板）

**用途：** 在菜单栏弹出窗口和设置窗口中展示扩展健康状态
**内容：** 状态图标（SF Symbol）+ 状态文字 + 详情说明
**交互：** 正常状态仅展示；异常状态提供操作按钮
**状态：** 正常（绿色，`.checkmark.circle.fill`）/ 警告（黄色，`.exclamationmark.triangle.fill`）/ 异常（红色，`.xmark.circle.fill`）
**实现：** `HStack` + `Image(systemName:)` + `VStack(Text, Text)` + 条件按钮
**无障碍：** `.accessibilityLabel("扩展状态：[正常/警告/异常]，[详情]")`

#### 4. RecoveryGuidePanel（恢复引导面板）

**用途：** 扩展异常时在弹出窗口中展示恢复引导
**内容：** 异常原因说明 + 恢复步骤 + 操作按钮（"修复" / "稍后"）
**交互：** "修复"跳转系统设置；"稍后"关闭面板
**状态：** 检测中（loading）/ 异常已识别（展示恢复方案）/ 恢复成功（确认提示）
**实现：** `VStack` + `HealthStatusPanel` + `Text` 说明 + `HStack` 按钮组
**无障碍：** `.accessibilityLabel("扩展需要修复")` + 按钮独立标签

#### 5. CommandEditor（命令编辑器）

**用途：** 高级用户编辑自定义打开命令
**内容：** 等宽字体文本编辑区 + 占位符提示（`{app}`, `{path}`）+ 实时预览
**交互：** 文本编辑；预览区展示替换占位符后的完整命令
**状态：** 默认 / 编辑中 / 语法提示（占位符高亮）/ 错误（无效命令）
**实现：** `VStack` + `TextEditor` + `.font(.system(.body, design: .monospaced))` + 预览 `Text`
**无障碍：** `.accessibilityLabel("自定义命令编辑器")` + `.accessibilityHint("输入命令模板，支持 {app} 和 {path} 占位符")`

### Component Implementation Strategy

| 策略维度 | 决策 |
|---|---|
| 构建方式 | 使用 SwiftUI 原生组件组合，不引入第三方 UI 库 |
| 样式一致性 | 所有自定义组件使用系统语义颜色和默认间距 |
| 状态管理 | 组件通过 `@Binding` 或 `@Observable` 接收外部状态 |
| 复用策略 | 自定义组件放在 RCMMShared Package 中，主应用和引导流程共用 |
| 测试策略 | SwiftUI Preview 验证所有状态变体 |

### Implementation Roadmap

**Phase 1 — 核心流程组件（MVP 必需）：**

- `AppListRow` — 引导流程和设置窗口的核心列表项
- `OnboardingStepIndicator` — 引导流程进度展示
- `HealthStatusPanel` — 菜单栏弹出窗口状态展示

**Phase 2 — 高级功能组件（MVP P1）：**

- `CommandEditor` — 自定义命令编辑
- `RecoveryGuidePanel` — 异常恢复引导

**Phase 3 — 增强组件（发布后）：**

- 命令编辑器语法高亮增强
- 应用分类筛选组件
- 配置导入/导出界面

## UX Consistency Patterns

### Button Hierarchy

rcmm 使用三级按钮层级，遵循 macOS HIG 原生样式：

| 层级 | SwiftUI 样式 | 使用场景 | 示例 |
|---|---|---|---|
| 主要操作 | `.buttonStyle(.borderedProminent)` | 每个视图最多一个，推动流程前进 | "下一步"、"修复"、"添加应用" |
| 次要操作 | `.buttonStyle(.bordered)` | 辅助操作，不推动主流程 | "跳过"、"稍后"、"自定义" |
| 三级操作 | `.buttonStyle(.plain)` 或文字链接 | 低优先级操作 | "打开设置"、"退出" |

**按钮规则：**
- 每个视图/面板最多一个主要操作按钮
- 破坏性操作（删除菜单项）使用 `.tint(.red)` 标记
- 引导流程中"下一步"始终在右下角，"跳过"在左下角
- 弹出窗口中按钮垂直排列，设置窗口中按钮水平排列

### Feedback Patterns

| 反馈类型 | 触发场景 | 反馈方式 | 持续时间 |
|---|---|---|---|
| 成功 | 配置保存、扩展恢复 | 无显式反馈（即时生效即最好的反馈） | — |
| 错误-系统级 | 应用启动失败 | macOS 系统错误对话框（`open` 命令默认行为） | 用户关闭 |
| 错误-内部 | 脚本缺失、权限错误 | 下次打开主 App 时在弹出窗口顶部展示 | 用户操作后消失 |
| 警告 | 扩展异常 | 菜单栏图标变体 + 弹出窗口恢复面板 | 持续到修复 |
| 信息 | 引导完成 | 内联文字确认 + 图标 | 5 秒后淡出或用户关闭 |

**反馈原则：**
- 配置变更不弹 toast/通知 — 实时生效本身就是反馈
- 不使用自定义弹窗覆盖层 — 利用系统原生对话框
- 持久性异常使用持久性指示（菜单栏图标），瞬时操作使用瞬时反馈

### Status Indication Patterns

rcmm 的状态指示贯穿三个层面：

**菜单栏图标状态：**

| 状态 | 图标 | 颜色 | 含义 |
|---|---|---|---|
| 正常 | 默认图标 | 系统菜单栏色 | 扩展已启用，一切正常 |
| 警告 | 图标 + 感叹号变体 | 黄色 | 扩展状态未知 |
| 异常 | 图标 + 斜杠变体 | 红色 | 扩展未启用或失效 |

**应用列表项状态：**

| 状态 | 视觉表现 | 含义 |
|---|---|---|
| 正常 | 应用图标 + 名称 | 应用已安装，命令正常 |
| 自定义 | 名称旁显示"自定义"标签 | 使用自定义命令 |
| 未安装 | 图标灰化 + 警告标签 | 应用路径无效 |

**状态规则：**
- 状态同时使用图标变体和颜色传达，不仅依赖颜色（色盲友好）
- 菜单栏图标状态是全局最高优先级指示器
- 应用列表项状态仅在设置窗口中可见

### Empty States

| 空状态场景 | 展示内容 | 操作引导 |
|---|---|---|
| 无配置应用（首次） | 引导流程自动启动 | 引导用户选择应用 |
| 无配置应用（手动清空） | "还没有配置任何应用" + 图标 | "添加应用"按钮 |
| 扫描无结果 | "未在 /Applications 中发现应用" | "手动添加"按钮 |
| 扩展未启用 | 恢复引导面板 | "前往系统设置"按钮 |

**空状态原则：**
- 每个空状态都提供明确的下一步操作
- 使用 SF Symbol 图标 + 简短文字，不使用大段说明
- 首次空状态触发引导流程，非首次展示静态空状态

### Progressive Disclosure

rcmm 使用渐进式披露管理界面复杂度：

| 层级 | 默认可见 | 展开后可见 | 触发方式 |
|---|---|---|---|
| 应用列表项 | 图标 + 名称 + 状态 | 自定义命令编辑器 | 点击"自定义"或 `DisclosureGroup` |
| 菜单栏弹出窗口 | 状态行 + 快捷操作 | 恢复引导面板（异常时自动展示） | 状态驱动自动切换 |
| 设置窗口 | 菜单配置 Tab | 通用 Tab / 关于 Tab | `TabView` 切换 |

**披露原则：**
- 80% 用户只需看到默认层级
- 展开操作使用 SwiftUI 默认动画（`.default`）
- 展开状态不持久化 — 关闭窗口后恢复默认收起

### Design System Integration

**与 HIG + SwiftUI 原生组件的集成规则：**

| 规则 | 说明 |
|---|---|
| 颜色 | 所有模式使用系统语义颜色，禁止硬编码 hex 值 |
| 间距 | 使用 SwiftUI `.padding()` 默认值，不自定义间距常量 |
| 动画 | 使用 `.default` 或 `.spring` 系统动画，不自定义时长/曲线 |
| 图标 | SF Symbols 优先，仅菜单栏图标使用自定义资源 |
| 字体 | 系统字体层级（`.title`, `.headline`, `.body`, `.caption`），命令编辑器使用 `.monospaced` |
| 暗色模式 | 系统语义颜色自动适配，无需额外处理 |
| 无障碍 | 所有交互元素添加 `.accessibilityLabel`；状态变化使用 `.accessibilityValue` |

## Responsive Design & Accessibility

### Window Adaptation Strategy

rcmm 是纯 macOS 桌面应用，无跨设备响应式需求。窗口适配策略聚焦于两个交互面的尺寸管理：

| 交互面 | 尺寸策略 | 说明 |
|---|---|---|
| MenuBarExtra 弹出窗口 | 固定宽度 ~280-320pt，高度自适应 | 内容由状态驱动，正常时极简，异常时展开恢复面板 |
| Settings 窗口 | 固定尺寸 ~480×400pt，不可调整 | TabView 分页，内容不需要滚动（菜单配置列表除外） |
| 引导窗口 | 固定尺寸 ~400×500pt | 步骤式流程，每步内容量可控 |

**窗口适配规则：**
- 弹出窗口高度随内容自适应（`fixedSize(horizontal: true, vertical: false)`）
- 菜单配置列表使用 `List` 原生滚动，列表项数量不限
- 所有窗口支持 Dynamic Type — 字体放大时内容区域自动扩展
- 不支持窗口缩放（工具类应用无此需求）

### Accessibility Strategy

**合规目标：** macOS 原生无障碍标准（等效 WCAG AA）

rcmm 使用 SwiftUI 原生组件，自动获得基础无障碍支持。额外工作集中在自定义组件和状态传达。

**VoiceOver 支持：**

| 组件 | VoiceOver 行为 |
|---|---|
| 菜单栏图标 | `.accessibilityLabel("rcmm")` + `.accessibilityValue("[状态]")` |
| 应用列表项 | 读出"[应用名]，[状态]，拖拽可排序" |
| 引导步骤 | 读出"步骤 X，共 Y 步，[步骤标题]" |
| 健康状态面板 | 读出"扩展状态：[正常/警告/异常]，[详情]" |
| 命令编辑器 | 读出"自定义命令编辑器，当前内容：[命令]" |
| 操作按钮 | 读出按钮标签 + 操作提示 |

**键盘导航：**

| 场景 | 键盘支持 |
|---|---|
| 设置窗口 Tab 切换 | SwiftUI `TabView` 原生支持 |
| 应用列表导航 | 上下箭头键选择，Delete 键删除 |
| 引导流程 | Tab 键在按钮间切换，Enter 确认，Esc 跳过 |
| 命令编辑器 | 标准文本编辑键盘快捷键 |
| 弹出窗口 | Tab 键导航按钮，Enter 确认 |

**视觉无障碍：**

| 维度 | 策略 |
|---|---|
| 对比度 | 系统语义颜色自动满足 4.5:1 对比度 |
| 色盲友好 | 健康状态同时使用 SF Symbol 变体（`.checkmark` / `.exclamationmark` / `.xmark`）和颜色 |
| Dynamic Type | SwiftUI 系统字体自动缩放，布局使用相对尺寸适配 |
| 减少动态效果 | 尊重 `accessibilityReduceMotion`，禁用非必要动画 |
| 高对比度 | 尊重 `accessibilityIncreaseContrast`，系统语义颜色自动适配 |

### Testing Strategy

**无障碍测试：**

| 测试方式 | 工具 | 覆盖范围 |
|---|---|---|
| VoiceOver 手动测试 | macOS 内置 VoiceOver | 所有交互元素可读取、可操作 |
| Accessibility Inspector | Xcode Accessibility Inspector | 检查标签、角色、值是否正确 |
| 键盘导航测试 | 手动 Tab/Arrow/Enter | 所有功能可通过键盘完成 |
| Dynamic Type 测试 | 系统设置调整字体大小 | 布局不溢出、不截断 |
| 色盲模拟 | Xcode Color Blindness Simulator | 状态信息不仅依赖颜色 |

**窗口适配测试：**

| 测试场景 | 验证内容 |
|---|---|
| 长应用列表（20+ 项） | 列表滚动流畅，无性能问题 |
| Dynamic Type 最大字号 | 弹出窗口和设置窗口布局正常 |
| 弹出窗口内容变化 | 正常→异常状态切换时高度平滑过渡 |

### Implementation Guidelines

**开发规范：**

| 规范 | 说明 |
|---|---|
| 所有自定义组件 | 必须添加 `.accessibilityLabel` 和 `.accessibilityHint` |
| 状态变化 | 使用 `.accessibilityValue` 传达动态状态 |
| 图标 | 装饰性图标使用 `.accessibilityHidden(true)`，功能性图标添加标签 |
| 分组 | 相关元素使用 `.accessibilityElement(children: .combine)` 合并 |
| 排序操作 | 拖拽排序同时提供 `.accessibilityAction` 替代方案 |
| 系统设置尊重 | 检查 `accessibilityReduceMotion` 和 `accessibilityIncreaseContrast` |

**SwiftUI Preview 验证清单：**
- 每个自定义组件提供 Light/Dark Mode 双预览
- 每个自定义组件提供 Dynamic Type 大字号预览
- 状态组件提供所有状态变体预览
