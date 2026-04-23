import Foundation
import Testing
@testable import RCMMShared

@Suite("ExtensionInstallHealthResolver 测试")
struct ExtensionInstallHealthTests {
    private let currentPath = "/Applications/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex"
    private let oldDebugPath = "/Users/test/Library/Developer/Xcode/DerivedData/rcmm/Build/Products/Debug/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex"

    @Test("当前进程已启用时直接视为当前安装正常")
    func currentProcessEnabledWins() {
        let report = ExtensionInstallHealthResolver.resolve(
            currentExtensionPath: currentPath,
            currentProcessExtensionEnabled: true,
            pluginKitOutput: nil
        )

        #expect(report.status == .enabled)
        #expect(report.enabledExtensionPaths.isEmpty)
    }

    @Test("pluginkit 包含当前安装路径时视为当前安装正常")
    func currentPathFoundInPluginKitOutput() {
        let report = ExtensionInstallHealthResolver.resolve(
            currentExtensionPath: currentPath,
            currentProcessExtensionEnabled: false,
            pluginKitOutput: """
            +    com.sunven.rcmm.FinderExtension(1.0.0)\tID-1\t2026-04-22 10:00:00 +0000\t\(currentPath)
            """
        )

        #expect(report.status == .enabled)
        #expect(report.enabledExtensionPaths == [currentPath])
    }

    @Test("只有旧安装路径启用时标记为另一份安装在工作")
    func otherInstallEnabled() {
        let report = ExtensionInstallHealthResolver.resolve(
            currentExtensionPath: currentPath,
            currentProcessExtensionEnabled: false,
            pluginKitOutput: """
            +    com.sunven.rcmm.FinderExtension(1.0.0)\tID-1\t2026-04-22 10:00:00 +0000\t\(oldDebugPath)
            """
        )

        #expect(report.status == .otherInstallationEnabled)
        #expect(report.enabledExtensionPaths == [oldDebugPath])
        #expect(report.primaryEnabledPath == oldDebugPath)
    }

    @Test("多份安装同时启用时标记为安装冲突")
    func multipleEnabledInstallationsConflict() {
        let report = ExtensionInstallHealthResolver.resolve(
            currentExtensionPath: currentPath,
            currentProcessExtensionEnabled: false,
            pluginKitOutput: """
            +    com.sunven.rcmm.FinderExtension(1.0.0)\tID-1\t2026-04-22 10:00:00 +0000\t\(currentPath)
            +    com.sunven.rcmm.FinderExtension(1.0.0)\tID-2\t2026-04-22 10:05:00 +0000\t\(oldDebugPath)
            """
        )

        #expect(report.status == .otherInstallationEnabled)
        #expect(report.enabledExtensionPaths == [currentPath, oldDebugPath])
    }

    @Test("没有启用项时标记为未启用")
    func noEnabledEntriesMeansDisabled() {
        let report = ExtensionInstallHealthResolver.resolve(
            currentExtensionPath: currentPath,
            currentProcessExtensionEnabled: false,
            pluginKitOutput: """
            =    com.sunven.rcmm.FinderExtension(1.0.0)\tID-1\t2026-04-22 10:00:00 +0000\t\(oldDebugPath)
            """
        )

        #expect(report.status == .disabled)
        #expect(report.enabledExtensionPaths.isEmpty)
    }

    @Test("无法读取 pluginkit 输出时保留未知状态")
    func nilPluginKitOutputIsUnknown() {
        let report = ExtensionInstallHealthResolver.resolve(
            currentExtensionPath: currentPath,
            currentProcessExtensionEnabled: false,
            pluginKitOutput: nil
        )

        #expect(report.status == .unknown)
        #expect(report.enabledExtensionPaths.isEmpty)
    }
}
