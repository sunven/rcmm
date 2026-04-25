import Foundation

struct SystemCommandResult: Sendable {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32
}

protocol SystemCommandRunning: Sendable {
    func run(executable: URL, arguments: [String]) throws -> SystemCommandResult
}

private final class ProcessPipeReader: @unchecked Sendable {
    private let handle: FileHandle
    private let group = DispatchGroup()
    private var data = Data()

    init(handle: FileHandle) {
        self.handle = handle
    }

    func start() {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            data = handle.readDataToEndOfFile()
            group.leave()
        }
    }

    func waitForData() -> Data {
        group.wait()
        return data
    }
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

        let stdoutReader = ProcessPipeReader(handle: stdoutPipe.fileHandleForReading)
        let stderrReader = ProcessPipeReader(handle: stderrPipe.fileHandleForReading)
        stdoutReader.start()
        stderrReader.start()

        defer {
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
        }

        do {
            try process.run()
            stdoutPipe.fileHandleForWriting.closeFile()
            stderrPipe.fileHandleForWriting.closeFile()
        } catch {
            stdoutPipe.fileHandleForWriting.closeFile()
            stderrPipe.fileHandleForWriting.closeFile()
            _ = stdoutReader.waitForData()
            _ = stderrReader.waitForData()
            throw error
        }

        process.waitUntilExit()

        let stdoutData = stdoutReader.waitForData()
        let stderrData = stderrReader.waitForData()

        return SystemCommandResult(
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self),
            terminationStatus: process.terminationStatus
        )
    }
}
