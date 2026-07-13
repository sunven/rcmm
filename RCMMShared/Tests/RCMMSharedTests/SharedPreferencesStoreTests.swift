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

    @Test("App Group 不可用时回退到 Application Scripts 共享 plist")
    func unavailableAppGroupFallbackUsesApplicationScripts() {
        let homeDirectory = URL(fileURLWithPath: "/Users/test", isDirectory: true)

        let url = SharedPreferencesStore.fallbackPreferencesURL(
            finderExtensionBundleID: "com.sunven.rcmm.FinderExtension",
            homeDirectory: homeDirectory
        )

        #expect(url.path == "/Users/test/Library/Application Scripts/com.sunven.rcmm.FinderExtension/rcmm.shared.plist")
        #expect(!url.path.contains("Library/Group Containers"))

        let resolvedURL = SharedPreferencesStore.appGroupPreferencesURL(
            appGroupID: "group.test.rcmm",
            finderExtensionBundleID: "com.sunven.rcmm.FinderExtension",
            fileManager: MissingAppGroupFileManager()
        )

        #expect(resolvedURL.path.hasSuffix("/Library/Application Scripts/com.sunven.rcmm.FinderExtension/rcmm.shared.plist"))
        #expect(!resolvedURL.path.contains("Library/Group Containers"))
    }

    @Test("多个 property list store 并发写不同 key 不会互相覆盖")
    func concurrentPropertyListWritesPreserveAllKeys() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory
            .appendingPathComponent("Library/Preferences", isDirectory: true)
            .appendingPathComponent("group.test.rcmm")
            .appendingPathExtension("plist")
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let queue = DispatchQueue(label: "shared.preferences.tests", attributes: .concurrent)
        let group = DispatchGroup()
        let writeCount = 80

        for index in 0..<writeCount {
            group.enter()
            queue.async {
                let store = SharedPreferencesStore(propertyListURL: url)
                store.set("value-\(index)", forKey: "key-\(index)")
                group.leave()
            }
        }
        group.wait()

        let reloaded = SharedPreferencesStore(propertyListURL: url)
        for index in 0..<writeCount {
            #expect(reloaded.string(forKey: "key-\(index)") == "value-\(index)")
        }
    }

    @Test("共享服务并发写不同 plist key 时都能保留")
    func sharedServicesConcurrentWritesPreserveIndependentDomains() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory
            .appendingPathComponent("Library/Preferences", isDirectory: true)
            .appendingPathComponent("group.test.rcmm")
            .appendingPathExtension("plist")
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let queue = DispatchQueue(label: "shared.services.tests", attributes: .concurrent)
        let group = DispatchGroup()
        group.enter()
        queue.async {
            SharedConfigService(preferences: SharedPreferencesStore(propertyListURL: url))
                .saveEntries([
                    .custom(MenuItemConfig(appName: "Terminal", appPath: "/Applications/Terminal.app")),
                ])
            group.leave()
        }
        group.enter()
        queue.async {
            ScriptPublishStore(preferences: SharedPreferencesStore(propertyListURL: url))
                .upsert(ScriptPublishState(entryID: "entry-1", status: .current, fingerprint: "fingerprint"))
            group.leave()
        }
        group.enter()
        queue.async {
            SharedErrorQueue(preferences: SharedPreferencesStore(propertyListURL: url))
                .upsert(ErrorRecord(source: "test", message: "failed", key: "error-1"))
            group.leave()
        }
        group.wait()

        let configService = SharedConfigService(preferences: SharedPreferencesStore(propertyListURL: url))
        let publishStore = ScriptPublishStore(preferences: SharedPreferencesStore(propertyListURL: url))
        let errorQueue = SharedErrorQueue(preferences: SharedPreferencesStore(propertyListURL: url))

        #expect(configService.loadEntries().map(\.displayName) == ["Terminal"])
        #expect(publishStore.state(for: "entry-1")?.fingerprint == "fingerprint")
        #expect(errorQueue.loadAll().map(\.key) == ["error-1"])
    }
}

private final class MissingAppGroupFileManager: FileManager {
    override func containerURL(
        forSecurityApplicationGroupIdentifier groupIdentifier: String
    ) -> URL? {
        nil
    }
}
