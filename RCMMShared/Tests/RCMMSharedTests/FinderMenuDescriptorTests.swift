import Foundation
import Testing
@testable import RCMMShared

@Suite("Finder Menu Descriptor 往返测试")
struct FinderMenuDescriptorTests {
    // MARK: - Helpers

    /// 让每个 Script-Backed Entry 都处于 `.current` 且 fingerprint 匹配，使其进入可见菜单。
    private func currentPublishStates(
        for entries: [MenuEntry]
    ) -> [String: ScriptPublishState] {
        var states: [String: ScriptPublishState] = [:]
        for entry in entries {
            for scriptBackedEntry in MenuEntryEvaluator.evaluate(entry).scriptBacked {
                states[scriptBackedEntry.id] = ScriptPublishState(
                    entryID: scriptBackedEntry.id,
                    status: .current,
                    fingerprint: scriptBackedEntry.fingerprint
                )
            }
        }
        return states
    }

    private func customEntry(appName: String, path: String) -> MenuEntry {
        .custom(
            MenuItemConfig(
                appName: appName,
                appPath: path
            )
        )
    }

    private func compositeEntry(name: String) -> MenuEntry {
        .composite(
            CompositeMenuItemConfig(
                name: name,
                steps: [
                    CompositeCommandStep(
                        kind: .shell,
                        name: "step",
                        commandTemplate: "open -a Terminal {path}"
                    ),
                ]
            )
        )
    }

    private func newFileEntry(
        name: String,
        templateNames: [String]
    ) -> MenuEntry {
        .newFile(
            NewFileMenuConfig(
                name: name,
                templates: templateNames.map { displayName in
                    NewFileTemplateConfig(
                        displayName: displayName,
                        fileExtension: "txt",
                        creationMode: .emptyFile
                    )
                }
            )
        )
    }

    // MARK: - 往返不变量

    @Test(
        "构造出的每个菜单项都能按 Finder 实测保真度反解回原 Script-Backed Entry",
        arguments: [MenuPresentationMode.flat, .nestedUnderRCMM]
    )
    func roundTripsEveryScriptBackedItem(mode: MenuPresentationMode) {
        let entries: [MenuEntry] = [
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
            customEntry(appName: "Code", path: "/Applications/Visual Studio Code.app"),
            customEntry(appName: "Ghostty", path: "/Applications/Ghostty.app"),
            compositeEntry(name: "VS Code + Terminal"),
            newFileEntry(name: "新建", templateNames: ["txt", "md"]),
        ]

        let snapshot = FinderMenuSnapshot(
            entries: entries,
            publishStates: currentPublishStates(for: entries),
            presentationMode: mode,
            applicationIcons: [:],
            generation: 1
        )

        let clicks = snapshot.observedScriptBackedClicks
        // 2 个 custom + 1 个 composite + 2 个模板
        #expect(clicks.count == 5)

        for click in clicks {
            let resolved = snapshot.resolve(click.fields).entry
            #expect(
                resolved?.id == click.scriptID,
                "标题 \(click.fields.title) 反解到 \(resolved?.id ?? "nil")，期望 \(click.scriptID)"
            )
        }
    }

    @Test("nestedUnderRCMM 把全部菜单项收进 RCMM 子菜单")
    func nestsUnderRootWhenRequested() {
        let entries = [customEntry(appName: "Code", path: "/Applications/Code.app")]
        let snapshot = FinderMenuSnapshot(
            entries: entries,
            publishStates: currentPublishStates(for: entries),
            presentationMode: .nestedUnderRCMM,
            applicationIcons: [:],
            generation: 1
        )

        #expect(snapshot.descriptors.count == 1)
        #expect(snapshot.descriptors.first?.title == FinderMenuDescriptorBuilder.rootTitle)
        #expect(snapshot.descriptors.first?.action == .container)
        #expect(snapshot.descriptors.first?.children.count == 1)
    }

    @Test("空菜单不产出 RCMM 父项")
    func emptyMenuProducesNoRoot() {
        let snapshot = FinderMenuSnapshot(
            entries: [],
            publishStates: [:],
            presentationMode: .nestedUnderRCMM,
            applicationIcons: [:],
            generation: 1
        )

        #expect(snapshot.descriptors.isEmpty)
    }

    // MARK: - 身份字段与图标

    @Test("custom 项标题按执行模式生成，图标优先用缓存的应用图标")
    func customTitleAndIconFollowExecutionMode() {
        let config = MenuItemConfig(
            appName: "Code",
            appPath: "/Applications/Code.app"
        )
        let iconData = Data([0x1, 0x2, 0x3])
        let entries = [MenuEntry.custom(config)]

        let snapshot = FinderMenuSnapshot(
            entries: entries,
            publishStates: currentPublishStates(for: entries),
            presentationMode: .flat,
            applicationIcons: [config.id.uuidString: iconData],
            generation: 1
        )

        let descriptor = snapshot.descriptors.first
        #expect(descriptor?.title == "用 Code 打开")
        #expect(descriptor?.icon == .applicationIcon(data: iconData, fallbackSymbolName: "app"))
        #expect(descriptor?.action == .scriptBacked(
            FinderMenuItemIdentity(
                scriptID: config.id.uuidString,
                tag: FinderMenuItemTag.encode(generation: 1, index: 0)
            )
        ))
    }

    @Test("模板项挂在父菜单下并带 creationMode 对应图标")
    func newFileTemplatesBecomeChildren() {
        let entries = [newFileEntry(name: "新建", templateNames: ["txt"])]
        let snapshot = FinderMenuSnapshot(
            entries: entries,
            publishStates: currentPublishStates(for: entries),
            presentationMode: .flat,
            applicationIcons: [:],
            generation: 1
        )

        let parent = snapshot.descriptors.first
        #expect(parent?.action == .container)
        #expect(parent?.children.count == 1)
        #expect(parent?.children.first?.title == "txt")
        #expect(parent?.children.first?.icon == .symbol("doc"))
    }

    // MARK: - 已确证的现存缺陷（第③步修复）

    @Test("同名 custom 项应各自路由到自己的脚本")
    func distinguishesCustomItemsWithSameAppName() {
        let entries = [
            customEntry(appName: "Code", path: "/Applications/Visual Studio Code.app"),
            customEntry(appName: "Code", path: "/Applications/Code - Insiders.app"),
        ]
        let snapshot = FinderMenuSnapshot(
            entries: entries,
            publishStates: currentPublishStates(for: entries),
            presentationMode: .flat,
            applicationIcons: [:],
            generation: 1
        )

        for click in snapshot.observedScriptBackedClicks {
            #expect(snapshot.resolve(click.fields).entry?.id == click.scriptID)
        }
    }

    @Test("同名 composite 项应各自路由到自己的脚本")
    func distinguishesCompositesWithSameName() {
        let entries = [
            compositeEntry(name: "构建"),
            compositeEntry(name: "构建"),
        ]
        let snapshot = FinderMenuSnapshot(
            entries: entries,
            publishStates: currentPublishStates(for: entries),
            presentationMode: .flat,
            applicationIcons: [:],
            generation: 1
        )

        for click in snapshot.observedScriptBackedClicks {
            #expect(snapshot.resolve(click.fields).entry?.id == click.scriptID)
        }
    }

    @Test("不同 New File 菜单下的同名模板应各自路由到自己的脚本")
    func distinguishesTemplatesWithSameNameAcrossMenus() {
        let entries = [
            newFileEntry(name: "新建文件", templateNames: ["txt"]),
            newFileEntry(name: "新建脚本", templateNames: ["txt"]),
        ]
        let snapshot = FinderMenuSnapshot(
            entries: entries,
            publishStates: currentPublishStates(for: entries),
            presentationMode: .flat,
            applicationIcons: [:],
            generation: 1
        )

        for click in snapshot.observedScriptBackedClicks {
            #expect(snapshot.resolve(click.fields).entry?.id == click.scriptID)
        }
    }

    // MARK: - 跨快照错位

    @Test("拿旧快照的点击去解析新快照，不得路由到别的脚本")
    func staleClickDoesNotResolveToAnotherEntry() {
        let removed = customEntry(appName: "Ghostty", path: "/Applications/Ghostty.app")
        let kept = customEntry(appName: "Code", path: "/Applications/Code.app")

        let oldEntries = [removed, kept]
        let oldSnapshot = FinderMenuSnapshot(
            entries: oldEntries,
            publishStates: currentPublishStates(for: oldEntries),
            presentationMode: .flat,
            applicationIcons: [:],
            generation: 1
        )

        let newEntries = [kept]
        let newSnapshot = FinderMenuSnapshot(
            entries: newEntries,
            publishStates: currentPublishStates(for: newEntries),
            presentationMode: .flat,
            applicationIcons: [:],
            generation: 1
        )

        let removedScriptID = MenuEntryEvaluator.evaluate(removed).scriptBacked.first!.id
        let staleClick = oldSnapshot.observedScriptBackedClicks.first {
            $0.scriptID == removedScriptID
        }!

        // 已删除的菜单项要么解析不出，要么仍指向自己 —— 绝不能落到 kept 上。
        let resolved = newSnapshot.resolve(staleClick.fields).entry
        #expect(resolved?.id != MenuEntryEvaluator.evaluate(kept).scriptBacked.first!.id)
    }

    // MARK: - tag 编码与失配

    @Test("tag 编码可往返，非 script-backed 项解码为 nil")
    func tagRoundTrips() {
        let tag = FinderMenuItemTag.encode(generation: 7, index: 42)
        let decoded = FinderMenuItemTag.decode(tag)

        #expect(decoded?.generation == 7)
        #expect(decoded?.index == 42)
        #expect(FinderMenuItemTag.decode(FinderMenuItemTag.none) == nil)
        #expect(FinderMenuItemTag.decode(-1) == nil)
    }

    @Test("generation 从 1 起，编码结果不会与非 script-backed 的 0 冲突")
    func firstGenerationNeverEncodesToNone() {
        #expect(FinderMenuItemTag.encode(generation: 1, index: 0) != FinderMenuItemTag.none)
        // generation 非法时退化为 none，宁可无法路由也不错位命中
        #expect(FinderMenuItemTag.encode(generation: 0, index: 5) == FinderMenuItemTag.none)
        #expect(
            FinderMenuItemTag.encode(
                generation: 1,
                index: FinderMenuItemTag.maximumIndex + 1
            ) == FinderMenuItemTag.none
        )
    }

    @Test("旧快照的点击在新快照上判为过期，而不是错位命中")
    func clickFromPreviousGenerationIsStale() {
        let entries = [
            customEntry(appName: "Code", path: "/Applications/Code.app"),
            customEntry(appName: "Ghostty", path: "/Applications/Ghostty.app"),
        ]
        let states = currentPublishStates(for: entries)

        let old = FinderMenuSnapshot(
            entries: entries,
            publishStates: states,
            presentationMode: .flat,
            applicationIcons: [:],
            generation: 1
        )
        // 同样的配置，但快照换了一代
        let new = FinderMenuSnapshot(
            entries: entries,
            publishStates: states,
            presentationMode: .flat,
            applicationIcons: [:],
            generation: 2
        )

        for click in old.observedScriptBackedClicks {
            #expect(new.resolve(click.fields) == .staleSnapshot)
        }
    }

    @Test("索引命中但标题不符时报告失配，不执行")
    func titleMismatchIsReported() {
        let entries = [customEntry(appName: "Code", path: "/Applications/Code.app")]
        let snapshot = FinderMenuSnapshot(
            entries: entries,
            publishStates: currentPublishStates(for: entries),
            presentationMode: .flat,
            applicationIcons: [:],
            generation: 1
        )

        let click = snapshot.observedScriptBackedClicks[0]
        let tampered = MenuItemFields(title: "用 别的东西 打开", tag: click.fields.tag)

        #expect(
            snapshot.resolve(tampered)
                == .titleMismatch(expected: "用 Code 打开", actual: "用 别的东西 打开")
        )
    }

    @Test("内置项与父项的 tag 判为非 script-backed")
    func containerAndBuiltInAreNotScriptBacked() {
        let entries = [
            MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
        ]
        let snapshot = FinderMenuSnapshot(
            entries: entries,
            publishStates: currentPublishStates(for: entries),
            presentationMode: .flat,
            applicationIcons: [:],
            generation: 1
        )

        #expect(snapshot.observedScriptBackedClicks.isEmpty)
        #expect(
            snapshot.resolve(
                MenuItemFields(title: "复制路径", tag: FinderMenuItemTag.none)
            ) == .notScriptBacked
        )
    }
}
