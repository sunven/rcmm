import Foundation
import Testing
@testable import RCMMShared

@Suite("AppCategory 测试")
struct AppCategoryTests {

    // MARK: - AppCategory 基本测试

    @Test("AppCategory 枚举包含三种类型")
    func allCases() {
        let cases = AppCategory.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.terminal))
        #expect(cases.contains(.editor))
        #expect(cases.contains(.other))
    }

    @Test("AppCategory Comparable 排序: terminal < editor < other")
    func comparableOrdering() {
        #expect(AppCategory.terminal < AppCategory.editor)
        #expect(AppCategory.editor < AppCategory.other)
        #expect(AppCategory.terminal < AppCategory.other)
    }

    @Test("AppCategory sortWeight 正确")
    func sortWeights() {
        #expect(AppCategory.terminal.sortWeight == 0)
        #expect(AppCategory.editor.sortWeight == 1)
        #expect(AppCategory.other.sortWeight == 2)
    }

    @Test("AppCategory 编解码 round-trip")
    func codableRoundTrip() throws {
        for category in AppCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(AppCategory.self, from: data)
            #expect(decoded == category)
        }
    }

    @Test("AppCategory 数组按 Comparable 排序正确")
    func arraySorting() {
        let unsorted: [AppCategory] = [.other, .terminal, .editor, .other, .terminal]
        let sorted = unsorted.sorted()
        #expect(sorted == [.terminal, .terminal, .editor, .other, .other])
    }

    // MARK: - AppCategorizer 测试

    @Test("已知终端 bundleId 分类为 .terminal")
    func categorizeTerminals() {
        let terminalBundleIds = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "net.kovidgoyal.kitty",
            "org.alacritty",
            "com.github.wez.wezterm",
            "dev.warp.Warp-Stable",
            "co.zeit.hyper",
            "com.mitchellh.ghostty",
        ]
        for bundleId in terminalBundleIds {
            #expect(
                AppCategorizer.categorize(bundleId: bundleId) == .terminal,
                "Expected \(bundleId) to be .terminal"
            )
        }
    }

    @Test("已知编辑器 bundleId 分类为 .editor")
    func categorizeEditors() {
        let editorBundleIds = [
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92",
            "com.apple.dt.Xcode",
            "com.sublimetext.4",
            "com.sublimetext.3",
            "com.panic.Nova",
            "com.barebones.bbedit",
            "com.macromates.TextMate",
            "com.coteditor.CotEditor",
            "dev.zed.Zed",
        ]
        for bundleId in editorBundleIds {
            #expect(
                AppCategorizer.categorize(bundleId: bundleId) == .editor,
                "Expected \(bundleId) to be .editor"
            )
        }
    }

    @Test("未知 bundleId 分类为 .other")
    func categorizeUnknown() {
        #expect(AppCategorizer.categorize(bundleId: "com.example.unknown") == .other)
        #expect(AppCategorizer.categorize(bundleId: "org.random.app") == .other)
    }

    @Test("nil bundleId 分类为 .other")
    func categorizeNil() {
        #expect(AppCategorizer.categorize(bundleId: nil) == .other)
    }
}
