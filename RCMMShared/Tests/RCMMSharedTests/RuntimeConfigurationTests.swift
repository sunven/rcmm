import Foundation
import Testing
@testable import RCMMShared

@Suite("RuntimeConfiguration 测试")
struct RuntimeConfigurationTests {
    @Test("缺失或未展开的 build setting 使用 fallback")
    func fallsBackForMissingOrUnexpandedValues() {
        #expect(
            RuntimeConfiguration.stringValue(
                for: "MissingKey",
                fallback: "fallback"
            ) == "fallback"
        )
        #expect(
            RuntimeConfiguration.stringValue(
                for: "RCMMAppGroupIdentifier",
                fallback: "fallback",
                bundle: makeBundle(info: ["RCMMAppGroupIdentifier": "$(RCMM_APP_GROUP_IDENTIFIER)"])
            ) == "fallback"
        )
    }

    @Test("Info.plist 中的运行时标识优先于默认值")
    func readsConfiguredIdentifierFromBundleInfo() {
        let bundle = makeBundle(info: [
            "RCMMFinderExtensionBundleIdentifier": "com.example.debug.FinderExtension"
        ])

        #expect(
            RuntimeConfiguration.stringValue(
                for: "RCMMFinderExtensionBundleIdentifier",
                fallback: "fallback",
                bundle: bundle
            ) == "com.example.debug.FinderExtension"
        )
    }

    @Test("Release 通知名前缀保持兼容，Debug 按 App Group 隔离")
    func notificationPrefixUsesDebugAppGroupOnlyWhenConfigured() {
        #expect(
            RuntimeConfiguration.notificationPrefix(
                appGroupID: "group.com.sunven.rcmm"
            ) == "com.sunven.rcmm"
        )
        #expect(
            RuntimeConfiguration.notificationPrefix(
                appGroupID: "group.com.sunven.rcmm.debug"
            ) == "group.com.sunven.rcmm.debug"
        )
    }

    private func makeBundle(info: [String: String]) -> Bundle {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        let contents = root.appendingPathComponent("Contents", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: contents,
            withIntermediateDirectories: true
        )
        let infoURL = contents.appendingPathComponent("Info.plist")
        let plist = NSMutableDictionary(dictionary: info)
        plist["CFBundleIdentifier"] = info["CFBundleIdentifier"] ?? UUID().uuidString
        plist["CFBundleExecutable"] = "TestBundle"
        plist.write(to: infoURL, atomically: true)
        return Bundle(url: root) ?? .main
    }
}
