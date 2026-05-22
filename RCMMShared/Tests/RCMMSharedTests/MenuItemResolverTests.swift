import Foundation
import Testing
@testable import RCMMShared

@Suite("MenuItemResolver 测试")
struct MenuItemResolverTests {
    @Test("优先使用 representedObject 中的配置 ID")
    func resolvesByRepresentedObjectID() {
        let items = makeItems()

        let result = MenuItemResolver.customItem(
            in: items,
            representedObject: items[1].id.uuidString,
            tag: 0,
            title: "用 Ghostty 打开"
        )

        #expect(result?.appName == "Code")
    }

    @Test("representedObject 缺失时使用 tag 回退")
    func resolvesByTagWhenRepresentedObjectIsMissing() {
        let items = makeItems()

        let result = MenuItemResolver.customItem(
            in: items,
            representedObject: nil,
            tag: 1,
            title: "用 Code 打开"
        )

        #expect(result?.appName == "Code")
    }

    @Test("representedObject 和 tag 都不可用时使用菜单标题回退")
    func resolvesByMenuTitleWhenOtherIdentifiersAreMissing() {
        let items = makeItems()

        let result = MenuItemResolver.customItem(
            in: items,
            representedObject: nil,
            tag: -1,
            title: "用 Ghostty 打开"
        )

        #expect(result?.appName == "Ghostty")
    }

    @Test("tag 和标题冲突时优先使用标题避免错路由")
    func prefersMenuTitleWhenTagConflictsWithTitle() {
        let items = makeItems()

        let result = MenuItemResolver.customItem(
            in: items,
            representedObject: nil,
            tag: 0,
            title: "用 Code 打开"
        )

        #expect(result?.appName == "Code")
    }

    @Test("非自定义菜单标题不使用 tag 回退")
    func doesNotUseTagFallbackForNonCustomTitle() {
        let items = makeItems()

        let result = MenuItemResolver.customItem(
            in: items,
            representedObject: nil,
            tag: 0,
            title: "VS Code + Terminal"
        )

        #expect(result == nil)
    }

    @Test("脚本菜单解析优先使用唯一可见标题")
    func scriptBackedResolutionPrefersUniqueVisibleTitle() {
        let items = makeItems()
        let compositeID = "2D9111D2-45A8-428E-B399-B79F41DE7F8C"
        let entries = makeScriptBackedEntries(items: items, compositeID: compositeID)

        let result = MenuItemResolver.scriptBackedEntry(
            in: entries,
            customItems: items,
            representedObject: items[0].id.uuidString,
            identifier: nil,
            tag: 0,
            title: "VS Code + Terminal"
        )

        #expect(result?.id == compositeID)
    }

    @Test("脚本菜单 representedObject 缺失时可用 identifier 解析")
    func scriptBackedResolutionUsesIdentifierFallback() {
        let items = makeItems()
        let compositeID = "2D9111D2-45A8-428E-B399-B79F41DE7F8C"
        let entries = makeScriptBackedEntries(items: items, compositeID: compositeID)

        let result = MenuItemResolver.scriptBackedEntry(
            in: entries,
            customItems: items,
            representedObject: nil,
            identifier: compositeID,
            tag: -1,
            title: "未匹配标题"
        )

        #expect(result?.id == compositeID)
    }

    @Test("脚本菜单自定义项可见标题优先于陈旧 ID")
    func scriptBackedCustomResolutionPrefersVisibleTitle() {
        let items = makeItems()
        let entries = makeScriptBackedEntries(items: items, compositeID: nil)

        let result = MenuItemResolver.scriptBackedEntry(
            in: entries,
            customItems: items,
            representedObject: items[0].id.uuidString,
            identifier: nil,
            tag: 0,
            title: "用 Code 打开"
        )

        #expect(result?.id == items[1].id.uuidString)
    }

    @Test("新建模板用父菜单和子菜单标题回退解析")
    func newFileTemplateResolutionUsesParentAndChildTitle() {
        let menuID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let txtID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let otherID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let entries = [
            ScriptBackedMenuEntry(
                id: MenuEntryScriptPolicy.newFileScriptID(menuID: menuID, templateID: txtID),
                kind: .newFileTemplate,
                displayName: "txt",
                fingerprint: "txt",
                source: .newFileTemplate(menuID: menuID, templateID: txtID),
                targetPolicy: .containingDirectory,
                parentDisplayName: "新建"
            ),
            ScriptBackedMenuEntry(
                id: MenuEntryScriptPolicy.newFileScriptID(menuID: menuID, templateID: otherID),
                kind: .newFileTemplate,
                displayName: "txt",
                fingerprint: "other",
                source: .newFileTemplate(menuID: menuID, templateID: otherID),
                targetPolicy: .containingDirectory,
                parentDisplayName: "模板"
            ),
        ]

        let result = MenuItemResolver.scriptBackedEntry(
            in: entries,
            customItems: [],
            representedObject: nil,
            identifier: nil,
            tag: -1,
            title: "txt",
            parentMenuTitle: "新建"
        )

        #expect(result?.id == entries[0].id)
    }

    @Test("新建模板缺少父菜单标题且同名时不误解析")
    func newFileTemplateResolutionDoesNotGuessWhenDuplicateWithoutParentTitle() {
        let entries = [
            ScriptBackedMenuEntry(
                id: "one",
                kind: .newFileTemplate,
                displayName: "txt",
                fingerprint: "one",
                source: .newFileTemplate(menuID: UUID(), templateID: UUID()),
                targetPolicy: .containingDirectory,
                parentDisplayName: "新建"
            ),
            ScriptBackedMenuEntry(
                id: "two",
                kind: .newFileTemplate,
                displayName: "txt",
                fingerprint: "two",
                source: .newFileTemplate(menuID: UUID(), templateID: UUID()),
                targetPolicy: .containingDirectory,
                parentDisplayName: "模板"
            ),
        ]

        let result = MenuItemResolver.scriptBackedEntry(
            in: entries,
            customItems: [],
            representedObject: nil,
            identifier: nil,
            tag: -1,
            title: "txt"
        )

        #expect(result == nil)
    }

    @Test("新建模板缺少父菜单标题但子项标题唯一时可回退解析")
    func newFileTemplateResolutionFallsBackToUniqueChildTitle() {
        let entry = ScriptBackedMenuEntry(
            id: "one",
            kind: .newFileTemplate,
            displayName: "txt",
            fingerprint: "one",
            source: .newFileTemplate(menuID: UUID(), templateID: UUID()),
            targetPolicy: .containingDirectory,
            parentDisplayName: "新建"
        )

        let result = MenuItemResolver.scriptBackedEntry(
            in: [entry],
            customItems: [],
            representedObject: nil,
            identifier: nil,
            tag: -1,
            title: "txt"
        )

        #expect(result == entry)
    }

    @Test("能从中文菜单标题解析应用名")
    func parsesAppNameFromMenuTitle() {
        #expect(MenuItemResolver.appName(fromMenuTitle: "用 Visual Studio Code 打开") == "Visual Studio Code")
        #expect(MenuItemResolver.appName(fromMenuTitle: "拷贝路径") == nil)
        #expect(MenuItemResolver.appName(fromMenuTitle: "用  打开") == nil)
    }

    private func makeItems() -> [MenuItemConfig] {
        [
            MenuItemConfig(
                id: UUID(uuidString: "1EB4CA58-7345-4514-8A52-1AC62215797E")!,
                appName: "Ghostty",
                appPath: "/Applications/Ghostty.app"
            ),
            MenuItemConfig(
                id: UUID(uuidString: "603534E3-066A-4519-B245-D819B2D7BD64")!,
                appName: "Code",
                appPath: "/Applications/Visual Studio Code.app"
            ),
        ]
    }

    private func makeScriptBackedEntries(
        items: [MenuItemConfig],
        compositeID: String?
    ) -> [ScriptBackedMenuEntry] {
        var entries = items.map { item in
            ScriptBackedMenuEntry(
                id: item.id.uuidString,
                kind: .custom,
                displayName: item.appName,
                fingerprint: item.id.uuidString,
                source: .custom(id: item.id),
                targetPolicy: .selectedPath
            )
        }

        if let compositeID {
            entries.append(
                ScriptBackedMenuEntry(
                    id: compositeID,
                    kind: .composite,
                    displayName: "VS Code + Terminal",
                    fingerprint: compositeID,
                    source: .composite(
                        id: UUID(uuidString: compositeID)!,
                        executableStepIDs: []
                    ),
                    targetPolicy: .selectedPath
                )
            )
        }

        return entries
    }
}
