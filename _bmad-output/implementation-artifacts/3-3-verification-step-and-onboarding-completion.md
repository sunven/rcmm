# Story 3.3: 验证步骤与引导完成

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a 首次用户,
I want 引导最后一步提示我去 Finder 测试右键菜单，确认一切正常,
So that 我在引导结束时就能体验到产品价值。

## Acceptance Criteria

1. **步骤指示器更新** — 用户进入引导步骤 3（验证）时，`OnboardingStepIndicator` 更新为步骤 3/3（步骤 1、2 显示已完成绿色勾，步骤 3 高亮当前）。
2. **验证提示与操作指引** — 显示提示文字"现在去 Finder 试试右键！"和简要操作指引（右键目录 → 点击菜单项 → 确认应用打开）。使用清晰的图标和排版引导用户完成验证。
3. **完成按钮与引导结束** — 用户测试完成后返回引导界面，点击"完成"按钮时：
   - 显示引导完成确认（简短的成功信息）
   - 提供开机自启选项（`Toggle`，默认开启），使用 `SMAppService.mainApp` 管理登录项
   - 引导状态标记为已完成（`appState.isOnboardingCompleted = true`），下次启动不再触发引导
   - 关闭引导窗口，应用进入正常菜单栏常驻状态（调用 `appState.closeOnboarding()`）
4. **跳过支持** — 验证步骤允许"跳过"（沿用现有"跳过"按钮模式），跳过时仍标记引导完成并关闭窗口。
5. **无障碍支持** — 所有交互元素添加 `.accessibilityLabel`；Toggle 和按钮支持 VoiceOver 读取；键盘 Tab 导航可完成所有操作。

## Tasks / Subtasks

- [x] Task 1: 创建 VerifyStepView 验证步骤视图 (AC: #1, #2, #3, #5)
  - [x] 1.1 在 `RCMMApp/Views/Onboarding/` 创建 `VerifyStepView.swift`
  - [x] 1.2 实现验证提示区域：图标（`hand.tap` SF Symbol）+ 标题"现在去 Finder 试试右键！" + 操作指引文字（3 步：① 在 Finder 中右键一个目录 ② 点击菜单中的应用 ③ 确认应用打开到对应目录）
  - [x] 1.3 实现开机自启 Toggle：`@Binding var launchAtLogin: Bool`（默认开启），父视图通过 `completeOnboarding()` 使用 `SMAppService.mainApp` 注册登录项（遵循 Dev Notes 技术决策 5：完成时一次性注册）
  - [x] 1.4 SMAppService 注册在 `completeOnboarding()` 中统一执行，错误时 os_log 记录（遵循 Dev Notes 最终方案）
  - [x] 1.5 通过 `var onComplete: () -> Void` 闭包将完成事件传给父视图
  - [x] 1.6 添加所有交互元素的 `.accessibilityLabel` 和 `.accessibilityHint`

- [x] Task 2: 集成 VerifyStepView 到 OnboardingFlowView (AC: #1, #3, #4)
  - [x] 2.1 在 `OnboardingFlowView.swift` 中将 `verifyPlaceholder` 替换为 `VerifyStepView(launchAtLogin: $launchAtLogin, onComplete: completeOnboarding)`
  - [x] 2.2 删除 `verifyPlaceholder` 计算属性
  - [x] 2.3 修改底部导航按钮：当 `currentStep == .verify` 时，将"下一步"替换为"完成"按钮（`.buttonStyle(.borderedProminent)`）
  - [x] 2.4 实现 `completeOnboarding()` 方法：SMAppService 注册 → 标记 `appState.isOnboardingCompleted = true` → 调用 `appState.closeOnboarding()` 关闭窗口
  - [x] 2.5 "跳过"按钮在验证步骤时也触发 `completeOnboarding()`（非 `advanceToNextStep`）
  - [x] 2.6 移除验证步骤的"下一步"通用按钮逻辑，改用"完成"按钮

- [x] Task 3: 编译验证与测试 (AC: 全部)
  - [x] 3.1 `xcodebuild -scheme rcmm` 编译成功（零错误）— BUILD SUCCEEDED
  - [x] 3.2 `swift test --package-path RCMMShared` 全部 25 个测试通过，无回归
  - [ ] 3.3 手动测试：引导步骤 2 完成后 → 自动进入步骤 3 → 步骤指示器显示 3/3
  - [ ] 3.4 手动测试：验证提示和操作指引正确展示
  - [ ] 3.5 手动测试：开机自启 Toggle 默认开启 → 切换 Toggle → SMAppService 注册/取消正确执行
  - [ ] 3.6 手动测试：点击"完成" → 引导标记完成 → 窗口关闭 → 应用回到菜单栏常驻
  - [ ] 3.7 手动测试：点击"跳过" → 引导标记完成 → 窗口关闭
  - [ ] 3.8 手动测试：重启应用 → 引导不再触发（`isOnboardingCompleted == true`）
  - [ ] 3.9 SwiftUI Preview 验证：VerifyStepView Light/Dark Mode

## Dev Notes

### 架构模式与约束

**本 Story 在架构中的位置：**

本 Story 是 Epic 3（首次引导体验）的最后一个 Story，在 Story 3.1 建立的引导流程框架和 Story 3.2 实现的应用选择步骤基础上，实现验证步骤（步骤 3）和引导完成标记。Story 完成后，用户首次引导流程完整可用：启用扩展 → 选择应用 → 验证右键 → 完成。

**FRs 覆盖：** FR-ONBOARDING-004（引导完成后，系统提示用户测试右键菜单是否正常工作）

**跨 Story 依赖：**
- 依赖 Story 3.1：`OnboardingFlowView`（引导容器）、`OnboardingStepIndicator`（步骤指示器）、`OnboardingStep` 枚举
- 依赖 Story 3.2：`SelectAppsStepView`（前一步骤），`saveSelectedApps()` 逻辑
- 依赖 Story 1.2：`SharedKeys.onboardingCompleted` 键名常量
- `AppState.isOnboardingCompleted` 和 `AppState.closeOnboarding()` 已在 Story 3.1 中实现
- SMAppService 登录项管理是 Epic 5 (Story 5.2) 的完整实现范围，但引导完成时的开机自启选项属于本 Story 范围

### 关键技术决策

**1. VerifyStepView 通过闭包通知完成**

参考 `EnableExtensionStepView` 使用 `onNext` 闭包的模式，`VerifyStepView` 使用 `onComplete` 闭包：

```swift
struct VerifyStepView: View {
    var onComplete: () -> Void
    @State private var launchAtLogin = true
    // ...
}
```

`OnboardingFlowView` 中：
```swift
case .verify:
    VerifyStepView(onComplete: completeOnboarding)
```

"完成"按钮在 `OnboardingFlowView` 底部导航区域，保持与其他步骤一致的导航模式。

**2. 开机自启实现（SMAppService）**

```swift
import ServiceManagement

// 注册登录项
try SMAppService.mainApp.register()

// 取消登录项
try SMAppService.mainApp.unregister()

// 检查状态
let status = SMAppService.mainApp.status
// .enabled / .notRegistered / .notFound / .requiresApproval
```

Toggle 状态变更时：
- 开启 → `try SMAppService.mainApp.register()`
- 关闭 → `try SMAppService.mainApp.unregister()`
- 错误时回退 Toggle 状态，os_log 记录错误

注意：SMAppService 不需要额外的 entitlement 或 capability 配置。macOS 15+ 完全支持。

**3. 完成按钮 vs 下一步按钮**

当 `currentStep == .verify` 时，底部导航的"下一步"按钮替换为"完成"按钮。完成按钮的行为是：
1. 触发 `completeOnboarding()`
2. `completeOnboarding()` 标记 `appState.isOnboardingCompleted = true`
3. 调用 `appState.closeOnboarding()` 关闭窗口

"跳过"按钮在验证步骤也触发 `completeOnboarding()`（用户可以选择不验证直接完成引导）。

**4. 验证步骤不做自动检测**

验证步骤是让用户自行去 Finder 测试右键菜单。我们不做自动检测（无法检测用户是否真的测试过），只提供清晰的指引和"完成"按钮。这符合 UX 设计中"容错设计"原则 — 不强制用户完成验证。

**5. 开机自启注册时机**

开机自启在用户点击"完成"时根据 Toggle 状态执行注册/取消。这样即使用户反复切换 Toggle，也只在最终确认时执行一次系统调用。

替代方案：Toggle 实时注册/取消 — 但引导流程中用户可能还在探索，不需要每次切换都执行系统操作。最终方案：在 `completeOnboarding()` 中根据 Toggle 状态一次性执行。

### 前序 Story 经验总结

**来自 Story 3.1（引导框架）：**
- 引导窗口使用 `NSWindow + NSHostingView` 实现
- `OnboardingFlowView` 使用 `@State currentStep: OnboardingStep` 管理步骤
- `EnableExtensionStepView` 使用 `onNext` 闭包通知父视图前进
- 引导窗口固定尺寸 480×500pt
- `AppState.closeOnboarding()` 已实现：移除 window close observer → 关闭窗口 → 设为 nil → `NSApp.setActivationPolicy(.accessory)`

**来自 Story 3.2（应用选择）：**
- 采用 `@Binding` 传递选中状态，"下一步"点击时在父视图执行保存
- "跳过"按钮允许步骤 1 和步骤 2 跳过，直接前进
- `verifyPlaceholder` 在 `OnboardingFlowView.swift:78-88` 等待替换
- 编译和测试一次通过

**Git 提交模式：**
- 提交消息格式：`feat: implement [feature description] (Story X.Y)`
- 每个 Story 一个 commit

**当前代码状态（需修改的核心文件）：**
- `RCMMApp/Views/Onboarding/OnboardingFlowView.swift:28-29` — `verifyPlaceholder` 引用需替换为 `VerifyStepView`
- `RCMMApp/Views/Onboarding/OnboardingFlowView.swift:51-61` — "下一步"按钮需在验证步骤变为"完成"
- `RCMMApp/Views/Onboarding/OnboardingFlowView.swift:40-47` — "跳过"按钮需在验证步骤触发 `completeOnboarding`
- `RCMMApp/Views/Onboarding/OnboardingFlowView.swift:78-88` — `verifyPlaceholder` 计算属性需删除

**需新建的文件：**
- `RCMMApp/Views/Onboarding/VerifyStepView.swift` — 验证步骤视图

### macOS 版本兼容说明

- `SMAppService.mainApp` — macOS 13+，macOS 15+ 完全支持
- `SMAppService.mainApp.register()` / `.unregister()` — 标准 ServiceManagement API
- `SMAppService.mainApp.status` — 可检查当前注册状态

### Swift 6 并发注意事项

- `SMAppService.mainApp.register()` 和 `.unregister()` 是同步方法（可能内部执行 IPC），在主线程调用即可
- Toggle 状态变更回调在主线程，无并发问题
- `VerifyStepView` 的所有状态都是 `@State` 本地状态

### 反模式清单（禁止）

- ❌ 自动检测用户是否完成了验证（无法可靠检测，不做假检测）
- ❌ 使用 `ObservableObject/@Published`（统一用 `@Observable`）
- ❌ 在验证步骤中修改 `MenuItemConfig` 或其他 RCMMShared 模型
- ❌ 使用 `try!` 或 force unwrap（SMAppService 调用必须 try/catch）
- ❌ 硬编码字符串键名（使用 `SharedKeys` 常量）
- ❌ 在 `VerifyStepView` 中直接调用 `appState.isOnboardingCompleted = true`（由 `OnboardingFlowView.completeOnboarding()` 统一管理）
- ❌ 直接关闭窗口而不调用 `appState.closeOnboarding()`（该方法处理了 observer 清理和 activation policy 切换）
- ❌ 在 RCMMShared 中引入 ServiceManagement 依赖

### 范围边界说明

**本 Story 范围内：**
- `VerifyStepView` 验证步骤视图（验证提示 + 操作指引 + 开机自启 Toggle）
- 替换 `OnboardingFlowView` 中的 `verifyPlaceholder`
- 修改 `OnboardingFlowView` 底部导航：验证步骤显示"完成"按钮
- 实现 `completeOnboarding()` 方法：标记完成 + 注册登录项 + 关闭窗口
- "跳过"按钮在验证步骤触发 `completeOnboarding()`

**本 Story 范围外（明确排除）：**
- 设置窗口中的开机自启完整管理（Epic 5, Story 5.2：包含 GeneralTab Toggle + 状态显示）
- 菜单栏图标状态指示（Epic 6）
- 异常恢复引导（Epic 6）
- 任何 RCMMShared 模型修改

### Project Structure Notes

**本 Story 新建文件：**

```
rcmm/
├── RCMMApp/
│   └── Views/
│       └── Onboarding/
│           └── VerifyStepView.swift        # [新建] 验证步骤视图（含开机自启 Toggle）
```

**本 Story 修改文件：**

```
RCMMApp/Views/Onboarding/OnboardingFlowView.swift  # [修改] 替换占位视图 + 完成逻辑
```

**不变的文件（已验证无需修改）：**

```
RCMMApp/AppState.swift                                # 不变 — isOnboardingCompleted 和 closeOnboarding() 已实现
RCMMApp/Services/PluginKitService.swift               # 不变
RCMMApp/Views/Onboarding/OnboardingStepIndicator.swift # 不变 — 步骤指示器已支持 verify
RCMMApp/Views/Onboarding/EnableExtensionStepView.swift # 不变
RCMMApp/Views/Onboarding/SelectAppsStepView.swift      # 不变
RCMMApp/Views/Settings/SettingsView.swift              # 不变
RCMMApp/rcmmApp.swift                                  # 不变
RCMMShared/Sources/Constants/SharedKeys.swift          # 不变 — onboardingCompleted 已定义
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.3] — Story 需求定义和验收标准（引导步骤 3：验证与完成）
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries] — 项目目录结构（RCMMApp/Views/Onboarding/）
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns] — 命名规范、结构模式、反模式清单
- [Source: _bmad-output/planning-artifacts/architecture.md#Core Architectural Decisions] — SMAppService 登录项管理决策
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#User Journey Flows] — Journey 1: First-Time Setup Step 3 验证 UX 定义
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Button Hierarchy] — 引导流程按钮层级（"完成"为主要操作按钮）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Feedback Patterns] — 信息反馈（内联文字确认 + 图标，5 秒后淡出）
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Accessibility Strategy] — VoiceOver、键盘导航、Dynamic Type
- [Source: _bmad-output/planning-artifacts/prd.md#首次引导] — FR-ONBOARDING-004（引导完成后测试验证）
- [Source: _bmad-output/implementation-artifacts/3-2-app-selection-onboarding-step.md] — 前序 Story（应用选择步骤 + OnboardingFlowView 导航模式）
- [Source: RCMMApp/Views/Onboarding/OnboardingFlowView.swift:28-29] — verifyPlaceholder 引用
- [Source: RCMMApp/Views/Onboarding/OnboardingFlowView.swift:78-88] — verifyPlaceholder 占位视图实现
- [Source: RCMMApp/Views/Onboarding/OnboardingFlowView.swift:51-61] — "下一步"按钮逻辑
- [Source: RCMMApp/Views/Onboarding/OnboardingFlowView.swift:40-47] — "跳过"按钮逻辑
- [Source: RCMMApp/AppState.swift:12-17] — isOnboardingCompleted 属性与 UserDefaults 绑定
- [Source: RCMMApp/AppState.swift:82-90] — closeOnboarding() 窗口关闭和清理
- [Source: RCMMShared/Sources/Constants/SharedKeys.swift:6] — onboardingCompleted 键名定义
- [Source: RCMMApp/Views/Onboarding/EnableExtensionStepView.swift] — 步骤 1 的 onNext 闭包模式参考

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

无调试问题。编译和测试一次通过。

### Completion Notes List

- 创建 `VerifyStepView.swift`：验证步骤视图，包含 `hand.tap` 图标、标题、3 步操作指引、开机自启 Toggle（@Binding）
- 修改 `OnboardingFlowView.swift`：替换 `verifyPlaceholder` 为 `VerifyStepView`；删除占位视图；底部导航验证步骤显示"完成"按钮；"跳过"按钮在验证步骤触发 `completeOnboarding()`
- 实现 `completeOnboarding()`：根据 Toggle 状态通过 `SMAppService.mainApp.register()` 注册开机自启 → 标记 `isOnboardingCompleted = true` → 调用 `closeOnboarding()` 关闭窗口
- 遵循 Dev Notes 技术决策 5：SMAppService 注册在完成时一次性执行，而非 Toggle 实时触发，避免引导流程中不必要的系统调用
- 使用 `@Binding` 而非 `@State` 传递 launchAtLogin 状态，使父视图可在 `completeOnboarding()` 中读取 Toggle 状态
- 所有交互元素添加 `.accessibilityLabel` 和 `.accessibilityHint`
- `xcodebuild -scheme rcmm` 编译成功（BUILD SUCCEEDED）
- `swift test --package-path RCMMShared` 25/25 测试通过，无回归
- Task 3.3-3.9 为手动测试项，需用户在运行应用时验证

**代码审查修复（2026-02-22）：**
- [修复 HIGH-1] 新增 `completionConfirmationView`：点击"完成"后显示绿色对勾 + "设置完成！"成功提示，2 秒后自动关闭窗口，满足 AC #3 的"显示引导完成确认"要求
- [修复 MED-1] `completeOnboarding()` 补全 else 分支：`launchAtLogin == false` 时调用 `SMAppService.mainApp.unregister()`（首次安装未注册的错误以 debug 级别记录）
- [修复 MED-2] 移除 `VerifyStepView` 中从未调用的 `onComplete: () -> Void` 死代码参数，接口更清晰
- [修复 MED-3] 注册失败时将错误信息展示在完成确认视图中（橙色警告标签）
- [修复 LOW-1] 为 3 个操作指引 `Label` 添加 `.accessibilityLabel`，改善 VoiceOver 读取体验
- [修复 LOW-2] VerifyStepView Preview 尺寸调整为 480×380，与实际嵌入环境一致
- 新增 `guard !isCompleting else { return }` 防止"完成"按钮重复触发
- 编译验证：BUILD SUCCEEDED；25/25 测试通过，无回归

### File List

- `RCMMApp/Views/Onboarding/VerifyStepView.swift` — [新建] 验证步骤视图（验证提示 + 操作指引 + 开机自启 Toggle）
- `RCMMApp/Views/Onboarding/OnboardingFlowView.swift` — [修改] 替换占位视图、添加完成按钮和 completeOnboarding() 方法

## Change Log

- 2026-02-22: 实现验证步骤与引导完成（Story 3.3）— 新建 VerifyStepView 验证步骤视图，集成到 OnboardingFlowView，实现开机自启 Toggle 和引导完成流程
- 2026-02-22: 代码审查修复 — 新增完成确认视图、补全 SMAppService unregister 分支、移除死代码参数、改善无障碍标签
