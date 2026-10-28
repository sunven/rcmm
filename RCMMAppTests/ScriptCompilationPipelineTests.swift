import Foundation
import RCMMShared
import Testing
@testable import rcmm

@Suite("Script Compilation Pipeline tests", .serialized)
struct ScriptCompilationPipelineTests {
    private static let cleanupTypes: [BuiltInType] = [
        .cleanNodeModules,
        .cleanJavaTarget,
        .cleanRustTarget,
    ]

    @Test("三种清理脚本均可被 osacompile 编译")
    func cleanupScriptsCompile() throws {
        for type in Self.cleanupTypes {
            let source = try cleanupSource(for: type)
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("cleanup-\(type.rawValue)-\(UUID().uuidString)")
                .appendingPathExtension("scpt")
            defer { try? FileManager.default.removeItem(at: outputURL) }

            try AppleScriptCompiler().compile(source: source, outputURL: outputURL)

            #expect(FileManager.default.fileExists(atPath: outputURL.path))
        }
    }

    @Test("node_modules 扫描列出全部目录且不删除")
    func cleanNodeModulesScriptListsPathsWithoutDeleting() throws {
        let rootURL = try makeTemporaryDirectory(prefix: "clean-node-modules-preview")
        let firstURL = rootURL.appendingPathComponent("app/node_modules")
        let secondURL = rootURL.appendingPathComponent("包含换行\n的目录/node_modules")
        try FileManager.default.createDirectory(at: firstURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondURL, withIntermediateDirectories: true)

        let paths = try runCleanupList(type: .cleanNodeModules, root: rootURL)

        #expect(Set(paths) == Set([firstURL.path, secondURL.path]))
        #expect(FileManager.default.fileExists(atPath: firstURL.path))
        #expect(FileManager.default.fileExists(atPath: secondURL.path))
    }

    @Test("Java 扫描只匹配同级存在构建描述文件的 target")
    func javaTargetScanRequiresBuildManifest() throws {
        let rootURL = try makeTemporaryDirectory(prefix: "clean-java-target")
        let fixtures: [(module: String, manifest: String?)] = [
            ("maven", "pom.xml"),
            ("gradle", "build.gradle"),
            ("gradle-kts", "build.gradle.kts"),
            ("ant", "build.xml"),
            ("with space", "pom.xml"),
            ("unrelated", nil),
        ]
        var expectedPaths: Set<String> = []

        for fixture in fixtures {
            let moduleURL = rootURL.appendingPathComponent(fixture.module)
            let targetURL = moduleURL.appendingPathComponent("target")
            try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
            if let manifest = fixture.manifest {
                try Data().write(to: moduleURL.appendingPathComponent(manifest))
                expectedPaths.insert(targetURL.path)
            }
        }
        try FileManager.default.createDirectory(
            at: rootURL.appendingPathComponent("maven/target/nested/target"),
            withIntermediateDirectories: true
        )

        let paths = try runCleanupList(type: .cleanJavaTarget, root: rootURL)

        #expect(Set(paths) == expectedPaths)
        #expect(paths.allSatisfy { FileManager.default.fileExists(atPath: $0) })
    }

    @Test("Rust 扫描只匹配同级存在 Cargo.toml 的 target")
    func rustTargetScanRequiresCargoManifest() throws {
        let rootURL = try makeTemporaryDirectory(prefix: "clean-rust-target")
        let workspaceURL = rootURL.appendingPathComponent("workspace")
        let workspaceTarget = workspaceURL.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: workspaceTarget, withIntermediateDirectories: true)
        try Data().write(to: workspaceURL.appendingPathComponent("Cargo.toml"))

        let spacedURL = rootURL.appendingPathComponent("with space")
        let spacedTarget = spacedURL.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: spacedTarget, withIntermediateDirectories: true)
        try Data().write(to: spacedURL.appendingPathComponent("Cargo.toml"))

        try FileManager.default.createDirectory(
            at: workspaceTarget.appendingPathComponent("debug/target"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: rootURL.appendingPathComponent("workspace/member/target"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: rootURL.appendingPathComponent("unrelated/target"),
            withIntermediateDirectories: true
        )

        let paths = try runCleanupList(type: .cleanRustTarget, root: rootURL)

        #expect(Set(paths) == Set([workspaceTarget.path, spacedTarget.path]))
    }

    @Test("清理脚本把目录移到废纸篓且不影响兄弟目录")
    func cleanupScriptMovesDirectoryToTrash() throws {
        let rootURL = try makeTemporaryDirectory(prefix: "clean-trash")
        let targetURL = rootURL.appendingPathComponent("待清理/node_modules")
        let untouchedURL = rootURL.appendingPathComponent("保留/node_modules")
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: untouchedURL, withIntermediateDirectories: true)

        let trashedPath = try runCleanupHandler(
            type: .cleanNodeModules,
            handler: "trashItem",
            argument: targetURL.path
        )
        defer { try? FileManager.default.removeItem(atPath: trashedPath) }

        #expect(!FileManager.default.fileExists(atPath: targetURL.path))
        #expect(FileManager.default.fileExists(atPath: untouchedURL.path))
        #expect(FileManager.default.fileExists(atPath: trashedPath))
    }

    @Test("清理型内置项发布统一 handler 的废纸篓脚本")
    func publishesCleanupScripts() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let entries = Self.cleanupTypes.map {
            MenuEntry.builtIn(BuiltInMenuItem(type: $0, isEnabled: true))
        }
        harness.configService.saveEntries(entries)

        let outcome = await harness.pipeline.publishCurrentConfiguration()

        #expect(
            outcome.results.map(\.entryID)
                == Self.cleanupTypes.map { "builtIn.\($0.rawValue)" }
        )
        #expect(harness.compiler.compiledSources.count == Self.cleanupTypes.count)

        for source in harness.compiler.compiledSources {
            #expect(!source.contains("display dialog"))
            #expect(!source.contains("rm -rf"))
            #expect(source.contains("use framework \"Foundation\""))
            #expect(source.contains("use scripting additions"))
            #expect(source.contains("on listCleanupTargets(thePath)"))
            #expect(source.contains("on trashItem(thePath)"))
            #expect(source.contains("trashItemAtURL:fileURL"))
        }

        let sources = Dictionary(
            uniqueKeysWithValues: zip(Self.cleanupTypes, harness.compiler.compiledSources)
        )
        #expect(sources[.cleanNodeModules]?.contains("-name 'node_modules'") == true)
        #expect(sources[.cleanJavaTarget]?.contains("-name 'target'") == true)
        #expect(sources[.cleanJavaTarget]?.contains("-f pom.xml") == true)
        #expect(sources[.cleanJavaTarget]?.contains("-f build.gradle") == true)
        #expect(sources[.cleanJavaTarget]?.contains("-f build.gradle.kts") == true)
        #expect(sources[.cleanJavaTarget]?.contains("-f build.xml") == true)
        #expect(sources[.cleanRustTarget]?.contains("-f Cargo.toml") == true)
    }

    private func cleanupSource(for type: BuiltInType) throws -> String {
        let entry = MenuEntry.builtIn(BuiltInMenuItem(type: type, isEnabled: true))
        let scriptBackedEntry = try #require(MenuEntryEvaluator.evaluate(entry).scriptBacked.first)
        return try ScriptSourceGenerator().generate(
            for: entry,
            scriptBackedEntry: scriptBackedEntry
        )
    }

    private func makeTemporaryDirectory(prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func runCleanupList(type: BuiltInType, root: URL) throws -> [String] {
        let encoded = try runCleanupHandler(
            type: type,
            handler: "listCleanupTargets",
            argument: root.path
        )
        let data = try #require(Data(base64Encoded: encoded))
        return data.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
    }

    private func runCleanupHandler(
        type: BuiltInType,
        handler: String,
        argument: String
    ) throws -> String {
        let source = try cleanupSource(for: type)
        let runnableSource = source + """

        on run argv
        return \(handler)(item 1 of argv)
        end run
        """
        let sourceRoot = try makeTemporaryDirectory(prefix: "cleanup-script")
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let sourceURL = sourceRoot.appendingPathComponent("cleanup.applescript")
        try runnableSource.write(to: sourceURL, atomically: true, encoding: .utf8)

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [sourceURL.path, argument]
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()

        let result = String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(process.terminationStatus == 0)
        return result
    }

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
        #expect(harness.iconPublisher.publishedEntries == [[.custom(item)]])
        #expect(harness.fileManager.fileExists(atPath: scriptURL.path))
        #expect(harness.notifier.postedConfigChangedCount == 1)
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
