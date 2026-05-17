import Foundation
import os.log
import RCMMShared

enum ScriptSyncStatus: Hashable, Sendable {
    case current
    case failed
    case stale
}

struct ScriptSyncResult: Hashable, Sendable {
    let entryID: String
    let displayName: String
    let fingerprint: String
    let status: ScriptSyncStatus
    let errorSummary: String?
}

final class ScriptInstallerService {
    private let logger = Logger(
        subsystem: "com.sunven.rcmm",
        category: "script"
    )

    private let compiler: AppleScriptCompiling
    private let sourceGenerator: ScriptSourceGenerator
    private let publishStore: ScriptPublishStore
    private let errorQueue: SharedErrorQueue
    private let configService: SharedConfigService
    private let fileManager: FileManager
    private let extensionBundleID: String

    init(
        compiler: AppleScriptCompiling = AppleScriptCompiler(),
        sourceGenerator: ScriptSourceGenerator = ScriptSourceGenerator(),
        publishStore: ScriptPublishStore = ScriptPublishStore(),
        errorQueue: SharedErrorQueue = SharedErrorQueue(),
        configService: SharedConfigService = SharedConfigService(),
        fileManager: FileManager = .default,
        extensionBundleID: String = RuntimeConfiguration.finderExtensionBundleID
    ) {
        self.compiler = compiler
        self.sourceGenerator = sourceGenerator
        self.publishStore = publishStore
        self.errorQueue = errorQueue
        self.configService = configService
        self.fileManager = fileManager
        self.extensionBundleID = extensionBundleID
    }

    private var scriptsDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Scripts")
            .appendingPathComponent(extensionBundleID)
    }

    /// 同步脚本文件：删除多余脚本，编译当前脚本，并写入 Finder 可读的发布状态。
    @discardableResult
    func syncScripts(with entries: [MenuEntry]) -> [ScriptSyncResult] {
        let entriesToSync = configService.hasSavedEntriesData
            ? configService.loadEntries()
            : entries
        let scriptBackedEntries = entriesToSync.compactMap { entry -> (MenuEntry, ScriptBackedMenuEntry)? in
            guard let scriptBackedEntry = MenuEntryScriptPolicy.scriptBackedEntry(for: entry) else {
                return nil
            }
            return (entry, scriptBackedEntry)
        }
        let expectedIDs = Set(scriptBackedEntries.map(\.1.id))

        do {
            try fileManager.createDirectory(
                at: scriptsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            let summary = "创建脚本目录失败: \(error.localizedDescription)"
            logger.error("\(summary)")
            return scriptBackedEntries.map { entry, scriptBackedEntry in
                recordFailure(
                    entry: entry,
                    scriptBackedEntry: scriptBackedEntry,
                    error: error,
                    kind: .scriptPublish
                )
            }
        }

        removeObsoleteScripts(expectedIDs: expectedIDs)
        publishStore.removeAll(except: expectedIDs)

        return scriptBackedEntries.map { entry, scriptBackedEntry in
            syncScript(for: entry, scriptBackedEntry: scriptBackedEntry)
        }
    }

    private func syncScript(
        for entry: MenuEntry,
        scriptBackedEntry: ScriptBackedMenuEntry
    ) -> ScriptSyncResult {
        guard isStillCurrent(scriptBackedEntry) else {
            logger.debug("跳过过期脚本同步结果: \(scriptBackedEntry.id, privacy: .public)")
            return ScriptSyncResult(
                entryID: scriptBackedEntry.id,
                displayName: scriptBackedEntry.displayName,
                fingerprint: scriptBackedEntry.fingerprint,
                status: .stale,
                errorSummary: nil
            )
        }

        let finalURL = scriptURL(for: scriptBackedEntry.id)
        let tempURL = scriptsDirectory
            .appendingPathComponent(".\(scriptBackedEntry.id).\(UUID().uuidString)")
            .appendingPathExtension("scpt")

        let source: String
        do {
            source = try sourceGenerator.generate(
                for: entry,
                scriptBackedEntry: scriptBackedEntry
            )
        } catch {
            try? fileManager.removeItem(at: finalURL)
            return recordFailure(
                entry: entry,
                scriptBackedEntry: scriptBackedEntry,
                error: error,
                kind: .scriptCompile
            )
        }

        do {
            try compiler.compile(source: source, outputURL: tempURL)
        } catch {
            try? fileManager.removeItem(at: tempURL)
            try? fileManager.removeItem(at: finalURL)
            return recordFailure(
                entry: entry,
                scriptBackedEntry: scriptBackedEntry,
                error: error,
                kind: .scriptCompile
            )
        }

        guard isStillCurrent(scriptBackedEntry) else {
            try? fileManager.removeItem(at: tempURL)
            logger.debug("丢弃过期脚本编译结果: \(scriptBackedEntry.id, privacy: .public)")
            return ScriptSyncResult(
                entryID: scriptBackedEntry.id,
                displayName: scriptBackedEntry.displayName,
                fingerprint: scriptBackedEntry.fingerprint,
                status: .stale,
                errorSummary: nil
            )
        }

        do {
            try publishCompiledScript(tempURL: tempURL, finalURL: finalURL)
            publishStore.upsert(
                ScriptPublishState(
                    entryID: scriptBackedEntry.id,
                    status: .current,
                    fingerprint: scriptBackedEntry.fingerprint
                )
            )
            removePublishErrors(for: scriptBackedEntry.id)

            logger.info("脚本发布成功: \(scriptBackedEntry.displayName, privacy: .public)")
            return ScriptSyncResult(
                entryID: scriptBackedEntry.id,
                displayName: scriptBackedEntry.displayName,
                fingerprint: scriptBackedEntry.fingerprint,
                status: .current,
                errorSummary: nil
            )
        } catch {
            try? fileManager.removeItem(at: tempURL)
            try? fileManager.removeItem(at: finalURL)
            return recordFailure(
                entry: entry,
                scriptBackedEntry: scriptBackedEntry,
                error: error,
                kind: .scriptPublish
            )
        }
    }

    private func publishCompiledScript(tempURL: URL, finalURL: URL) throws {
        if fileManager.fileExists(atPath: finalURL.path) {
            _ = try fileManager.replaceItemAt(
                finalURL,
                withItemAt: tempURL,
                backupItemName: nil,
                options: [.usingNewMetadataOnly]
            )
        } else {
            try fileManager.moveItem(at: tempURL, to: finalURL)
        }
    }

    private func recordFailure(
        entry: MenuEntry,
        scriptBackedEntry: ScriptBackedMenuEntry,
        error: Error,
        kind: ErrorRecordKind
    ) -> ScriptSyncResult {
        guard isStillCurrent(scriptBackedEntry) else {
            return ScriptSyncResult(
                entryID: scriptBackedEntry.id,
                displayName: scriptBackedEntry.displayName,
                fingerprint: scriptBackedEntry.fingerprint,
                status: .stale,
                errorSummary: nil
            )
        }

        let summary = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        publishStore.upsert(
            ScriptPublishState(
                entryID: scriptBackedEntry.id,
                status: .compileFailed,
                fingerprint: scriptBackedEntry.fingerprint,
                errorSummary: summary
            )
        )

        errorQueue.upsert(
            ErrorRecord(
                source: "app",
                message: failureMessage(kind: kind, summary: summary),
                context: entry.displayName,
                key: errorKey(
                    entryID: scriptBackedEntry.id,
                    fingerprint: scriptBackedEntry.fingerprint,
                    kind: kind
                ),
                kind: kind
            )
        )

        logger.error("脚本发布失败: \(scriptBackedEntry.displayName, privacy: .public): \(summary, privacy: .public)")
        return ScriptSyncResult(
            entryID: scriptBackedEntry.id,
            displayName: scriptBackedEntry.displayName,
            fingerprint: scriptBackedEntry.fingerprint,
            status: .failed,
            errorSummary: summary
        )
    }

    private func removeObsoleteScripts(expectedIDs: Set<String>) {
        let existingScripts = (try? fileManager.contentsOfDirectory(
            at: scriptsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []

        for scriptURL in existingScripts where scriptURL.pathExtension == "scpt" {
            let id = scriptURL.deletingPathExtension().lastPathComponent
            guard !expectedIDs.contains(id) else { continue }
            do {
                try fileManager.removeItem(at: scriptURL)
                publishStore.remove(entryID: id)
                logger.info("删除多余脚本: \(id, privacy: .public)")
            } catch {
                logger.warning("删除多余脚本失败: \(id, privacy: .public): \(error.localizedDescription)")
            }
        }
    }

    private func scriptURL(for entryID: String) -> URL {
        scriptsDirectory
            .appendingPathComponent(entryID)
            .appendingPathExtension("scpt")
    }

    private func isStillCurrent(_ scriptBackedEntry: ScriptBackedMenuEntry) -> Bool {
        configService.loadEntries()
            .compactMap(MenuEntryScriptPolicy.scriptBackedEntry)
            .contains { current in
                current.id == scriptBackedEntry.id
                    && current.fingerprint == scriptBackedEntry.fingerprint
            }
    }

    private func errorKey(
        entryID: String,
        fingerprint: String,
        kind: ErrorRecordKind
    ) -> String {
        "script.\(entryID).\(fingerprint).\(kind.rawValue)"
    }

    private func removePublishErrors(for entryID: String) {
        let keyPrefix = "script.\(entryID)."
        errorQueue.removeAll { record in
            guard let key = record.key,
                  key.hasPrefix(keyPrefix),
                  let kind = record.kind else {
                return false
            }
            return kind == .scriptCompile || kind == .scriptPublish
        }
    }

    private func failureMessage(kind: ErrorRecordKind, summary: String) -> String {
        switch kind {
        case .scriptCompile:
            return "脚本编译失败: \(summary)"
        case .scriptPublish:
            return "脚本发布失败: \(summary)"
        case .scriptLoad:
            return "脚本文件不存在或无法加载: \(summary)"
        case .scriptExecution:
            return "脚本执行失败: \(summary)"
        }
    }
}
