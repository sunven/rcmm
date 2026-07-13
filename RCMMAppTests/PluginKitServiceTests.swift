import Foundation
import Testing
@testable import rcmm

@Suite("PluginKitService tests", .serialized)
struct PluginKitServiceTests {
    @Test("切换到 Debug 扩展时先停用 Release，再启用 Debug 并重启 Finder")
    func activatesDebugExtensionExclusively() throws {
        let runner = RecordingSystemCommandRunner()

        try PluginKitService.activateCurrent(
            extensionBundleID: "com.sunven.rcmm.debug.FinderExtension",
            commandRunner: runner
        )

        #expect(runner.commands == [
            Command(
                executable: "/usr/bin/pluginkit",
                arguments: ["-e", "ignore", "-i", "com.sunven.rcmm.FinderExtension"]
            ),
            Command(
                executable: "/usr/bin/pluginkit",
                arguments: ["-e", "use", "-i", "com.sunven.rcmm.debug.FinderExtension"]
            ),
            Command(
                executable: "/usr/bin/killall",
                arguments: ["Finder"]
            ),
        ])
    }
}

private struct Command: Equatable {
    let executable: String
    let arguments: [String]
}

private final class RecordingSystemCommandRunner: SystemCommandRunning, @unchecked Sendable {
    private(set) var commands: [Command] = []

    func run(executable: URL, arguments: [String]) throws -> SystemCommandResult {
        commands.append(Command(executable: executable.path, arguments: arguments))
        return SystemCommandResult(stdout: "", stderr: "", terminationStatus: 0)
    }
}
