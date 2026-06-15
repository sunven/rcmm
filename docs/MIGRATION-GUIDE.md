# AppState 拆分迁移指南

## 概述

本指南描述如何将现有代码从 `AppState` 迁移到新的协调器架构。

## 已完成的工作

✅ 创建了四个新文件：
- `RCMMApp/Coordinators/MenuConfigStore.swift` — 领域模型
- `RCMMApp/Coordinators/ScriptSyncCoordinator.swift` — 脚本同步编排
- `RCMMApp/Coordinators/WindowCoordinator.swift` — 窗口和 UI 流程
- `RCMMApp/Coordinators/AppCoordinator.swift` — 顶层编排器

✅ 更新了架构文档：
- `CONTEXT.md` — 领域术语定义
- `docs/adr/0001-split-appstate.md` — 架构决策记录

## 迁移步骤

### 步骤 1：验证新文件已被 Xcode 识别

新版 Xcode 使用文件系统同步，新文件应该会自动被识别。验证：

```bash
cd /Users/sunven/github/rcmm
xcodebuild -project rcmm.xcodeproj -target rcmm -configuration Debug -showBuildSettings | grep -i coordinator
```

如果没有自动识别，需要在 Xcode 中手动添加：
1. 右键点击 `RCMMApp` 组
2. 选择 "Add Files to 'rcmm'..."
3. 选择 `RCMMApp/Coordinators/` 目录
4. 确保 Target Membership 选择 `rcmm`

### 步骤 2：更新 rcmmApp.swift

**文件**: `RCMMApp/rcmmApp.swift`

**之前：**
```swift
@State private var appState = AppState()
```

**之后：**
```swift
@State private var appCoordinator = AppCoordinator()
```

**在 MenuBarExtra 和 Settings 中：**
```swift
// 之前
.environment(appState)

// 之后
.environment(appCoordinator)
```

### 步骤 3：属性访问路径对照表

所有 View 文件需要更新属性访问路径。

#### 3.1 MenuConfigStore（领域数据）

| 之前 | 之后 |
|------|------|
| `appState.menuEntries` | `appCoordinator.configStore.menuEntries` |
| `appState.scriptPublishStates` | `appCoordinator.configStore.scriptPublishStates` |
| `appState.errorRecords` | `appCoordinator.configStore.errorRecords` |

#### 3.1 MenuConfigStore（领域数据）

| 之前 | 之后 |
|------|------|
| `appState.menuEntries` | `appCoordinator.configStore.menuEntries` |
| `appState.scriptPublishStates` | `appCoordinator.configStore.scriptPublishStates` |
| `appState.errorRecords` | `appCoordinator.configStore.errorRecords` |
| `appState.menuPresentationMode` | `appCoordinator.configStore.menuPresentationMode` |
| `appState.primaryNewFileMenu` | `appCoordinator.configStore.primaryNewFileMenu` |

#### 3.2 WindowCoordinator（UI 状态）

| 之前 | 之后 |
|------|------|
| `appState.popoverState` | `appCoordinator.windowCoordinator.popoverState` |
| `appState.extensionStatus` | `appCoordinator.windowCoordinator.extensionStatus` |
| `appState.extensionStatusDetail` | `appCoordinator.windowCoordinator.extensionStatusDetail` |
| `appState.updateState` | `appCoordinator.windowCoordinator.updateState` |
| `appState.updateStatusText` | `appCoordinator.windowCoordinator.updateStatusText` |
| `appState.isOnboardingCompleted` | `appCoordinator.windowCoordinator.isOnboardingCompleted` |
| `appState.currentDisplayVersion` | `appCoordinator.windowCoordinator.currentDisplayVersion` |
| `appState.isShowingExtensionCleanupSheet` | `appCoordinator.windowCoordinator.isShowingExtensionCleanupSheet` |
| `appState.extensionCleanupFlowState` | `appCoordinator.windowCoordinator.extensionCleanupFlowState` |

#### 3.3 AppCoordinator（编排层）

| 之前 | 之后 |
|------|------|
| `appState.autoRepairMessage` | `appCoordinator.autoRepairMessage` |

#### 3.4 方法调用

| 之前 | 之后 |
|------|------|
| `appState.saveAndSync()` | `appCoordinator.saveAndSync()` |
| `appState.loadErrors()` | `appCoordinator.configStore.loadErrors()` |
| `appState.dismissAllErrors()` | `appCoordinator.dismissAllErrors()` |
| `appState.addMenuItem(from:)` | `appCoordinator.configStore.addMenuItem(from:)` |
| `appState.addEmptyCompositeCommand()` | `appCoordinator.configStore.addEmptyCompositeCommand()` |
| `appState.addGitPullCommand()` | `appCoordinator.configStore.addGitPullCommand()` |
| `appState.toggleEntry(for:isEnabled:)` | `appCoordinator.configStore.toggleEntry(for:isEnabled:)` |
| `appState.moveEntry(from:to:sync:)` | `appCoordinator.configStore.moveEntry(from:to:)` |
| `appState.removeEntry(at:)` | `appCoordinator.configStore.removeEntry(at:)` |
| `appState.updateCustomCommand(...)` | `appCoordinator.configStore.updateCustomCommand(...)` |
| `appState.updateCompositeName(...)` | `appCoordinator.configStore.updateCompositeName(...)` |
| `appState.updateMenuPresentationMode(...)` | `appCoordinator.configStore.saveMenuPresentationMode(...)`<br>+ `DarwinNotificationCenter.shared.post(.configChanged)` |
| `appState.checkExtensionStatus()` | `appCoordinator.windowCoordinator.checkExtensionStatus()` |
| `appState.checkForUpdates()` | `await appCoordinator.windowCoordinator.checkForUpdates()` |
| `appState.performUpdatePrimaryAction()` | `appCoordinator.windowCoordinator.performUpdatePrimaryAction()` |
| `appState.showOnboardingIfNeeded()` | `appCoordinator.windowCoordinator.showOnboardingIfNeeded()` |
| `appState.closeOnboarding()` | `appCoordinator.windowCoordinator.closeOnboarding()` |
| `appState.beginExtensionCleanup()` | `appCoordinator.windowCoordinator.beginExtensionCleanup()` |
| `appState.executeExtensionCleanup(steps:)` | `appCoordinator.windowCoordinator.executeExtensionCleanup(steps:)` |
| `appState.finishExtensionCleanup()` | `appCoordinator.windowCoordinator.finishExtensionCleanup()` |

### 步骤 4：批量替换策略

使用 Xcode 的全局查找替换（⌘⇧F）：

1. **替换 Environment 声明**
   - 查找：`@Environment(AppState.self) private var appState`
   - 替换：`@Environment(AppCoordinator.self) private var appCoordinator`

2. **替换属性访问（按优先级）**
   - 查找：`appState.menuEntries`
   - 替换：`appCoordinator.configStore.menuEntries`
   
   依次替换其他属性...

**注意**：手动检查每个替换，确保上下文正确。

### 步骤 5：处理未迁移的功能

以下 AppState 功能尚未迁移到新协调器：

#### discoveredApps & compositePresetMessage

```swift
// AppState 中：
var discoveredApps: [AppInfo] = []
var compositePresetMessage: String? = nil

func addEditorTerminalPreset(onCreated: ((UUID) -> Void)? = nil)
```

**临时方案**：保留这些属性在 AppState 中，或移到 MenuConfigStore。

**长期方案**：创建独立的 `AppDiscoveryCoordinator`。

### 步骤 6：验证编译

```bash
cd /Users/sunven/github/rcmm
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build 2>&1 | grep -i error
```

编译错误会指出哪些文件仍在使用旧的 AppState 路径。

### 步骤 7：测试清单

迁移完成后，测试以下功能：

- [ ] 启动应用，显示 onboarding（首次启动）
- [ ] 添加自定义菜单项
- [ ] 编辑菜单项命令
- [ ] 拖拽排序菜单项
- [ ] 删除菜单项
- [ ] 切换菜单项启用/禁用
- [ ] 在 Finder 中右键查看菜单
- [ ] 点击菜单项执行命令
- [ ] 健康监控（30 分钟后检查扩展状态）
- [ ] 手动检查更新
- [ ] 查看错误队列
- [ ] 自动修复（删除脚本文件后重新打开应用）
- [ ] Extension cleanup 流程

### 步骤 8：删除旧的 AppState

**仅在所有测试通过后执行：**

1. 确认没有编译错误
2. 完整测试所有功能
3. 删除 `RCMMApp/AppState.swift`
4. 从 Xcode 项目中移除引用（如果需要）
5. 提交 git：`git add . && git commit -m "refactor: split AppState into three coordinators"`

## 常见问题

### Q: 编译错误 "Cannot find 'appState' in scope"

**A:** 检查该 View 是否已更新 `@Environment` 声明：
```swift
@Environment(AppCoordinator.self) private var appCoordinator
```

### Q: 运行时错误 "keypath not found"

**A:** SwiftUI 的 Observation 可能需要显式声明访问路径。确保使用正确的路径：
```swift
// 错误
Text(appCoordinator.menuEntries[0].displayName)

// 正确
Text(appCoordinator.configStore.menuEntries[0].displayName)
```

### Q: discoveredApps 功能如何处理？

**A:** 有两个选择：
1. 临时保留在 AppState 中，待后续迁移
2. 立即移到 MenuConfigStore 或创建独立的 AppDiscoveryService

### Q: 测试时发现脚本同步不工作？

**A:** 检查 Darwin 通知是否正常发送。在 `ScriptSyncCoordinator` 的 `syncScriptsInBackground` 中添加日志：
```swift
DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
print("✅ Posted configChanged notification")
```

## 回滚方案

如果迁移遇到严重问题：

```bash
# 回滚所有修改的 View 文件
git checkout RCMMApp/*.swift RCMMApp/Views/*.swift

# 保留新的协调器文件（它们不会影响现有代码）
```

## 下一步优化

迁移完成后的改进方向（参考架构评审报告）：

1. **候选项 #2**：实现显式脚本编译管线（CompilationRequest + generation counter）
2. **候选项 #3**：添加同步世代计数器（sync epoch）到跨进程协议
3. **候选项 #4**：内联浅工具类（CommandTemplateProcessor、FinderMenuPresenter）
4. **测试覆盖**：为每个协调器添加单元测试

## 参考文档

- `CONTEXT.md` — 领域术语和架构概念
- `docs/adr/0001-split-appstate.md` — 设计决策和理由
- `/var/folders/.../architecture-review-20260615-143924.html` — 架构评审报告
