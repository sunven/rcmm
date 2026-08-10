import Testing
@testable import RCMMShared

struct ErrorRecordTests {
    @Test("运行期脚本错误 key 保留包含点号的脚本 ID")
    func runtimeScriptKeyRoundTripsDottedScriptID() {
        let scriptID = "11111111-1111-1111-1111-111111111111.22222222-2222-2222-2222-222222222222"
        let record = ErrorRecord(
            source: "extension",
            message: "load failed",
            key: ErrorRecord.runtimeScriptKey(scriptID: scriptID, kind: .scriptLoad),
            kind: .scriptLoad
        )

        #expect(record.runtimeScriptID == scriptID)
    }

    @Test("非运行期脚本错误不暴露运行期脚本 ID")
    func compileErrorHasNoRuntimeScriptID() {
        let record = ErrorRecord(
            source: "app",
            message: "compile failed",
            key: ErrorRecord.runtimeScriptKey(scriptID: "entry", kind: .scriptCompile),
            kind: .scriptCompile
        )

        #expect(record.runtimeScriptID == nil)
    }
}
