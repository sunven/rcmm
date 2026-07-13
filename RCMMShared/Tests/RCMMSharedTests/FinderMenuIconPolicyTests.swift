import Testing
@testable import RCMMShared

@Suite("FinderMenuIconPolicy 测试")
struct FinderMenuIconPolicyTests {
    @Test("普通应用菜单项只使用系统占位图标，不读取 app bundle")
    func selectedPathApplicationUsesPlaceholderWithoutPreloadingIcon() {
        let config = MenuItemConfig(
            appName: "Code",
            appPath: "/Applications/Visual Studio Code.app",
            executionMode: .selectedPath
        )

        #expect(FinderMenuIconPolicy.placeholderSymbolName(for: config) == "app")
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
    }
}
