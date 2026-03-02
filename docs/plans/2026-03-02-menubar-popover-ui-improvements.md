# MenuBar Popover UI Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve the menu bar popover UI by reducing width and adding hover visual effects for menu items.

**Architecture:** Create a custom `MenuItemButtonStyle` that provides hover highlighting similar to native macOS menu items. Apply this style to all menu action buttons and reduce the popover width from 300px to 220px for a more compact appearance.

**Tech Stack:** SwiftUI, Swift 6

---

## Task 1: Create MenuItemButtonStyle

**Files:**
- Create: `RCMMApp/Views/MenuBar/MenuItemButtonStyle.swift`

**Step 1: Create the custom button style with hover effect**

```swift
import SwiftUI

/// 菜单项按钮样式，提供类似原生 macOS 菜单的悬停高亮效果
struct MenuItemButtonStyle: ButtonStyle {
    @Environment(\.isHovered) private var isHovered

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .contentShape(Rectangle())
    }
}

/// 环境键用于传递悬停状态
private struct IsHoveredKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isHovered: Bool {
        get { self[IsHoveredKey.self] }
        set { self[IsHoveredKey.self] = newValue }
    }
}

/// 悬停状态修饰符
extension View {
    func onHoverState(perform action: @escaping (Bool) -> Void) -> some View {
        self.onHover(perform: action)
    }
}
```

**Step 2: Verify the file compiles**

Run: `xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | head -50`
Expected: BUILD SUCCEEDED (or only unrelated warnings)

**Step 3: Commit**

```bash
git add RCMMApp/Views/MenuBar/MenuItemButtonStyle.swift
git commit -m "feat: add MenuItemButtonStyle with hover effect"
```

---

## Task 2: Update NormalPopoverView to use the new button style

**Files:**
- Modify: `RCMMApp/Views/MenuBar/NormalPopoverView.swift`

**Step 1: Add hover state and apply MenuItemButtonStyle**

Replace the entire file content with:

```swift
import RCMMShared
import SettingsAccess
import SwiftUI

/// 正常状态弹出窗口，展示扩展状态 + 错误信息 + 打开设置 + 退出按钮
struct NormalPopoverView: View {
    @Environment(AppState.self) private var appState
    @State private var settingsHovered = false
    @State private var quitHovered = false

    var body: some View {
        VStack(spacing: 12) {
            HealthStatusPanel(status: appState.extensionStatus)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            if !appState.errorRecords.isEmpty || appState.autoRepairMessage != nil {
                Divider()
                ErrorBannerView()
            }

            Divider()

            SettingsLink {
                Text("打开设置…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } preAction: {
                ActivationPolicyManager.activateAsRegularApp()
            } postAction: {
            }
            .buttonStyle(MenuItemButtonStyle())
            .environment(\.isHovered, settingsHovered)
            .onHover { settingsHovered = $0 }
            .accessibilityLabel("打开设置")
            .keyboardShortcut(",", modifiers: .command)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("退出")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuItemButtonStyle())
            .environment(\.isHovered, quitHovered)
            .onHover { quitHovered = $0 }
            .accessibilityLabel("退出 rcmm")
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(12)
    }
}

#Preview {
    NormalPopoverView()
        .environment(AppState(forPreview: true))
        .frame(width: 220)
}

#Preview("有错误") {
    let state = AppState(forPreview: true)
    state.errorRecords = [
        ErrorRecord(source: "ScriptExecutor", message: "脚本执行失败: exit code 1", context: "VS Code"),
    ]
    return NormalPopoverView()
        .environment(state)
        .frame(width: 220)
}
```

**Step 2: Verify the build**

Run: `xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add RCMMApp/Views/MenuBar/NormalPopoverView.swift
git commit -m "feat: apply MenuItemButtonStyle to menu items with hover effect"
```

---

## Task 3: Reduce PopoverContainerView width

**Files:**
- Modify: `RCMMApp/Views/MenuBar/PopoverContainerView.swift`

**Step 1: Change width from 300 to 220**

In `PopoverContainerView.swift`, change line 19:

From:
```swift
.frame(width: 300)
```

To:
```swift
.frame(width: 220)
```

**Step 2: Verify the build**

Run: `xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add RCMMApp/Views/MenuBar/PopoverContainerView.swift
git commit -m "style: reduce popover width from 300px to 220px"
```

---

## Task 4: Update ErrorBannerView preview width

**Files:**
- Modify: `RCMMApp/Views/MenuBar/ErrorBannerView.swift`

**Step 1: Update preview widths to match new popover width**

In the `#Preview` sections at the bottom of the file, change all instances of `width: 280` to `width: 196` (220 - 24 for padding):

Lines 123, 135, 143: Change `width: 280` to `width: 196`

**Step 2: Verify the build**

Run: `xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add RCMMApp/Views/MenuBar/ErrorBannerView.swift
git commit -m "style: update ErrorBannerView preview widths to match new popover width"
```

---

## Task 5: Manual Testing

**Step 1: Build and run the app**

Run: `open rcmm.xcodeproj`
Then: Select RCMMApp scheme and run (Cmd+R)

**Step 2: Verify the UI changes**

1. Click the menu bar icon - popover should appear with 220px width
2. Hover over "打开设置…" - should see light blue/accent color background highlight
3. Hover over "退出" - should see light blue/accent color background highlight
4. Move mouse away - highlight should disappear

**Step 3: Final commit if needed**

If any adjustments are needed during testing, commit them:

```bash
git add -A
git commit -m "fix: adjust UI based on manual testing"
```
