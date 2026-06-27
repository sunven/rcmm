import Foundation
import RCMMShared
import Testing
@testable import rcmm

@Suite("Script Compilation Pipeline tests", .serialized)
struct ScriptCompilationPipelineTests {
    @Test("publishes saved Menu Entry configuration through one pipeline interface")
    func publishesSavedConfiguration() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }

        let itemID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let item = MenuItemConfig(
            id: itemID,
            appName: "Terminal",
            appPath: "/System/Applications/Utilities/Terminal.app"
        )
        harness.configService.saveEntries([.custom(item)])

        let outcome = await harness.pipeline.publishCurrentConfiguration()

        let scriptID = itemID.uuidString
        let scriptURL = harness.scriptsDirectory
            .appendingPathComponent(scriptID)
            .appendingPathExtension("scpt")

        #expect(outcome.results.map(\.entryID) == [scriptID])
        #expect(outcome.publishStates[scriptID]?.status == .current)
        #expect(outcome.errorRecords.isEmpty)
        #expect(harness.compiler.compiledSources.count == 1)
        #expect(harness.fileManager.fileExists(atPath: scriptURL.path))
        #expect(harness.notifier.postedConfigChangedCount == 1)
    }
}

private final class PipelineHarness {
    let suiteName: String
    let defaults: UserDefaults
    let fileManager: FileManager
    let temporaryRoot: URL
    let scriptsDirectory: URL
    let compiler: RecordingAppleScriptCompiler
    let notifier: RecordingScriptCompilationNotifier
    let configService: SharedConfigService
    let pipeline: ScriptCompilationPipeline

    init() throws {
        suiteName = "script.pipeline.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        fileManager = .default
        temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent("ScriptCompilationPipelineTests-\(UUID().uuidString)", isDirectory: true)
        scriptsDirectory = temporaryRoot.appendingPathComponent("Scripts", isDirectory: true)
        try fileManager.createDirectory(
            at: scriptsDirectory,
            withIntermediateDirectories: true
        )

        compiler = RecordingAppleScriptCompiler()
        notifier = RecordingScriptCompilationNotifier()
        configService = SharedConfigService(defaults: defaults)

        pipeline = ScriptCompilationPipeline(
            configService: configService,
            publishStore: ScriptPublishStore(defaults: defaults),
            errorQueue: SharedErrorQueue(defaults: defaults),
            compiler: compiler,
            sourceGenerator: ScriptSourceGenerator(),
            fileManager: fileManager,
            scriptsDirectory: scriptsDirectory,
            notifier: notifier
        )
    }

    func cleanup() {
        try? fileManager.removeItem(at: temporaryRoot)
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private final class RecordingAppleScriptCompiler: AppleScriptCompiling {
    private(set) var compiledSources: [String] = []

    func compile(source: String, outputURL: URL) throws {
        compiledSources.append(source)
        try Data("compiled".utf8).write(to: outputURL)
    }
}

private final class RecordingScriptCompilationNotifier: ScriptCompilationNotifying {
    private(set) var postedConfigChangedCount = 0

    func postConfigChanged() {
        postedConfigChangedCount += 1
    }
}
