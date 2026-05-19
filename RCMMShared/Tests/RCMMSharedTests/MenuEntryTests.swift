import Foundation
import Testing
@testable import RCMMShared

@Suite("MenuEntry 编解码测试")
struct MenuEntryTests {

    @Test("builtIn entry id 格式正确")
    func builtInId() {
        let entry = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))
        #expect(entry.id == "builtIn.copyPath")
    }

    @Test("custom entry id 使用 UUID")
    func customId() {
        let uuid = UUID()
        let config = MenuItemConfig(id: uuid, appName: "Test", appPath: "/test")
        let entry = MenuEntry.custom(config)
        #expect(entry.id == uuid.uuidString)
    }

    @Test("composite entry id 使用 UUID")
    func compositeId() {
        let uuid = UUID()
        let config = CompositeMenuItemConfig(id: uuid, name: "Pair", steps: [])
        let entry = MenuEntry.composite(config)
        #expect(entry.id == uuid.uuidString)
    }

    @Test("builtIn entry isEnabled 正确")
    func builtInIsEnabled() {
        let enabled = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))
        let disabled = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: false))
        #expect(enabled.isEnabled == true)
        #expect(disabled.isEnabled == false)
    }

    @Test("custom entry isEnabled 正确")
    func customIsEnabled() {
        let enabled = MenuEntry.custom(MenuItemConfig(appName: "T", appPath: "/t", isEnabled: true))
        let disabled = MenuEntry.custom(MenuItemConfig(appName: "T", appPath: "/t", isEnabled: false))
        #expect(enabled.isEnabled == true)
        #expect(disabled.isEnabled == false)
    }

    @Test("composite entry isEnabled 正确")
    func compositeIsEnabled() {
        let enabled = MenuEntry.composite(CompositeMenuItemConfig(name: "T", steps: [], isEnabled: true))
        let disabled = MenuEntry.composite(CompositeMenuItemConfig(name: "T", steps: [], isEnabled: false))
        #expect(enabled.isEnabled == true)
        #expect(disabled.isEnabled == false)
    }

    @Test("builtIn displayName 正确")
    func builtInDisplayName() {
        let entry = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))
        #expect(entry.displayName == "拷贝路径")
    }

    @Test("builtIn systemSymbolName 使用共享图标元数据")
    func builtInSystemSymbolName() {
        let item = BuiltInMenuItem(type: .copyPath, isEnabled: true)
        let entry = MenuEntry.builtIn(item)
        #expect(entry.systemSymbolName == item.iconName)
        #expect(entry.systemSymbolName == "doc.on.clipboard")
    }

    @Test("custom entry 没有 systemSymbolName")
    func customSystemSymbolName() {
        let entry = MenuEntry.custom(MenuItemConfig(appName: "Terminal", appPath: "/t"))
        #expect(entry.systemSymbolName == nil)
    }

    @Test("composite systemSymbolName 使用配置图标")
    func compositeSystemSymbolName() {
        let entry = MenuEntry.composite(
            CompositeMenuItemConfig(
                name: "Pair",
                iconName: "rectangle.split.2x1",
                steps: []
            )
        )
        #expect(entry.systemSymbolName == "rectangle.split.2x1")
    }

    @Test("custom displayName 使用 appName")
    func customDisplayName() {
        let entry = MenuEntry.custom(MenuItemConfig(appName: "Terminal", appPath: "/t"))
        #expect(entry.displayName == "Terminal")
    }

    @Test("composite displayName 使用 name")
    func compositeDisplayName() {
        let entry = MenuEntry.composite(CompositeMenuItemConfig(name: "VS Code + Terminal", steps: []))
        #expect(entry.displayName == "VS Code + Terminal")
    }

    @Test("Round-trip 编解码 builtIn entry")
    func roundTripBuiltIn() throws {
        let entry = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(MenuEntry.self, from: data)
        #expect(decoded == entry)
    }

    @Test("Round-trip 编解码 custom entry")
    func roundTripCustom() throws {
        let config = MenuItemConfig(appName: "Terminal", appPath: "/Applications/Utilities/Terminal.app")
        let entry = MenuEntry.custom(config)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(MenuEntry.self, from: data)
        #expect(decoded == entry)
    }

    @Test("Round-trip 编解码 composite entry")
    func roundTripComposite() throws {
        let config = CompositeMenuItemConfig(
            name: "VS Code + Terminal",
            steps: [
                CompositeCommandStep(
                    kind: .shell,
                    name: "Terminal",
                    commandTemplate: "open -a Terminal {path}"
                ),
            ]
        )
        let entry = MenuEntry.composite(config)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(MenuEntry.self, from: data)
        #expect(decoded == entry)
    }

    @Test("混合数组编解码保持顺序和类型")
    func mixedArrayRoundTrip() throws {
        let entries: [MenuEntry] = [
            .custom(MenuItemConfig(appName: "Terminal", appPath: "/t")),
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
            .composite(CompositeMenuItemConfig(name: "Pair", steps: [])),
            .custom(MenuItemConfig(appName: "iTerm", appPath: "/i")),
        ]
        let data = try JSONEncoder().encode(entries)
        let decoded = try JSONDecoder().decode([MenuEntry].self, from: data)
        #expect(decoded.count == 4)
        #expect(decoded[0].id == entries[0].id)
        #expect(decoded[1].id == "builtIn.copyPath")
        #expect(decoded[2].displayName == "Pair")
        #expect(decoded[3].id == entries[3].id)
    }

    @Test("isBuiltIn 判断正确")
    func isBuiltIn() {
        let builtIn = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))
        let custom = MenuEntry.custom(MenuItemConfig(appName: "T", appPath: "/t"))
        let composite = MenuEntry.composite(CompositeMenuItemConfig(name: "T", steps: []))
        #expect(builtIn.isBuiltIn == true)
        #expect(custom.isBuiltIn == false)
        #expect(composite.isBuiltIn == false)
    }

    @Test("currentDirectory 自定义命令无 appPath 时仍可生成脚本菜单项")
    func currentDirectoryCustomCommandIsScriptBackedWithoutAppPath() throws {
        let config = MenuItemConfig(
            appName: "Git Pull",
            appPath: "",
            customCommand: "git pull",
            executionMode: .currentDirectory
        )

        let scriptBackedEntry = try #require(
            MenuEntryScriptPolicy.scriptBackedEntry(for: .custom(config))
        )

        #expect(scriptBackedEntry.displayName == "Git Pull")
        #expect(scriptBackedEntry.kind == .custom)
    }

    @Test("自定义命令执行模式变化会改变 fingerprint")
    func customCommandExecutionModeChangesFingerprint() {
        let id = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let selectedPath = MenuItemConfig(
            id: id,
            appName: "Command",
            appPath: "/Applications/Terminal.app",
            customCommand: "open -a {app} {path}",
            executionMode: .selectedPath
        )
        let currentDirectory = MenuItemConfig(
            id: id,
            appName: "Command",
            appPath: "/Applications/Terminal.app",
            customCommand: "open -a {app} {path}",
            executionMode: .currentDirectory
        )

        #expect(
            MenuEntryScriptPolicy.fingerprint(for: selectedPath)
                != MenuEntryScriptPolicy.fingerprint(for: currentDirectory)
        )
    }
}
