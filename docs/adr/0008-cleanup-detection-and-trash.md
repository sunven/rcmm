# ADR-0008: 清理型内置项按构建描述文件识别，并统一移到废纸篓

状态：已接受 (Accepted) - 2026-10-28

## 背景

新增“清理 Java target”和“清理 Rust target”时，`target` 是 Java 与 Rust 共用的目录名，
无关项目也可能有叫 `target` 的目录。可复用的既有实现只有 `清理 node_modules`：
它按目录名扫描，确认后用 `rm -rf` 永久删除。直接照搬会让两个新菜单互相扫到对方的目录，
也可能清理与构建无关的 `target`；永久删除则与用户对“清理”的可恢复预期不符。

## 决策

1. **扫描规则带构建上下文**：Java target 要求同级存在 `pom.xml` / `build.gradle` /
   `build.gradle.kts` / `build.xml`；Rust target 要求同级存在 `Cargo.toml`。node_modules
   保持按名匹配。扫描使用 `find ... -prune`，命中目录不再向下展开。
2. **删除改为移到废纸篓**：三个清理型内置项统一在发布的 AppleScript 里用
   `NSFileManager.trashItem`（AppleScriptObjC）移动目录，不再调用 `rm -rf`。移动失败不永久删除，
   保留原目录并把失败路径写入错误队列。
3. **共用清理管线**：扫描/移动使用统一 handler 名，扩展侧共用一套确认与进度面板；
   每个内置项只提供自己的扫描 filter 与展示名词。

## 为什么不选其他方案

- **纯按目录名扫描**：Java/Rust 会互相命中，并可能清理无关的 `target`。目录可恢复并不等于
  可以接受误伤。
- **用 `CACHEDIR.TAG` 识别 Rust**：更严格，但会漏掉从未构建或半清理的 target，且依赖
  Cargo 内部实现细节。
- **扩展内直接 `FileManager.trashItem`**：Finder 扩展沙盒不保证对扫描出的深层路径有写权限；
  现有清理通道本来就是通过 `NSUserAppleScriptTask` 执行的脚本（已验证可用）。
- **脚本里让 Finder 删除**：需要 Automation 授权，Finder 扩展无法可靠获得该授权；
  Foundation 的 `trashItem` 不需要 TCC，且保留“放回原处”能力。
- **失败时回退 `rm -rf`**：违背“移到废纸篓、永不永久删除”的产品承诺。

## 后果

- 删除可恢复，但磁盘空间在用户清空废纸篓前不会释放；确认面板与完成文案已明确说明。
- 找不到构建描述文件的 `target` 不会被清理，空结果提示会解释匹配条件。
- Java 覆盖 Maven、Ant 与自定义了 buildDir 的 Gradle 项目；Gradle 默认的 `build/` 不在本功能范围。
- node_modules 的脚本指纹升级（v5 → v6），旧脚本在重新发布前会被菜单快照隐藏。
- 新内置项在加载配置时自动补入并默认启用，与既有 Built-in Entry 一致；已存在的停用状态保留。
