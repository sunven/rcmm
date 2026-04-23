import Foundation

struct SystemCommandResult: Sendable {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32
}

protocol SystemCommandRunning: Sendable {
    func run(executable: URL, arguments: [String]) throws -> SystemCommandResult
}

struct SystemCommandRunner: SystemCommandRunning {
    func run(executable: URL, arguments: [String]) throws -> SystemCommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return SystemCommandResult(
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self),
            terminationStatus: process.terminationStatus
        )
    }
}
