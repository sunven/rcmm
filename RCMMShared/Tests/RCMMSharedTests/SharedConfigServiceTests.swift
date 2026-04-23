import Foundation
import Testing
@testable import RCMMShared

@Suite("SharedConfigService 读写测试", .serialized)
struct SharedConfigServiceTests {
    private struct LegacyMenuItemConfig: Codable, Equatable {
        let id: UUID
        var appName: String
        var bundleId: String?
        var appPath: String
        var customCommand: String?
        var sortOrder: Int
        var isEnabled: Bool
    }

    let defaults: UserDefaults
    let service: SharedConfigService
    let suiteName: String

    init() {
        suiteName = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        service = SharedConfigService(defaults: defaults)
    }

    private func cleanup() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test("保存后可正确读取 entries")
    func saveAndLoadEntries() throws {
        let entries: [MenuEntry] = [
            .custom(MenuItemConfig(appName: "Terminal", appPath: "/Applications/Utilities/Terminal.app")),
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
        ]
        service.saveEntries(entries)
        let loaded = service.loadEntries()
        #expect(loaded.count == 2)
        #expect(loaded[0].displayName == "Terminal")
        #expect(loaded[1].displayName == "拷贝路径")
        cleanup()
    }

    @Test("无数据时返回空数组")
    func emptyDefaults() {
        let loaded = service.loadEntries()
        #expect(loaded.isEmpty)
        cleanup()
    }

    @Test("覆盖写入替换旧数据")
    func overwrite() {
        service.saveEntries([.custom(MenuItemConfig(appName: "Old", appPath: "/old"))])
        service.saveEntries([.custom(MenuItemConfig(appName: "New", appPath: "/new"))])
        let loaded = service.loadEntries()
        #expect(loaded.count == 1)
        #expect(loaded[0].displayName == "New")
        cleanup()
    }

    @Test("混合数组保持顺序")
    func mixedOrderPreserved() {
        let entries: [MenuEntry] = [
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
            .custom(MenuItemConfig(appName: "Terminal", appPath: "/t")),
            .custom(MenuItemConfig(appName: "iTerm", appPath: "/i")),
        ]
        service.saveEntries(entries)
        let loaded = service.loadEntries()
        #expect(loaded[0].id == "builtIn.copyPath")
        #expect(loaded[1].displayName == "Terminal")
        #expect(loaded[2].displayName == "iTerm")
        cleanup()
    }

    @Test("缺失 unified key 时从 legacy keys 迁移")
    func loadLegacyKeysWhenUnifiedEntriesMissing() throws {
        let legacyItems = [
            LegacyMenuItemConfig(
                id: UUID(),
                appName: "Warp",
                bundleId: "dev.warp.Warp-Stable",
                appPath: "/Applications/Warp.app",
                customCommand: nil,
                sortOrder: 0,
                isEnabled: true
            ),
            LegacyMenuItemConfig(
                id: UUID(),
                appName: "Cursor",
                bundleId: "com.todesktop.230313mzl4w4u92",
                appPath: "/Applications/Cursor.app",
                customCommand: nil,
                sortOrder: 1,
                isEnabled: false
            ),
        ]
        defaults.set(try JSONEncoder().encode(legacyItems), forKey: "rcmm.menu.items")
        defaults.set(true, forKey: "rcmm.copyPath.enabled")

        let loaded = service.loadEntries()

        #expect(loaded.count == 3)
        if loaded.count == 3 {
            #expect(loaded[0].displayName == "Warp")
            #expect(loaded[0].isEnabled == true)
            #expect(loaded[1].displayName == "Cursor")
            #expect(loaded[1].isEnabled == false)
            #expect(loaded[2].displayName == "拷贝路径")
            #expect(loaded[2].isBuiltIn == true)
        }
        #expect(defaults.data(forKey: SharedKeys.menuEntries) != nil)
        cleanup()
    }

    @Test("保存 unified entries 时同步镜像 legacy keys")
    func saveEntriesMirrorsLegacyKeys() throws {
        let entries: [MenuEntry] = [
            .custom(MenuItemConfig(appName: "Warp", appPath: "/Applications/Warp.app")),
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: false)),
            .custom(MenuItemConfig(appName: "Code", appPath: "/Applications/Visual Studio Code.app", isEnabled: false)),
        ]

        service.saveEntries(entries)

        let legacyCopyPathEnabled = defaults.bool(forKey: "rcmm.copyPath.enabled")
        #expect(legacyCopyPathEnabled == false)

        guard let legacyData = defaults.data(forKey: "rcmm.menu.items") else {
            Issue.record("legacy menu items should be mirrored")
            cleanup()
            return
        }

        let legacyItems = try JSONDecoder().decode([LegacyMenuItemConfig].self, from: legacyData)
        #expect(legacyItems.count == 2)
        #expect(legacyItems[0].appName == "Warp")
        #expect(legacyItems[0].sortOrder == 0)
        #expect(legacyItems[0].isEnabled == true)
        #expect(legacyItems[1].appName == "Code")
        #expect(legacyItems[1].sortOrder == 1)
        #expect(legacyItems[1].isEnabled == false)
        cleanup()
    }
}
