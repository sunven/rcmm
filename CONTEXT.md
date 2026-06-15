# CONTEXT.md

领域语言和架构概念。

## 核心概念

### Menu Entry（菜单项）
用户配置的 Finder 右键菜单项。包含：
- 应用信息（名称、路径、bundle ID）
- 执行模式（打开应用、执行自定义命令、组合步骤）
- 目标策略（当前选中路径 vs 包含目录）

分类：
- **Script-Backed Entry** — 需要编译为 AppleScript 的菜单项（应用启动、自定义命令、组合步骤）
- **Built-in Entry** — 内置功能菜单项（复制路径、在终端打开等）
- **New File Template** — 新建文件模板菜单项

### Script Compilation Pipeline（脚本编译管线）
将菜单配置转换为可执行 AppleScript 的流程：

1. **Config → Script Source** — 从 MenuEntry 生成 AppleScript 源码
2. **Script Source → Compiled Script** — 用 `osacompile` 编译为 `.scpt` 文件
3. **Install** — 将 `.scpt` 安装到 `~/Library/Application Scripts/{extension-bundle-id}/`
4. **Publish State** — 记录编译结果和指纹（fingerprint）

### Fingerprint（指纹）
菜单项内容的哈希值，用于检测配置变更：
- 配置更改 → 指纹变化 → 需要重新编译
- 扩展加载时比对指纹，过滤掉过期的菜单项

### Publish State（发布状态）
脚本编译结果的记录：
- `.current` — 脚本已编译且最新
- `.outdated` — 配置已变更，脚本过期
- `.failed` — 编译失败

### Cross-Process Sync（跨进程同步）
App 和 Extension 运行在独立沙盒进程中，通过以下机制通信：

- **App Group UserDefaults** — 共享配置数据（菜单项、发布状态）
- **Darwin Notifications** — 广播式唤醒信号，通知配置变更
- **Script Files** — 编译后的 `.scpt` 文件存储在共享目录

协议：
1. App 保存配置 → 写入 UserDefaults
2. App 发送 Darwin Notification（`.configChanged`）
3. Extension 收到通知 → 重新加载 UserDefaults
4. Extension 根据 Publish State 过滤菜单项

### Auto-Repair（自动修复）
检测到特定错误时自动触发脚本重新同步：
- 触发条件：错误队列中存在"脚本文件不存在"错误
- 修复动作：重新执行脚本编译管线
- 清理：修复成功后清除匹配的错误记录

### Health Monitoring（健康监控）
定期检查扩展状态，更新 UI 提示：
- 每 30 分钟检查一次 PluginKit 状态
- 状态：enabled / disabled / unknown
- 影响：菜单栏图标红点、popover 提示内容

## 架构术语

### Coordinator（协调器）
负责特定领域的状态管理和业务逻辑编排：

- **MenuConfigStore** — 领域模型，管理菜单配置、发布状态、错误记录
- **ScriptSyncCoordinator** — 编排脚本编译管线、Darwin 通知、后台任务队列
- **WindowCoordinator** — 管理窗口生命周期、UI 流程（onboarding、settings、更新检查）、健康监控
- **AppCoordinator** — 顶层编排器，持有三个独立的协调器，协调它们之间的交互

### Module Depth（模块深度）
接口复杂度与实现复杂度的比值：
- **Deep Module（深模块）** — 小接口隐藏大量实现，高 leverage
- **Shallow Module（浅模块）** — 接口复杂度接近实现复杂度，低 leverage