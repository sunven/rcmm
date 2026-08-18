# ADR-0006: Menu Entry 的校验与 Script-Backed 判定合并为一个 module

状态：已接受 (Accepted) - 2026-08-17

## 背景

「这个 Menu Entry 有效吗」此前由三个互不相识的 module 各自回答：
`CustomCommandValidator`（167 行）、`CompositeMenuItemValidator`（321 行）、
`NewFileMenuValidator`（353 行）。三者各自定义了 Severity、Code、Issue、Result 四个类型，
其中 `errors` / `warnings` / `hasErrors` / `hasWarnings` 四个计算属性**逐字重复三遍**。

而「哪些 Menu Entry 产出脚本」是第四处，写在 `MenuEntryScriptPolicy` 里 —— 它调用那三个
校验器，只取 `isExecutable`，把 `issues` 全部丢掉。

于是每个消费者都要按 kind 分三路手工拼装。三路里有一路漏了。

### 由此确证的缺陷

`FinderMenuEntrySummaryBuilder.customSummary` 既不调用 `CustomCommandValidator`，
也不读 Publish State —— 它只问 `appExists(config.appPath)`。三种情形因此在设置界面
显示「就绪」，而 Finder 右键菜单里根本没有这一项、或者点了执行的是旧脚本：

| 情形 | 设置界面 | 实际 |
|---|---|---|
| 名称超过 80 字符 | 就绪 | 校验不通过，不发布，菜单里没有 |
| `osacompile` 失败 | 就绪 | `publishState = .compileFailed`，未被读取 |
| 配置刚改、脚本未重编 | 就绪 | 仍是旧脚本（composite 这里会显示「同步中」） |

`DESIGN.md` 对「就绪」的定义是 *enabled and published/current*，三者都不满足。

根因不是漏了几个判断，而是**状态阶梯被写了两遍半**：`FinderMenuEntrySummary` 与
`NewFileMenuStatusResolver` 各有一份同形状的实现，custom 一份都没有。补第三份只会让
下一个 kind 继续漏。

## 决策

### 1. 校验与 Script-Backed 判定是同一个问题

`MenuEntryEvaluator.evaluate(entry, environment:)` 同时给出 `scriptBacked`、`issues`
与 `isExecutable`。三个校验器降为 `internal`，成为它的实现；`MenuEntryScriptPolicy`
只剩 `newFileScriptID` 的拼装规则（`FinderMenuDescriptor` 需要独立于评估结果构造它）。

**这条最该被后来者读到**：下一次评审很可能提议把两者拆回去 ——「校验器不该知道脚本」
听起来很对。但它们本来就是同一个问题的两面：能执行的才产出脚本，不能执行的必有原因。
拆开的代价已经付过一次，就是上面那张表。

考虑过只做一个 facade 按 kind 分派、保留三种结果类型。否决：调用方还得 switch，
删除测试判「只是移动」，不是收敛。

也考虑过把 `executableStepIDs` 与 `executableTemplateIDs` 合并成一个
`executableChildIDs`。否决：**两者语义不同** —— composite 的步骤是「被写进那一个脚本」，
New File Template 是「本身就是一个脚本」。同一个字段名装两种含义，是在制造下一次评审的候选。
`ScriptBackedMenuEntry` 已经把这个不对称建模正确了（composite 一个条目带 `executableStepIDs`，
newFile N 个条目），所以让 evaluator 直接返回它。

### 2. 两种 environment，且发布门那条路不给参数

`.configurationOnly`（默认）只看配置，零文件系统 IO；`.filesystemAware` 额外检查配置指向的
应用与模板文件是否还在。

这个区分**此前已经存在但是隐形的**：`NewFileMenuValidator.validate(_:fileInfo:)` 的两个
调用方注入的东西不一样 —— 设置界面走真实文件系统，`MenuEntryScriptPolicy` 走一个私有的
`configurationOnlyFileInfo`（只从路径字符串编造 FileInfo，一次 IO 都不做）。只有读过那个
私有函数才知道。

**`FinderMenuSnapshot` 与发布门路径连参数都不暴露。** 它们会在扩展进程里、每次右键被调用；
给它们一个能打开文件系统 IO 的开关，等于把「别在这条路上做 IO」从类型系统降级成纪律。
想传也传不了，比传错了才发现好。

**默认值取 `.configurationOnly`**，因为忘记传参的后果不对称：设置界面漏传只是少一条提示，
发布门漏传是每次右键做 stat。

一个必须保留的微妙处：`NewFileMenuStatusResolver` 曾同时用两种模式 —— 阶梯走 FS-aware
（用户该看到文件丢了），模板计数走 config-only（扩展别做 IO）。那不是 bug，是两条约束的
正确交点。合并后由 `FinderMenuEntrySummaryBuilder` 显式传 `.filesystemAware` 承担。

### 3. 状态阶梯写成一份

`MenuEntryStatusResolver` 是全应用唯一一处阶梯，四种 kind 都走它。

`isExecutable` **不从 `scriptBacked.isEmpty` 派生**：Built-in Entry 没有脚本却是 Finder 里
真实可见的菜单项，派生会让它读成不可用。

阶梯需要区分「不可用」与「部分可用」，这同样不能从 `scriptBacked.isEmpty` 派生：组合命令
名称为空时条目不产出脚本（`isExecutable = false`），但步骤本身可能全合法。那是部分可用。
因此 `MenuEntryEvaluation` 带一个 `hasExecutableChildren` —— 阶梯真正需要的那个布尔量，
而不是两个语义不同的 ID 集合。

### 4. 「应用不存在」归校验，不归展示

它和 New File Template 的 `templatePathMissing` 是同一类规则 ——「配置指向的文件不在了」——
此前一个在 summary 里、一个在校验器里。现在都是 `.filesystemAware` 下的 error
（新增 `applicationMissing`）。

**发布门仍走 `.configurationOnly`**，所以「应用临时不在但脚本照编」的行为不变。
用户可能只是卸载了一次应用，不该因此丢掉已编译的 `.scpt`。

### 5. 徽章是运行状态，不是类型标签

`FinderMenuEntryStatusKind.command` 删除。它的值恒为「命令」，是类型标签而非运行状态；
`DESIGN.md` 的徽章词汇里没有它，而 `FinderMenuEntrySummary` 早已有独立的 `typeLabel`
字段装它。custom 命令项一旦走统一阶梯，它就不可能幸存。

`.system` 保留给 Built-in Entry —— 它没有脚本，阶梯从发布状态往下都不适用。

`DESIGN.md` 列出六个徽章，其中没有「有警告」，但代码里有且有意义（例如命令缺 `{path}`）。
本次保留现状，未裁剪 —— 那是文档缺口，不该由一次重构单方面决定。

### 6. 分三步落地

| 步骤 | 内容 | 状态 |
|---|---|---|
| ① | 合并成 evaluator、统一 Issue 类型、environment 显式化，行为逐位等价 | 已完成 |
| ② | 状态阶梯写成一份，custom 缺陷随之修复，`applicationMissing` 入校验 | 已完成 |
| ③ | composite 的 14 条英文 message 改中文 | 已完成 |

第①步刻意不改行为：先把测试网架好，再动逻辑 —— 沿用 [ADR-0004](0004-finder-menu-descriptor.md)
第②步的做法。

## 关于 golden 等价性测试

第①步落地时录了一份 golden：15 格语料 × `.configurationOnly` 的 `scriptBacked`
（含 fingerprint）与 `issues`，逐位钉死。原计划把它当脚手架、第②步做完就删。

**保留了，因为它不只是脚手架。** 第②步只动展示侧，config-only 的 golden 一字未变 ——
这恰好构成「发布门路径没有移动」的机器可验证证明。更要紧的是它钉住了 fingerprint：
fingerprint 一变，全部 `.scpt` 重编、已发出的 Finder 菜单因 tag 失配集体点不动，
而且没有任何编译错误会提醒你。删掉一张能捕捉这种事故的网，不划算。

一个反面教训值得记下：最初还写了一条「只有某一格会随 environment 变化」的断言。
它在这台机器上是绿的，只因为 `/Applications/Visual Studio Code.app` 恰好存在 ——
换台机器就会变红。已改成直接断言不变量本身（config-only 不产生任何依赖文件系统的
问题码），并把需要确定答案的用例改用注入探针。**凡是拿真实文件系统当 golden 输入的
断言，都是假绿灯。**

## 后果

### 正面

- 三份 Severity/Code/Issue/Result 收成一套；fingerprint 的三处定义收成一处
- 三个校验器在 RCMMShared 之外零引用，真正成为实现
- custom 项的三个「谎报就绪」情形修复，并首次被测试覆盖
- New File Menu 的模板发布失败现在会显示「同步失败」，此前只有「同步中」
- 「哪条路会碰文件系统」从纪律变成类型系统的事
- 删除 `NewFileMenuStatus` 及其独立的 kind 枚举，状态词汇合并为一套
- RCMMShared 用例 270 → 296

### 负面

- `MenuEntryIssueCode` 平铺 36 个 case，其中含五组「名称为空」、五组「名称过长」等同义项。
  未合并：没有任何生产代码按 code 分支，合并的收益是零、代价是全部断言重写。
  出现按 code 分支的消费者时再回来收敛。
- `MenuEntryEvaluation` 多一个 `hasExecutableChildren` 字段，需要本 ADR 解释它为何
  不能从 `scriptBacked` 派生
- 徽章文案变化未经真机回归 —— `RCMMAppTests` 在本机跑不起来，设置界面的渲染只能手工确认

### 风险

**第②步的真机回归尚未进行。** 需要确认的格子：custom 应用项在「应用已卸载」「脚本编译
失败」「配置刚改」三种状态下的徽章；custom 命令项的徽章不再恒为「命令」；New File Menu
在模板文件丢失时显示不可用。发布门未受影响这一点由 golden 覆盖，不需要手工验。

## 参考

- [CONTEXT.md](../../CONTEXT.md) — Menu Entry Evaluation 与 Menu Entry Status 术语
- [DESIGN.md](../../DESIGN.md) — 「Finder Menu Row」一节规定徽章词汇
- [ADR-0002](0002-deepen-script-compilation-pipeline.md) — 同类的「把散落职责收进一个 seam」
- [ADR-0004](0004-finder-menu-descriptor.md) — 「先架测试网、再动逻辑」的分步做法
- `/improve-codebase-architecture` 评审报告候选 1
