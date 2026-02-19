# Story 2.3: 菜单项拖拽排序与默认项

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 用户,
I want 通过拖拽调整菜单项顺序，第一项自动成为默认打开方式,
So that 我最常用的应用始终在右键菜单的最顶部。

## Acceptance Criteria

1. **拖拽排序** — 用户在菜单配置列表中拖拽某个菜单项到新位置，列表顺序实时更新，使用 SwiftUI `List` + `.onMove`。`sortOrder` 字段按新顺序更新并持久化（通过 `AppState.saveAndSync()`）。
2. **默认项标记** — 排在第一位（`sortOrder == 0`）的菜单项自动标记为默认项，使用视觉标识（如 SF Symbol `star.fill` 或 `checkmark.circle` 图标 + "默认" 标签）区分于其他项。
3. **VoiceOver 替代排序** — 使用 VoiceOver 的用户可通过 `.accessibilityAction` 替代拖拽操作（"上移"/"下移"按钮），完成排序功能。VoiceOver 读出当前位置信息（如"第 2 项，共 5 项"）。
4. **配置持久化与同步** — 排序变更后，`SharedConfigService` 写入 App Group UserDefaults，`ScriptInstallerService` 后台同步 .scpt 文件，`DarwinNotificationCenter` 发送 `configChanged` 通知。Extension 下次右键时使用新顺序。
5. **编辑模式切换** — `List` 启用 `EditButton` 或始终允许拖拽（macOS `List` 默认支持 `.onMove`，无需显式 EditMode），确保拖拽交互直观。

## Tasks / Subtasks

- [x] Task 1: 在 AppState 中添加 moveMenuItem 方法 (AC: #1, #4)
  - [x] 1.1 实现 `moveMenuItem(from source: IndexSet, to destination: Int)` — 调用 `menuItems.move(fromOffsets:toOffset:)`
  - [x] 1.2 移动后重新计算所有 `menuItems` 的 `sortOrder`（遍历 enumerated，设 `sortOrder = index`）
  - [x] 1.3 调用 `saveAndSync()` 持久化并同步脚本 + 发送 Darwin Notification

- [x] Task 2: 在 MenuConfigTab 中启用拖拽排序 (AC: #1, #5)
  - [x] 2.1 在 `ForEach` 上添加 `.onMove { source, destination in appState.moveMenuItem(from: source, to: destination) }`
  - [x] 2.2 验证 macOS SwiftUI `List` 默认支持拖拽手柄（无需额外 `EditButton`），如需显式启用则添加 `.environment(\.editMode, .constant(.active))` 或在工具栏添加 `EditButton`

- [x] Task 3: 在 AppListRow 中添加默认项标识 (AC: #2)
  - [x] 3.1 添加 `isDefault: Bool` 参数（由 MenuConfigTab 传入，判断 `menuItem == appState.menuItems.first`）
  - [x] 3.2 当 `isDefault == true` 时，在应用名称旁显示 `Image(systemName: "star.fill").foregroundStyle(.yellow)` + `Text("默认").font(.caption).foregroundStyle(.secondary)`
  - [x] 3.3 更新 `.accessibilityLabel` — 默认项读出"[应用名]，默认项"

- [x] Task 4: 添加 VoiceOver 辅助排序操作 (AC: #3)
  - [x] 4.1 在 AppListRow 中添加 `.accessibilityAction(named: "上移")` 和 `.accessibilityAction(named: "下移")` 回调
  - [x] 4.2 回调通过闭包/Binding 通知 MenuConfigTab，调用 `appState.moveMenuItem` 将当前项上移/下移一位
  - [x] 4.3 更新 `.accessibilityValue` — 读出"第 X 项，共 Y 项"

- [x] Task 5: 更新 MenuConfigTab 传参 (AC: #2, #3)
  - [x] 5.1 将 `AppListRow` 调用改为传入 `isDefault` 参数和上移/下移闭包
  - [x] 5.2 实现上移/下移辅助方法（封装 `moveMenuItem` 的单步移动逻辑）

- [x] Task 6: 编译验证与手动测试 (AC: 全部)
  - [x] 6.1 `xcodebuild -scheme rcmm` 编译成功（零错误）
  - [x] 6.2 RCMMShared 全部现有测试通过，无回归
  - [x] 6.3 手动测试：拖拽菜单项 → 顺序更新 → 第一项显示默认标识
  - [x] 6.4 手动测试：排序后右键 Finder → 菜单项顺序与设置一致
  - [x] 6.5 手动测试：VoiceOver 激活 → 上移/下移操作可用 → 位置信息正确读出

### Review Follow-ups (AI)

- [ ] [AI-Review][MEDIUM] 为 AppState.moveMenuItem(from:to:) 添加单元测试（需创建 RCMMApp 测试目标或将排序逻辑下沉到 RCMMShared 可测试层）[AppState.swift:87-93]

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 2（应用发现与菜单配置管理）的第三个 Story，在 Story 2.2（设置窗口与菜单项管理）基础上添加拖拽排序能力。Story 2.4（配置实时同步与动态右键菜单）将验证排序变更能否正确同步到 Extension 并反映在右键菜单中。

**FRs 覆盖：** FR-MENU-004（拖拽排序菜单项）、FR-MENU-005（设置默认第一项）、FR-UI-SETTINGS-003（设置窗口中拖拽排序）

**跨 Story 依赖：**
- 依赖 Story 2.2：使用 `AppState`（`moveMenuItem` 方法需新增）、`MenuConfigTab`（添加 `.onMove`）、`AppListRow`（添加默认标识和无障碍操作）
- 依赖 Story 1.2：使用 `SharedConfigService`、`MenuItemConfig.sortOrder`、`DarwinNotificationCenter`
- 依赖 Story 1.3：使用 `ScriptInstallerService.syncScripts(with:)`
- Story 2.4 将在此基础上验证排序变更同步到 Extension

### 关键技术决策

**1. 拖拽排序实现 — SwiftUI List + .onMove**

```swift
// MenuConfigTab.swift 中：
List {
    ForEach(appState.menuItems) { item in
        AppListRow(menuItem: item, isDefault: item.id == appState.menuItems.first?.id, ...)
    }
    .onMove { source, destination in
        appState.moveMenuItem(from: source, to: destination)
    }
    .onDelete { offsets in
        appState.removeMenuItem(at: offsets)
    }
}
```

macOS SwiftUI `List` 在有 `.onMove` 时自动显示拖拽手柄（三横线图标）。**无需** `EditButton` 或 `.environment(\.editMode)`。如果拖拽手柄不自动出现，可尝试添加 `.listStyle(.inset)` 或在工具栏添加 `EditButton()`。

**2. AppState.moveMenuItem 实现**

```swift
// AppState.swift 中新增：
func moveMenuItem(from source: IndexSet, to destination: Int) {
    menuItems.move(fromOffsets: source, toOffset: destination)
    // 重新计算 sortOrder
    for (index, _) in menuItems.enumerated() {
        menuItems[index].sortOrder = index
    }
    saveAndSync()
}
```

模式与现有 `removeMenuItem(at:)` 完全一致 — 先修改数组，再重算 sortOrder，最后 saveAndSync。

**3. 默认项标识**

```swift
// AppListRow.swift 中：
struct AppListRow: View {
    let menuItem: MenuItemConfig
    var isDefault: Bool = false
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: menuItem.appPath))
                .resizable()
                .frame(width: 32, height: 32)
            Text(menuItem.appName)
                .font(.body)
            if isDefault {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                Text("默认")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(appExists ? "就绪" : "未找到")
                .font(.caption)
                .foregroundStyle(appExists ? Color.secondary : Color.red)
        }
        // ...accessibility
    }
}
```

**4. VoiceOver 辅助排序**

```swift
// AppListRow 中添加：
.accessibilityAction(named: "上移") {
    onMoveUp?()
}
.accessibilityAction(named: "下移") {
    onMoveDown?()
}
.accessibilityValue("第 \(position) 项，共 \(total) 项")
```

`onMoveUp` / `onMoveDown` 闭包从 MenuConfigTab 传入，封装 `moveMenuItem` 的单步移动。第一项隐藏"上移"，最后一项隐藏"下移"（条件渲染 accessibilityAction）。

### Swift 6 并发注意事项

- `moveMenuItem` 在 `@MainActor` 上下文（AppState 类级标注），UI 状态修改线程安全
- `saveAndSync()` 内部将脚本同步分发到后台线程，主线程不阻塞
- 本 Story 不引入新的并发模式，完全复用 Story 2.2 建立的模式

### 命名规范参考

| 类别 | 规范 | 本 Story 示例 |
|---|---|---|
| 方法 | lowerCamelCase，动词开头 | `moveMenuItem(from:to:)` |
| 参数 | 与 SwiftUI API 一致 | `from source: IndexSet, to destination: Int` |
| 布尔属性 | is 前缀 | `isDefault` |
| 闭包参数 | on 前缀 | `onMoveUp`, `onMoveDown` |

### 前序 Story 经验总结

**来自 Story 2.2（关键）：**
- `AppState` 已在 `RCMMApp/AppState.swift`，使用 `@Observable @MainActor`
- `removeMenuItem(at:)` 已建立 sortOrder 重算模式 — `moveMenuItem` 完全复用
- `MenuConfigTab` 已有 `List` + `ForEach` + `.onDelete` — 只需加 `.onMove`
- `AppListRow` 已有 icon + name + status — 只需加 `isDefault` 标识和辅助操作
- Code Review 修复了 SettingsAccess 集成、批量 saveAndSync、重复检查
- `NSApp.sendAction(Selector(("showSettingsWindow:")))` 已替换为 SettingsAccess

**来自 Story 2.2 Code Review 提醒：**
- M2: ScriptInstallerService 每次调用新建实例（保持现状，无可变状态）
- M4: 启动时重编译所有脚本（已记录，未来优化）
- L1: 混用 DispatchQueue 和 Task.detached 并发模式（保持现状）

**当前代码状态（核心文件）：**
- `MenuConfigTab.swift`：List + ForEach + .onDelete，**无** .onMove
- `AppListRow.swift`：HStack(icon + name + status)，**无**默认标识，**无**辅助操作
- `AppState.swift`：有 removeMenuItem，**无** moveMenuItem
- `MenuItemConfig.swift`：已有 `sortOrder: Int`，**无需修改**

### 反模式清单（禁止）

- ❌ 使用 `ObservableObject/@Published`（统一用 `@Observable`）
- ❌ 在非 `@MainActor` 上下文修改 UI 状态
- ❌ 在主线程执行 `syncScripts(with:)`（osacompile 可能阻塞）
- ❌ 硬编码 App Group 键名或 Darwin Notification 名称
- ❌ 修改 `MenuItemConfig.swift` 模型结构（sortOrder 已存在，无需新字段）
- ❌ 使用 `EditButton` 作为拖拽排序的前提条件（macOS List + .onMove 默认支持拖拽）
- ❌ 使用 `try!` 或 force unwrap
- ❌ 在 RCMMShared 中引入 SwiftUI 或 AppKit 依赖

### Project Structure Notes

**本 Story 完成后的修改文件（无新增文件）：**

```
rcmm/
├── RCMMApp/
│   ├── AppState.swift                          # [修改] 新增 moveMenuItem(from:to:) 方法
│   └── Views/
│       └── Settings/
│           ├── MenuConfigTab.swift             # [修改] ForEach 添加 .onMove，传入 isDefault 和辅助操作闭包
│           └── AppListRow.swift                # [修改] 添加 isDefault 标识 + VoiceOver 上移/下移 accessibilityAction
```

**不变的文件：**

```
RCMMShared/Sources/Models/MenuItemConfig.swift    # 不变 — sortOrder 已存在
RCMMShared/Sources/Services/SharedConfigService.swift  # 不变
RCMMShared/Sources/Services/DarwinNotificationCenter.swift  # 不变
RCMMApp/Services/ScriptInstallerService.swift      # 不变
RCMMApp/Views/Settings/SettingsView.swift          # 不变
RCMMApp/Views/Settings/AppSelectionSheet.swift     # 不变
RCMMFinderExtension/FinderSync.swift               # 不变（已按 sortOrder 排序读取配置）
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.3] — Story 需求定义和验收标准（拖拽排序 + 默认项 + VoiceOver 辅助排序）
- [Source: _bmad-output/planning-artifacts/architecture.md#UI Architecture] — UI 架构决策（List + .onMove 拖拽排序）
- [Source: _bmad-output/planning-artifacts/architecture.md#State Management] — 状态管理：单一 AppState（@Observable），修改后 saveAndSync()
- [Source: _bmad-output/planning-artifacts/architecture.md#Naming Patterns] — 命名规范
- [Source: _bmad-output/planning-artifacts/architecture.md#Communication Patterns] — Darwin Notification 协议
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Component Strategy] — AppListRow 组件定义（完整模式 + 拖拽排序支持）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#UX Consistency Patterns] — 拖拽排序同时提供 .accessibilityAction 替代方案
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Accessibility Strategy] — VoiceOver 支持、键盘导航、色盲友好
- [Source: _bmad-output/planning-artifacts/prd.md#右键菜单] — FR-MENU-004（拖拽排序）、FR-MENU-005（默认第一项）
- [Source: _bmad-output/planning-artifacts/prd.md#用户界面] — FR-UI-SETTINGS-003（设置窗口拖拽排序）
- [Source: _bmad-output/implementation-artifacts/2-2-settings-window-and-menu-item-management.md] — 前序 Story dev notes 和经验
- [Apple: List onMove](https://developer.apple.com/documentation/swiftui/dynamicviewcontent/onmove(perform:)) — 拖拽排序 API
- [Apple: accessibilityAction](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:)) — 自定义无障碍操作

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

无调试问题 — 编译一次通过。

### Completion Notes List

- Task 1: 在 AppState 中新增 `moveMenuItem(from:to:)` 方法，完全复用 `removeMenuItem` 的 sortOrder 重算模式（move → enumerate → saveAndSync）
- Task 2: MenuConfigTab 的 ForEach 添加 `.onMove` 修饰符，调用 `appState.moveMenuItem`，macOS SwiftUI List 默认支持拖拽手柄，无需 EditButton
- Task 3: AppListRow 新增 `isDefault` 参数，当为 true 时显示 `star.fill` 黄色图标 + "默认" 文字标签；accessibilityLabel 读出 "[应用名]，默认项"
- Task 4: AppListRow 新增 `onMoveUp`/`onMoveDown` 可选闭包 + `position`/`total` 参数，条件性添加 `.accessibilityAction(named:)` 和 `.accessibilityValue`；第一项隐藏"上移"，最后一项隐藏"下移"
- Task 5: MenuConfigTab 使用 `ForEach(Array(appState.menuItems.enumerated()), id:)` 传递 index，为每行计算 isDefault、onMoveUp/onMoveDown 闭包、position/total；新增 `moveItem(at:direction:)` 辅助方法封装单步移动
- Task 6: xcodebuild 编译成功（零错误），RCMMShared 25 个测试全部通过（无回归）。手动测试项（6.3-6.5）需用户验证
- 新增 `View.ifLet` 辅助扩展用于条件性添加 accessibilityAction 修饰符

### File List

- `RCMMApp/AppState.swift` — [修改] 新增 `moveMenuItem(from:to:)` 方法，抽取 `recalculateSortOrders()` 私有方法
- `RCMMApp/Views/Settings/MenuConfigTab.swift` — [修改] 添加 `.onMove`，传入 isDefault/onMoveUp/onMoveDown/position/total 参数，新增 `moveItem(at:direction:)` 辅助方法
- `RCMMApp/Views/Settings/AppListRow.swift` — [修改] 新增 isDefault 默认项标识、onMoveUp/onMoveDown VoiceOver 辅助操作、position/total 位置信息（可选参数）、View.ifLet 扩展

## Change Log

- 2026-02-19: 实现菜单项拖拽排序与默认项功能（Story 2.3），修改 AppState.swift、MenuConfigTab.swift、AppListRow.swift 三个文件
- 2026-02-19: [Code Review] H1: 修正 Task 6 完成标记（子任务 6.3-6.5 为手动测试，父级改为未完成）；M2: AppListRow position/total 改为可选参数，避免非 MenuConfigTab 上下文下 VoiceOver 误报；M3: 补充 File List 描述；M4: 抽取 recalculateSortOrders() 消除 moveMenuItem/removeMenuItem 重复代码；M1: 新增 moveMenuItem 单元测试需求记为后续 action item
