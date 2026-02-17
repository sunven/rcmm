import AppKit
import Foundation
import os.log
import RCMMShared
import UniformTypeIdentifiers

final class AppDiscoveryService: @unchecked Sendable {

    private let logger = Logger(
        subsystem: "com.sunven.rcmm",
        category: "discovery"
    )

    /// 扫描 /Applications 和 ~/Applications，返回按类型和名称排序的应用列表
    ///
    /// - Note: 此方法为同步方法，涉及文件系统 IO。调用者应避免在主线程调用，
    ///   建议在后台线程或 Task 中使用以防止 UI 卡顿。
    func scanApplications() -> [AppInfo] {
        let systemApps = URL(fileURLWithPath: "/Applications")
        let userApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")

        var allApps: [AppInfo] = []

        for directory in [systemApps, userApps] {
            let apps = scanDirectory(directory)
            allApps.append(contentsOf: apps)
        }

        // 去重（同一 bundleId 或同名应用优先保留 /Applications 中的）
        var seenBundleIds = Set<String>()
        var seenAppNames = Set<String>()
        var deduplicated: [AppInfo] = []
        for app in allApps {
            if let bundleId = app.bundleId {
                if seenBundleIds.contains(bundleId) { continue }
                seenBundleIds.insert(bundleId)
            } else {
                let appName = app.name.lowercased()
                if seenAppNames.contains(appName) { continue }
                seenAppNames.insert(appName)
            }
            deduplicated.append(app)
        }

        // 按 category 排序（terminal > editor > other），同类内按名称字母序
        let sorted = deduplicated.sorted { lhs, rhs in
            let lhsCat = lhs.category ?? .other
            let rhsCat = rhs.category ?? .other
            if lhsCat != rhsCat {
                return lhsCat < rhsCat
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        logger.info("应用扫描完成: 发现 \(sorted.count) 个应用")
        return sorted
    }

    /// 弹出 NSOpenPanel 让用户手动选择 .app 文件
    @MainActor
    func selectApplicationManually() async -> AppInfo? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "选择"

        let response = await panel.begin()
        guard response == .OK, let url = panel.url else {
            logger.info("用户取消了手动选择应用")
            return nil
        }

        let result = appInfo(from: url)
        if let result {
            logger.info("用户手动选择了应用: \(result.name) (\(result.bundleId ?? "无 bundleId"))")
        }
        return result
    }

    // MARK: - Private

    private func scanDirectory(_ directory: URL) -> [AppInfo] {
        let prefetchKeys: [URLResourceKey] = [.localizedNameKey, .isApplicationKey]

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: prefetchKeys,
            options: [.skipsHiddenFiles]
        ) else {
            logger.info("目录不存在或无法访问: \(directory.path)")
            return []
        }

        let appURLs = contents.filter { $0.pathExtension == "app" }
        logger.info("扫描 \(directory.path): 发现 \(appURLs.count) 个 .app")

        return appURLs.compactMap { appInfo(from: $0) }
    }

    private func appInfo(from appURL: URL) -> AppInfo? {
        let bundle = Bundle(url: appURL)
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? appURL.deletingPathExtension().lastPathComponent

        let bundleId = bundle?.bundleIdentifier
        let category = AppCategorizer.categorize(bundleId: bundleId)

        return AppInfo(
            name: name,
            bundleId: bundleId,
            path: appURL.path,
            category: category
        )
    }
}
