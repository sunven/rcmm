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

@Suite("AppState coordinator wiring tests", .serialized)
@MainActor
struct AppStateCoordinatorWiringTests {
    @Test("ensureNewFileMenu 使用注入 coordinator 的真实配置 store")
    func ensureNewFileMenuUsesInjectedCoordinatorStore() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }

        let coordinator = AppCoordinator(
            configStore: MenuConfigStore(
                configService: harness.configService,
                publishStore: harness.publishStore,
                errorQueue: harness.errorQueue
            ),
            scriptCompilationPipeline: harness.pipeline,
            startsServices: false
        )
        let state = AppState(coordinator: coordinator, forPreview: true)
        let expectedID = coordinator.configStore.primaryNewFileMenu?.id

        let actualID = state.ensureNewFileMenu()

        #expect(actualID == expectedID)
        #expect(expectedID != nil)
    }

    @Test("MenuConfigStore 添加应用按非空 bundleId 优先，缺失时按路径去重")
    func menuConfigStoreDeduplicatesApplicationsByBundleThenPath() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let store = MenuConfigStore(
            configService: harness.configService,
            publishStore: harness.publishStore,
            errorQueue: harness.errorQueue
        )
        store.menuEntries = [
            .custom(MenuItemConfig(
                appName: "Existing Bundle",
                bundleId: "com.example.editor",
                appPath: "/Applications/OldEditor.app"
            )),
            .custom(MenuItemConfig(
                appName: "Existing No Bundle",
                appPath: "/Applications/NoBundle.app"
            )),
        ]

        let addedIDs = store.addMenuItems(from: [
            AppInfo(
                name: "Same Bundle",
                bundleId: "com.example.editor",
                path: "/Applications/NewEditor.app"
            ),
            AppInfo(
                name: "Same Path No Bundle",
                path: "/Applications/NoBundle.app"
            ),
            AppInfo(
                name: "Different Path No Bundle",
                path: "/Applications/OtherNoBundle.app"
            ),
            AppInfo(
                name: "New Bundle",
                bundleId: "com.example.viewer",
                path: "/Applications/Viewer.app"
            ),
        ])

        #expect(addedIDs.count == 2)
        #expect(store.menuEntries.compactMap { entry -> String? in
            guard case .custom(let item) = entry else { return nil }
            return item.appName
        } == [
            "Existing Bundle",
            "Existing No Bundle",
            "Different Path No Bundle",
            "New Bundle",
        ])
    }
}

@Suite("ScriptInstallerService tests", .serialized)
struct ScriptInstallerServiceTests {
    @Test("编译期间配置变化时丢弃 stale 结果")
    func dropsCompiledScriptWhenConfigurationChangesDuringCompile() throws {
        let harness = try InstallerHarness()
        defer { harness.cleanup() }
        let item = MenuItemConfig(
            appName: "Git Pull",
            appPath: "",
            customCommand: "git pull",
            executionMode: .currentDirectory
        )
        harness.configService.saveEntries([.custom(item)])
        let compiler = MutatingAppleScriptCompiler {
            harness.configService.saveEntries([
                .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
            ])
            harness.forcePreferencesModificationDate()
        }

        let result = harness.installer(compiler: compiler)
            .syncScripts(with: [.custom(item)])

        #expect(result.map(\.status) == [.stale])
        #expect(harness.publishStore.state(for: item.id.uuidString) == nil)
        #expect(!harness.fileManager.fileExists(atPath: harness.scriptURL(for: item.id.uuidString).path))
    }

    @Test("编译失败会删除旧脚本并记录错误")
    func compileFailureRemovesStaleScriptAndRecordsError() throws {
        let harness = try InstallerHarness()
        defer { harness.cleanup() }
        let item = MenuItemConfig(
            appName: "Git Pull",
            appPath: "",
            customCommand: "git pull",
            executionMode: .currentDirectory
        )
        harness.configService.saveEntries([.custom(item)])
        try harness.fileManager.createDirectory(
            at: harness.scriptsDirectory,
            withIntermediateDirectories: true
        )
        try Data("old".utf8).write(to: harness.scriptURL(for: item.id.uuidString))

        let result = harness.installer(compiler: ThrowingAppleScriptCompiler())
            .syncScripts(with: [.custom(item)])

        #expect(result.map(\.status) == [.failed])
        #expect(harness.publishStore.state(for: item.id.uuidString)?.status == .compileFailed)
        #expect(harness.errorQueue.loadAll().contains { $0.kind == .scriptCompile })
        #expect(!harness.fileManager.fileExists(atPath: harness.scriptURL(for: item.id.uuidString).path))
    }

    @Test("复制模板会发布脚本和模板资源")
    func copyTemplatePublishesTemplateResource() throws {
        let harness = try InstallerHarness()
        defer { harness.cleanup() }
        let menuID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let templateID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let templateURL = harness.temporaryRoot.appendingPathComponent("template.docx")
        try Data("template-data".utf8).write(to: templateURL)
        let entry = MenuEntry.newFile(NewFileMenuConfig(
            id: menuID,
            templates: [
                NewFileTemplateConfig(
                    id: templateID,
                    displayName: "word",
                    fileExtension: "docx",
                    creationMode: .copyTemplate,
                    templatePath: templateURL.path
                ),
            ]
        ))
        harness.configService.saveEntries([entry])
        let scriptID = MenuEntryScriptPolicy.newFileScriptID(menuID: menuID, templateID: templateID)
        let resourceName = NewFileScriptBuilder.templateResourceName(
            for: scriptID,
            fileExtension: "docx"
        )

        let result = harness.installer().syncScripts(with: [entry])

        #expect(result.map(\.status) == [.current])
        #expect(harness.fileManager.fileExists(atPath: harness.scriptURL(for: scriptID).path))
        let resourceURL = harness.scriptsDirectory.appendingPathComponent(resourceName)
        #expect(try Data(contentsOf: resourceURL) == Data("template-data".utf8))
    }

    @Test("发布失败会记录 scriptPublish 错误")
    func publishFailureRecordsError() throws {
        let harness = try InstallerHarness()
        defer { harness.cleanup() }
        let item = MenuItemConfig(
            appName: "Git Pull",
            appPath: "",
            customCommand: "git pull",
            executionMode: .currentDirectory
        )
        harness.configService.saveEntries([.custom(item)])

        let result = harness.installer(compiler: DeletingOutputAppleScriptCompiler())
            .syncScripts(with: [.custom(item)])

        #expect(result.map(\.status) == [.failed])
        #expect(harness.errorQueue.loadAll().contains { $0.kind == .scriptPublish })
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
            notifier: notifier
        )
    }

    func cleanup() {
        try? fileManager.removeItem(at: temporaryRoot)
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private final class InstallerHarness {
    let fileManager: FileManager
    let temporaryRoot: URL
    let scriptsDirectory: URL
    let preferencesURL: URL
    let configService: SharedConfigService
    let publishStore: ScriptPublishStore
    let errorQueue: SharedErrorQueue

    init() throws {
        fileManager = .default
        temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent("ScriptInstallerServiceTests-\(UUID().uuidString)", isDirectory: true)
        scriptsDirectory = temporaryRoot.appendingPathComponent("Scripts", isDirectory: true)
        preferencesURL = temporaryRoot.appendingPathComponent("group.plist")
        try fileManager.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )

        let preferences = SharedPreferencesStore(propertyListURL: preferencesURL)
        configService = SharedConfigService(preferences: preferences)
        publishStore = ScriptPublishStore(preferences: preferences)
        errorQueue = SharedErrorQueue(preferences: preferences)
    }

    func installer(
        compiler: AppleScriptCompiling = RecordingAppleScriptCompiler()
    ) -> ScriptInstallerService {
        ScriptInstallerService(
            compiler: compiler,
            sourceGenerator: ScriptSourceGenerator(),
            publishStore: publishStore,
            errorQueue: errorQueue,
            configService: configService,
            fileManager: fileManager,
            scriptsDirectory: scriptsDirectory
        )
    }

    func scriptURL(for entryID: String) -> URL {
        scriptsDirectory
            .appendingPathComponent(entryID)
            .appendingPathExtension("scpt")
    }

    func forcePreferencesModificationDate() {
        try? fileManager.setAttributes(
            [.modificationDate: Date().addingTimeInterval(10)],
            ofItemAtPath: preferencesURL.path
        )
    }

    func cleanup() {
        try? fileManager.removeItem(at: temporaryRoot)
    }
}

private final class RecordingAppleScriptCompiler: AppleScriptCompiling {
    private(set) var compiledSources: [String] = []

    func compile(source: String, outputURL: URL) throws {
        compiledSources.append(source)
        try Data("compiled".utf8).write(to: outputURL)
    }
}

private final class MutatingAppleScriptCompiler: AppleScriptCompiling {
    private let mutate: () -> Void

    init(mutate: @escaping () -> Void) {
        self.mutate = mutate
    }

    func compile(source: String, outputURL: URL) throws {
        mutate()
        try Data("compiled".utf8).write(to: outputURL)
    }
}

private final class ThrowingAppleScriptCompiler: AppleScriptCompiling {
    func compile(source: String, outputURL: URL) throws {
        throw NSError(
            domain: "ScriptInstallerServiceTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "compile failed"]
        )
    }
}

private final class DeletingOutputAppleScriptCompiler: AppleScriptCompiling {
    func compile(source: String, outputURL: URL) throws {
        try Data("compiled".utf8).write(to: outputURL)
        try FileManager.default.removeItem(at: outputURL)
    }
}

private final class RecordingScriptCompilationNotifier: ScriptCompilationNotifying {
    private(set) var postedConfigChangedCount = 0

    func postConfigChanged() {
        postedConfigChangedCount += 1
    }
}
