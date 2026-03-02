# 菜单项启用/停用开关实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 为每个菜单配置项添加启用/停用开关，用户可以临时禁用菜单项而无需删除。

**架构：** 在 `MenuItemConfig` 模型中添加 `isEnabled: Bool` 字段，默认值为 `true`。在 `FinderSync.menu(for:)` 构建右键菜单时过滤掉已停用的项。在 `AppListRow` UI 中添加 Toggle 开关控件。

**技术栈：** Swift 6, SwiftUI, Codable

---

### 任务 1：为 MenuItemConfig 模型添加 isEnabled 字段

**文件：**
- 修改: `RCMMShared/Sources/Models/MenuItemConfig.swift:3-26`

**步骤 1：添加 isEnabled 属性**

```swift
import Foundation

public struct MenuItemConfig: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var appName: String
    public var bundleId: String?
    public var appPath: String
    public var customCommand: String?
    public var sortOrder: Int
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleId: String? = nil,
        appPath: String,
        customCommand: String? = nil,
        sortOrder: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.appPath = appPath
        self.customCommand = customCommand
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
    }
}
```

**步骤 2：运行测试验证当前行为**

运行: `xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | grep -E "(Test Case|passed|failed|error:)"`
预期: 测试可能因 JSON 中缺少 isEnabled 字段而失败

**步骤 3：提交**

```bash
git add RCMMShared/Sources/Models/MenuItemConfig.swift
git commit -m "feat: 为 MenuItemConfig 添加 isEnabled 字段"
```

---

### 任务 2：更新 isEnabled 字段的测试

**文件：**
- 修改: `RCMMShared/Tests/RCMMSharedTests/MenuItemConfigTests.swift`

**步骤 1：更新 roundTrip 测试以包含 isEnabled**

```swift
@Test("Round-trip 编解码保持值一致")
func roundTrip() throws {
    let item = MenuItemConfig(
        appName: "Terminal",
        appPath: "/Applications/Utilities/Terminal.app",
        sortOrder: 0,
        isEnabled: true
    )
    let data = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(MenuItemConfig.self, from: data)
    #expect(decoded == item)
    #expect(decoded.isEnabled == true)
}
```

**步骤 2：添加停用项测试**

```swift
@Test("禁用项编解码正确")
func disabledItem() throws {
    let item = MenuItemConfig(
        appName: "Disabled App",
        appPath: "/Applications/Disabled.app",
        sortOrder: 5,
        isEnabled: false
    )
    let data = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(MenuItemConfig.self, from: data)
    #expect(decoded.isEnabled == false)
}
```

**步骤 3：添加向后兼容性测试（缺失 isEnabled 默认为 true）**

```swift
@Test("解码时缺失 isEnabled 默认为 true")
func missingIsEnabledField() throws {
    let json = """
    {"id":"550E8400-E29B-41D4-A716-446655440000","appName":"Test","appPath":"/test","sortOrder":0}
    """
    let item = try JSONDecoder().decode(MenuItemConfig.self, from: Data(json.utf8))
    #expect(item.isEnabled == true)
}
```

**步骤 4：实现 CodingKeys 以支持向后兼容**

在 MenuItemConfig 中添加:

```swift
enum CodingKeys: String, CodingKey {
    case id, appName, bundleId, appPath, customCommand, sortOrder, isEnabled
}

public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    appName = try container.decode(String.self, forKey: .appName)
    bundleId = try container.decodeIfPresent(String.self, forKey: .bundleId)
    appPath = try container.decode(String.self, forKey: .appPath)
    customCommand = try container.decodeIfPresent(String.self, forKey: .customCommand)
    sortOrder = try container.decode(Int.self, forKey: .sortOrder)
    isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
}
```

**步骤 5：运行测试验证**

运行: `xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | grep -E "(Test Case|passed|failed|error:)"`
预期: 所有测试通过

**步骤 6：提交**

```bash
git add RCMMShared/Tests/RCMMSharedTests/MenuItemConfigTests.swift RCMMShared/Sources/Models/MenuItemConfig.swift
git commit -m "test: 添加 isEnabled 字段测试并支持向后兼容"
```

---

### 任务 3：在 Finder 扩展中过滤已停用项

**文件：**
- 修改: `RCMMFinderExtension/FinderSync.swift:30-57`

**步骤 1：在 menu(for:) 中添加启用项过滤**

```swift
override func menu(for menuKind: FIMenuKind) -> NSMenu {
    let menu = NSMenu(title: "")
    let items = configService.load()
        .filter { $0.isEnabled }
        .sorted(by: { $0.sortOrder < $1.sortOrder })

    guard !items.isEmpty else {
        logger.warning("无菜单配置项")
        return menu
    }

    for item in items {
        // ... 现有代码
    }

    return menu
}
```

**步骤 2：提交**

```bash
git add RCMMFinderExtension/FinderSync.swift
git commit -m "feat: 在 Finder 右键菜单中过滤已停用项"
```

---

### 任务 4：为 AppListRow 添加 Toggle UI

**文件：**
- 修改: `RCMMApp/Views/Settings/AppListRow.swift`

**步骤 1：添加 onToggle 回调和 Toggle 控件**

```swift
struct AppListRow: View {
    let menuItem: MenuItemConfig
    var isDefault: Bool = false
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggle: ((Bool) -> Void)?  // 新增
    var position: Int?
    var total: Int?

    @State private var isHovered = false

    // ... 现有计算属性

    var body: some View {
        HStack(spacing: 12) {
            // 应用图标，停用时灰度显示
            Image(nsImage: NSWorkspace.shared.icon(forFile: menuItem.appPath))
                .resizable()
                .frame(width: 32, height: 32)
                .saturation(appExists ? (menuItem.isEnabled ? 1 : 0.3) : 0)
                .opacity(appExists ? (menuItem.isEnabled ? 1 : 0.5) : 0.4)

            Text(menuItem.appName)
                .font(.body)
                .foregroundStyle(menuItem.isEnabled ? .primary : .secondary)

            if isDefault {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                Text("默认")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 状态文字
            if !menuItem.isEnabled {
                Text("已停用")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text(appExists ? "就绪" : "未找到")
                    .font(.caption)
                    .foregroundStyle(appExists ? Color.secondary : Color.red)
            }

            // Toggle 开关
            if let onToggle = onToggle {
                Toggle("", isOn: Binding(
                    get: { menuItem.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .help(menuItem.isEnabled ? "停用此菜单项" : "启用此菜单项")
            }

            // 删除按钮
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("删除此菜单项")
            }
        }
        // ... 现有修饰符
    }
}
```

**步骤 2：更新 Preview**

```swift
#Preview("启用状态") {
    AppListRow(
        menuItem: MenuItemConfig(
            appName: "Terminal",
            bundleId: "com.apple.Terminal",
            appPath: "/System/Applications/Utilities/Terminal.app",
            sortOrder: 0,
            isEnabled: true
        ),
        isDefault: true,
        onToggle: { _ in },
        position: 1,
        total: 3
    )
    .padding()
}

#Preview("禁用状态") {
    AppListRow(
        menuItem: MenuItemConfig(
            appName: "iTerm",
            appPath: "/Applications/iTerm.app",
            sortOrder: 1,
            isEnabled: false
        ),
        onToggle: { _ in },
        position: 2,
        total: 3
    )
    .padding()
}
```

**步骤 3：提交**

```bash
git add RCMMApp/Views/Settings/AppListRow.swift
git commit -m "feat: 为 AppListRow 添加启用/停用开关"
```

---

### 任务 5：将 Toggle 连接到 AppState

**文件：**
- 修改: `RCMMApp/AppState.swift`
- 修改: `RCMMApp/Views/Settings/MenuConfigTab.swift`

**步骤 1：在 AppState 中添加 toggleMenuItem 方法**

在 `updateCustomCommand` 方法后添加:

```swift
/// 切换菜单项的启用/禁用状态
func toggleMenuItem(for itemId: UUID, isEnabled: Bool) {
    guard let index = menuItems.firstIndex(where: { $0.id == itemId }) else { return }
    menuItems[index].isEnabled = isEnabled
    saveAndSync()
}
```

**步骤 2：在 MenuConfigTab 中传递 onToggle 给 AppListRow**

```swift
AppListRow(
    menuItem: item,
    isDefault: index == 0,
    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
    onMoveDown: index < appState.menuItems.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
    onDelete: { appState.removeMenuItem(at: IndexSet(integer: index)) },
    onToggle: { isEnabled in
        appState.toggleMenuItem(for: item.id, isEnabled: isEnabled)
    },
    position: index + 1,
    total: appState.menuItems.count
)
```

**步骤 3：提交**

```bash
git add RCMMApp/AppState.swift RCMMApp/Views/Settings/MenuConfigTab.swift
git commit -m "feat: 将 Toggle 开关连接到 AppState"
```

---

### 任务 6：最终验证

**步骤 1：构建所有 target**

运行: `xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | tail -20`
预期: BUILD SUCCEEDED

运行: `xcodebuild -project rcmm.xcodeproj -scheme RCMMFinderExtension -configuration Debug build 2>&1 | tail -20`
预期: BUILD SUCCEEDED

**步骤 2：运行测试**

运行: `xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | grep -E "(Test Case|passed|failed|error:)"`
预期: 所有测试通过

**步骤 3：手动测试清单**

- [ ] 打开设置窗口
- [ ] 确认每个菜单项都有 Toggle 开关
- [ ] 关闭某个项 - 应显示"已停用"并变灰
- [ ] 打开 Finder 右键菜单 - 已停用项不应出现
- [ ] 重新启用该项 - 应再次出现在右键菜单中
- [ ] 验证没有 isEnabled 字段的旧配置默认为启用状态

---

## 任务摘要

| 任务 | 描述 | 修改文件 |
|------|------|----------|
| 1 | 为模型添加 isEnabled 字段 | MenuItemConfig.swift |
| 2 | 更新测试 + 向后兼容 | MenuItemConfigTests.swift, MenuItemConfig.swift |
| 3 | 在 Finder 扩展中过滤 | FinderSync.swift |
| 4 | 添加 Toggle UI | AppListRow.swift |
| 5 | 连接到 AppState | AppState.swift, MenuConfigTab.swift |
| 6 | 验证 | - |
