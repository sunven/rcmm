import Foundation
import RCMMShared

struct ScriptCompilationOutcome: Hashable, Sendable {
    let results: [ScriptSyncResult]
    let publishStates: [String: ScriptPublishState]
    let errorRecords: [ErrorRecord]
}

protocol ScriptCompilationNotifying {
    func postConfigChanged()
}

struct DarwinScriptCompilationNotifier: ScriptCompilationNotifying {
    func postConfigChanged() {
        DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
    }
}

final class ScriptCompilationPipeline: @unchecked Sendable {
    private static let publishQueue = DispatchQueue(
        label: "com.sunven.rcmm.scriptCompilation",
        qos: .userInitiated
    )

    private let installer: ScriptInstallerService
    private let configService: SharedConfigService
    private let publishStore: ScriptPublishStore
    private let errorQueue: SharedErrorQueue
    private let iconPublisher: ApplicationIconPublishing
    private let notifier: ScriptCompilationNotifying

    init(
        configService: SharedConfigService = SharedConfigService(),
        publishStore: ScriptPublishStore = ScriptPublishStore(),
        errorQueue: SharedErrorQueue = SharedErrorQueue(),
        compiler: AppleScriptCompiling = AppleScriptCompiler(),
        sourceGenerator: ScriptSourceGenerator = ScriptSourceGenerator(),
        fileManager: FileManager = .default,
        scriptsDirectory: URL? = nil,
        iconPublisher: ApplicationIconPublishing = ApplicationIconPublisher(),
        notifier: ScriptCompilationNotifying = DarwinScriptCompilationNotifier()
    ) {
        self.configService = configService
        self.publishStore = publishStore
        self.errorQueue = errorQueue
        self.iconPublisher = iconPublisher
        self.notifier = notifier
        self.installer = ScriptInstallerService(
            compiler: compiler,
            sourceGenerator: sourceGenerator,
            publishStore: publishStore,
            errorQueue: errorQueue,
            configService: configService,
            fileManager: fileManager,
            scriptsDirectory: scriptsDirectory
        )
    }

    func publishCurrentConfiguration() async -> ScriptCompilationOutcome {
        await withCheckedContinuation { continuation in
            Self.publishQueue.async {
                let entries = self.configService.loadEntries()
                self.iconPublisher.publishIcons(for: entries)
                let results = self.installer.syncScripts(with: entries)
                self.notifier.postConfigChanged()
                continuation.resume(
                    returning: ScriptCompilationOutcome(
                        results: results,
                        publishStates: self.publishStore.loadAll(),
                        errorRecords: self.errorQueue.loadAll()
                    )
                )
            }
        }
    }
}
