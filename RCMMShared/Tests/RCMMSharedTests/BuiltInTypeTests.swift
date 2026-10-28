import Foundation
import Testing
@testable import RCMMShared

@Suite("BuiltInType 编解码测试")
struct BuiltInTypeTests {

    @Test("copyPath 不需要脚本且没有清理语义")
    func copyPathMetadata() {
        #expect(BuiltInType.copyPath.rawValue == "copyPath")
        #expect(!BuiltInType.copyPath.requiresPublishedScript)
        #expect(!BuiltInType.copyPath.isCleanup)
        #expect(BuiltInType.copyPath.cleanupProfile == nil)
    }

    @Test("清理型内置项共享清理语义")
    func cleanupTypesMetadata() {
        let cases: [(type: BuiltInType, rawValue: String, noun: String)] = [
            (.cleanNodeModules, "cleanNodeModules", "node_modules"),
            (.cleanJavaTarget, "cleanJavaTarget", "Java target"),
            (.cleanRustTarget, "cleanRustTarget", "Rust target"),
        ]

        for (type, rawValue, noun) in cases {
            #expect(type.rawValue == rawValue)
            #expect(type.requiresPublishedScript)
            #expect(type.isCleanup)
            #expect(type.cleanupProfile?.noun == noun)
        }
    }

    @Test("Java 与 Rust 的空结果提示说明匹配条件", arguments: [
        BuiltInType.cleanNodeModules, .cleanJavaTarget, .cleanRustTarget,
    ])
    func emptyResultHints(type: BuiltInType) {
        switch type {
        case .cleanNodeModules:
            #expect(type.cleanupProfile?.emptyResultHint == nil)
        case .cleanJavaTarget:
            #expect(type.cleanupProfile?.emptyResultHint?.contains("pom.xml") == true)
        case .cleanRustTarget:
            #expect(type.cleanupProfile?.emptyResultHint?.contains("Cargo.toml") == true)
        case .copyPath:
            Issue.record("copyPath 不是清理型内置项")
        }
    }

    @Test("Round-trip 编解码保持值一致", arguments: BuiltInType.allCases)
    func roundTrip(original: BuiltInType) throws {
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BuiltInType.self, from: data)
        #expect(decoded == original)
    }
}
