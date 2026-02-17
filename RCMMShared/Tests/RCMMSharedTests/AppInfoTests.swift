import Foundation
import Testing
@testable import RCMMShared

@Suite("AppInfo 测试")
struct AppInfoTests {

    @Test("AppInfo 新增 category 字段 round-trip 编解码")
    func categoryRoundTrip() throws {
        let app = AppInfo(
            name: "Terminal",
            bundleId: "com.apple.Terminal",
            path: "/Applications/Utilities/Terminal.app",
            category: .terminal
        )
        let data = try JSONEncoder().encode(app)
        let decoded = try JSONDecoder().decode(AppInfo.self, from: data)
        #expect(decoded.category == .terminal)
        #expect(decoded == app)
    }

    @Test("旧数据无 category 字段可正常解码（向后兼容）")
    func backwardCompatibility() throws {
        let json = """
        {"id":"550E8400-E29B-41D4-A716-446655440000","name":"Test App","path":"/Applications/Test.app"}
        """
        let decoded = try JSONDecoder().decode(AppInfo.self, from: Data(json.utf8))
        #expect(decoded.name == "Test App")
        #expect(decoded.path == "/Applications/Test.app")
        #expect(decoded.category == nil)
        #expect(decoded.bundleId == nil)
    }

    @Test("AppInfo 含 category 为 nil 编解码")
    func nilCategoryRoundTrip() throws {
        let app = AppInfo(
            name: "Unknown App",
            path: "/Applications/Unknown.app"
        )
        #expect(app.category == nil)
        let data = try JSONEncoder().encode(app)
        let decoded = try JSONDecoder().decode(AppInfo.self, from: data)
        #expect(decoded.category == nil)
        #expect(decoded == app)
    }

    @Test("AppInfo 各种 category 值编解码")
    func allCategoryValues() throws {
        for category in AppCategory.allCases {
            let app = AppInfo(
                name: "App",
                path: "/Applications/App.app",
                category: category
            )
            let data = try JSONEncoder().encode(app)
            let decoded = try JSONDecoder().decode(AppInfo.self, from: data)
            #expect(decoded.category == category)
        }
    }

    @Test("AppInfo 保持 Identifiable, Hashable, Sendable")
    func protocolConformance() {
        let app = AppInfo(name: "Test", path: "/test")
        // Identifiable
        _ = app.id
        // Hashable
        var set = Set<AppInfo>()
        set.insert(app)
        #expect(set.count == 1)
    }
}
