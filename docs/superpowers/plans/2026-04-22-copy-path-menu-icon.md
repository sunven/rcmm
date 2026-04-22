# 拷贝路径右键菜单图标 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Finder 右键菜单里的“拷贝路径”项显示与设置页一致的系统图标，同时保持现有复制路径行为不回退。

**Architecture:** 共享层继续负责内置菜单项的文案和符号名元数据，避免 Finder 扩展里再硬编码一份标题或图标字符串。由于 `RCMMShared` 不能依赖 AppKit，真正的 `NSImage` 创建仍放在 `RCMMFinderExtension` 内，由扩展在构建 `NSMenuItem` 时把共享层提供的 SF Symbol 名称转成菜单图标。

**Tech Stack:** Swift 6, Swift Testing, AppKit, FinderSync, `swift test`, `xcodebuild`, ripgrep

---

## File Map

- Modify: `RCMMShared/Sources/Models/MenuEntry.swift` — 为菜单条目补一个只读的系统图标名访问器，让 Finder 扩展可以在不关心内部枚举细节的情况下读取 built-in 图标元数据。
- Modify: `RCMMShared/Tests/RCMMSharedTests/MenuEntryTests.swift` — 为新的共享层图标元数据访问器增加自动化测试，锁定 built-in 与 custom 两种分支行为。
- Modify: `RCMMFinderExtension/FinderSync.swift` — 把 built-in 菜单项创建抽成 helper，并在“拷贝路径”项上挂接 `NSImage(systemSymbolName:)` 图标。

## Scope Guards

- 不新增 PNG、PDF 或 asset catalog 资源，直接复用现有 `doc.on.clipboard` SF Symbol。
- 不改设置页 UI，`BuiltInListRow` 现有 `item.iconName` 已经能正确显示图标。
- 不改 `copyPath(_:)` 的剪贴板逻辑，不改配置持久化结构，也不新增菜单排序功能。

### Task 1: 为菜单条目补齐可测试的图标元数据接口

**Files:**
- Modify: `RCMMShared/Sources/Models/MenuEntry.swift`
- Test: `RCMMShared/Tests/RCMMSharedTests/MenuEntryTests.swift`

- [ ] **Step 1: 先写共享层失败测试，锁定 built-in 和 custom 的图标元数据行为**

在 `RCMMShared/Tests/RCMMSharedTests/MenuEntryTests.swift` 的 `builtInDisplayName()` 后面插入下面两个测试：

```swift
    @Test("builtIn systemSymbolName 使用共享图标元数据")
    func builtInSystemSymbolName() {
        let entry = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))
        #expect(entry.systemSymbolName == "doc.on.clipboard")
    }

    @Test("custom entry 没有 systemSymbolName")
    func customSystemSymbolName() {
        let entry = MenuEntry.custom(MenuItemConfig(appName: "Terminal", appPath: "/t"))
        #expect(entry.systemSymbolName == nil)
    }
```

- [ ] **Step 2: 运行共享层测试，确认它先因为缺少新接口而失败**

Run:

```bash
cd RCMMShared && swift test --filter MenuEntryTests
```

Expected: 编译失败，并出现类似 `value of type 'MenuEntry' has no member 'systemSymbolName'` 的报错。

- [ ] **Step 3: 在共享层补上新的图标元数据访问器**

把 `RCMMShared/Sources/Models/MenuEntry.swift` 中 `displayName` 属性后面改成下面这样：

```swift
    public var displayName: String {
        switch self {
        case .builtIn(let item): return item.displayName
        case .custom(let config): return config.appName
        }
    }

    public var systemSymbolName: String? {
        switch self {
        case .builtIn(let item): return item.iconName
        case .custom: return nil
        }
    }

    public var isBuiltIn: Bool {
        if case .builtIn = self { return true }
        return false
    }
```

- [ ] **Step 4: 重新运行共享层测试，确认新契约通过**

Run:

```bash
cd RCMMShared && swift test --filter MenuEntryTests
```

Expected: `MenuEntryTests` 全部通过，新加的两个测试显示 `passed`。

- [ ] **Step 5: 提交共享层契约改动**

```bash
git add RCMMShared/Sources/Models/MenuEntry.swift RCMMShared/Tests/RCMMSharedTests/MenuEntryTests.swift
git commit -m "feat(shared): expose menu entry symbol metadata"
```

### Task 2: 在 Finder 右键菜单里给“拷贝路径”挂上图标

**Files:**
- Modify: `RCMMFinderExtension/FinderSync.swift`

- [ ] **Step 1: 把 built-in 菜单项创建抽成 helper，并在“拷贝路径”项上设置系统图标**

把 `RCMMFinderExtension/FinderSync.swift` 里的菜单构建部分改成下面这样：

```swift
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let entries = configService.loadEntries()
            .filter { $0.isEnabled }

        guard !entries.isEmpty else {
            logger.warning("无菜单配置项")
            return menu
        }

        for entry in entries {
            switch entry {
            case .builtIn:
                menu.addItem(makeBuiltInMenuItem(from: entry))
            case .custom(let config):
                menu.addItem(makeCustomMenuItem(config))
            }
        }

        return menu
    }

    private func makeBuiltInMenuItem(from entry: MenuEntry) -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: entry.displayName,
            action: #selector(copyPath(_:)),
            keyEquivalent: ""
        )
        menuItem.target = self

        if let symbolName = entry.systemSymbolName,
           let image = makeMenuSymbolImage(
               named: symbolName,
               accessibilityDescription: entry.displayName
           ) {
            menuItem.image = image
        }

        return menuItem
    }

    private func makeCustomMenuItem(_ config: MenuItemConfig) -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: "用 \(config.appName) 打开",
            action: #selector(openWithApp(_:)),
            keyEquivalent: ""
        )
        menuItem.representedObject = config.id.uuidString
        menuItem.target = self

        let icon = NSWorkspace.shared.icon(forFile: config.appPath)
        icon.size = NSSize(width: 16, height: 16)
        menuItem.image = icon

        return menuItem
    }

    private func makeMenuSymbolImage(
        named symbolName: String,
        accessibilityDescription: String
    ) -> NSImage? {
        guard let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityDescription
        ) else {
            logger.error("无法创建系统图标: \(symbolName)")
            return nil
        }

        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = true
        return image
    }
```

- [ ] **Step 2: 用文本检索确认 Finder 扩展已经接上共享图标元数据**

Run:

```bash
rg -n "entry\\.systemSymbolName|makeBuiltInMenuItem|makeMenuSymbolImage|NSImage\\(systemSymbolName" RCMMFinderExtension/FinderSync.swift
```

Expected: 能看到 `makeBuiltInMenuItem`、`makeMenuSymbolImage` 和 `entry.systemSymbolName` 的匹配结果。

- [ ] **Step 3: 构建 Finder 扩展，确认改动可编译**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme RCMMFinderExtension -configuration Debug build | rg "BUILD SUCCEEDED|error:"
```

Expected: 输出 `BUILD SUCCEEDED`，且没有 `error:`。

- [ ] **Step 4: 手动验证 Finder 菜单图标和复制行为**

按下面顺序检查：

1. 在 Xcode 里选择 `RCMMFinderExtension` scheme，并把 Host Application 设为 Finder。
2. 运行扩展后，在 Finder 里右键一个文件或文件夹，前提是菜单配置中已启用“拷贝路径”。
3. 确认菜单里的“拷贝路径”左侧出现剪贴板图标，尺寸与自定义应用图标视觉上保持一致。
4. 点击“拷贝路径”，再到 TextEdit 或 Terminal 粘贴。
5. 确认粘贴出来的仍是目标文件或目录的完整路径，没有因为挂图标导致 action 丢失。

Expected: “拷贝路径”显示图标且仍能正常写入剪贴板。

- [ ] **Step 5: 提交 Finder 扩展图标接线**

```bash
git add RCMMFinderExtension/FinderSync.swift
git commit -m "feat(finder): add icon for copy-path menu item"
```

## Self-Review

- Spec coverage: Task 1 锁定共享层图标元数据访问接口，Task 2 把该元数据接进 Finder 菜单并手动验证显示与复制行为，没有遗漏“拷贝路径也要有图标”这一需求。
- Placeholder scan: 全文没有 `TODO`、`TBD`、`implement later`、`类似 Task N` 这类占位语句。
- Type consistency: 计划中统一使用 `systemSymbolName` 作为共享层访问器命名，Finder 扩展也只消费这个名字，没有在后续步骤切换成别的属性名。
