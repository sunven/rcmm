import Testing
@testable import RCMMShared

@Suite("FinderMenuIconPolicy 测试")
struct FinderMenuIconPolicyTests {
    @Test("普通应用菜单项使用轻量占位图标并允许后台预热真实图标")
    func selectedPathApplicationUsesPlaceholderAndPreloadsIcon() {
        let config = MenuItemConfig(
            appName: "Code",
            appPath: "/Applications/Visual Studio Code.app",
            executionMode: .selectedPath
        )

        #expect(FinderMenuIconPolicy.placeholderSymbolName(for: config) == "app")
        #expect(FinderMenuIconPolicy.shouldPreloadApplicationIcon(for: config))
    }

    @Test("当前目录命令使用终端符号且不预热 app 图标")
    func currentDirectoryCommandUsesTerminalSymbolWithoutPreloadingIcon() {
        let config = MenuItemConfig(
            appName: "Git Pull",
            appPath: "",
            customCommand: "git pull",
            executionMode: .currentDirectory
        )

        #expect(FinderMenuIconPolicy.placeholderSymbolName(for: config) == "terminal")
        #expect(!FinderMenuIconPolicy.shouldPreloadApplicationIcon(for: config))
    }

    @Test("空 appPath 不触发后台图标预热")
    func emptyApplicationPathDoesNotPreloadIcon() {
        let config = MenuItemConfig(
            appName: "Missing",
            appPath: "   ",
            executionMode: .selectedPath
        )

        #expect(!FinderMenuIconPolicy.shouldPreloadApplicationIcon(for: config))
    }
}
