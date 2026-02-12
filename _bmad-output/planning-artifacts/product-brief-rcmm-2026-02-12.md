---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments:
  - brainstorming-session-2026-02-12.md
  - domain-macos-finder-context-menu-tool-research-2026-02-12.md
  - market-macos-finder-context-menu-tool-research-2026-02-12.md
  - technical-macos-finder-context-menu-tool-research-2026-02-12.md
date: 2026-02-12
author: Sunven
---

# Product Brief: rcmm

## 执行摘要

rcmm（Right Click Menu Manager）是一个 macOS Finder 右键菜单配置中心，让用户在 Finder 中右键目录或空白背景，用任意应用打开当前路径。

产品的核心承诺是"安装即可用"：首次打开 app 即触发引导流程，引导完成后右键菜单立即生效，零额外配置。

rcmm 面向所有使用 Finder 的 macOS 开发者，解决一个每天重复数十次的低效操作 — 从文件浏览到代码操作的上下文切换。相比当前市场领导者 OpenInTerminal（6.7k GitHub stars），rcmm 在三个维度形成差异化：开箱即用的首次体验、不限于终端和编辑器的通用化设计、以及内置扩展健康检测确保跨 macOS 版本的稳定运行。

---

## 核心愿景

### 问题陈述

macOS 开发者每天在 Finder、终端、编辑器之间频繁切换。当在 Finder 中找到目标目录后，没有原生的一级右键菜单入口来"用指定应用打开当前目录"。macOS 内置的 "New Terminal at Folder" 服务藏在二级菜单中，且仅支持 Terminal.app。

### 问题影响

- 每次手动打开终端 → cd 到目录的操作耗时 5-10 秒，每天数十次累积成显著的生产力损耗
- 当前最流行的第三方方案 OpenInTerminal 在 macOS 新版本上安装后不生效，需要额外配置才能使用，用户体验断裂
- 终端模拟器市场从 iTerm2 一家独大变为 6+ 主流选择（Warp、Ghostty、Kitty、Alacritty 等），硬编码应用列表的方案越来越难以为继

### 为什么现有方案不够好

- **OpenInTerminal**：macOS 新版本安装后不生效，需要额外配置；硬编码 40+ 应用枚举，无法覆盖所有终端和编辑器；6 个构建目标带来高维护负担和兼容性风险
- **cdto**：已停滞 3+ 年无更新，仅支持 Terminal.app
- **macOS 原生 Service**：藏在二级菜单，不支持第三方终端
- **Raycast 扩展**：需要快捷键触发，不是右键菜单的直觉操作

### 解决方案

rcmm 是一个 Finder 右键菜单配置中心，通过 Finder Sync Extension 提供一级右键菜单。核心设计原则：

1. **安装即可用** — 首次打开 app 即触发引导流程（选应用 → 确认扩展启用），引导完成后右键菜单立即可用
2. **通用化** — 不限于终端和编辑器，自动发现已安装应用，用任意应用打开目录
3. **稳定可靠** — 内置扩展健康检测，异常时主动引导用户恢复，确保跨 macOS 版本稳定运行

### 关键差异化

| 维度 | OpenInTerminal | rcmm |
|---|---|---|
| 首次体验 | 安装后需额外配置才生效 | 首次打开即引导，引导完即可用 |
| 应用支持 | 硬编码 40+ 应用枚举 | 自动发现 + 自定义命令，任意应用 |
| 稳定性 | 无健康检测，macOS 升级后可能默默失效 | 内置扩展健康检测 + 恢复引导 |
| 架构复杂度 | 6 个构建目标 | 3 个构建目标（App + Extension + 共享 Package） |
| UI 框架 | Cocoa + Storyboard | SwiftUI（macOS 15+） |

## 目标用户

### 主要用户

**全栈/前端开发者 — "小明"**

小明是一个工作 3 年的前端开发者，日常在 Finder、VS Code、终端之间高频切换。他的典型工作流是：在 Finder 中浏览项目目录 → 右键用 VS Code 打开 → 右键用终端打开跑命令。他之前用过 OpenInTerminal，但升级 macOS 后发现装完没效果，折腾了一阵配置后放弃了。他需要一个装完就能用的工具。

- **角色**：前端/全栈开发者
- **环境**：macOS，日常使用 Finder 浏览项目文件
- **核心工具**：VS Code / Cursor、Terminal / iTerm2 / Warp
- **痛点**：每天数十次从 Finder 切换到终端或编辑器，手动 cd 到目录重复且低效；现有工具在 macOS 升级后需要额外配置才能生效
- **期望**：安装 → 打开 → 引导完成 → 右键即可用，零摩擦

**DevOps / 后端开发者 — "阿强"**

阿强是一个 DevOps 工程师，终端是他的主要工作环境。他使用 Kitty 终端，经常需要从 Finder 快速切入终端处理部署脚本和配置文件。OpenInTerminal 对 Kitty 的支持需要特殊参数，他希望工具能自动处理这些差异，或者让他自定义打开命令。

- **角色**：DevOps / 后端开发者
- **环境**：macOS，重度终端用户
- **核心工具**：Kitty / Alacritty / WezTerm 等非主流终端
- **痛点**：特殊终端需要特殊参数才能正确打开目录，硬编码方案无法覆盖
- **期望**：内置常见终端的命令映射，同时支持自定义命令

### 次要用户

无。rcmm 聚焦服务开发人员，不考虑非开发者用户群体。

### 用户旅程

1. **发现**：在 GitHub 搜索 "macOS Finder open terminal" 或看到同事右键直接打开 VS Code，问"你用的什么工具"
2. **安装**：`brew install --cask rcmm`，一行命令完成
3. **首次使用**：打开 app → 引导流程自动启动 → 选择常用应用 → 确认扩展启用 → 完成
4. **价值时刻**：引导完成后，在 Finder 中右键目录，看到自己配置的应用列表，点一下 VS Code 就打开了 — "就是这个"
5. **日常使用**：设置后遗忘型工具，右键菜单成为肌肉记忆的一部分
6. **长期留存**：macOS 升级后，rcmm 检测到扩展状态异常，主动弹出恢复引导，用户无需自己排查

## 成功指标

### 用户成功指标

- **首次引导完成率**：用户首次打开 app 后，能顺利完成引导流程并成功使用右键菜单
- **右键菜单响应**：点击菜单项后，目标应用在合理时间内打开
- **跨版本稳定性**：macOS 大版本升级后，扩展健康检测能正确识别异常并引导恢复

### 业务目标

暂不设定。当前阶段聚焦产品质量，指标和开源策略后续再定。

### 关键性能指标

暂不设定。优先确保核心功能稳定可用。

## MVP 范围

### 核心功能

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

### MVP 不做

- Lite 独立版本
- Finder 工具栏按钮
- 全局快捷键
- 终端/编辑器分类
- Mac App Store 发布
- Storyboard / XIB
- 多语言支持
- 自动更新（Sparkle）
- App Intents / Spotlight 集成

### MVP 成功标准

- 首次打开 app 完成引导后，右键菜单立即可用
- 支持用任意应用打开目录，包括需要特殊参数的终端
- macOS 15 和 macOS 26 双版本验证通过
- 扩展健康检测能正确识别异常状态并引导恢复

### 未来愿景

- **自动更新**：集成 Sparkle 2.x + GitHub Releases
- **App Intents 集成**：通过 Spotlight Quick Keys 提供补充入口
- **多语言支持**：中英文等多语言界面
- **Homebrew 分发**：提交 Homebrew Cask
- **代码签名 + 公证**：Apple Developer Program 注册，消除 Gatekeeper 警告
- **AI 智能推荐**：基于 Foundation Models 根据目录内容推荐应用
