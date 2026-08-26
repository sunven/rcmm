import Foundation
import RCMMShared
import Testing
@testable import rcmm

@Suite("Script Compilation Pipeline tests", .serialized)
struct ScriptCompilationPipelineTests {
    @Test("node_modules 清理脚本可被 osacompile 编译")
    func cleanNodeModulesScriptCompiles() throws {
        let entry = MenuEntry.builtIn(
            BuiltInMenuItem(type: .cleanNodeModules, isEnabled: true)
        )
        let scriptBackedEntry = try #require(MenuEntryEvaluator.evaluate(entry).scriptBacked.first)
        let source = try ScriptSourceGenerator().generate(
            for: entry,
            scriptBackedEntry: scriptBackedEntry
        )
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clean-node-modules-\(UUID().uuidString)")
            .appendingPathExtension("scpt")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try AppleScriptCompiler().compile(source: source, outputURL: outputURL)

        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }

    @Test("node_modules 清理脚本扫描完整路径且不删除目录")
    func cleanNodeModulesScriptListsPathsWithoutDeleting() throws {
        let entry = MenuEntry.builtIn(
            BuiltInMenuItem(type: .cleanNodeModules, isEnabled: true)
        )
        let scriptBackedEntry = try #require(MenuEntryEvaluator.evaluate(entry).scriptBacked.first)
        let source = try ScriptSourceGenerator().generate(
            for: entry,
            scriptBackedEntry: scriptBackedEntry
        )
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clean-node-modules-preview-\(UUID().uuidString)")
        let firstURL = rootURL.appendingPathComponent("app/node_modules")
        let secondURL = rootURL.appendingPathComponent("包含换行\n的目录/node_modules")
        let sourceURL = rootURL.appendingPathComponent("preview.applescript")
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try FileManager.default.createDirectory(at: firstURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondURL, withIntermediateDirectories: true)
        let runnableSource = source + """

        on run argv
        return listNodeModules(item 1 of argv)
        end run
        """
        try runnableSource.write(to: sourceURL, atomically: true, encoding: .utf8)

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [sourceURL.path, rootURL.path]
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()

        let encodedPaths = String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let pathData = try #require(Data(base64Encoded: encodedPaths))
        let paths = pathData.split(separator: 0).map {
            String(decoding: $0, as: UTF8.self)
        }

        #expect(process.terminationStatus == 0)
        #expect(Set(paths) == Set([firstURL.path, secondURL.path]))
        #expect(FileManager.default.fileExists(atPath: firstURL.path))
        #expect(FileManager.default.fileExists(atPath: secondURL.path))
    }

    @Test("node_modules 清理脚本只删除指定目录")
    func cleanNodeModulesScriptDeletesOnlySpecifiedDirectory() throws {
        let entry = MenuEntry.builtIn(
            BuiltInMenuItem(type: .cleanNodeModules, isEnabled: true)
        )
        let scriptBackedEntry = try #require(MenuEntryEvaluator.evaluate(entry).scriptBacked.first)
        let source = try ScriptSourceGenerator().generate(
            for: entry,
            scriptBackedEntry: scriptBackedEntry
        )
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clean-node-modules-delete-\(UUID().uuidString)")
        let targetURL = rootURL.appendingPathComponent("待清理/node_modules")
        let untouchedURL = rootURL.appendingPathComponent("保留/node_modules")
        let sourceURL = rootURL.appendingPathComponent("clean.applescript")
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: untouchedURL, withIntermediateDirectories: true)
        let runnableSource = source + """

        on run argv
        cleanNodeModule(item 1 of argv)
        end run
        """
        try runnableSource.write(to: sourceURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [sourceURL.path, targetURL.path]
        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        #expect(!FileManager.default.fileExists(atPath: targetURL.path))
        #expect(FileManager.default.fileExists(atPath: untouchedURL.path))
    }

    @Test("node_modules 清理项发布无交互且带安全查找参数的脚本")
    func publishesCleanNodeModulesScript() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let entry = MenuEntry.builtIn(
            BuiltInMenuItem(type: .cleanNodeModules, isEnabled: true)
        )
        harness.configService.saveEntries([entry])

        let outcome = await harness.pipeline.publishCurrentConfiguration()

        let source = try #require(harness.compiler.compiledSources.first)
        #expect(outcome.results.map(\.entryID) == ["builtIn.cleanNodeModules"])
        #expect(!source.contains("display dialog"))
        #expect(source.contains("on listNodeModules(thePath)"))
        #expect(source.contains("on cleanNodeModule(thePath)"))
        #expect(!source.contains("on cleanNodeModules(thePath)"))
        #expect(!source.contains("on openApp(thePath)"))
        #expect(source.contains("-name 'node_modules'"))
        #expect(source.contains("-prune"))
        #expect(source.contains("-print0 | /usr/bin/base64"))
        #expect(source.contains("rm -rf --"))
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
