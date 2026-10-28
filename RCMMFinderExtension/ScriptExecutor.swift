import Foundation
import os.log
import Carbon
import RCMMShared

final class ScriptExecutor {
    private let logger = Logger(
        subsystem: RuntimeConfiguration.finderExtensionBundleID,
        category: "script"
    )
    private let errorQueue = SharedErrorQueue()

    /// 获取 Extension 脚本目录
    private var scriptsDirectory: URL? {
        try? FileManager.default.url(
            for: .applicationScriptsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
    }

    /// 执行指定脚本，传入目标路径（文件或目录）
    func execute(
        scriptId: String,
        targetPath: String,
        menuItemName: String,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        executeTask(
            scriptId: scriptId,
            handlerName: "openApp",
            targetPath: targetPath,
            menuItemName: menuItemName
        ) { [weak self] _, error in
            if let error {
                self?.logger.error("脚本执行失败: \(scriptId): \(error.localizedDescription)")
            } else {
                self?.logger.info("脚本执行成功: \(scriptId) → \(targetPath)")
            }
            completion?(error)
        }
    }

    /// 扫描清理目标；结果通过无交互 AppleScript handler 返回。
    func listCleanupTargets(
        scriptId: String,
        targetPath: String,
        menuItemName: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        executeTask(
            scriptId: scriptId,
            handlerName: "listCleanupTargets",
            targetPath: targetPath,
            menuItemName: menuItemName
        ) { [weak self] descriptor, error in
            if let error {
                self?.logger.error("脚本扫描失败: \(scriptId): \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let encodedPaths = descriptor?.stringValue,
                  let data = Data(base64Encoded: encodedPaths),
                  let paths = Self.decodeNullSeparatedPaths(data) else {
                let error = NSError(
                    domain: "ScriptExecutor",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "脚本扫描结果无效"]
                )
                self?.logger.error("脚本扫描结果无效: \(scriptId)")
                self?.recordError(
                    message: error.localizedDescription,
                    context: menuItemName,
                    scriptId: scriptId,
                    kind: .scriptExecution
                )
                completion(.failure(error))
                return
            }

            completion(.success(paths))
        }
    }

    func trashItem(
        scriptId: String,
        targetPath: String,
        menuItemName: String,
        completion: @escaping (Error?) -> Void
    ) {
        executeTask(
            scriptId: scriptId,
            handlerName: "trashItem",
            targetPath: targetPath,
            menuItemName: menuItemName,
            recordsError: false
        ) { [weak self] _, error in
            if let error {
                self?.logger.error("移到废纸篓失败: \(scriptId): \(targetPath): \(error.localizedDescription)")
            } else {
                self?.logger.info("已移到废纸篓: \(scriptId) → \(targetPath)")
            }
            completion(error)
        }
    }

    /// 逐个清理失败会共用同一个脚本级错误键，此处汇总成一条记录保留全部失败路径。
    func recordCleanupFailures(
        _ failures: [CleanupFailure],
        menuItemName: String,
        scriptId: String
    ) {
        guard !failures.isEmpty else { return }

        let details = failures
            .map { "\($0.path): \($0.reason)" }
            .joined(separator: "\n")
        recordError(
            message: "移到废纸篓失败 \(failures.count) 个目录:\n\(details)",
            context: menuItemName,
            scriptId: scriptId,
            kind: .scriptExecution
        )
    }

    private func executeTask(
        scriptId: String,
        handlerName: String,
        targetPath: String,
        menuItemName: String,
        recordsError: Bool = true,
        completion: @escaping (NSAppleEventDescriptor?, Error?) -> Void
    ) {
        guard let scriptsDir = scriptsDirectory else {
            let error = NSError(
                domain: "ScriptExecutor",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法获取脚本目录"]
            )
            logger.error("脚本目录不可用")
            if recordsError {
                recordError(
                    message: "脚本目录不可用",
                    context: menuItemName,
                    scriptId: scriptId,
                    kind: .scriptLoad
                )
            }
            completion(nil, error)
            return
        }

        let scriptURL = scriptsDir
            .appendingPathComponent(scriptId)
            .appendingPathExtension("scpt")

        do {
            // 每次执行创建新的 NSUserAppleScriptTask 实例（单次使用限制）
            let task = try NSUserAppleScriptTask(url: scriptURL)

            // 构建 Apple Event，传递目标路径作为参数
            let event = Self.buildAppleEvent(
                handlerName: handlerName,
                parameter: targetPath
            )

            task.execute(withAppleEvent: event) { [weak self] descriptor, error in
                if let error, recordsError {
                    self?.recordError(
                        message: "脚本执行失败: \(error.localizedDescription)",
                        context: menuItemName,
                        scriptId: scriptId,
                        kind: .scriptExecution
                    )
                }
                completion(descriptor, error)
            }
        } catch {
            logger.error("脚本加载失败: \(scriptId): \(error.localizedDescription)")
            if recordsError {
                recordError(
                    message: "脚本文件不存在或无法加载: \(error.localizedDescription)",
                    context: menuItemName,
                    scriptId: scriptId,
                    kind: .scriptLoad
                )
            }
            completion(nil, error)
        }
    }

    private static func decodeNullSeparatedPaths(_ data: Data) -> [String]? {
        guard !data.isEmpty else { return [] }

        let components = data.split(separator: 0, omittingEmptySubsequences: true)
        var paths: [String] = []
        paths.reserveCapacity(components.count)
        for component in components {
            guard let path = String(data: Data(component), encoding: .utf8) else {
                return nil
            }
            paths.append(path)
        }
        return paths
    }

    /// 构建 Apple Event 调用脚本中的 handler
    private static func buildAppleEvent(
        handlerName: String,
        parameter: String
    ) -> NSAppleEventDescriptor {
        let parameters = NSAppleEventDescriptor.list()
        parameters.insert(NSAppleEventDescriptor(string: parameter), at: 0)

        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kASAppleScriptSuite),
            eventID: AEEventID(kASSubroutineEvent),
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        event.setDescriptor(
            NSAppleEventDescriptor(string: handlerName),
            forKeyword: AEKeyword(keyASSubroutineName)
        )
        event.setDescriptor(parameters, forKeyword: AEKeyword(keyDirectObject))

        return event
    }

    /// 记录错误到 App Group 错误队列
    private func recordError(
        message: String,
        context: String,
        scriptId: String,
        kind: ErrorRecordKind
    ) {
        let record = ErrorRecord(
            source: "extension",
            message: message,
            context: context,
            key: ErrorRecord.runtimeScriptKey(scriptID: scriptId, kind: kind),
            kind: kind
        )
        errorQueue.upsert(record)
    }
}

struct CleanupFailure {
    let path: String
    let reason: String
}
