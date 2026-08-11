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
            for scriptBackedEntry in MenuEntryScriptPolicy.scriptBackedEntries(for: entry) {
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
            applicationIcons: [:]
        )

        let clicks = snapshot.observedScriptBackedClicks
        // 2 个 custom + 1 个 composite + 2 个模板
        #expect(clicks.count == 5)

        for click in clicks {
            let resolved = snapshot.scriptBackedEntry(for: click.fields)
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
            applicationIcons: [:]
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
            applicationIcons: [:]
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
            applicationIcons: [config.id.uuidString: iconData]
        )

        let descriptor = snapshot.descriptors.first
        #expect(descriptor?.title == "用 Code 打开")
        #expect(descriptor?.icon == .applicationIcon(data: iconData, fallbackSymbolName: "app"))
        #expect(descriptor?.action == .scriptBacked(
            FinderMenuItemIdentity(scriptID: config.id.uuidString, tag: 0)
        ))
    }

    @Test("模板项挂在父菜单下并带 creationMode 对应图标")
    func newFileTemplatesBecomeChildren() {
        let entries = [newFileEntry(name: "新建", templateNames: ["txt"])]
        let snapshot = FinderMenuSnapshot(
            entries: entries,
            publishStates: currentPublishStates(for: entries),
            presentationMode: .flat,
            applicationIcons: [:]
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
            applicationIcons: [:]
        )

        withKnownIssue(
            "标题相同使唯一匹配失效，回退链会把两项都解析到第一个 —— 静默路由到错误的应用。第③步改用 tag 全局索引后修复。"
        ) {
            for click in snapshot.observedScriptBackedClicks {
                #expect(snapshot.scriptBackedEntry(for: click.fields)?.id == click.scriptID)
            }
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
            applicationIcons: [:]
        )

        withKnownIssue(
            "composite 的 tag 恒为 -1，标题唯一匹配失败后无索引可用，点击落空。第③步改用 tag 全局索引后修复。"
        ) {
            for click in snapshot.observedScriptBackedClicks {
                #expect(snapshot.scriptBackedEntry(for: click.fields)?.id == click.scriptID)
            }
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
            applicationIcons: [:]
        )

        withKnownIssue(
            "Finder 不回传父菜单标题，parentMenuTitle 恒为 nil，模板的父菜单区分从未生效，两个同名模板都点不动。第③步改用 tag 全局索引后修复。"
        ) {
            for click in snapshot.observedScriptBackedClicks {
                #expect(snapshot.scriptBackedEntry(for: click.fields)?.id == click.scriptID)
            }
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
            applicationIcons: [:]
        )

        let newEntries = [kept]
        let newSnapshot = FinderMenuSnapshot(
            entries: newEntries,
            publishStates: currentPublishStates(for: newEntries),
            presentationMode: .flat,
            applicationIcons: [:]
        )

        let removedScriptID = MenuEntryScriptPolicy.scriptBackedEntry(for: removed)!.id
        let staleClick = oldSnapshot.observedScriptBackedClicks.first {
            $0.scriptID == removedScriptID
        }!

        // 已删除的菜单项要么解析不出，要么仍指向自己 —— 绝不能落到 kept 上。
        let resolved = newSnapshot.scriptBackedEntry(for: staleClick.fields)
        #expect(resolved?.id != MenuEntryScriptPolicy.scriptBackedEntry(for: kept)!.id)
    }
}
