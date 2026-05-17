import Foundation
import Testing
@testable import RCMMShared

@Suite("ScriptPublishStore 测试", .serialized)
struct ScriptPublishStoreTests {
    let defaults: UserDefaults
    let store: ScriptPublishStore
    let suiteName: String

    init() {
        suiteName = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = ScriptPublishStore(defaults: defaults)
    }

    private func cleanup() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test("upsert 后可读取发布状态")
    func upsertAndLoad() {
        let state = ScriptPublishState(
            entryID: "entry-1",
            status: .current,
            fingerprint: "abc"
        )

        store.upsert(state)

        #expect(store.state(for: "entry-1") == state)
        #expect(store.loadAll()["entry-1"] == state)
        cleanup()
    }

    @Test("removeAll except 会清理非预期状态")
    func removeAllExcept() {
        store.upsert(ScriptPublishState(entryID: "keep", status: .current, fingerprint: "a"))
        store.upsert(ScriptPublishState(entryID: "drop", status: .current, fingerprint: "b"))

        store.removeAll(except: ["keep"])

        let loaded = store.loadAll()
        #expect(loaded.keys.sorted() == ["keep"])
        cleanup()
    }

    @Test("compileFailed 状态可保存错误摘要")
    func failedStatePersistsSummary() {
        store.upsert(
            ScriptPublishState(
                entryID: "entry-1",
                status: .compileFailed,
                fingerprint: "abc",
                errorSummary: "compile failed"
            )
        )

        let loaded = store.state(for: "entry-1")
        #expect(loaded?.status == .compileFailed)
        #expect(loaded?.errorSummary == "compile failed")
        cleanup()
    }
}
