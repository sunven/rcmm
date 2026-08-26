import Foundation
import Testing
@testable import RCMMShared

@Suite("BuiltInType 编解码测试")
struct BuiltInTypeTests {

    @Test("copyPath rawValue 为 copyPath")
    func copyPathRawValue() {
        #expect(BuiltInType.copyPath.rawValue == "copyPath")
    }

    @Test("cleanNodeModules rawValue 为 cleanNodeModules")
    func cleanNodeModulesRawValue() {
        #expect(BuiltInType.cleanNodeModules.rawValue == "cleanNodeModules")
        #expect(BuiltInType.cleanNodeModules.requiresPublishedScript)
        #expect(!BuiltInType.copyPath.requiresPublishedScript)
    }

    @Test("Round-trip 编解码保持值一致")
    func roundTrip() throws {
        let original = BuiltInType.cleanNodeModules
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BuiltInType.self, from: data)
        #expect(decoded == original)
    }
}
