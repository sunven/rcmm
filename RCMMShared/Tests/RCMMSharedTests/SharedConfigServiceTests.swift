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

    @Test("保存后可正确读取")
    func saveAndLoad() throws {
        let items = [MenuItemConfig(appName: "Terminal", appPath: "/Applications/Utilities/Terminal.app", sortOrder: 0)]
        service.save(items)
        let loaded = service.load()
        #expect(loaded == items)
        cleanup()
    }

    @Test("无数据时返回空数组")
    func emptyDefaults() {
        let loaded = service.load()
        #expect(loaded.isEmpty)
        cleanup()
    }

    @Test("覆盖写入替换旧数据")
    func overwrite() {
        service.save([MenuItemConfig(appName: "Old", appPath: "/old", sortOrder: 0)])
        service.save([MenuItemConfig(appName: "New", appPath: "/new", sortOrder: 0)])
        let loaded = service.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.appName == "New")
        cleanup()
    }
}
