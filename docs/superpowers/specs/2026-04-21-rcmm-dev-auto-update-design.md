# RCMM 开发版自动更新设计

## 摘要

为 `rcmm` 增加仅面向开发版的应用内自动更新能力，更新引擎使用 Sparkle，同时保留现有基于 GitHub Release + DMG 的手动安装链路。自动更新链路消费 CI 产出的 `.zip` 包和固定的 `dev-appcast.xml` feed，在应用启动后自动检查更新；当发现更高版本的开发版构建时，先显示 RCMM 自己的轻量提示，再在用户确认后把下载、替换和重启交给 Sparkle 处理。

本设计明确只覆盖当前公开 GitHub 开发版发布流程，不试图一次性解决正式版通道、notarization，或 delta 增量更新。

## 目标

- 让已经安装的内部开发版可以在应用内完成自更新。
- 保留现有 DMG 流程，继续作为人工安装和兜底恢复路径。
- 保持“启动自动检查 + 关于页手动检查”的更新发现方式。
- 避免为自替换安装流程单独开发一套高风险安装器，优先复用 Sparkle 已经成熟的下载、替换和重启能力。
- 尽量贴合现有 SwiftUI 应用结构，只增加最小必要的 UI 面积。

## 非目标

- 不引入正式版或稳定版更新通道。
- 不实现 delta 或 patch 更新；第一阶段只做完整包替换。
- 不在未征求用户确认的情况下静默下载和安装更新。
- 不把更新入口塞进菜单栏 popover。
- 不把更新错误接入 Finder Extension 的健康检查错误面板。
- 不在这一阶段重做签名体系，也不把项目迁移到 `Developer ID` / notarization。

## 已确认决策

- 功能目标只面向内部开发版。
- 期望结果是应用内“一键更新”，而不是“跳转下载页”。
- 分发仍然基于公开 GitHub Releases。
- 当前签名模型保持不变，仍允许 ad-hoc 或本地开发签名，不在本阶段引入 `Developer ID` 要求。
- 更新安装后允许应用自动退出并重启。
- 可以调整 CI 和发布产物，只要能提升更新体验。
- DMG 继续保留给人工安装，同时新增 `.zip` 产物供 updater 消费。
- 更新检查同时支持启动自动检查和 About 页手动检查。
- 发现新版本时，先弹 RCMM 自己的轻提示；只有用户明确确认后才开始下载。

## 当前项目约束

- [`README.md`](../../../README.md) 记录了当前开发版基于 GitHub prerelease 和开发版 DMG 的发布流程。
- [`scripts/build-dev-dmg.sh`](../../../scripts/build-dev-dmg.sh) 已经能构建 Release archive、提取 `rcmm.app`、校验嵌入的 Finder Extension，并打包 DMG。
- [`.github/workflows/development-release.yml`](../../../.github/workflows/development-release.yml) 目前只构建 prerelease DMG，并且在 CI 中显式使用 ad-hoc 签名。
- [`RCMMApp/Views/Settings/SettingsView.swift`](../../../RCMMApp/Views/Settings/SettingsView.swift) 已经有独立的 About 页，它天然适合作为显式的更新入口。
- [`RCMMApp/Views/Settings/AboutTab.swift`](../../../RCMMApp/Views/Settings/AboutTab.swift) 当前只展示图标和产品名称，还没有版本信息和更新控制。
- [`RCMMApp/AppState.swift`](../../../RCMMApp/AppState.swift) 已经承担了启动期行为和定时系统检查，因此更新编排应优先落在这里，而不是散落在视图层。
- 当前仓库唯一现成的自动化测试目标位于 [`RCMMShared/Tests/RCMMSharedTests`](../../../RCMMShared/Tests/RCMMSharedTests)，因此更新策略类逻辑应尽量保持纯逻辑、可脱离 Sparkle 做测试。
- [`rcmm.xcodeproj/project.pbxproj`](../../../rcmm.xcodeproj/project.pbxproj) 里的版本号目前仍是静态配置，发布构建还没有按 tag 注入可比较的 bundle version。

## 为什么不用 GitHub “Latest Release”

当前开发版发布流程生成的是 GitHub prerelease，而 GitHub REST 的 “latest release” 端点不会返回 prerelease。若直接依赖该端点，自动更新将无法正确跟踪当前开发版通道。

因此，客户端不应该在运行时去猜“最新 release”，而应该读取一个固定的、明确代表“当前可安装开发版”的 appcast URL。

## 更新通道模型

updater 只跟踪一个明确的开发版通道：

- Feed URL：`https://sunven.github.io/rcmm/appcasts/dev.xml`
- 托管位置：当前公开仓库对应的 GitHub Pages
- feed 维护方式：每次新的开发版 tag 发布时，由 CI 同步更新
- feed 暴露范围：只需要暴露当前最新、可安装的开发版构建

这样客户端逻辑会保持简单：

- 应用本身不需要 GitHub API 凭证。
- 应用不需要理解 GitHub prerelease 的筛选逻辑。
- 应用只需要一个稳定数据源来回答“我现在可以升级到哪个版本”。

## 版本模型

当前 git tag 格式已经接近需求，但不能原样作为唯一的可比较 bundle version。自动更新需要一对稳定、可排序的版本字段：

- git tag 输入：`vX.Y.Z-dev.N`
- 展示版本：`X.Y.Z-dev.N`
- `CFBundleShortVersionString`：`X.Y.Z`
- `CFBundleVersion`：`X.Y.Z.N`

如果开发版 tag 省略尾部序号，则归一化为 `.0`。

示例：

- `v1.2.3-dev.4` -> short version `1.2.3`，bundle version `1.2.3.4`，display version `1.2.3-dev.4`
- `v1.2.3-dev` -> short version `1.2.3`，bundle version `1.2.3.0`，display version `1.2.3-dev`

另外，设计中会引入一个单独的 display-version 字段用于 UI 和日志，因为用户可见版本号应保留 `-dev` 后缀，而可比较版本号则需要规范化。

发布构建必须在 CI 中按 tag 注入这些值，而不是继续沿用项目里的静态默认版本号。

## 发布流水线设计

当前开发版发布流程需要从“只产出一个 DMG”扩展为“构建同一个 app bundle，并以两种包装形式发布，同时维护一个 feed”。

### 必要发布产物

- `rcmm-dev-<display-version>.dmg`
- `rcmm-dev-<display-version>.zip`
- `rcmm-dev-<display-version>.zip.sig` 或等价的 Sparkle 签名元数据
- 发布到 GitHub Pages 的 `dev.xml` appcast
- 供人工核对和兜底恢复使用的 SHA-256 校验文件

### CI 行为

1. 解析推送的开发版 tag，归一化 short version、可比较 bundle version 和 display version。
2. 在归档 `rcmm` scheme 时注入版本覆盖值，确保产出的 app bundle 真实反映当前发布版本。
3. 提取 `rcmm.app`，并校验内嵌的 Finder Extension 仍然存在。
4. 保留现有 DMG 打包路径，继续给人工安装使用。
5. 基于同一个 `rcmm.app` 额外生成 `.zip`，供 Sparkle 消费。
6. 为 `.zip` 生成 Sparkle 所需的更新签名。
7. 将 DMG 和 ZIP 一起上传到 GitHub prerelease。
8. 重新生成开发版 appcast，使其指向最新公开 ZIP asset，并携带 Sparkle 所需版本元数据。
9. 将更新后的 appcast 发布到 GitHub Pages。

### Feed 发布规则

feed 应作为同一次 tag 发布流程的一部分被原子更新。如果工作流无法为新生成的 ZIP 发布一条一致、可用的 appcast 记录，那么这次 release job 应直接失败，而不是留下一个“DMG 可下载、自动更新已失真”的半成品状态。

这里优先保证一致性，而不是接受部分成功。对内部测试来说，若用户已经看到可下载新包，但应用内更新通道仍指向旧版本，会造成误导。

## 应用集成设计

Sparkle 只集成到主应用 target，不进入 Finder Extension。

### 新增职责

- 引入一个独立的 updater service，对 Sparkle 做薄封装，避免框架类型向应用其他层泄漏。
- [`RCMMApp/AppState.swift`](../../../RCMMApp/AppState.swift) 持有一个轻量更新状态机，并负责调用 updater service。
- About 页从 `AppState` 读取更新状态，继续作为唯一显式的设置页更新入口。
- Finder Extension 不直接接触 updater 逻辑；它只是随着主应用 bundle 被整体替换。

### 建议的服务边界

- `UpdateService`
  - 负责 Sparkle controller 初始化
  - 负责启动后台检查
  - 负责触发手动检查
  - 以回调或异步事件的形式暴露 available / no-update / failure / installing 等状态
- `UpdatePolicy`
  - 承载安装资格判断、版本展示格式化、用户态状态映射等纯逻辑
  - 保持在可测试的非框架代码中
- `UpdateState`
  - 面向视图层的状态，由 `AppState` 持有

### 启动行为

- 应用启动几秒后安排一次自动更新检查。
- 启动检查不应与 onboarding 抢时机。如果 onboarding 正在进行或尚未完成，应把自动检查延迟到应用进入稳定状态之后。
- 启动检查在“没有更新”时不弹提示；静默成功是默认行为。

## 用户体验

### About 页

[`RCMMApp/Views/Settings/AboutTab.swift`](../../../RCMMApp/Views/Settings/AboutTab.swift) 需要扩展为展示：

- 当前 display version
- 当前更新状态
- “检查更新”按钮
- 当没有新版本时的被动信息，例如“上次检查时间”或“当前已是最新版本”

轻提示关闭后，更新失败信息也应能在 About 页继续查看。

### 自动发现更新时的提示

当启动后的后台检查发现更新版本的开发版构建时，RCMM 应先显示自己的轻量提示，而不是直接弹 Sparkle 默认界面。这个提示只需要：

- 新版本号
- 可选的 release notes 链接
- `立即更新`
- `稍后`

行为约定：

- `立即更新`：进入 Sparkle 管理的下载和安装流程。
- `稍后`：关闭提示，并在本次应用运行周期内不再重复打扰。
- 在用户点击 `立即更新` 之前，不开始下载。

### 安装流程

用户确认后，Sparkle 负责：

- 下载
- 签名校验
- 应用替换
- 自动重启

RCMM 自己不额外做复杂安装 UI，只需要在必要时反映粗粒度状态，例如 downloading 或 installing。

## 安装资格与失败处理

### 安装资格

第一阶段只允许在受支持的已安装位置上做应用内替换，规范路径定义为 `/Applications/rcmm.app`。

如果 RCMM 运行在不受支持的位置，例如挂载中的 DMG、Downloads 目录中的临时副本等，应用仍然可以检查更新，但不应尝试原地替换。在这种情况下，提示应降级为人工恢复路径，例如打开 release 页面，或明确提示用户先把 RCMM 安装到 `/Applications`。

这样做主要是为了规避内部开发环境中最常见的边界情况：直接从安装镜像启动，或者从临时目录运行 ad-hoc 解包副本。

### 失败处理

- feed 拉取失败：记录非阻塞错误消息，并允许用户在 About 页手动重试。
- feed 内容或签名无效：停止安装，并展示明确的 updater 专用错误。
- 下载失败：允许重试，且不影响应用正常功能。
- 替换或重启失败：展示恢复指引，并提供手动下载兜底路径。
- 任何 updater 错误都必须与现有 Finder Extension 健康检查 UI 隔离，且不能混入 [`SharedErrorQueue`](../../../RCMMShared/Sources/Services/SharedErrorQueue.swift)。

即使更新检查失败，应用也必须继续正常工作。自动更新是附加能力，不是启动依赖。

## Finder Extension 预期

Finder Sync extension 仍旧作为主应用 bundle 的一部分存在，并随着整包更新一起被替换。

本功能的成功标准定义为：

- 主应用能更新并重启到新版本。
- 更新后的 bundle 中仍然包含 Finder Extension。
- Finder Extension 在系统正常的重新注册窗口后恢复工作。

本设计不承诺替换瞬间完全无波动。对于内部开发版 updater，允许存在一个短暂恢复窗口。

## 测试与验证

### 自动化验证

- 为版本归一化和安装资格判断补充单元测试。
- 为 `UpdatePolicy` 的状态流转和提示抑制逻辑补充单元测试。
- 在引入 Sparkle 后，继续验证 `rcmm` scheme 能正常构建。
- 在 CI 中验证发布工作流会成组产出 DMG、ZIP、签名元数据和 appcast。

纯逻辑测试应尽量复用现有共享测试面，而不是因为接入 Sparkle 就立刻引入新的 app test target。

### 手工验证

1. 在 `/Applications` 安装一个较旧的开发版。
2. 发布一个更新的开发版 prerelease。
3. 启动旧版本应用，等待启动自动检查完成。
4. 确认轻提示出现。
5. 点击 `立即更新`。
6. 确认应用完成下载、替换自身、退出并重启到新的 display version。
7. 确认 Finder Extension 仍然嵌入在更新后的 bundle 中，并在重启后恢复健康状态。
8. 确认 About 页仍可手动检查，并在当前已是最新版本时正确显示状态。

### 2026-04-21 手工验收结果

- 验收基线使用安装在 `/Applications/rcmm.app` 的 `v1.0.0-dev.9002`。
- 公开 feed `https://sunven.github.io/rcmm/appcasts/dev.xml` 最终切到 `v1.0.0-dev.9004`，其中 ZIP 下载地址、`sparkle:version`、`sparkle:shortVersionString` 和 `sparkle:edSignature` 均与 release 资产一致。
- 重新启动 `9002` 后，不打开设置页，等待约 3 秒，成功出现指向 `1.0.0-dev.9004` 的轻量更新提示。
- 点击“稍后”后，本次运行周期内没有再次重复弹出同版本提示。
- 打开 About 页后，仍然能看到可更新状态和主操作按钮，说明启动提示关闭后状态没有丢失。
- 点击“立即更新”后，Sparkle 成功完成 ZIP 下载、替换、退出和自动重启。
- 重启后的应用版本已变为 `1.0.0-dev.9004`。
- Finder Extension 在更新重启后仍然可用，满足第一阶段的兼容性预期。
- 本轮还验证到一个发布链路细节：`v1.0.0-dev.9002` 和 `v1.0.0-dev.9003` 都指向同一提交 `d876574` 时，GitHub Pages 对外仍持续返回旧的 `dev.xml`；在创建空提交 `c1bae05` 并发布 `v1.0.0-dev.9004` 后，公开 appcast 才切换到新版本。

## 风险与第一阶段实施里程碑

本设计里最大的技术假设是：在当前开发版签名模型下，Sparkle 仍能足够可靠地完成原地替换流程。

因此，第一阶段实现的首个里程碑不应是完整功能落地，而应是一个兼容性验证 spike，至少要在真实机器上证明以下几点能够同时成立：

- RCMM 能正确消费公开 appcast。
- CI 风格产出的开发版 ZIP 能通过 Sparkle 安装。
- 被替换后的应用能从 `/Applications` 正常重启。
- 被替换后的 bundle 仍然保留完整 Finder Extension 结构。

如果这个 spike 在当前签名模型下失败，实施应立即暂停并重新回到设计阶段，而不是悄悄把目标降级成“半自动下载”。

## 推荐实施形态

- 把 Sparkle 相关代码限制在一个窄边界的 `UpdateService` 后面。
- 把版本和策略逻辑尽量保持为纯 Swift，避免与框架耦合，便于测试。
- 把可见 UI 控制在 About 页和一个轻量发现提示内。
- 让发布自动化保持确定性：一个 tag 对应一组一致的 DMG / ZIP / appcast 输出。
- 在真正需要多通道管理之前，只维护单一开发版更新通道。
