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

    @Test("共享配置路径落在扩展的 Application Scripts 目录内")
    func sharedPreferencesURLUsesApplicationScripts() {
        let url = SharedPaths.extensionScriptsPreferencesURL(
            finderExtensionBundleID: "com.sunven.rcmm.FinderExtension"
        )

        #expect(url.path.hasSuffix(
            "/Library/Application Scripts/com.sunven.rcmm.FinderExtension/rcmm.shared.plist"
        ))
        #expect(!url.path.contains("Library/Group Containers"))
    }

    @Test("错误队列路径落在扩展沙盒容器内")
    func errorQueueURLUsesExtensionContainer() {
        let url = SharedPaths.extensionContainerErrorQueueURL(
            finderExtensionBundleID: "com.sunven.rcmm.FinderExtension"
        )

        #expect(url.path.hasSuffix(
            "/Library/Containers/com.sunven.rcmm.FinderExtension/Data/Library/Preferences/rcmm.errors.plist"
        ))
        #expect(!url.path.contains("Library/Group Containers"))
    }

    @Test("目录不存在时 requireExisting 策略放弃写入")
    func requireExistingPolicySkipsWriteWhenDirectoryMissing() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("rcmm.errors.plist")
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = SharedPreferencesStore(
            propertyListURL: url,
            directoryPolicy: .requireExisting
        )
        store.set("value", forKey: "key")

        #expect(!FileManager.default.fileExists(atPath: url.path))

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        store.set("value", forKey: "key")

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(SharedPreferencesStore(propertyListURL: url).string(forKey: "key") == "value")
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
