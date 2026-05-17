import Foundation
import Testing
@testable import RCMMShared

@Suite("SharedErrorQueue 测试", .serialized)
struct SharedErrorQueueTests {
    let defaults: UserDefaults
    let queue: SharedErrorQueue
    let suiteName: String

    init() {
        suiteName = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        queue = SharedErrorQueue(defaults: defaults)
    }

    private func cleanup() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test("追加后可正确读取")
    func appendAndLoad() {
        let error = ErrorRecord(source: "extension", message: "Test error")
        queue.append(error)
        let loaded = queue.loadAll()
        #expect(loaded.count == 1)
        #expect(loaded.first?.message == "Test error")
        cleanup()
    }

    @Test("无数据时返回空数组")
    func emptyQueue() {
        let loaded = queue.loadAll()
        #expect(loaded.isEmpty)
        cleanup()
    }

    @Test("removeAll 清空所有记录")
    func removeAll() {
        queue.append(ErrorRecord(source: "app", message: "Error 1"))
        queue.append(ErrorRecord(source: "app", message: "Error 2"))
        queue.removeAll()
        let loaded = queue.loadAll()
        #expect(loaded.isEmpty)
        cleanup()
    }

    @Test("FIFO 淘汰超过 20 条记录")
    func fifoEviction() {
        for i in 1...25 {
            queue.append(ErrorRecord(source: "app", message: "Error \(i)"))
        }
        let loaded = queue.loadAll()
        #expect(loaded.count == 20)
        #expect(loaded.first?.message == "Error 6")
        #expect(loaded.last?.message == "Error 25")
        cleanup()
    }

    @Test("upsert 使用 key 去重")
    func keyedUpsertDeduplicates() {
        queue.upsert(
            ErrorRecord(
                source: "app",
                message: "Old",
                key: "script.entry.fingerprint.compile",
                kind: .scriptCompile
            )
        )
        queue.upsert(
            ErrorRecord(
                source: "app",
                message: "New",
                key: "script.entry.fingerprint.compile",
                kind: .scriptCompile
            )
        )

        let loaded = queue.loadAll()
        #expect(loaded.count == 1)
        #expect(loaded[0].message == "New")
        #expect(loaded[0].kind == .scriptCompile)
        cleanup()
    }

    @Test("remove key 只移除匹配记录")
    func removeKey() {
        queue.append(ErrorRecord(source: "app", message: "A", key: "a"))
        queue.append(ErrorRecord(source: "app", message: "B", key: "b"))

        queue.remove(key: "a")

        let loaded = queue.loadAll()
        #expect(loaded.map(\.message) == ["B"])
        cleanup()
    }

    @Test("removeAll where 按 predicate 删除记录")
    func removeAllWhere() {
        queue.append(ErrorRecord(source: "app", message: "A", kind: .scriptCompile))
        queue.append(ErrorRecord(source: "app", message: "B", kind: .scriptLoad))
        queue.append(ErrorRecord(source: "app", message: "C", kind: .scriptPublish))

        queue.removeAll { $0.kind == .scriptCompile || $0.kind == .scriptPublish }

        let loaded = queue.loadAll()
        #expect(loaded.map(\.message) == ["B"])
        cleanup()
    }
}
