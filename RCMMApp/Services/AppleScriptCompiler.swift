import Foundation

protocol AppleScriptCompiling {
    func compile(source: String, outputURL: URL) throws
}

struct AppleScriptCompiler: AppleScriptCompiling {
    func compile(source: String, outputURL: URL) throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("applescript")
        try source.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osacompile")
        process.arguments = ["-o", outputURL.path, tempURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()

        let timeoutWorkItem = DispatchWorkItem { [weak process] in
            process?.terminate()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeoutWorkItem)

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeoutWorkItem.cancel()

        guard process.terminationStatus == 0 else {
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "AppleScriptCompiler",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorMsg]
            )
        }
    }
}
