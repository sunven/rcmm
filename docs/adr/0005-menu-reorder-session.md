# ADR-0005: 拖拽重排抽出为 MenuReorderSession

状态：已接受 (Accepted) - 2026-08-12

## 背景

`MenuConfigTab.swift`（707 行）里混着一台拖拽重排状态机：6 个 `@State`、约 145 行逻辑，
覆盖命中测试、预览、提交、取消与 120 秒过期。它是 [ADR-0003](0003-menu-entry-write-interface.md)
中 `preview` / `commitPreview` 语义的**唯一**消费者，却没有任何测试；
提交 2290da7「Fix menu reorder drag overlay」正是在这块出的问题（175+/106-，一次重写）。

`isExpired`（120 秒）诞生于 a446293，当时用的是 `.onDrag` + `DropDelegate`（NSItemProvider
系统拖放）——那套 API 下拖拽可能被系统静默中断而不给回调，`activeDrag` 会永远悬着，
需要超时兜底。2290da7 换成 `DragGesture` 后，手势必然走到 `.onEnded`，
该兜底失去了原本的理由。

## 决策

抽出 `MenuReorderSession`：纯值语义 `struct`，只管顺序。

### 1. 放在 RCMMShared，而不是 RCMMApp

这是本 ADR 最反直觉、也最需要写下来的一条：**一个纯 UI 的拖拽状态机为什么在共享库里？**

因为 `RCMMAppTests` 在开发机上跑不起来
（`The test runner hung before establishing connection.`，未签名的 LSUIElement 宿主起不来，
已在未改动的基线提交上对照确认）。放进 `RCMMApp` 意味着"抽出来了但依然测不了"，
这次深化的唯一目的直接落空。放在 `RCMMShared` 才能被 `swift test` 覆盖。

**若将来 `RCMMAppTests` 能跑了，把它移回 `RCMMApp` 是合理的**——但要连测试一起搬，
不要只搬实现。

### 2. 只认识 ID 顺序，不认识 MenuEntry

session 持有 `originalOrder` / `currentOrder`（都是 `[String]`），输出目标顺序，
由视图转交 `AppCoordinator` 的 `preview` / `commitPreview`。它不依赖任何 App 层类型，
测试里不需要构造 `AppCoordinator`、不需要等 `publishTask`。

取消拖拽因此只恢复**顺序**，不再像原来那样用 `$0.menuEntries = drag.originalEntries`
覆盖整份配置——「取消这次拖拽」不该等于「把配置整体倒回拖拽开始前」，
那会把拖拽期间别处对菜单项内容的改动一并回滚。`MenuConfigStore` 为此新增
`reorderEntries(toOrder:)`，preview 与 cancel 从两条路径合并为一条。

### 3. 命中测试按位置，不按行身份

`targetIndex(atY:rows:)` 返回**第几行**而非目标行的 id。

原因是 `rowFrames` 经 SwiftUI `PreferenceKey` 回传，天然可能滞后一帧：顺序刚改、
frames 还没更新时，同一个 y 会再次命中同一个 id，导致来回抖动。而行的**几何位置**
在拖拽期间是稳定的，变的只是谁占据哪个位置——按位置判定就对滞后免疫。
`MenuRowBounds` 因此不带 id。

视图侧必须按 `minY` 排序后再交进来，**不能**按当前顺序取：preview 改变顺序后
按顺序取会得到非单调的几何序列，命中会落到错误的位置上。

### 4. 几何用一维，不引入 CoreGraphics

命中测试本来就只用 `location.y`。`MenuRowBounds` 只有 `minY` / `maxY`（`Double`），
`RCMMShared` 保持只依赖 Foundation，不碰 CLAUDE.md 的包依赖规则。
视图侧把 `[String: CGRect]` 压成一维是三行机械转换。

### 5. 删除 isExpired

它在 `DragGesture` 下的实际语义变成「按住拖超过 2 分钟就取消」，没人想要这个行为。
即使手势真被中断导致 session 悬着，下次拖拽的 `startDragIfNeeded` 会先取消旧 session
再重开，**已经自愈**。删掉后 session 不需要时钟，是纯函数。

### 6. 留在视图里的部分

- **overlay 几何**（`dragLocation` / `dragOverlaySize` / `dragGrabOffset`）——
  分界是「决策 vs 渲染」：命中与顺序推演是决策，把光标位置换算成 overlay 中心是渲染。
- **选中项**——[ADR-0003](0003-menu-entry-write-interface.md) 已把它归为视图状态。
  session 只在输出里带上被拖项的 ID，视图自己设。
- `dragPreviewEntries` 已删除：`preview` 早已把新顺序写进 store，它只是同一份数据的副本，
  实际仅充当「是否正在拖拽」的标志，而 session 本身就能表达。

## 后果

### 正面

- `MenuConfigTab` 707 → 626 行；拖拽 `@State` 从 6 个减到 4 个（余下均为 overlay 渲染）
- 重排逻辑首次被测试覆盖：16 个用例，含滞后一帧不抖动、行高不等、拖出列表、
  拖回原位不提交、单项列表、边界缺失
- ADR-0003 的 `preview` / `commitPreview` 语义有了测试守护
- 取消拖拽不再覆盖菜单项内容
- 命中测试对 `PreferenceKey` 滞后免疫

### 负面

- 一个 UI 概念住在 `RCMMShared` 里，需要本 ADR 解释
- 视图与 session 之间多一层 `CGRect → MenuRowBounds` 转换
- 手势接线（`onChanged` / `onEnded`、overlay 跟手、`PreferenceKey` 回传）仍只能手工验证

### 未做

`row(for:at:)` 里 4 个近乎相同的分支（各约 18 行，`onMoveUp` / `onMoveDown` / `onToggle` /
`position` / `total` 接线重复四遍）没有一并处理——它是行式重复，与重排状态机正交，
混进来会让「重排行为没变」这个判断难以支撑。

## 参考

- [CONTEXT.md](../../CONTEXT.md) — MenuReorderSession 术语
- [ADR-0003](0003-menu-entry-write-interface.md) — 四入口写模型，本模块是 `preview` 的唯一消费者
- a446293、2290da7 — `isExpired` 的来源与拖拽实现的那次重写
- `/improve-codebase-architecture` 评审报告候选 2
