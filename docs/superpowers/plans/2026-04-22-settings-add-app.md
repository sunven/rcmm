# 设置页添加应用入口收口 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让设置页只保留一个“添加应用”入口，并在选择面板中明确说明只支持 `/Applications` 与 `~/Applications` 中的应用。

**Architecture:** 这次只改设置页的两个 SwiftUI 视图，不扩大扫描范围，也不改 onboarding。`MenuConfigTab` 负责把新增入口收敛成单一按钮；`AppSelectionSheet` 负责承接全部新增流程，并把支持范围与空状态规则直接展示给用户。`AppDiscoveryService` 不需要改动，因为它当前的扫描目录已经符合新的产品边界，而手动选择 `.app` 仍被 onboarding 使用。

**Tech Stack:** Swift 6, SwiftUI, Observation, AppKit, ripgrep, xcodebuild

---

## File Map

- Modify: `RCMMApp/Views/Settings/MenuConfigTab.swift` — 删除设置页中的 `手动添加` 按钮和对应的手动选 `.app` 调用链，只保留 `AppSelectionSheet` 入口。
- Modify: `RCMMApp/Views/Settings/AppSelectionSheet.swift` — 在选择面板中增加支持范围说明，并把空状态改成“无兜底动作、只解释规则”的文案。
- No change: `RCMMApp/Services/AppDiscoveryService.swift` — 保持只扫描 `/Applications` 和 `~/Applications`；`selectApplicationManually()` 先保留给 onboarding 使用。

## Scope Guards

- 不改 `RCMMApp/Views/Onboarding/SelectAppsStepView.swift`。
- 不扩展扫描目录，不新增递归搜索或 Spotlight 搜索。
- 不下线 `AppDiscoveryService.selectApplicationManually()`，因为 onboarding 还依赖它。
- 不处理历史配置兼容，也不清理旧数据。

### Task 1: 收口设置页底部入口

**Files:**
- Modify: `RCMMApp/Views/Settings/MenuConfigTab.swift`

- [ ] **Step 1: 先把底部按钮收敛成单入口**

把 `RCMMApp/Views/Settings/MenuConfigTab.swift` 的底部 `HStack` 改成下面这样，只保留一个主按钮：

```swift
            HStack(spacing: 8) {
                Button("添加应用") {
                    showingAppSelection = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("添加应用到右键菜单")

                Spacer()
            }
            .padding(Layout.footerPadding)
```

- [ ] **Step 2: 删除设置页里不再使用的手动选择调用链**

在同一个文件里删除整段 `selectManually()`，让 `.sheet` 后面直接接 `moveItem`。删除后，相关结构应像下面这样：

```swift
        .sheet(isPresented: $showingAppSelection) {
            AppSelectionSheet()
        }
    }

    private func moveItem(at index: Int, direction: Int) {
        let destination = direction < 0 ? index - 1 : index + 2
        appState.moveEntry(from: IndexSet(integer: index), to: destination)
    }
```

- [ ] **Step 3: 检查设置页文件里已经没有手动添加残留**

Run:

```bash
rg -n "手动添加|selectManually" RCMMApp/Views/Settings/MenuConfigTab.swift
```

Expected: 无输出，说明设置页入口已经完全收口。

- [ ] **Step 4: 构建应用，确认设置页修改可以编译**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme rcmm -destination 'platform=macOS' build -quiet
```

Expected: 命令结束并输出 `** BUILD SUCCEEDED **`。

- [ ] **Step 5: 提交 Task 1**

```bash
git add RCMMApp/Views/Settings/MenuConfigTab.swift
git commit -m "refactor(settings): remove manual add entrypoint"
```

### Task 2: 在选择面板中显式展示支持范围

**Files:**
- Modify: `RCMMApp/Views/Settings/AppSelectionSheet.swift`

- [ ] **Step 1: 给选择面板加上支持范围说明和新的空状态文案**

在 `RCMMApp/Views/Settings/AppSelectionSheet.swift` 中增加一组本地文案常量，并同时更新标题区域与空状态。目标代码如下：

```swift
struct AppSelectionSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAppIds: Set<UUID> = []
    @State private var isLoading = false

    private enum Copy {
        static let supportedScope = "仅显示 /Applications 和 ~/Applications 中的应用"
        static let emptyTitle = "未发现可添加应用"
        static let emptyDetail = "仅支持从 /Applications 和 ~/Applications 添加应用"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("选择应用")
                    .font(.headline)

                Text(Copy.supportedScope)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

            if isLoading {
                Spacer()
                ProgressView("正在扫描应用…")
                Spacer()
            } else if appState.discoveredApps.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Text(Copy.emptyTitle)
                        .foregroundStyle(.secondary)

                    Text(Copy.emptyDetail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                Spacer()
            } else {
                List {
                    ForEach(groupedApps, id: \.category) { group in
                        Section(header: Text(group.category.displayName)) {
                            ForEach(group.apps) { app in
                                appRow(for: app)
                            }
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("确认添加") {
                    addSelectedApps()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedAppIds.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .task {
            await loadApps()
        }
    }
```

- [ ] **Step 2: 用文本检索确认新文案已经落到面板里**

Run:

```bash
rg -n "仅显示 /Applications 和 ~/Applications 中的应用|未发现可添加应用|仅支持从 /Applications 和 ~/Applications 添加应用" RCMMApp/Views/Settings/AppSelectionSheet.swift
```

Expected: 返回 3 处匹配，分别对应标题说明、空状态标题和空状态说明。

- [ ] **Step 3: 再次构建应用，确认面板修改可以编译**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme rcmm -destination 'platform=macOS' build -quiet
```

Expected: 命令结束并输出 `** BUILD SUCCEEDED **`。

- [ ] **Step 4: 做一轮设置页手动验证**

手动检查下面这些结果：

1. 启动 `rcmm`，打开设置页并进入菜单配置页。
2. 确认底部只剩一个 `添加应用` 按钮。
3. 点击 `添加应用`，确认弹出的面板标题下方显示 `仅显示 /Applications 和 ~/Applications 中的应用`。
4. 如果扫描到了应用，确认仍然可以多选并点击 `确认添加` 完成批量添加。
5. 对已存在于菜单中的应用，确认右侧继续显示 `已添加`，不会重复勾选。

Expected: 设置页不再暴露“手动添加”路径，原有多选添加和去重展示行为不回退。

- [ ] **Step 5: 提交 Task 2**

```bash
git add RCMMApp/Views/Settings/AppSelectionSheet.swift
git commit -m "feat(settings): clarify add-app support scope"
```

### Task 3: 做最终回归并确认范围没有外溢

**Files:**
- Verify only: `RCMMApp/Views/Settings/MenuConfigTab.swift`
- Verify only: `RCMMApp/Views/Settings/AppSelectionSheet.swift`
- Verify only: `RCMMApp/Views/Onboarding/SelectAppsStepView.swift`
- Verify only: `RCMMApp/Services/AppDiscoveryService.swift`

- [ ] **Step 1: 全局确认设置页之外没有被误改的手动添加入口**

Run:

```bash
rg -n "手动添加|selectApplicationManually\\(" RCMMApp
```

Expected:
- `RCMMApp/Views/Settings/MenuConfigTab.swift` 不再出现在结果中。
- `RCMMApp/Views/Onboarding/SelectAppsStepView.swift` 仍然保留 `手动添加` 和 `selectApplicationManually()` 调用。
- `RCMMApp/Services/AppDiscoveryService.swift` 仍然保留 `selectApplicationManually()` 实现。

- [ ] **Step 2: 做一轮最终构建回归**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme rcmm -destination 'platform=macOS' build -quiet
```

Expected: 命令结束并输出 `** BUILD SUCCEEDED **`，没有因为删除设置页入口而引入新的编译错误。

- [ ] **Step 3: 记录最终验收结论**

确认下面 4 条都成立后再宣告完成：

1. 设置页只剩一个 `添加应用` 主入口。
2. 选择面板明确写出只支持 `/Applications` 和 `~/Applications`。
3. 空状态不再提供手动兜底路径。
4. onboarding 的手动添加能力没有被误伤。
