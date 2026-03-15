# 拷贝路径功能实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 新增「拷贝路径」开关，启用后在 Finder 右键菜单中显示拷贝路径选项。

**架构：** 在 App Group UserDefaults 中存储布尔标志，通过 SharedConfigService 读写。FinderSync 扩展在每次右键时读取该标志，若启用则在菜单末尾追加分隔线 + "拷贝路径"菜单项。点击后直接通过 NSPasteboard 复制路径，无需 AppleScript。

**技术栈：** Swift 6, SwiftUI, FinderSync, NSPasteboard, App Group UserDefaults

---

### 任务 1：添加 SharedKeys 常量

**文件：**
- 修改：`RCMMShared/Sources/Constants/SharedKeys.swift:3-8`

**步骤 1：添加 key 常量**

在 `SharedKeys` 枚举中添加 `copyPathEnabled`：

```swift
public enum SharedKeys {
    public static let menuItems = "rcmm.menu.items"
    public static let errorQueue = "rcmm.error.queue"
    public static let onboardingCompleted = "rcmm.settings.onboardingCompleted"
    public static let loginItemEnabled = "rcmm.settings.loginItemEnabled"
    public static let copyPathEnabled = "rcmm.copyPath.enabled"
}
```

**步骤 2：提交**

```bash
git add RCMMShared/Sources/Constants/SharedKeys.swift
git commit -m "feat: add copyPathEnabled key to SharedKeys"
```

---

### 任务 2：为 SharedConfigService 添加读写方法

**文件：**
- 修改：`RCMMShared/Sources/Services/SharedConfigService.swift:23-24`
- 测试：`RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift`

**步骤 1：编写失败测试**

在 `SharedConfigServiceTests.swift` 中添加以下测试：

```swift
@Test("copyPathEnabled 默认返回 false")
func copyPathEnabledDefaultFalse() {
    let loaded = service.loadCopyPathEnabled()
    #expect(loaded == false)
    cleanup()
}

@Test("保存 copyPathEnabled 后可正确读取")
func saveCopyPathEnabled() {
    service.saveCopyPathEnabled(true)
    #expect(service.loadCopyPathEnabled() == true)
    service.saveCopyPathEnabled(false)
    #expect(service.loadCopyPathEnabled() == false)
    cleanup()
}
```

**步骤 2：运行测试确认失败**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20`
预期：编译失败 — `saveCopyPathEnabled` 和 `loadCopyPathEnabled` 方法不存在

**步骤 3：编写最小实现**

在 `SharedConfigService` 的 `load()` 方法之后添加：

```swift
public func saveCopyPathEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: SharedKeys.copyPathEnabled)
}

public func loadCopyPathEnabled() -> Bool {
    defaults.bool(forKey: SharedKeys.copyPathEnabled)
}
```

**步骤 4：运行测试确认通过**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20`
预期：所有测试通过

**步骤 5：提交**

```bash
git add RCMMShared/Sources/Services/SharedConfigService.swift RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift
git commit -m "feat: add copyPathEnabled read/write to SharedConfigService"
```

---

### 任务 3：为 AppState 添加 copyPathEnabled 属性

**文件：**
- 修改：`RCMMApp/AppState.swift`

**步骤 1：添加属性和保存逻辑**

在 `autoRepairMessage`（第 14 行）之后添加属性：

```swift
var copyPathEnabled: Bool = false {
    didSet {
        configService.saveCopyPathEnabled(copyPathEnabled)
        DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
    }
}
```

在 `loadMenuItems()`（第 43 行）之后，加载初始值：

```swift
copyPathEnabled = configService.loadCopyPathEnabled()
```

**步骤 2：提交**

```bash
git add RCMMApp/AppState.swift
git commit -m "feat: add copyPathEnabled property to AppState"
```

---

### 任务 4：在 MenuConfigTab 添加 Toggle 开关

**文件：**
- 修改：`RCMMApp/Views/Settings/MenuConfigTab.swift`

**步骤 1：在应用列表上方添加 Toggle**

在 `VStack(spacing: 0)` 内部，`if appState.menuItems.isEmpty` 之前（第 12 行）插入：

```swift
// 拷贝路径开关
HStack {
    Toggle("拷贝路径", isOn: Binding(
        get: { appState.copyPathEnabled },
        set: { appState.copyPathEnabled = $0 }
    ))
    .toggleStyle(.switch)
    Text("在右键菜单中显示「拷贝路径」选项")
        .font(.caption)
        .foregroundStyle(.secondary)
    Spacer()
}
.padding(.horizontal)
.padding(.vertical, 8)

Divider()
```

**步骤 2：提交**

```bash
git add RCMMApp/Views/Settings/MenuConfigTab.swift
git commit -m "feat: add copy-path toggle to MenuConfigTab"
```

---

### 任务 5：在 FinderSync 中添加拷贝路径菜单项

**文件：**
- 修改：`RCMMFinderExtension/FinderSync.swift`

**步骤 1：修改 `menu(for:)` 方法**

将现有的 `guard` 块（第 36-39 行）改为同时考虑 copyPath 开关：

```swift
let copyPathEnabled = configService.loadCopyPathEnabled()

guard !items.isEmpty || copyPathEnabled else {
    logger.warning("无菜单配置项")
    return menu
}

for item in items {
    // ... 现有循环代码不变
}

if copyPathEnabled {
    if !items.isEmpty {
        menu.addItem(NSMenuItem.separator())
    }
    let copyPathItem = NSMenuItem(
        title: "拷贝路径",
        action: #selector(copyPath(_:)),
        keyEquivalent: ""
    )
    copyPathItem.target = self
    menu.addItem(copyPathItem)
}
```

**步骤 2：添加 `copyPath(_:)` action 处理方法**

在 `openWithApp(_:)` 之后添加：

```swift
@objc func copyPath(_ sender: NSMenuItem) {
    guard let targetPath = resolveTargetPath() else {
        logger.error("拷贝路径: 无法解析目标路径")
        return
    }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(targetPath, forType: .string)

    logger.info("已拷贝路径: \(targetPath)")
}
```

**步骤 3：提交**

```bash
git add RCMMFinderExtension/FinderSync.swift
git commit -m "feat: add copy-path menu item to FinderSync extension"
```

---

### 任务 6：构建验证

**步骤 1：构建两个 Target**

```bash
xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | tail -5
xcodebuild -project rcmm.xcodeproj -scheme RCMMFinderExtension -configuration Debug build 2>&1 | tail -5
```

预期：两个 Target 均 BUILD SUCCEEDED

**步骤 2：运行测试**

```bash
xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test 2>&1 | tail -20
```

预期：所有测试通过
