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

### Finder Menu Descriptor（Finder 菜单描述）

> 状态：已设计，尚未落地。

Menu Entry 在 Finder 右键菜单里的投影，扩展侧构造菜单与反解点击的唯一入口。树形结构，
子节点对应 `nestedUnderRCMM` 与 New File Template 的二级子菜单。

接口两端成对：`descriptors(...)` 产出描述树，`entry(for:)` 从点击反解回 Script-Backed Entry。
二者同处一个模块，避免菜单项身份的编码与解码分居两个 target。

- **MenuItemFields** — 描述与 `NSMenuItem` 之间的纯值中间层（`title` / `tag` / `identifier` /
  `representedObject` / `parentMenuTitle`）。扩展侧只做 fields ↔ `NSMenuItem` 的机械转换，
  往返正确性在 RCMMShared 内可测。
- **不变量** — 构造菜单与反解点击必须使用同一份不可变快照。快照生成时一并产出身份索引，
  消除"按旧菜单点击、按新配置解析"的时间窗。
- **与 Finder Menu Entry Summary 的分工** — Descriptor 面向 Finder 右键菜单（扩展侧，
  负责身份）；Summary 面向设置界面（App 侧，负责状态展示）。两者都从 Menu Entry 派生，
  服务于不同进程。

### Script Compilation Pipeline（脚本编译管线）
将菜单配置转换为可执行 AppleScript 的流程：

1. **Config → Script Source** — 从 MenuEntry 生成 AppleScript 源码
2. **Script Source → Compiled Script** — 用 `osacompile` 编译为 `.scpt` 文件
3. **Install** — 将 `.scpt` 安装到 `~/Library/Application Scripts/{extension-bundle-id}/`
4. **Publish State** — 记录编译结果和指纹（fingerprint）

接口：调用方先保存配置，然后调用 `publishCurrentConfiguration()`。管线从已保存配置读取 Menu Entry，串行执行编译和发布，更新 Publish State 与错误队列，并发送 Cross-Process Sync 通知。

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
2. Script Compilation Pipeline 发布当前已保存配置
3. App 发送 Darwin Notification（`.configChanged`）
4. Extension 收到通知 → 重新加载 UserDefaults
5. Extension 根据 Publish State 过滤菜单项

### Auto-Repair（自动修复）
检测到特定错误时自动触发脚本重新同步：
- 触发条件：错误队列中存在带稳定脚本身份的 `scriptLoad` 类型错误
- 修复动作：重新执行脚本编译管线
- 清理：发布成功后清除已恢复菜单项的错误；菜单项已删除时，其错误视为过期
- 结果：没有剩余可自动修复的 `scriptLoad` 错误即为成功；只清除部分错误即为部分失败

### Health Monitoring（健康监控）
定期检查扩展状态，更新 UI 提示：
- 每 30 分钟检查一次 PluginKit 状态
- 状态：
  - `enabled` — 当前安装的扩展正常启用
  - `otherBuildEnabled` — Release 与 Debug 中的另一构建版本已启用
  - `otherInstallationEnabled` — 同一构建存在其他安装路径或多份启用记录
  - `disabled` — 当前扩展未启用
  - `unknown` — 暂时无法确认扩展状态
- 影响：菜单栏图标红点、popover 提示内容

## 架构术语

### Coordinator（协调器）
负责特定领域的状态管理和业务逻辑编排：

- **MenuConfigStore** — 领域模型，管理菜单配置、发布状态、错误记录
- **ScriptCompilationPipeline** — 深模块，读取已保存菜单配置，串行执行脚本编译管线，发布状态、错误记录和 Cross-Process Sync 通知
- **WindowCoordinator** — 管理 onboarding、更新提示和扩展清理窗口的生命周期与应用激活策略
- **ApplicationDiscoveryCoordinator** — 缓存应用扫描结果，并从扫描结果创建常用组合菜单预设
- **ExtensionHealthMonitor** — 管理 Finder Extension 健康状态、诊断详情与定期刷新
- **ExtensionCleanupCoordinator** — 管理旧扩展副本清理的计划、确认、执行、取消与结果状态
- **UpdateCoordinator** — 管理应用更新状态、feed 请求、启动检查、安装动作与更新提示
- **AppFlowCoordinator** — 编排应用启动、Onboarding 完成状态与扩展清理窗口；不复制健康、清理、更新或应用发现状态
- **AppCoordinator** — 顶层编排器，持有 MenuConfigStore、ScriptCompilationPipeline，协调配置写入、脚本发布与自动修复

### Menu Entry 写入接口（四入口写模型）

视图**读**配置直接用 MenuConfigStore；**写**配置只经过 AppCoordinator 上的四个入口：

| 入口 | 改内存 | 落盘 | 脚本发布 |
|---|---|---|---|
| `edit { store in … }` | ✓ | ✓ | ✓ |
| `preview { store in … }` | ✓ | — | — |
| `commitPreview()` | — | ✓ | ✓ |
| `updateMenuPresentationMode(_:)` | ✓ | ✓ | 仅 Cross-Process Sync 通知 |

- **不变量** — 每一次已提交编辑恰好触发一次发布。
- **edit** — 闭包同步执行，返回值原样带出（新建条目的 ID）；发布异步进行，调用方不等待编译。无论闭包走 MenuConfigStore 的具名方法还是直接改 `menuEntries`，落盘都由 `edit` 保证。
- **preview** — 拖拽排序这类过程态。回滚责任在调用方（它同时持有选中项与动画等视图状态），取消同样走 `preview` 把原顺序写回。
- **为什么 `updateMenuPresentationMode` 不走 `edit`** — 展示方式不影响 `.scpt` 内容，走 `edit` 会为一个枚举触发全量 AppleScript 重编译。

详见 [ADR-0003](docs/adr/0003-menu-entry-write-interface.md)。

### Module Depth（模块深度）
接口复杂度与实现复杂度的比值：
- **Deep Module（深模块）** — 小接口隐藏大量实现，高 leverage
- **Shallow Module（浅模块）** — 接口复杂度接近实现复杂度，低 leverage
