# Finder 扩展旧副本清理设计

## 摘要

为 rcmm 增加一个“清理旧扩展副本”能力，用于处理同一台机器上存在多份历史调试/打包版 `rcmm`，导致 Finder 同时记录多份 `RCMMFinderExtension.appex` 的问题。功能入口同时出现在异常恢复面板和设置页，统一走“扫描 -> 展示清理计划 -> 二次确认 -> 执行清理 -> 自动切回当前扩展并重启 Finder -> 展示结果”的流程。

本次设计采用保守清理策略：只自动处理 `~/Library/Developer/Xcode/DerivedData/.../rcmm.app` 和当前仓库 `build/dev-release/.../rcmm.app` 中的旧副本，不自动删除 `/Applications`、`~/Applications` 或其他用户目录中的正式安装包。

## 目标

- 帮用户在应用内完成旧 `rcmm` 调试/打包副本的识别和清理。
- 避免用户手工定位多个历史副本、结束旧进程、删除旧包、切换扩展和重启 Finder。
- 在执行破坏性动作前，清楚展示将删除的副本、将结束的进程和后续自动动作。
- 让恢复面板和设置页复用同一套清理流程，而不是各自实现一份逻辑。

## 非目标

- 不自动删除 `/Applications`、`~/Applications`、桌面、下载目录或其他用户任意位置的 `rcmm.app`。
- 不处理源码仓库本身或做“顺手清空整个 `build/` / `DerivedData/`”。
- 不修改 Finder 扩展菜单生成逻辑。
- 不尝试清理非 `rcmm` 的 Finder 扩展。
- 不做无确认的后台自动删除。

## 已确认决策

- 只清理 `DerivedData` 和当前仓库 `build/dev-release` 中的旧 `rcmm` 副本。
- 删除前必须展示待处理项并二次确认。
- 清理执行时自动结束命中的旧 `rcmm` 进程。
- 清理后自动执行：
  - `pluginkit -e use -i com.sunven.rcmm.FinderExtension`
  - `killall Finder`
- 除恢复面板外，还要在设置页额外提供 `清理旧扩展副本` 入口。
- 设置页和恢复面板共用同一套扫描、确认和执行流程。

## 当前项目上下文

- [`RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift`](../../../RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift) 当前已经在扩展异常时显示修复引导，但只有“前往系统设置修复扩展”能力。
- [`RCMMApp/Services/PluginKitService.swift`](../../../RCMMApp/Services/PluginKitService.swift) 已负责读取当前进程路径、调用 `pluginkit`、生成扩展状态详情文案。
- [`RCMMShared/Sources/Services/ExtensionInstallHealthResolver.swift`](../../../RCMMShared/Sources/Services/ExtensionInstallHealthResolver.swift) 已负责把 `pluginkit` 输出解析为“当前启用 / 其他安装启用 / 多份安装冲突”等状态。
- 设置页当前没有“清理旧扩展副本”的手动入口。
- 现有仓库中可稳定运行的是 `RCMMShared` 测试，因此涉及路径白名单、候选规划和结果归类的核心规则应优先下沉到共享层做纯逻辑测试。

## 设计方案

### 总体架构

新增一套以“规划”和“执行”分层的清理架构：

- `RCMMShared`
  - 纯数据模型：
    - `ExtensionCleanupCandidate`
    - `ExtensionCleanupPlan`
    - `ExtensionCleanupResult`
  - 纯逻辑规划器：
    - `ExtensionCleanupPlanner`
  - 职责：
    - 识别哪些路径可自动清理
    - 过滤当前安装版
    - 基于白名单生成候选清理计划
    - 归类执行结果为“完全成功 / 部分成功 / 未执行”

- `RCMMApp`
  - 副作用执行服务：
    - `ExtensionCleanupService`
  - 可选执行包装：
    - `SystemCommandRunner`
  - 职责：
    - 扫描文件系统
    - 查找命中的旧 `rcmm` 进程
    - 结束旧进程
    - 删除旧副本
    - 执行 `pluginkit`
    - 执行 `killall Finder`
    - 重检扩展状态

`PluginKitService` 继续只负责健康检测与路径读取，不承担删除动作，避免健康查询与破坏性修复耦合。

### 用户入口

新增两个用户入口，但都走同一套清理流程：

- 恢复面板
  - 位置：[`RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift`](../../../RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift)
  - 显示条件：状态为“多份 `rcmm` Finder 扩展同时启用”时
  - 入口文案：`清理旧扩展副本…`

- 设置页
  - 位置：建议放在 `GeneralTab`
  - 入口文案：`清理旧扩展副本…`
  - 作用：即使用户当前没有打开异常恢复面板，也可以主动执行同样的修复流程

### 确认交互

用户点击入口后，不直接执行删除，而是先做一次只读扫描，生成 `ExtensionCleanupPlan`，然后弹出确认 sheet。

确认 sheet 内容分三块：

- `将删除的副本`
  - 展示待删除的 `rcmm.app` 绝对路径
- `将结束的旧进程`
  - 展示命中的旧 `rcmm` 进程及其路径归属
- `后续自动执行`
  - `切换到当前 rcmm Finder 扩展`
  - `重启 Finder`
  - `重新检测扩展状态`

顶部摘要给出一次结论，例如：

`发现 5 个旧副本，会结束 2 个旧 rcmm 进程，并在清理后自动切回当前扩展、重启 Finder。`

底部只有两个动作：

- `取消`
- `确认清理`

执行前会显式提示：`不会处理 /Applications 中的正式安装版。`

### 执行态与结果态

用户确认后，sheet 切到执行态，展示阶段性进度：

1. 正在结束旧 rcmm 进程
2. 正在删除旧扩展副本
3. 正在切换到当前扩展
4. 正在重启 Finder
5. 正在重新检测状态

结果页分三类：

- 完全成功
- 部分成功
- 未执行清理

每类结果都要包含：

- 已完成动作摘要
- 未完成动作摘要
- 下一步建议

示例建议：

- `请手动关闭 Finder 后重试`
- `部分路径因权限或白名单限制未删除`
- `请检查当前安装版 rcmm 是否仍在运行`

## 扫描规则

### 数据源

- `pluginkit -m -ADv -i com.sunven.rcmm.FinderExtension`
  - 提供“系统当前记录为启用中的扩展路径”
- 文件系统扫描
  - `~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/rcmm.app`
  - 当前仓库 `build/dev-release/**/rcmm.app`
    - 仅在应用能可靠推导出仓库根目录时启用
    - 若当前运行环境无法判断仓库根目录，则跳过该扫描源，不影响 `DerivedData` 清理

### 当前安装版识别

通过当前进程 `Bundle.main.builtInPlugInsURL/.../RCMMFinderExtension.appex` 反推出当前 app 所在路径。任何与当前 app 同源的路径都不得进入清理候选。

### 候选条件

候选路径必须同时满足：

- 路径名是 `rcmm.app`
- 包内存在 `Contents/PlugIns/RCMMFinderExtension.appex`
- 不等于当前安装版路径
- 位于允许自动清理的白名单根目录内

### 去重规则

同一路径如果同时来自 `pluginkit` 输出和文件系统扫描，只保留一个候选。

## 删除边界

### 允许自动删除

- `~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/rcmm.app`
- 当前仓库 `build/dev-release/.../rcmm.app`
  - 前提：仓库根目录可被可靠识别

### 不允许自动删除

- `/Applications/rcmm.app`
- `~/Applications/rcmm.app`
- 桌面、下载目录或其他任意用户目录下的 `rcmm.app`
- 当前工作区源码目录

### 删除粒度

- 只删除候选命中的 `rcmm.app` 包
- 对 `build/dev-release` 只删除匹配到的 `rcmm.app`，不清空整个 `build/`
- 不做模糊递归删除

如果某个路径被识别为“疑似旧副本”但不在白名单目录内，应在计划中标记为“检测到但不允许自动清理”，只展示，不执行删除。

## 进程处理规则

- 通过 `ps` 或 `pgrep` 获取正在运行的 `rcmm` 进程
- 根据进程可执行文件路径归属到候选副本
- 只结束命中旧副本路径的进程
- 永远不结束当前 app 自己
- 结束顺序：
  - 先发送温和终止
  - 等待短超时
  - 仍未退出时再强制结束

## 执行顺序

1. 生成 `ExtensionCleanupPlan`
2. 用户确认
3. 结束旧进程
4. 删除旧副本
5. 执行 `pluginkit -e use -i com.sunven.rcmm.FinderExtension`
6. 执行 `killall Finder`
7. 等待数秒后重检健康状态
8. 展示 `ExtensionCleanupResult`

## 失败处理

- 任一步失败时停止后续破坏性动作
- 如果删除已完成，但 `pluginkit` 或 `killall Finder` 失败，则仍要继续做健康重检，并把状态展示给用户
- 结果页明确指出失败发生在哪一步，不允许静默半成功
- 对于白名单限制导致未删除的路径，应明确标为“未执行”，不是“删除失败”

## 实现边界

### 建议新增文件

- `RCMMShared/Sources/Models/ExtensionCleanupCandidate.swift`
- `RCMMShared/Sources/Models/ExtensionCleanupPlan.swift`
- `RCMMShared/Sources/Models/ExtensionCleanupResult.swift`
- `RCMMShared/Sources/Services/ExtensionCleanupPlanner.swift`
- `RCMMApp/Services/ExtensionCleanupService.swift`
- `RCMMApp/Services/SystemCommandRunner.swift`
- `RCMMApp/Views/ExtensionCleanup/ExtensionCleanupSheet.swift`

### 建议修改文件

- [`RCMMApp/Services/PluginKitService.swift`](../../../RCMMApp/Services/PluginKitService.swift)
  - 暴露清理所需的当前安装路径与启用路径读取能力
- [`RCMMApp/AppState.swift`](../../../RCMMApp/AppState.swift)
  - 承接清理计划、sheet 展示状态、执行中状态和结果态
- [`RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift`](../../../RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift)
  - 接入入口与结果刷新
- `RCMMApp/Views/Settings/GeneralTab.swift`
  - 增加设置页入口

## 测试策略

### 自动化测试

优先把可判定规则下沉到 `RCMMShared`，覆盖：

- 白名单规则
- 当前安装版排除规则
- 候选去重
- 清理计划生成
- 结果归类

新增测试建议：

- `ExtensionCleanupPlannerTests`
  - 允许 `DerivedData` 路径进入候选
  - 允许 `build/dev-release` 路径进入候选
  - 拒绝 `/Applications`、`~/Applications`、桌面、下载目录
  - 当前 app 路径永远不会被计划删除
  - `pluginkit` 和文件系统重复命中时能正确去重
  - 部分成功和未执行的结果映射正确

### 手工验证

1. 构造多个旧调试副本和 1 个当前副本
2. 恢复面板中点击 `清理旧扩展副本…`
3. 确认 sheet 只列出白名单范围内旧副本
4. 确认 `/Applications` 中的正式安装版不会进入待删除列表
5. 执行后验证：
   - 旧进程被结束
   - 旧副本被删除
   - `pluginkit` 切回当前扩展
   - Finder 被重启
   - 健康状态恢复
6. 构造失败场景，验证结果页能明确指出失败阶段与后续建议

## 验收标准

- 恢复面板中在多份扩展冲突时出现 `清理旧扩展副本…`
- 设置页存在相同入口
- 点击入口后先展示二次确认，不直接删除
- 确认页明确展示待删除副本、待结束进程和后续自动动作
- 自动清理仅作用于白名单目录
- 不会删除 `/Applications` 或其他非白名单目录中的 `rcmm.app`
- 清理后自动切回当前扩展并重启 Finder
- 成功、部分成功、未执行三种结果都能被清楚展示
