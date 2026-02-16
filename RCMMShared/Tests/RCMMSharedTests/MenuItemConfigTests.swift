import Foundation
import Testing
@testable import RCMMShared

@Suite("MenuItemConfig 编解码测试")
struct MenuItemConfigTests {

    @Test("Round-trip 编解码保持值一致")
    func roundTrip() throws {
        let item = MenuItemConfig(
            appName: "Terminal",
            appPath: "/Applications/Utilities/Terminal.app",
            sortOrder: 0
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MenuItemConfig.self, from: data)
        #expect(decoded == item)
    }

    @Test("解码时缺失可选字段使用 nil")
    func missingOptionalFields() throws {
        let json = """
        {"id":"550E8400-E29B-41D4-A716-446655440000","appName":"Test","appPath":"/test","sortOrder":0}
        """
        let item = try JSONDecoder().decode(MenuItemConfig.self, from: Data(json.utf8))
        #expect(item.bundleId == nil)
        #expect(item.customCommand == nil)
    }

    @Test("多实例编解码保持一致")
    func multipleItems() throws {
        let items = [
            MenuItemConfig(appName: "Terminal", appPath: "/Applications/Utilities/Terminal.app", sortOrder: 0),
            MenuItemConfig(appName: "iTerm", bundleId: "com.googlecode.iterm2", appPath: "/Applications/iTerm.app", customCommand: "open -a iTerm", sortOrder: 1),
        ]
        let data = try JSONEncoder().encode(items)
        let decoded = try JSONDecoder().decode([MenuItemConfig].self, from: data)
        #expect(decoded == items)
    }

    @Test("包含所有字段的完整编解码")
    func fullFields() throws {
        let item = MenuItemConfig(
            appName: "VS Code",
            bundleId: "com.microsoft.VSCode",
            appPath: "/Applications/Visual Studio Code.app",
            customCommand: "code",
            sortOrder: 5
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MenuItemConfig.self, from: data)
        #expect(decoded == item)
        #expect(decoded.bundleId == "com.microsoft.VSCode")
        #expect(decoded.customCommand == "code")
    }
}
