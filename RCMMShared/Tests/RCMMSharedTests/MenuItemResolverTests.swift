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
}
