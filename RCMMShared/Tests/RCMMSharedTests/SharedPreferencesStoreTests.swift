import Foundation
import Testing
@testable import RCMMShared

@Suite("SharedPreferencesStore 测试", .serialized)
struct SharedPreferencesStoreTests {
    @Test("property list 后端可读写多种共享值")
    func propertyListBackendReadsAndWritesValues() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory
            .appendingPathComponent("Library/Preferences", isDirectory: true)
            .appendingPathComponent("group.test.rcmm")
            .appendingPathExtension("plist")
        let store = SharedPreferencesStore(propertyListURL: url)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let data = Data("payload".utf8)
        store.set(data, forKey: "data")
        store.set("nested", forKey: "string")
        store.set(true, forKey: "bool")

        let reloaded = SharedPreferencesStore(propertyListURL: url)
        #expect(reloaded.data(forKey: "data") == data)
        #expect(reloaded.string(forKey: "string") == "nested")
        #expect(reloaded.bool(forKey: "bool") == true)

        reloaded.removeObject(forKey: "string")
        #expect(SharedPreferencesStore(propertyListURL: url).string(forKey: "string") == nil)
    }

    @Test("注入 UserDefaults 时保留测试隔离行为")
    func injectedUserDefaultsBackendIsSupported() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedPreferencesStore(defaults: defaults)
        defer {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }

        store.set("value", forKey: "key")

        #expect(defaults.string(forKey: "key") == "value")
        #expect(store.string(forKey: "key") == "value")
    }
}
