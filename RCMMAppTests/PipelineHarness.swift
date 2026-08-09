import Foundation
import RCMMShared
@testable import rcmm

/// 脚本发布管线的测试脚手架：把 compiler / notifier / iconPublisher / 文件系统
/// 全部换成可记录的替身，配置走独立 UserDefaults suite，脚本写进临时目录。
///
/// `AppCoordinatorEditTests`、`MenuConfigStoreTests`、`ScriptCompilationPipelineTests`
/// 共用这一份 —— 它们测的是同一条链上的不同模块。
final class PipelineHarness {
    let suiteName: String
    let defaults: UserDefaults
    let fileManager: FileManager
    let temporaryRoot: URL
    let scriptsDirectory: URL
    let compiler: RecordingAppleScriptCompiler
    let iconPublisher: RecordingApplicationIconPublisher
    let notifier: RecordingScriptCompilationNotifier
    let configService: SharedConfigService
    let publishStore: ScriptPublishStore
    let errorQueue: SharedErrorQueue
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
        iconPublisher = RecordingApplicationIconPublisher()
        notifier = RecordingScriptCompilationNotifier()
        configService = SharedConfigService(defaults: defaults)
        publishStore = ScriptPublishStore(defaults: defaults)
        errorQueue = SharedErrorQueue(defaults: defaults)

        pipeline = ScriptCompilationPipeline(
            configService: configService,
            publishStore: publishStore,
            errorQueue: errorQueue,
            compiler: compiler,
            sourceGenerator: ScriptSourceGenerator(),
            fileManager: fileManager,
            scriptsDirectory: scriptsDirectory,
            iconPublisher: iconPublisher,
            notifier: notifier
        )
    }

    /// 用这份脚手架的存储构建一个 MenuConfigStore。
    @MainActor
    func makeConfigStore() -> MenuConfigStore {
        MenuConfigStore(
            configService: configService,
            publishStore: publishStore,
            errorQueue: errorQueue
        )
    }

    /// 用这份脚手架构建 AppCoordinator。`startsServices: false` 跳过启动时同步，
    /// 让测试能从一个确定的发布计数开始。
    @MainActor
    func makeCoordinator(configStore: MenuConfigStore? = nil) -> AppCoordinator {
        AppCoordinator(
            configStore: configStore ?? makeConfigStore(),
            scriptCompilationPipeline: pipeline,
            startsServices: false
        )
    }

    func cleanup() {
        try? fileManager.removeItem(at: temporaryRoot)
        defaults.removePersistentDomain(forName: suiteName)
    }
}

final class RecordingAppleScriptCompiler: AppleScriptCompiling {
    private(set) var compiledSources: [String] = []

    func compile(source: String, outputURL: URL) throws {
        compiledSources.append(source)
        try Data("compiled".utf8).write(to: outputURL)
    }
}

final class MutatingAppleScriptCompiler: AppleScriptCompiling {
    private let mutate: () -> Void

    init(mutate: @escaping () -> Void) {
        self.mutate = mutate
    }

    func compile(source: String, outputURL: URL) throws {
        mutate()
        try Data("compiled".utf8).write(to: outputURL)
    }
}

final class ThrowingAppleScriptCompiler: AppleScriptCompiling {
    func compile(source: String, outputURL: URL) throws {
        throw NSError(
            domain: "ScriptInstallerServiceTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "compile failed"]
        )
    }
}

final class DeletingOutputAppleScriptCompiler: AppleScriptCompiling {
    func compile(source: String, outputURL: URL) throws {
        try Data("compiled".utf8).write(to: outputURL)
        try FileManager.default.removeItem(at: outputURL)
    }
}

final class RecordingScriptCompilationNotifier: ScriptCompilationNotifying {
    private(set) var postedConfigChangedCount = 0

    func postConfigChanged() {
        postedConfigChangedCount += 1
    }
}

final class RecordingApplicationIconPublisher: ApplicationIconPublishing, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedEntries: [[MenuEntry]] = []

    var publishedEntries: [[MenuEntry]] {
        lock.lock()
        defer { lock.unlock() }
        return recordedEntries
    }

    func publishIcons(for entries: [MenuEntry]) {
        lock.lock()
        recordedEntries.append(entries)
        lock.unlock()
    }
}
