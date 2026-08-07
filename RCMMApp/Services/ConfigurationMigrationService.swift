import Foundation
import os.log
import RCMMShared

/// 从旧 App Group 容器迁移配置到新的 Application Scripts 位置。
///
/// 旧版本把共享配置写在 App Group 容器（`~/Library/Group Containers/group.com.sunven.rcmm/`），
/// 但在无付费开发者账号、无 Team ID 前缀、无内嵌 provisioning profile 的情况下，该容器
/// 会触发 macOS 的 App Data（TCC）门禁，任何 App 弹文件选择器都会让 FinderSync 扩展
/// 初始化时反复弹授权提示。
///
/// 新版改为双通道：配置下行走 Application Scripts（扩展只读、App 读写、无 TCC），
/// 错误上行走扩展沙盒容器（两者都可写、无 TCC）。
final class ConfigurationMigrationService {
    private let logger = Logger(subsystem: "com.sunven.rcmm", category: "migration")
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// 执行一次性迁移：App Group → Application Scripts。
    ///
    /// 迁移完成后会在新位置标记 `rcmm.migration.completed`，避免重复执行。
    func migrateIfNeeded() {
        let newStore = SharedPreferencesStore()
        guard !newStore.bool(forKey: "rcmm.migration.completed") else {
            logger.info("配置迁移已完成，跳过")
            return
        }

        guard let legacyURL = SharedPreferencesStore.legacyAppGroupPreferencesURL(
            fileManager: fileManager
        ) else {
            logger.info("旧 App Group 容器不存在，无需迁移")
            markMigrationCompleted(in: newStore)
            return
        }

        guard fileManager.fileExists(atPath: legacyURL.path) else {
            logger.info("旧配置文件不存在: \(legacyURL.path, privacy: .public)")
            markMigrationCompleted(in: newStore)
            return
        }

        logger.info("开始迁移配置: \(legacyURL.path, privacy: .public)")

        let legacyStore = SharedPreferencesStore(
            propertyListURL: legacyURL,
            fileManager: fileManager
        )

        migrateKey(SharedKeys.menuEntries, from: legacyStore, to: newStore)
        migrateKey(SharedKeys.applicationIcons, from: legacyStore, to: newStore)
        migrateKey(SharedKeys.menuPresentationMode, from: legacyStore, to: newStore)
        migrateKey(SharedKeys.scriptPublishStates, from: legacyStore, to: newStore)
        migrateKey(SharedKeys.onboardingCompleted, from: legacyStore, to: newStore)
        migrateKey(SharedKeys.legacyCopyPathEnabled, from: legacyStore, to: newStore)

        markMigrationCompleted(in: newStore)
        logger.info("配置迁移完成")
    }

    private func migrateKey(
        _ key: String,
        from source: SharedPreferencesStore,
        to destination: SharedPreferencesStore
    ) {
        guard let value = source.object(forKey: key) else {
            return
        }
        destination.set(value, forKey: key)
        logger.debug("已迁移 key: \(key, privacy: .public)")
    }

    private func markMigrationCompleted(in store: SharedPreferencesStore) {
        store.set(true, forKey: "rcmm.migration.completed")
    }
}
