# 菜单栏 UI 优化实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 优化状态栏菜单的间距，并在 Finder 扩展未启用时提供退出按钮

**Architecture:** 修改 SwiftUI 视图的 VStack spacing 和按钮 padding 减小间距；在 RecoveryGuidePanel 添加退出按钮

**Tech Stack:** Swift 6, SwiftUI, macOS 15+

---

## 问题分析

### 问题 1：菜单项间距太大

**当前实现：**
- `NormalPopoverView` 使用 `VStack(spacing: 12)` — 12pt 间距
- `MenuItemButtonStyle` 使用 `.padding(.vertical, 6)` — 上下各 6pt
- `Divider()` 元素之间也有 spacing

**解决方案：**
- 将 `VStack(spacing: 12)` 改为 `VStack(spacing: 8)`
- 将 `.padding(.vertical, 6)` 改为 `.padding(.vertical, 4)`
- 整体 `.padding(12)` 改为 `.padding(10)`

### 问题 2：RecoveryGuidePanel 缺少退出按钮

**当前实现：**
- 只有"修复"和"稍后"按钮
- 用户无法直接退出应用

**解决方案：**
- 在 `recoveryGuideContent` 中添加"退出"按钮
- 按钮样式与"稍后"按钮一致（`.bordered`）

---

## Task 1: 减小菜单按钮内边距

**Files:**
- Modify: `RCMMApp/Views/MenuBar/MenuItemButtonStyle.swift:9`

**Step 1: 修改 MenuItemButtonStyle 的垂直内边距**

将 `.padding(.vertical, 6)` 改为 `.padding(.vertical, 4)`：

```swift
func makeBody(configuration: Configuration) -> some View {
    configuration.label
        .padding(.vertical, 4)  // 从 6 改为 4
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
}
```

**Step 2: 验证构建**

Run: `xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | grep -E "(error:|warning:|Build succeeded|BUILD SUCCEEDED|BUILD FAILED)" | head -20`

Expected: BUILD SUCCEEDED

---

## Task 2: 减小 NormalPopoverView 的间距

**Files:**
- Modify: `RCMMApp/Views/MenuBar/NormalPopoverView.swift:12,49`

**Step 1: 修改 VStack spacing**

将 `VStack(spacing: 12)` 改为 `VStack(spacing: 8)`：

```swift
var body: some View {
    VStack(spacing: 8) {  // 从 12 改为 8
        // ... 内容不变
    }
    .padding(10)  // 从 12 改为 10
}
```

**Step 2: 验证构建**

Run: `xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | grep -E "(error:|warning:|Build succeeded|BUILD SUCCEEDED|BUILD FAILED)" | head -20`

Expected: BUILD SUCCEEDED

---

## Task 3: 减小 RecoveryGuidePanel 的间距

**Files:**
- Modify: `RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift:14,23,30`

**Step 1: 修改 VStack spacing 和 padding**

```swift
var body: some View {
    VStack(spacing: 8) {  // 从 12 改为 8
        if isRecovered {
            recoverySuccessContent
                .transition(.opacity)
        } else {
            recoveryGuideContent
                .transition(.opacity)
        }
    }
    .padding(10)  // 从 12 改为 10
    .animation(.easeInOut(duration: 0.3), value: isRecovered)
    .onAppear { startPolling() }
    .onDisappear { stopPolling() }
}

private var recoveryGuideContent: some View {
    VStack(spacing: 8) {  // 从 12 改为 8
        // ... 其他内容不变
    }
    // ...
}
```

**Step 2: 验证构建**

Run: `xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | grep -E "(error:|warning:|Build succeeded|BUILD SUCCEEDED|BUILD FAILED)" | head -20`

Expected: BUILD SUCCEEDED

---

## Task 4: 为 RecoveryGuidePanel 添加退出按钮

**Files:**
- Modify: `RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift:51-58`

**Step 1: 在"稍后"按钮后添加"退出"按钮**

在 `recoveryGuideContent` 中，在"稍后"按钮后添加：

```swift
Button {
    NSApp.keyWindow?.close()
} label: {
    Text("稍后")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.bordered)
.accessibilityLabel("稍后修复")

Button {
    NSApplication.shared.terminate(nil)
} label: {
    Text("退出")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.bordered)
.accessibilityLabel("退出 rcmm")
```

**Step 2: 验证构建**

Run: `xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build 2>&1 | grep -E "(error:|warning:|Build succeeded|BUILD SUCCEEDED|BUILD FAILED)" | head -20`

Expected: BUILD SUCCEEDED

---

## Task 5: 提交更改

**Step 1: 查看更改**

Run: `git diff --stat`

**Step 2: 提交**

```bash
git add RCMMApp/Views/MenuBar/MenuItemButtonStyle.swift \
        RCMMApp/Views/MenuBar/NormalPopoverView.swift \
        RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift
git commit -m "$(cat <<'EOF'
fix: 优化菜单栏 UI 间距并添加退出按钮

- 减小菜单项之间的间距 (12pt → 8pt)
- 减小按钮内边距 (6pt → 4pt)
- 减小整体内边距 (12pt → 10pt)
- 在 Finder 扩展未启用提示中添加退出按钮
EOF
)"
```

---

## 测试计划

1. **菜单间距测试**
   - [ ] 点击状态栏图标，检查菜单项间距是否合理
   - [ ] 检查按钮悬停效果是否正常
   - [ ] 检查整体视觉效果是否紧凑

2. **退出按钮测试**
   - [ ] 禁用 Finder 扩展后打开状态栏菜单
   - [ ] 确认显示"修复"、"稍后"、"退出"三个按钮
   - [ ] 点击"退出"按钮，确认应用正常退出

3. **回归测试**
   - [ ] 正常状态下菜单显示正常
   - [ ] 扩展启用后自动恢复正常视图
