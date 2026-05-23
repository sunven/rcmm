import Foundation
import Testing
@testable import RCMMShared

@Suite("NewFileMenuPolicy 测试")
struct NewFileMenuPolicyTests {
    @Test("primaryNewFileMenu 选择第一个 newFile entry")
    func primaryNewFileMenuUsesFirstEntry() {
        let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let entries: [MenuEntry] = [
            .custom(MenuItemConfig(appName: "Terminal", appPath: "/Terminal.app")),
            .newFile(NewFileMenuConfig(id: firstID, name: "新建")),
            .newFile(NewFileMenuConfig(id: secondID, name: "新建 2")),
        ]

        let config = NewFileMenuPolicy.primaryNewFileMenu(in: entries)

        #expect(config?.id == firstID)
    }

    @Test("ensurePrimaryNewFileMenu 在缺失时追加默认 newFile")
    func ensurePrimaryNewFileMenuAppendsDefaultWhenMissing() {
        let menuID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let entries: [MenuEntry] = [
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
        ]

        let result = NewFileMenuPolicy.ensurePrimaryNewFileMenu(in: entries) {
            NewFileMenuConfig(id: menuID, name: "新建")
        }

        #expect(result.didInsert)
        #expect(result.menuID == menuID)
        #expect(result.entries.count == 2)
        #expect(NewFileMenuPolicy.primaryNewFileMenuID(in: result.entries) == menuID)
    }

    @Test("ensurePrimaryNewFileMenu 已存在时不重复插入")
    func ensurePrimaryNewFileMenuIsIdempotent() {
        let menuID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let entries: [MenuEntry] = [
            .newFile(NewFileMenuConfig(id: menuID, name: "新建")),
        ]

        let first = NewFileMenuPolicy.ensurePrimaryNewFileMenu(in: entries)
        let second = NewFileMenuPolicy.ensurePrimaryNewFileMenu(in: first.entries)

        #expect(!first.didInsert)
        #expect(!second.didInsert)
        #expect(second.entries == entries)
        #expect(second.menuID == menuID)
    }

    @Test("ensurePrimaryNewFileMenu 合并并移除重复 newFile entry")
    func ensurePrimaryNewFileMenuMergesDuplicateEntries() {
        let primaryID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let duplicateID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let txtID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let mdID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let entries: [MenuEntry] = [
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
            .newFile(NewFileMenuConfig(
                id: primaryID,
                name: "新建",
                templates: [
                    NewFileTemplateConfig(
                        id: txtID,
                        displayName: "txt",
                        fileExtension: "txt",
                        creationMode: .emptyFile
                    ),
                ]
            )),
            .custom(MenuItemConfig(appName: "Terminal", appPath: "/Terminal.app")),
            .newFile(NewFileMenuConfig(
                id: duplicateID,
                name: "其他新建",
                templates: [
                    NewFileTemplateConfig(
                        id: mdID,
                        displayName: "md",
                        fileExtension: "md",
                        creationMode: .emptyFile
                    ),
                ]
            )),
        ]

        let result = NewFileMenuPolicy.ensurePrimaryNewFileMenu(in: entries)

        #expect(!result.didInsert)
        #expect(result.didNormalize)
        #expect(result.didChange)
        #expect(result.menuID == primaryID)
        #expect(result.entries.count == 3)
        #expect(result.entries.filter {
            if case .newFile = $0 { return true }
            return false
        }.count == 1)
        #expect(NewFileMenuPolicy.primaryNewFileMenu(in: result.entries)?.templates.map(\.id) == [txtID, mdID])
    }

    @Test("ensurePrimaryNewFileMenu 合并重复模板名时保持可执行名称唯一")
    func ensurePrimaryNewFileMenuRenamesDuplicateTemplateNames() {
        let primaryID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let duplicateID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let entries: [MenuEntry] = [
            .newFile(NewFileMenuConfig(
                id: primaryID,
                templates: [
                    NewFileTemplateConfig(
                        displayName: "txt",
                        fileExtension: "txt",
                        creationMode: .emptyFile
                    ),
                ]
            )),
            .newFile(NewFileMenuConfig(
                id: duplicateID,
                templates: [
                    NewFileTemplateConfig(
                        displayName: "txt",
                        fileExtension: "md",
                        creationMode: .emptyFile
                    ),
                ]
            )),
        ]

        let result = NewFileMenuPolicy.ensurePrimaryNewFileMenu(in: entries)
        let menu = NewFileMenuPolicy.primaryNewFileMenu(in: result.entries)

        #expect(menu?.templates.map(\.displayName) == ["txt", "txt 2"])
        #expect(NewFileMenuValidator.validate(menu!).isExecutable)
    }

    @Test("ensurePrimaryNewFileMenu 保留重复启用菜单的可见性")
    func ensurePrimaryNewFileMenuPreservesEnabledDuplicateVisibility() {
        let primaryID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let duplicateID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let entries: [MenuEntry] = [
            .newFile(NewFileMenuConfig(
                id: primaryID,
                templates: [
                    NewFileTemplateConfig(
                        displayName: "txt",
                        fileExtension: "txt",
                        creationMode: .emptyFile
                    ),
                ],
                isEnabled: false
            )),
            .newFile(NewFileMenuConfig(
                id: duplicateID,
                templates: [
                    NewFileTemplateConfig(
                        displayName: "md",
                        fileExtension: "md",
                        creationMode: .emptyFile
                    ),
                ],
                isEnabled: true
            )),
        ]

        let result = NewFileMenuPolicy.ensurePrimaryNewFileMenu(in: entries)
        let menu = NewFileMenuPolicy.primaryNewFileMenu(in: result.entries)

        #expect(menu?.id == primaryID)
        #expect(menu?.isEnabled == true)
        #expect(menu?.templates.map(\.isEnabled) == [false, true])
        #expect(NewFileMenuValidator.validate(menu!).isExecutable)
    }
}
