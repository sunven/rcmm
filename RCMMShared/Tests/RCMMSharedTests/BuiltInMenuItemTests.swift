import Foundation
import Testing
@testable import RCMMShared

@Suite("BuiltInMenuItem 编解码测试")
struct BuiltInMenuItemTests {

    @Test("copyPath displayName 为 拷贝路径")
    func copyPathDisplayName() {
        let item = BuiltInMenuItem(type: .copyPath, isEnabled: true)
        #expect(item.displayName == "拷贝路径")
    }

    @Test("Round-trip 编解码保持值一致")
    func roundTrip() throws {
        let item = BuiltInMenuItem(type: .copyPath, isEnabled: true)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BuiltInMenuItem.self, from: data)
        #expect(decoded == item)
    }

    @Test("禁用状态正确编解码")
    func disabledRoundTrip() throws {
        let item = BuiltInMenuItem(type: .copyPath, isEnabled: false)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BuiltInMenuItem.self, from: data)
        #expect(decoded.isEnabled == false)
    }
}
