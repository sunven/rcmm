import Foundation
import Testing
@testable import RCMMShared

@Suite("SharedConfigService 读写测试", .serialized)
struct SharedConfigServiceTests {
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
}
