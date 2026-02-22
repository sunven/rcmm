import Foundation
import Testing
@testable import RCMMShared

@Suite("CommandMappingService 测试")
struct CommandMappingServiceTests {

    // MARK: - 内置命令映射测试

    @Test("kitty bundleId 返回正确命令")
    func kittyCommand() {
        let command = CommandMappingService.command(for: "net.kovidgoyal.kitty")
        #expect(command != nil)
        #expect(command == "/Applications/kitty.app/Contents/MacOS/kitty --single-instance --directory {path}")
    }

    @Test("Alacritty bundleId 返回正确命令")
    func alacrittyCommand() {
        let command = CommandMappingService.command(for: "org.alacritty")
        #expect(command != nil)
        #expect(command == "/Applications/Alacritty.app/Contents/MacOS/alacritty --working-directory {path}")
    }

    @Test("WezTerm bundleId 返回正确命令")
    func weztermCommand() {
        let command = CommandMappingService.command(for: "com.github.wez.wezterm")
        #expect(command != nil)
        #expect(command == "/Applications/WezTerm.app/Contents/MacOS/wezterm start --cwd {path}")
    }

    @Test("未知 bundleId 返回 nil")
    func unknownBundleId() {
        #expect(CommandMappingService.command(for: "com.example.unknown") == nil)
        #expect(CommandMappingService.command(for: "com.apple.Terminal") == nil)
    }

    @Test("nil bundleId 返回 nil")
    func nilBundleId() {
        let nilId: String? = nil
        #expect(CommandMappingService.command(for: nilId) == nil)
    }

    @Test("所有内置映射命令包含 {path} 占位符")
    func allMappingsContainPathPlaceholder() {
        let bundleIds = ["net.kovidgoyal.kitty", "org.alacritty", "com.github.wez.wezterm"]
        for bundleId in bundleIds {
            let command = CommandMappingService.command(for: bundleId)
            #expect(command != nil, "Expected command for \(bundleId)")
            #expect(command?.contains("{path}") == true, "Command for \(bundleId) should contain {path} placeholder")
        }
    }

    @Test("内置映射命令中 {path} 占位符不被引号包裹")
    func pathPlaceholderNotQuoted() {
        let bundleIds = ["net.kovidgoyal.kitty", "org.alacritty", "com.github.wez.wezterm"]
        for bundleId in bundleIds {
            let command = CommandMappingService.command(for: bundleId)
            #expect(command != nil)
            // {path} 不应被双引号包裹，否则 AppleScript 字符串拼接会失败
            #expect(command?.contains("\"{path}\"") == false,
                    "Command for \(bundleId) must not wrap {path} in quotes — causes AppleScript concatenation bug")
        }
    }
}
