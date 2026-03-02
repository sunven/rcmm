# 悬停效果与文件打开优化实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 为菜单配置行添加悬停效果，并修改文件处理逻辑，使选中文件时直接打开文件而非其父目录。

**架构：**
1. 悬停效果：在 `AppListRow.swift` 中添加 `@State` 悬停状态追踪，悬停时显示淡色背景。
2. 文件打开：修改 `FinderSync.resolveDirectoryPath()` 为返回实际文件路径，而不是父目录。现有 AppleScript 基础设施已支持此功能，因为 `{path}` 在运行时被替换。

**技术栈：** Swift 6, SwiftUI, FinderSync API

---

## 任务 1：为 AppListRow 添加悬停效果

**文件：**
- 修改：`RCMMApp/Views/Settings/AppListRow.swift`

**步骤 1：添加悬停状态追踪**

添加 `@State` 属性来追踪悬停状态，并为 HStack 添加悬停检测。

```swift
import AppKit
import RCMMShared
import SwiftUI

struct AppListRow: View {
    let menuItem: MenuItemConfig
    var isDefault: Bool = false
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var position: Int?
    var total: Int?

    @State private var isHovered = false

    private var appExists: Bool {
        FileManager.default.fileExists(atPath: menuItem.appPath)
    }

    var body: some View {
        HStack(spacing: 12) {
            // ... 现有内容保持不变 ...
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        // ... 其余现有修饰符 ...
    }
    // ... 文件其余部分保持不变 ...
}
```

**步骤 2：验证构建成功**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"`

预期：BUILD SUCCEEDED，无错误

**步骤 3：提交**

```bash
git add RCMMApp/Views/Settings/AppListRow.swift
git commit -m "feat: add hover effect to menu config rows"
```

---

## 任务 2：直接打开文件而非父目录

**文件：**
- 修改：`RCMMFinderExtension/FinderSync.swift`

**步骤 1：更新 resolveDirectoryPath 直接返回文件路径**

将函数重命名为 `resolveTargetPath()` 以更清晰表达意图，并移除对文件的父目录回退逻辑。

```swift
/// 解析右键点击的目标路径（文件或目录）
private func resolveTargetPath() -> String? {
    let controller = FIFinderSyncController.default()

    // 优先使用 selectedItemURLs（右键点击具体项目时）
    if let selectedItems = controller.selectedItemURLs(), !selectedItems.isEmpty {
        return selectedItems[0].path
    }

    // 回退：使用 targetedURL（右键空白背景时）
    return controller.targetedURL()?.path
}
```

**步骤 2：更新 openWithApp 中的调用**

将函数调用从 `resolveDirectoryPath()` 改为 `resolveTargetPath()`。

```swift
@objc func openWithApp(_ sender: NSMenuItem) {
    // ... 现有代码直到第 76 行 ...

    // 解析目标路径
    guard let targetPath = resolveTargetPath() else {
        logger.error("无法解析目标路径")
        return
    }

    logger.info("执行: \(item.appName) → \(targetPath)")

    scriptExecutor.execute(
        scriptId: item.id.uuidString,
        targetPath: targetPath,
        menuItemName: item.appName
    )
}
```

**步骤 3：更新 ScriptExecutor 参数名称以提高可读性**

在 `RCMMFinderExtension/ScriptExecutor.swift` 中，将 `directoryPath` 重命名为 `targetPath`。

```swift
/// 执行指定脚本，传入目标路径（文件或目录）
func execute(
    scriptId: String,
    targetPath: String,
    menuItemName: String,
    completion: (@Sendable (Error?) -> Void)? = nil
) {
    // ... 现有代码 ...

    logger.info("脚本执行成功: \(scriptId) → \(targetPath)")

    // ... 其余不变 ...
}
```

**步骤 4：验证构建成功**

运行：`xcodebuild -project rcmm.xcodeproj -scheme RCMMFinderExtension -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"`

预期：BUILD SUCCEEDED，无错误

**步骤 5：提交**

```bash
git add RCMMFinderExtension/FinderSync.swift RCMMFinderExtension/ScriptExecutor.swift
git commit -m "feat: open selected file directly instead of parent directory"
```

---

## 验证

完成两个任务后：

1. **悬停效果：** 打开设置 → 菜单配置标签页，将鼠标悬停在菜单项上，应看到淡色背景高亮
2. **文件打开：** 在 Finder 中选择一个文件（非文件夹），右键 → "用 Cursor 打开" 应该在该应用中打开该文件，而不是其父目录

## 注意事项

- AppleScript 命令中的 `{path}` 占位符已同时支持文件和目录
- `open -a "App" {path}` 等命令对文件和目录都能正确工作
- 带有 `--directory` 或 `--cwd` 参数的终端模拟器可能需要特殊处理（如果用户想在终端中打开文件，这是未来的考虑事项）
