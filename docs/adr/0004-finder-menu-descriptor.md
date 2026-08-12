# ADR-0004: Finder 菜单项身份的构造与反解收归一个模块

状态：已接受 (Accepted) - 2026-08-11

## 背景

菜单项身份的**编码**写在 `RCMMFinderExtension/FinderSync.swift`（该 target 没有测试），
**解码**写在 `RCMMShared/Sources/Services/MenuItemResolver.swift`（有 299 行测试）。
标题格式 `"用 X 打开"` / `"运行 X"` 在两处各写一遍，一处生成、一处反解，中间没有任何守护。
测试覆盖的是回退链的分支，不是「二者是否对得上」。

`MenuItemResolver` 诞生于 616025d「fix: route Finder custom menu actions reliably」——
原本只靠 `representedObject` 路由，那次修复加进了 `tag` 与 `title` 兜底。到 7c078a6 引入
Composite 时，标题匹配被直接放在回退链第一位。也就是说，「用单一 token 路由」这个看起来
显然的简化，当初已经被现实否掉过一次，但原因没有被记录下来。

## 实测事实（本决策的地基）

在 Debug 身份下加临时诊断日志，覆盖 custom / composite / New File Template 三条构造路径 ×
`flat` 与 `nestedUnderRCMM` 两种展示方式，共 7 次点击，结果完全一致：

| 字段 | 回传结果 | 结论 |
|---|---|---|
| `representedObject` | 恒 `nil` | 不可用 |
| `identifier` | 恒 `"openScriptBackedEntry:"`（action selector 名） | 被 Finder 占用，不可用 |
| `parentMenuTitle` | 恒 `nil`，二级、三级子菜单同样 | 不可用 |
| `title` | 原值正确 | 可用 |
| `tag` | 原值正确 | 可用 |

**Finder 不会把扩展构造的 `NSMenuItem` 原样传回，而是用自己重建的裸菜单项回调，
只保留 `title`、`tag`、`action`**；`menu` 与 `parent` 都取不到，因此层级信息也丢失。
这一条同时解释了三个字段为何全部失效，也说明它与菜单层级无关。

由此可知 `MenuItemResolver` 的 5 路回退链里有 **3 条是死代码**：按 `representedObject`
匹配、按 `identifier` 匹配、以及模板的父菜单区分（`parentMenuTitle` 恒 nil 使其永远
走 `return true`）。真正在工作的只有标题唯一匹配，加上 custom 项的 `tag` 索引兜底。

### 由此确证的三个现存缺陷

1. **同名 custom 项静默路由到错误的应用** —— 标题相同使唯一匹配失效，回退链的
   `customItem` 分支按标题返回第一个匹配项，第二项的点击会执行第一项的脚本。
2. **同名 composite 项点击落空** —— `tag` 恒为 `-1`，标题唯一匹配失败后无索引可用，
   且 composite 不在 `customItems` 里，解析返回 nil。
3. **不同 New File 菜单下的同名模板点击落空** —— 父菜单区分从未生效，两个同名模板
   互相冲突，双双失灵。

三者都不是重构引入的，而是身份载体选错导致的既有缺陷。

## 决策

### 1. Finder Menu Descriptor 同时拥有构造与反解

`FinderMenuDescriptorBuilder.layout(...)` 产出树形描述与身份索引，
`FinderMenuSnapshot.resolve(_:)` 反解点击。标题格式、图标选择、身份字段写入
规则都只在这一个模块里定义一次。`FinderSync` 退化为 `descriptor → NSMenuItem` 的 adapter
（548 → 412 行），不再直接引用 `MenuItemResolver`、`FinderMenuPresenter`、
`FinderMenuIconPolicy`、`MenuEntryScriptPolicy`。

`MenuEntryScriptPolicy` 保持在模块外部——App 侧的 `ScriptInstallerService` 也消费它，
它是跨两个 target 的共享词汇。`FinderTargetPathResolver`（执行期路径）与
`FinderMenuCacheInvalidationPolicy`（缓存时机）同样留在外面，它们与「菜单长什么样、
点中的是哪一项」正交。

### 2. MenuItemFields 作为纯值中间层

`RCMMShared` 不能依赖 AppKit，因此引入 `MenuItemFields`。第②步它携带 `NSMenuItem`
上全部五个可能回传的字段以保持行为等价；第③步收敛为只剩 `title` 与 `tag` ——
其余三个既然实测永远拿不到，就不该出现在接口里。扩展侧只做 fields ↔ `NSMenuItem`
的机械转换，往返正确性在 `swift test` 内可验证，无需给 `RCMMFinderExtension`
建测试 target、无需把 Finder 宿主拖进 CI。

图标以 `FinderMenuIconSource` 描述来源（`.symbol` / `.applicationIcon(data:fallbackSymbolName:)` /
`.none`），由 adapter 转 `NSImage`；`fallbackSymbolName` 保留了原有的「图标解码失败退化为
占位符号」行为。

### 3. 构造与反解绑定同一份不可变快照

`FinderMenuSnapshot` 在一次初始化里同时产出描述树与身份索引，原子替换。
此前构造菜单与解析点击是两次独立读取，中间若收到 Cross-Process Sync 通知，
就会出现「按旧菜单点击、按新配置解析」的时间窗——这也是 616025d 那个路由 bug 的一种
合理成因。绑定快照后该时间窗消失。

### 4. 实测保真度编码进代码

`MenuItemFields.finderObserved(title:tag:)` 按上表构造输入：只保留 `title` 与 `tag`。
往返不变量必须用这个保真度作输入——用理想输入（全字段可用）测出来的绿色是假的。

### 5. 分三步落地

| 步骤 | 内容 | 状态 |
|---|---|---|
| ① | `#if DEBUG` 临时诊断，取得上表事实 | 已完成并回滚 |
| ② | 引入 Descriptor / Snapshot / MenuItemFields，回退链**原样**搬入，补往返不变量测试，行为零变更 | 已完成 |
| ③ | `tag` 升级为全局索引 + 快照 generation 编码，砍掉死分支，兜底命中写错误队列 | 已完成 |

第②步刻意不改路由行为：先把测试网架好，再动逻辑。三个现存缺陷曾用
`withKnownIssue` 固定在 `FinderMenuDescriptorTests` 里，第③步落地后全部转绿，标记已摘除。

### 第③步的最终形状

- `tag` 编码为 `generation << 16 | index`，`index` 覆盖**全部** Script-Backed 项
  （此前只有 custom 项分配序号）。`generation` 从 1 起，因此有效编码不会等于
  非 Script-Backed 项的 `0`。
- 反解主路径是 tag 索引，标题相等校验作纵深防御；结果是
  `FinderMenuResolution`（`resolved` / `staleSnapshot` / `titleMismatch` / `notScriptBacked`），
  失败按类型写入错误队列（新增 `ErrorRecordKind.menuRouting`）。用户此前的感受是
  「点了没反应」且 App 侧毫不知情，现在看得见。
- `MenuItemResolver` 及其 299 行测试整体删除；`MenuItemFields` 收敛为只剩
  `title` 与 `tag` —— 其余字段既然永远拿不到，就不该出现在接口里。
- `ErrorRecord` 的 `kind` 解码改为容错：未知值降级为 nil 而非抛错。此前
  `decodeIfPresent` 遇到未知 rawValue 会抛错，配合 `loadAll` 的 `try?` 会让**整个**
  错误队列被当成空。加新 kind 前必须先修掉这个。
- `reloadMenuSnapshot` 只允许更大的 generation 覆盖当前快照，防止并发刷新时慢的一次
  后完成、把旧快照写回去（那会让已发出菜单的 tag 全部失配）。

## 理由

### 为什么不能只靠单一 token

这是本 ADR 最该被后来者读到的一条：**`representedObject` 与 `identifier` 都无法跨进程回传**，
所以「给菜单项挂一个 ID，点击时读回来」这个方案在 FinderSync 下不成立。唯一可靠的
结构化载体是 `tag`（Int），语义载体是 `title`。任何「用一个 token 消灭回退链」的提议
都必须先回答这个约束——2026-08-10 的架构评审就正好提了这个建议，理由是回退链看起来冗余。

### 为什么 tag 而不是 title 当主载体（第③步）

`tag` 是结构化的，可以直接索引进快照；`title` 是给人看的，同名即冲突。当前 `tag` 只对
custom 项分配了序号，composite 与模板都浪费成 `-1`，这正是三个缺陷的共同根因。

`tag` 索引带来一个 `title` 方案没有的新风险：菜单打开后配置变更，再点击时索引会错位到
**另一个脚本**——比「找不到」更坏，因为它会静默执行错误的脚本。因此第③步把快照
generation 编进 `tag`（`generation << 16 | index`），跨快照直接失效；并保留一层标题
相等校验作纵深防御，校验失败时写错误队列。`NSMenuItem.tag` 是 64 位 Int，编码空间足够。

### 为什么标题格式仍然保留

`"用 X 打开"` 的**解析**（`appName(fromMenuTitle:)`）在第③步不再承载身份，但格式本身
仍需在构造侧定义。差别在于：从「两处各写一遍的双向契约」降级为「一处生成 + 相等校验」。

### 为什么不给 RCMMFinderExtension 建测试 target

`FIFinderSync` 依赖 Finder 宿主，单测收益低。改为把 adapter 压薄到只剩字段赋值，
测试全部落在 `RCMMShared`。代价是多一个 `MenuItemFields` 类型，但它同时正是实测
事实的载体——哪些字段可靠，直接写在它的 `finderObserved` 上。

## 后果

### 正面

- 菜单项身份的编码与解码同处一个模块，标题格式只定义一次
- `FinderSync` 548 → 412 行，不再直接引用 4 个 policy 模块
- 往返不变量（构造 → Finder 保真度退化 → 反解）首次被测试覆盖
- 三个此前无人知晓的路由缺陷被确证并修复：同名 custom 项不再静默误路由、
  同名 composite 与跨菜单同名模板不再点不动
- 构造与解析绑定同一快照并由 generation 保证，跨快照点击判为过期而非错位命中
- 路由失败进入错误队列，用户与 App 侧都能看见
- 删除 `MenuItemResolver`（134 行）与其测试（299 行）

### 负面

- 多一个 `MenuItemFields` 中间类型
- `tag` 的 index 上限 65535；超限项退化为不可路由（会上报），实际不可达
- 扩展进程重启后 generation 归零重来，理论上可与旧菜单碰撞；但进程重启后
  Finder 的菜单也已失效，实际不可达
- 真机回归依赖手工点击，无法进 CI

### 风险

`RCMMApp` 的测试目前在本机无法执行（`The test runner hung before establishing connection.`），
与本决策无关，基线提交上同样失败。验证依据是 `RCMMShared` 的 254 个用例（零 known issue）
加上两个 target 的编译通过。

第②步的真机回归已完成：8 次点击覆盖 custom / composite / New File Template ×
`flat` / `nestedUnderRCMM` 六格，全部命中且字段与第①步基线一致。
**第③步的真机回归尚未进行** —— 它真正改变了路由载体，必须重跑同一组点击，
并补上同名 composite、跨菜单同名模板两个此前点不动的场景。

## 参考

- [CONTEXT.md](../../CONTEXT.md) — Finder Menu Descriptor 术语与快照不变量
- [ADR-0002](0002-deepen-script-compilation-pipeline.md) — 同类的「把散落职责收进一个 seam」
- 616025d、7c078a6、e6a0e77 — 回退链的三次演化
- `/improve-codebase-architecture` 评审报告候选 1 —— 其「单一 token 让回退链自然消失」
  的结论被本 ADR 的实测推翻，保留在此以免重复提议
