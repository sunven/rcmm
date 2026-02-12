---
stepsCompleted: [1, 2, 3, 4]
inputDocuments: []
session_topic: 'macOS 右键菜单管理应用 — 右键目录/背景快速打开终端、编辑器，参考 OpenInTerminal'
session_goals: '明确产品功能边界；技术架构方案选型；规避 Finder Sync Extension 已知痛点'
selected_approach: 'ai-recommended'
techniques_used: ['First Principles Thinking', 'SCAMPER Method', 'Constraint Mapping']
ideas_generated: ['产品本质定义', '功能边界清单', '技术架构方案', 'OpenInTerminal痛点规避策略', '构建目标简化', '统一菜单模型', '自动应用发现', '内置命令映射+自定义命令', '引导式授权流程', '扩展健康检测']
context_file: ''
session_active: false
workflow_completed: true
---

# Brainstorming Session Results

**Facilitator:** Sunven
**Date:** 2026-02-12

## Session Overview

**Topic:** macOS 右键菜单管理应用 — 在 Finder 中右键目录或空白背景，快速用任意应用打开当前路径
**Goals:** 明确产品功能边界；技术架构方案选型；规避 OpenInTerminal 中 Finder Sync Extension 已知痛点
**Constraints:** 兼容 macOS 15 (Sequoia) + macOS 16 (Tahoe)；独立分发（非 App Store）

### Context Guidance

_参考项目 OpenInTerminal (Ji4n1ng/OpenInTerminal)，已深入分析其 6 个构建目标的完整架构、30 个未解决 issue 和设计模式。_

### Session Setup

_用户选择 AI 推荐技法，由 AI 基于目标推荐最合适的创意技法组合。_

---

## Technique Selection

**Approach:** AI-Recommended Techniques
**Analysis Context:** macOS 右键菜单管理应用，聚焦功能边界和技术架构

**Recommended Techniques:**

- **First Principles Thinking:** 剥离 OpenInTerminal 的实现惯性，回到用户需求本质和 macOS 底层能力
- **SCAMPER Method:** 用七个维度系统拆解 OpenInTerminal 的设计决策，找到差异化空间
- **Constraint Mapping:** 用 macOS 硬约束（沙盒、权限、API 稳定性）过滤想法，输出可落地方案

**AI Rationale:** 先发散（第一性原理）→ 再系统化（SCAMPER）→ 最后收敛（约束地图），适合从参考项目出发做新产品定义的场景。

---

## Technique Execution Results

### Phase 1: First Principles Thinking — 产品本质定义

**探索路径：** 从"用户到底在做什么"出发，逐层剥离假设。

**第一层 — 行为本质：**
用户在做"上下文切换" — 从文件浏览切换到代码操作。Finder 是入口，终端/编辑器是目的地，路径是桥梁。

**第二层 — 为什么是右键菜单：**
对比了 macOS 上所有实现"快速打开目录"的方式：

| 方式 | 菜单层级 | 稳定性 | 自定义能力 |
|---|---|---|---|
| Finder Sync Extension | 一级 | 中等（已知问题） | 完全自定义 |
| Service Menu（服务） | 二级 | 高 | 有限 |
| Quick Action（快速操作） | 二级 | 高 | 有限 |
| 全局快捷键 | 无菜单 | 高 | 无菜单 |
| Dock 拖拽 | 无菜单 | 高 | 无菜单 |

**关键决策：** 用户需要一级菜单体验，Service Menu 和 Quick Action 都藏在二级菜单里，多一次点击。Finder Sync Extension 是唯一能提供一级右键菜单的方式。

**第三层 — App 的差异化价值：**
用户可以手动配 Quick Action 实现单个应用的打开，但 app 的价值在于：
- 管理多个目标应用
- 统一配置界面
- 自动检测已安装应用
- 屏蔽不同终端的参数差异

**第四层 — 加固而非替代：**
Finder Extension 的"不稳定"主要集中在工具栏按钮和扩展注册，右键菜单本身是最稳定的部分。不做工具栏按钮，风险面大幅缩小。

**产品本质：一个 Finder 右键菜单的配置中心 — 菜单栏 app 配置 + Finder Extension 集成 + App Group 共享。**

---

### Phase 2: SCAMPER — 功能边界

**S — Substitute（替代）：**
- AppleScript 保留，但大多数场景走 `do shell script "open -a ..."` 不触发 TCC 弹窗
- 首次使用时做引导式授权流程

**C — Combine（合并）：**
- 砍掉 Lite 版本，不需要
- Helper 登录项用 `SMAppService.mainApp` 替代
- 3 个构建目标：主 App + Finder Extension + 共享 Swift Package

**A — Adapt（调整）：**
- 统一菜单配置模型 — 所有菜单项一视同仁，拖拽排序，第一项即默认
- 应用发现改为自动扫描 + 手动添加，不硬编码枚举
- SwiftUI 重写设置界面
- 新增首次引导流程和扩展健康检测

**M — Modify（修改）：**
- 应用发现：硬编码枚举 → 自动扫描 /Applications
- 设置界面：Cocoa + Storyboard → SwiftUI
- 扩展监控：无 → 健康检测 + 恢复引导
- 首次体验：直接弹设置 → 引导流程

**P — Put to Other Uses（另作他用）：**
- 不限于终端和编辑器，做成通用的"用任意应用打开目录"
- 实现成本与限定版本相同（都是 `open -a AppName /path`）

**E — Eliminate（消除）：**
- Lite 版本 ✂️
- Finder 工具栏按钮 ✂️
- 全局快捷键 ✂️
- Helper 登录项 app ✂️
- Storyboard / XIB ✂️
- 终端/编辑器分类限制 ✂️
- 硬编码 40+ 应用枚举 ✂️

**R — Reverse（反转）：**
- 从"我来告诉你支持什么"反转为"你来告诉我要用什么"
- 特殊命令：内置常见映射（kitty、Alacritty、WezTerm）+ 暴露自定义命令给高级用户

---

### Phase 3: Constraint Mapping — 技术约束验证

| 约束 | 类型 | 状态 | 处理方案 |
|---|---|---|---|
| Finder Extension 必须沙盒 | 真约束 | ✅ 可解 | 预装 .scpt + NSUserAppleScriptTask |
| 主 App 沙盒 | 不需要 | ✅ 无碍 | 独立分发，不沙盒 |
| App Group 共享数据 | 真约束 | ✅ 可解 | 开发阶段 Xcode 自动管理，分发需 Developer 账号 |
| AppleScript 权限 (TCC) | 比预想轻 | ✅ 可解 | `do shell script` 不触发 TCC；少数深度集成才需授权 |
| 代码签名 / 公证 | 分发阶段 | ⏳ 延后 | 开发不影响，分发时注册 Developer 账号 ($99/年) |
| macOS 15/16 兼容 | 无障碍 | ✅ 无碍 | SwiftUI + 现代 API 全覆盖 |
| 自动更新 | 后期 | ⏳ 延后 | Sparkle + GitHub Releases |
| 特殊终端命令 | 可解 | ✅ 可解 | 内置 3-5 个映射 + 自定义命令模板 |

**关键发现：** 无不可逾越障碍。Developer 账号是分发阶段约束，不影响开发验证。

---

## Idea Organization and Prioritization

### 功能边界清单

**核心功能（必做）：**

1. **Finder Sync Extension 右键菜单** — 一级菜单项，点击即打开目标应用
2. **统一菜单配置** — 添加/删除/拖拽排序菜单项，第一项即默认
3. **自动应用发现** — 扫描 /Applications 展示已安装应用
4. **手动添加应用** — 通过 NSOpenPanel 选择任意 .app
5. **自定义打开命令** — 高级用户可编辑命令模板（`open -a {app} {path}`）
6. **内置特殊命令映射** — kitty、Alacritty、WezTerm 等自动使用正确参数
7. **首次引导流程** — 选应用 → 授权 → 确认扩展启用
8. **扩展健康检测** — 检测 Extension 注册状态，异常时引导恢复
9. **菜单栏常驻** — LSUIElement，无 Dock 图标
10. **开机自启** — SMAppService.mainApp

**不做：**

- Lite 独立版本
- Finder 工具栏按钮
- 全局快捷键
- 终端/编辑器分类
- Mac App Store 发布
- Storyboard / XIB

### 技术架构

**构建目标（3 个）：**

```
SharedPackage (Swift Package)
  ├── 主 App (非沙盒, SwiftUI, 菜单栏常驻)
  └── Finder Sync Extension (沙盒, 右键菜单)
```

**技术选型：**

| 决策点 | 方案 |
|---|---|
| UI 框架 | SwiftUI (macOS 15+) |
| 数据共享 | App Group + UserDefaults |
| 应用启动 | AppleScript `do shell script "open -a ..."` |
| 沙盒内执行 | NSUserAppleScriptTask + 预装 .scpt |
| 特殊应用 | bundleId → 命令映射字典 + 用户自定义 |
| 开机自启 | SMAppService.mainApp |
| 应用发现 | FileManager 扫描 + NSWorkspace |
| 分发方式 | DMG / Homebrew + Sparkle 更新 |
| 最低部署目标 | macOS 15 |

### OpenInTerminal 痛点规避

| OpenInTerminal 问题 | 我们的对策 |
|---|---|
| #220 Finder 工具栏失效 | 不做工具栏按钮 |
| #192 扩展注册消失 | 健康检测 + pluginkit 状态检查 + 恢复引导 |
| #249 卷宗图标被替换 | 精细化 directoryURLs 策略 |
| #239/#248 权限反复弹出 | 引导式授权 + 大多数场景不触发 TCC |
| #243/#231 快捷键全局冲突 | 不做全局快捷键 |
| 硬编码 40+ 应用 | 自动发现 + 自定义命令 |
| 6 个构建目标复杂 | 简化为 3 个 |

---

## Session Summary and Insights

**关键成果：**

- 明确了产品定位：Finder 右键菜单配置中心，用任意应用打开目录
- 确定了功能边界：10 项核心功能，6 项明确不做
- 输出了技术架构：3 个构建目标，完整技术选型
- 制定了 OpenInTerminal 6 个主要痛点的规避策略
- 验证了所有技术约束均有成熟解决方案

**下一步行动：**

1. 创建 Xcode 项目，配置 3 个 target（App + Extension + Swift Package）
2. 实现核心流程：Extension 获取路径 → 执行脚本 → 打开应用
3. 实现设置界面：应用列表管理、拖拽排序
4. 实现首次引导流程
5. 实现扩展健康检测

**Session Creative Journey：**

本次头脑风暴从 OpenInTerminal 的深度分析出发，通过第一性原理剥离了"右键打开终端"的需求本质，用 SCAMPER 系统拆解了每个设计决策找到差异化空间（通用化、简化、现代化），最后用约束地图验证了所有方案的可行性。最关键的洞察是：Finder Extension 的右键菜单本身是最稳定的部分，不稳定的是工具栏按钮 — 这让我们能放心使用 Extension 同时规避主要风险。
