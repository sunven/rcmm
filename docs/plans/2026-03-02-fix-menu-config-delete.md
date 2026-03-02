# Fix Menu Config Delete Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable users to delete menu configurations in the Settings view by adding a visible delete button to each row.

**Architecture:** Add a delete button (trash icon) directly in `AppListRow` component. The button will call a new `onDelete` callback that triggers `AppState.removeMenuItem()`. This is the most discoverable pattern for macOS apps.

**Tech Stack:** Swift 6, SwiftUI, macOS 15+

---

## Root Cause Analysis

The current implementation uses `.onDelete` modifier on `ForEach`:

```swift
ForEach(...) { ... }
    .onDelete { offsets in
        appState.removeMenuItem(at: offsets)
    }
```

**Problem:** On macOS, `.onDelete` only works when the list is in **edit mode** (via `EditButton`). There's no swipe-to-delete gesture like on iOS. Since no `EditButton` exists, users cannot delete items.

**Solution:** Add a visible delete button directly in each row.

---

## Task 1: Add Delete Callback to AppListRow

**Files:**
- Modify: `/Users/sunven/github/rcmm/RCMMApp/Views/Settings/AppListRow.swift:5-51`

**Step 1: Add onDelete callback parameter**

Add a new optional callback parameter for delete action:

```swift
struct AppListRow: View {
    let menuItem: MenuItemConfig
    var isDefault: Bool = false
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?  // NEW: Delete callback
    var position: Int?
    var total: Int?
    // ... rest unchanged
}
```

**Step 2: Add delete button to the row**

Modify the `body` to include a delete button. Add the button in the `HStack` after the status text:

```swift
var body: some View {
    HStack(spacing: 12) {
        Image(nsImage: NSWorkspace.shared.icon(forFile: menuItem.appPath))
            .resizable()
            .frame(width: 32, height: 32)
            .saturation(appExists ? 1 : 0)
            .opacity(appExists ? 1 : 0.4)
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

        // NEW: Delete button
        if let onDelete = onDelete {
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("删除此菜单项")
        }
    }
    // ... accessibility modifiers
}
```

**Step 3: Add accessibility action for delete**

Add accessibility action after the existing ones:

```swift
.ifLet(onMoveDown) { view, action in
    view.accessibilityAction(named: "下移", action)
}
.ifLet(onDelete) { view, action in
    view.accessibilityAction(named: "删除", action)
}
```

**Step 4: Build to verify**

Run: `xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED (warnings OK)

**Step 5: Commit**

```bash
git add RCMMApp/Views/Settings/AppListRow.swift
git commit -m "feat: add delete button to AppListRow"
```

---

## Task 2: Wire Delete Callback in MenuConfigTab

**Files:**
- Modify: `/Users/sunven/github/rcmm/RCMMApp/Views/Settings/MenuConfigTab.swift:32-41`

**Step 1: Pass onDelete callback to AppListRow**

Update the `AppListRow` call to include the delete action:

```swift
AppListRow(
    menuItem: item,
    isDefault: index == 0,
    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
    onMoveDown: index < appState.menuItems.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
    onDelete: { appState.removeMenuItem(at: IndexSet(integer: index)) },
    position: index + 1,
    total: appState.menuItems.count
)
```

**Step 2: Build to verify**

Run: `xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Manual test**

1. Open the app
2. Go to Settings > 菜单配置
3. Add an app if you haven't
4. Verify each row now shows a trash icon
5. Click the trash icon on a row
6. Verify the item is removed from the list

**Step 4: Commit**

```bash
git add RCMMApp/Views/Settings/MenuConfigTab.swift
git commit -m "feat: wire delete action to AppListRow in MenuConfigTab"
```

---

## Task 3: Remove Unused onDelete Modifier (Cleanup)

**Files:**
- Modify: `/Users/sunven/github/rcmm/RCMMApp/Views/Settings/MenuConfigTab.swift:46-48`

**Step 1: Remove the unused .onDelete modifier**

The `.onDelete` modifier is now redundant since we have a visible delete button. Remove it:

```swift
// REMOVE these lines:
.onDelete { offsets in
    appState.removeMenuItem(at: offsets)
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add RCMMApp/Views/Settings/MenuConfigTab.swift
git commit -m "refactor: remove unused .onDelete modifier from MenuConfigTab"
```

---

## Summary

| Task | Description | Files Changed |
|------|-------------|---------------|
| 1 | Add delete button to AppListRow | AppListRow.swift |
| 2 | Wire callback in MenuConfigTab | MenuConfigTab.swift |
| 3 | Remove unused .onDelete | MenuConfigTab.swift |

**Total estimated changes:** ~15 lines of code across 2 files.
