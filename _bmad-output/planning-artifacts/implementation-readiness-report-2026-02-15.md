---
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
documentsIncluded:
  prd: prd.md
  architecture: architecture.md
  epics: epics.md
  ux: ux-design-specification.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-02-15
**Project:** rcmm

## 1. Document Inventory

| 文档类型 | 文件名 | 大小 | 修改日期 |
|---------|--------|------|---------|
| PRD | prd.md | 13K | 2026-02-15 12:51 |
| 架构 | architecture.md | 32K | 2026-02-15 14:39 |
| 史诗与故事 | epics.md | 33K | 2026-02-15 15:09 |
| UX 设计 | ux-design-specification.md | 39K | 2026-02-15 13:40 |

**发现问题：** 无重复、无缺失、无分片文档冲突。

## 2. PRD 分析

### 功能需求（Functional Requirements）

| 编号 | 需求描述 |
|------|---------|
| FR-MENU-001 | 用户可以在 Finder 中右键目录或空白背景时，看到一级菜单项"用 [应用名] 打开" |
| FR-MENU-002 | 用户点击菜单项后，系统使用正确的方式打开目标应用 |
| FR-MENU-003 | 系统支持用户添加多个应用到右键菜单，每个应用对应一个菜单项 |
| FR-MENU-004 | 用户可以拖拽排序菜单项，顺序决定在菜单中的显示位置 |
| FR-MENU-005 | 用户可以将某个应用设为第一项，作为默认打开方式 |
| FR-APP-DISCOVERY-001 | 系统自动扫描 /Applications 目录，发现已安装的应用 |
| FR-APP-DISCOVERY-002 | 系统展示每个应用的名称、图标、路径 |
| FR-APP-DISCOVERY-003 | 用户可以通过文件选择器选择任意 .app 文件添加到菜单 |
| FR-APP-DISCOVERY-004 | 系统识别应用类型（终端、编辑器、其他），便于分类展示 |
| FR-COMMAND-001 | 对于大多数应用，系统使用 `open -a "{appPath}" "{path}"` 打开目录 |
| FR-COMMAND-002 | 系统内置 kitty、Alacritty、WezTerm 等特殊终端的正确打开命令 |
| FR-COMMAND-003 | 用户可以为应用编辑自定义命令模板，支持 `{app}` 和 `{path}` 占位符 |
| FR-COMMAND-004 | 用户在编辑自定义命令时，可以预览命令效果 |
| FR-ONBOARDING-001 | 用户首次打开应用时，系统自动启动引导流程 |
| FR-ONBOARDING-002 | 引导流程中，用户可以从扫描结果中选择要添加的应用 |
| FR-ONBOARDING-003 | 引导流程检测扩展状态，引导用户到系统设置启用扩展 |
| FR-ONBOARDING-004 | 引导完成后，系统提示用户测试右键菜单是否正常工作 |
| FR-HEALTH-001 | 系统定期或启动时检测 Finder Sync Extension 的注册状态 |
| FR-HEALTH-002 | 系统能识别扩展未启用、被禁用、状态未知等异常情况 |
| FR-HEALTH-003 | 系统通过菜单栏图标或状态指示器显示扩展健康状态 |
| FR-HEALTH-004 | 当检测到扩展异常时，系统提供一键恢复功能，引导用户到系统设置页面 |
| FR-UI-MENUBAR-001 | 应用在菜单栏显示图标，点击可弹出设置界面 |
| FR-UI-MENUBAR-002 | 应用运行时不在 Dock 中显示图标 |
| FR-UI-SETTINGS-001 | 应用提供独立的设置窗口管理所有配置 |
| FR-UI-SETTINGS-002 | 设置窗口展示所有已配置的菜单项，支持添加、删除、编辑操作 |
| FR-UI-SETTINGS-003 | 设置窗口中支持拖拽重新排序菜单项 |
| FR-SYSTEM-001 | 用户可以启用开机自动启动功能 |
| FR-SYSTEM-002 | 系统显示当前开机自启的状态 |
| FR-ERROR-001 | 系统检测目标应用是否已安装/存在 |
| FR-ERROR-002 | 当应用启动失败时，系统显示包含错误原因和操作建议的错误提示 |
| FR-ERROR-003 | 错误提示中包含恢复建议（如移除菜单项、安装应用） |
| FR-DATA-001 | 用户的菜单配置持久保存，重启后保持 |
| FR-DATA-002 | 主应用的配置变更在 1 秒内同步到 Finder Extension |

**总计 FRs: 32**

### 非功能需求（Non-Functional Requirements）

| 编号 | 类别 | 需求描述 | 目标 |
|------|------|---------|------|
| NFR-PERF-001 | 性能 | 右键菜单响应时间 | ≤ 2秒 |
| NFR-PERF-002 | 性能 | 主应用启动时间 | ≤ 3秒 |
| NFR-PERF-003 | 性能 | 内存占用（菜单栏常驻） | ≤ 50MB |
| NFR-PERF-004 | 性能 | 应用扫描时间 | ≤ 5秒 |
| NFR-REL-001 | 可靠性 | macOS 15 兼容性 | 100% 功能正常 |
| NFR-REL-002 | 可靠性 | macOS 26 兼容性 | 100% 功能正常 |
| NFR-REL-003 | 可靠性 | 扩展健康检测准确率 | ≥ 95% |
| NFR-REL-004 | 可靠性 | 崩溃率 | ≤ 0.1% |
| NFR-SEC-001 | 安全性 | 零遥测，零用户数据收集 | 必须 |
| NFR-SEC-002 | 安全性 | 仅请求必要系统权限 | 必须 |
| NFR-SEC-003 | 安全性 | 代码签名（Developer ID） | 必须 |
| NFR-SEC-004 | 安全性 | 公证（Apple Notarization） | 必须 |
| NFR-ACC-001 | 可访问性 | VoiceOver 可读取所有交互元素 | 必须 |
| NFR-ACC-002 | 可访问性 | 设置窗口支持键盘操作 | 必须 |
| NFR-ACC-003 | 可访问性 | 支持系统字体大小设置 | 必须 |

**总计 NFRs: 15**

### 额外需求与约束

| 类别 | 描述 |
|------|------|
| 技术约束 | SwiftUI（macOS 15+） |
| 技术约束 | 3 个构建目标架构（App + Extension + 共享 Package） |
| 技术约束 | App Group 数据共享 |
| 技术风险 | macOS 26 ARM FinderSync bug — 需跟踪 Apple 修复 |
| 技术风险 | Finder Sync API 废弃风险 — 架构隔离 Extension 依赖 |
| 技术风险 | UserDefaults 跨进程同步 — 备选方案：App Group 容器 JSON 文件 |

### PRD 完整性评估

PRD 文档结构清晰完整，包含：执行摘要、成功标准、产品范围、技术架构、用户旅程、功能需求、非功能需求、项目范围总结。需求编号规范，覆盖面广。用户旅程与功能需求有明确的追溯关系。

## 3. 史诗覆盖验证

### 覆盖矩阵

| FR 编号 | PRD 需求 | 史诗覆盖 | 状态 |
|---------|---------|---------|------|
| FR-MENU-001 | 右键菜单一级菜单项 | Epic 1, Story 1.3 | ✓ 覆盖 |
| FR-MENU-002 | 点击打开目标应用 | Epic 1, Story 1.3 | ✓ 覆盖 |
| FR-MENU-003 | 多应用多菜单项 | Epic 2, Story 2.2 | ✓ 覆盖 |
| FR-MENU-004 | 拖拽排序 | Epic 2, Story 2.3 | ✓ 覆盖 |
| FR-MENU-005 | 第一项为默认 | Epic 2, Story 2.3 | ✓ 覆盖 |
| FR-APP-DISCOVERY-001 | 自动扫描 /Applications | Epic 2, Story 2.1 | ✓ 覆盖 |
| FR-APP-DISCOVERY-002 | 展示名称、图标、路径 | Epic 2, Story 2.1 | ✓ 覆盖 |
| FR-APP-DISCOVERY-003 | 手动添加 .app | Epic 2, Story 2.1 | ✓ 覆盖 |
| FR-APP-DISCOVERY-004 | 识别应用类型 | Epic 2, Story 2.1 | ✓ 覆盖 |
| FR-COMMAND-001 | 默认 open -a 命令 | Epic 4, Story 4.1 | ✓ 覆盖 |
| FR-COMMAND-002 | 内置特殊终端映射 | Epic 4, Story 4.1 | ✓ 覆盖 |
| FR-COMMAND-003 | 自定义命令模板 | Epic 4, Story 4.2 | ✓ 覆盖 |
| FR-COMMAND-004 | 命令预览 | Epic 4, Story 4.3 | ✓ 覆盖 |
| FR-ONBOARDING-001 | 首次自动引导 | Epic 3, Story 3.1 | ✓ 覆盖 |
| FR-ONBOARDING-002 | 引导中选择应用 | Epic 3, Story 3.2 | ✓ 覆盖 |
| FR-ONBOARDING-003 | 引导启用扩展 | Epic 3, Story 3.1 | ✓ 覆盖 |
| FR-ONBOARDING-004 | 引导后验证 | Epic 3, Story 3.3 | ✓ 覆盖 |
| FR-HEALTH-001 | 定期检测扩展状态 | Epic 5, Story 5.1 | ✓ 覆盖 |
| FR-HEALTH-002 | 识别异常情况 | Epic 5, Story 5.1 | ✓ 覆盖 |
| FR-HEALTH-003 | 菜单栏状态指示 | Epic 5, Story 5.2 | ✓ 覆盖 |
| FR-HEALTH-004 | 一键恢复引导 | Epic 5, Story 5.3 | ✓ 覆盖 |
| FR-UI-MENUBAR-001 | 菜单栏图标+弹出窗口 | Epic 6, Story 6.1 | ✓ 覆盖 |
| FR-UI-MENUBAR-002 | 无 Dock 图标 | Epic 6, Story 6.1 | ✓ 覆盖 |
| FR-UI-SETTINGS-001 | 独立设置窗口 | Epic 2, Story 2.2 | ✓ 覆盖 |
| FR-UI-SETTINGS-002 | 菜单项增删改 | Epic 2, Story 2.2 | ✓ 覆盖 |
| FR-UI-SETTINGS-003 | 拖拽排序 | Epic 2, Story 2.3 | ✓ 覆盖 |
| FR-SYSTEM-001 | 开机自启 | Epic 6, Story 6.2 | ✓ 覆盖 |
| FR-SYSTEM-002 | 开机自启状态 | Epic 6, Story 6.2 | ✓ 覆盖 |
| FR-ERROR-001 | 检测应用存在 | Epic 7, Story 7.1 | ✓ 覆盖 |
| FR-ERROR-002 | 错误提示 | Epic 7, Story 7.2 | ✓ 覆盖 |
| FR-ERROR-003 | 恢复建议 | Epic 7, Story 7.2 | ✓ 覆盖 |
| FR-DATA-001 | 配置持久保存 | Epic 1, Story 1.2 | ✓ 覆盖 |
| FR-DATA-002 | 配置实时同步 | Epic 2, Story 2.4 | ✓ 覆盖 |

### 缺失需求

无缺失需求。

### 覆盖统计

- PRD 功能需求总数：32
- 史诗覆盖数：32
- 覆盖率：100%

## 4. UX 对齐评估

### UX 文档状态

已找到：`ux-design-specification.md`（39K，2026-02-15）。文档完整，包含执行摘要、核心体验、视觉设计、组件策略、用户旅程、无障碍设计等 14 个章节。

### UX ↔ PRD 对齐

| 维度 | 对齐状态 | 说明 |
|------|---------|------|
| 用户画像 | ✅ 一致 | UX 的小明/阿强与 PRD 完全一致 |
| 用户旅程 | ✅ 一致 | UX 覆盖 PRD 全部 4 个旅程，并增加了情感设计维度 |
| 引导流程 | ✅ 一致 | UX 3 步引导（启用扩展→选择应用→验证）与 PRD FR-ONBOARDING 对齐 |
| 右键菜单交互 | ✅ 一致 | UX 定义的核心交互与 PRD FR-MENU 完全匹配 |
| 健康检测 | ✅ 一致 | UX 的状态指示器设计与 PRD FR-HEALTH 对齐 |
| 自定义命令 | ✅ 一致 | UX 的渐进式披露策略与 PRD FR-COMMAND 对齐 |
| 错误处理 | ✅ 一致 | UX 利用系统默认对话框的策略与 PRD FR-ERROR 对齐 |
| 性能指标 | ✅ 一致 | UX 的响应时间目标（≤ 2s）与 PRD NFR-PERF 一致 |
| 可访问性 | ✅ 一致 | UX 的 VoiceOver/键盘导航/动态字体与 PRD NFR-ACC 对齐 |

### UX ↔ Architecture 对齐

| 维度 | 对齐状态 | 说明 |
|------|---------|------|
| MenuBarExtra 弹出窗口 | ✅ 一致 | 架构支持 `.menuBarExtraStyle(.window)` |
| Settings 窗口 | ⚠️ 差异 | 见下方详细说明 |
| 状态驱动路由 | ✅ 一致 | 架构的 PopoverState 枚举与 UX 状态驱动设计匹配 |
| App Group 数据共享 | ✅ 一致 | 架构的 IPC 方案完全支持 UX 的实时同步需求 |
| 自定义组件 | ✅ 一致 | 架构和 UX 均定义了 5 个自定义组件 |
| 无障碍实现 | ✅ 一致 | 架构的 SwiftUI 原生组件策略支持 UX 的无障碍需求 |
| 脚本执行 | ✅ 一致 | 架构的 NSUserAppleScriptTask 方案支持 UX 的命令执行需求 |

### 对齐问题

#### ⚠️ Settings 窗口 Tab 结构不一致

- **架构文档**定义了 5 个 Tab：菜单管理 / 应用发现 / 自定义命令 / 系统集成 / 关于
- **架构目录结构**包含 5 个 Tab 文件：MenuManagementTab、AppDiscoveryTab、CustomCommandTab、SystemTab、AboutTab
- **UX 设计规范**整合为 3 个 Tab：菜单配置 / 通用 / 关于
  - 应用发现和自定义命令通过渐进式披露（DisclosureGroup）内嵌在菜单配置 Tab
  - 系统集成（开机自启、扩展状态）归入通用 Tab

**影响**：实现时需明确以 UX 设计规范的 3 Tab 方案为准，架构目录结构中的 5 个 Tab 文件需合并调整。

**建议**：以 UX 设计规范为权威来源，更新架构文档的目录结构以反映 3 Tab 方案。

### 警告

无其他警告。UX 文档完整且与 PRD/Architecture 高度对齐，仅 Settings Tab 结构存在上述差异。

## 5. 史诗质量审查

### 史诗用户价值验证

| 史诗 | 标题 | 用户价值 | 评估 |
|------|------|---------|------|
| Epic 1 | 项目基础与右键菜单核心链路 | 用户可以右键打开 Terminal | ⚠️ 标题含技术语言，但描述和交付物是用户导向的 |
| Epic 2 | 应用发现与菜单配置管理 | 用户可以选择应用并管理菜单 | ✅ 用户价值明确 |
| Epic 3 | 首次引导体验 | 用户被引导完成设置 | ✅ 用户价值明确 |
| Epic 4 | 自定义命令与特殊终端支持 | 高级用户可以自定义命令 | ✅ 用户价值明确 |
| Epic 5 | 扩展健康检测与恢复引导 | 用户被告知扩展异常并引导恢复 | ✅ 用户价值明确 |
| Epic 6 | 系统集成与菜单栏体验 | 用户有菜单栏入口和开机自启 | ✅ 用户价值明确 |
| Epic 7 | 错误处理与用户反馈 | 用户看到错误原因和恢复建议 | ✅ 用户价值明确 |

### 史诗独立性验证

| 史诗 | 依赖 | 方向 | 评估 |
|------|------|------|------|
| Epic 1 | 无 | — | ✅ 完全独立 |
| Epic 2 | Epic 1 | 后向 | ✅ 合规 |
| Epic 3 | Epic 1, 2 | 后向 | ✅ 合规 |
| Epic 4 | Epic 1, 2 | 后向 | ✅ 合规 |
| Epic 5 | Epic 1, **Epic 6** | **前向** | ❌ Story 5.3 前向依赖 Epic 6 |
| Epic 6 | Epic 1 | 后向 | ✅ 合规 |
| Epic 7 | Epic 1, 6 | 后向 | ✅ 合规 |

### 故事验收标准质量

| 维度 | 评估 | 说明 |
|------|------|------|
| Given/When/Then 格式 | ✅ 全部合规 | 所有 20 个故事均使用 BDD 格式 |
| 可测试性 | ✅ 全部合规 | 每个 AC 可独立验证 |
| 完整性 | ✅ 良好 | 覆盖正常路径、错误路径、边界情况 |
| 具体性 | ✅ 良好 | 包含具体性能指标（≤ 2s, ≤ 1s, ≤ 5s） |
| 无障碍覆盖 | ✅ 良好 | 多个故事包含 VoiceOver 和键盘导航 AC |

### 最佳实践合规清单

| 检查项 | Epic 1 | Epic 2 | Epic 3 | Epic 4 | Epic 5 | Epic 6 | Epic 7 |
|--------|--------|--------|--------|--------|--------|--------|--------|
| 交付用户价值 | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 可独立运作 | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 故事大小合理 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 无前向依赖 | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| 验收标准清晰 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| FR 可追溯 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### 发现的问题

#### 🟠 Major Issue: Epic 5 Story 5.3 前向依赖 Epic 6

**问题描述：** Epic 5 Story 5.3（异常恢复引导面板）需要在菜单栏弹出窗口中展示 RecoveryGuidePanel，但 PopoverContainerView 的状态路由和完整弹出窗口体验在 Epic 6 Story 6.1 中实现。Epic 5 < Epic 6，构成前向依赖。

**影响：** 实现 Epic 5 时，Story 5.3 无法完成，因为弹出窗口容器尚未实现。

**修复建议：**
- 方案 A：将 Epic 5 和 Epic 6 的顺序对调（Epic 5 → Epic 6，Epic 6 → Epic 5），让菜单栏体验先于健康检测实现
- 方案 B：将 Epic 6 Story 6.1（菜单栏弹出窗口）提前到 Epic 1 中作为基础设施的一部分
- 方案 C：将 Story 5.3 移到 Epic 7 之后，作为独立的集成故事

#### 🟡 Minor Concern: Epic 1 标题含技术语言

**问题描述：** "项目基础与右键菜单核心链路"中的"项目基础"是技术语言。

**修复建议：** 可改为"右键菜单核心链路"或"用户可以通过右键菜单打开 Terminal"。

#### 🟡 Minor Concern: Story 1.1 和 1.2 为纯技术故事

**问题描述：** Story 1.1（Xcode 项目初始化）和 Story 1.2（共享数据层）不直接交付用户价值。

**说明：** 对于 greenfield 项目，架构文档明确指定项目初始化为第一步，这是可接受的模式。Story 1.3 交付了端到端用户价值。

#### 🟡 Minor Concern: Story 1.2 预创建所有共享模型

**问题描述：** Story 1.2 一次性创建了所有 5 个共享模型（MenuItemConfig, AppInfo, ExtensionStatus, ErrorRecord, PopoverState），而非按需创建。

**说明：** 对于 Swift Package 的共享模型层，集中创建是合理的工程实践，模型量小且相互关联。

## 6. 总结与建议

### 整体就绪状态

**基本就绪（READY WITH MINOR FIXES）**

项目规划文档质量高，PRD、架构、UX 设计和史诗文档之间高度对齐。32 个功能需求 100% 被史诗覆盖，验收标准规范完整。需要在实现前解决 1 个主要问题和 1 个对齐差异。

### 需要立即处理的问题

#### 1. 🟠 Epic 5 → Epic 6 前向依赖（必须修复）

Epic 5 Story 5.3（异常恢复引导面板）前向依赖 Epic 6 Story 6.1（菜单栏弹出窗口）。建议将 Epic 5 和 Epic 6 顺序对调，或将弹出窗口基础设施提前到 Epic 1。

#### 2. ⚠️ Settings 窗口 Tab 结构不一致（建议修复）

架构文档定义 5 个 Tab，UX 设计规范整合为 3 个 Tab。建议以 UX 设计规范为准，更新架构文档的目录结构。

### 建议的下一步

1. **修复 Epic 顺序**：将 Epic 6（菜单栏体验）移到 Epic 5（健康检测）之前，消除前向依赖
2. **统一 Settings Tab 结构**：更新架构文档目录结构，将 5 个 Tab 文件合并为 UX 规范的 3 个 Tab
3. **开始实现**：从 Epic 1 Story 1.1（Xcode 项目初始化）开始

### 评估统计

| 维度 | 结果 |
|------|------|
| 文档完整性 | 4/4 必需文档齐全 |
| FR 覆盖率 | 32/32（100%） |
| NFR 覆盖 | 15/15 全部有架构支持 |
| UX ↔ PRD 对齐 | 9/9 维度一致 |
| UX ↔ Architecture 对齐 | 6/7 维度一致（1 个差异） |
| 史诗用户价值 | 7/7 交付用户价值 |
| 史诗独立性 | 6/7 合规（1 个前向依赖） |
| 验收标准质量 | 20/20 故事合规 |
| 🔴 严重问题 | 0 |
| 🟠 主要问题 | 1（Epic 5→6 前向依赖） |
| 🟡 次要问题 | 3（标题措辞、技术故事、模型预创建） |

### 最终说明

本次评估在 6 个维度中发现 1 个主要问题和 4 个次要问题。整体规划质量优秀，文档间对齐度高，需求追溯完整。修复 Epic 顺序和 Tab 结构差异后即可进入实现阶段。
