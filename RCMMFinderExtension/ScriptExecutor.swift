import Foundation
import os.log
import Carbon
import RCMMShared

final class ScriptExecutor {
    private let logger = Logger(
        subsystem: "com.sunven.rcmm.FinderExtension",
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
        guard let scriptsDir = scriptsDirectory else {
            let error = NSError(
                domain: "ScriptExecutor",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法获取脚本目录"]
            )
            logger.error("脚本目录不可用")
            recordError(message: "脚本目录不可用", context: menuItemName)
            completion?(error)
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
                handlerName: "openApp",
                parameter: targetPath
            )

            task.execute(withAppleEvent: event) { [weak self] _, error in
                if let error = error {
                    self?.logger.error("脚本执行失败: \(scriptId): \(error.localizedDescription)")
                    self?.recordError(
                        message: "脚本执行失败: \(error.localizedDescription)",
                        context: menuItemName
                    )
                } else {
                    self?.logger.info("脚本执行成功: \(scriptId) → \(targetPath)")
                }
                completion?(error)
            }
        } catch {
            logger.error("脚本加载失败: \(scriptId): \(error.localizedDescription)")
            recordError(
                message: "脚本文件不存在或无法加载: \(error.localizedDescription)",
                context: menuItemName
            )
            completion?(error)
        }
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
    private func recordError(message: String, context: String) {
        let record = ErrorRecord(
            source: "extension",
            message: message,
            context: context
        )
        errorQueue.append(record)
    }
}
