import Darwin
import Foundation

/// 跨进程共享文件的路径定义。
///
/// App（非沙盒）与扩展（沙盒）的权限不对称，因此两个方向各走一条单向通道：
///
/// | 方向 | 位置 | App | 扩展 |
/// |---|---|---|---|
/// | 配置下行 | `~/Library/Application Scripts/{ext-id}/` | 读写 | 只读 |
/// | 错误上行 | `~/Library/Containers/{ext-id}/Data/` | 读写 | 读写 |
///
/// 两者都不经过 App Group 容器，避免 macOS 的 App Data（TCC）门禁在无付费开发者
/// 账号、无 Team ID 前缀、无 provisioning profile 授权时反复弹出授权提示。
public enum SharedPaths {
    /// 真实家目录。
    ///
    /// 沙盒进程里 `NSHomeDirectory()` 与 `FileManager.homeDirectoryForCurrentUser`
    /// 都返回容器内的 `Data` 目录，而 `getpwuid` 始终返回真实家目录 —— 两个进程算出
    /// 的绝对路径必须一致，所以这里统一用后者。
    public static func realHomeDirectory() -> URL {
        if let passwd = getpwuid(getuid()),
           let home = passwd.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home), isDirectory: true)
        }

        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// 共享配置（菜单项、图标缓存、发布状态）所在的 plist。
    ///
    /// 沙盒对扩展自己的 Application Scripts 目录天然授予读权限，无需 entitlement，
    /// 也不触发 TCC。但该目录对扩展**只读**，写入方只能是主 App。
    public static func extensionScriptsPreferencesURL(
        finderExtensionBundleID: String = RuntimeConfiguration.finderExtensionBundleID
    ) -> URL {
        extensionScriptsDirectory(finderExtensionBundleID: finderExtensionBundleID)
            .appendingPathComponent("rcmm.shared")
            .appendingPathExtension("plist")
    }

    public static func extensionScriptsDirectory(
        finderExtensionBundleID: String = RuntimeConfiguration.finderExtensionBundleID
    ) -> URL {
        realHomeDirectory()
            .appendingPathComponent("Library/Application Scripts")
            .appendingPathComponent(finderExtensionBundleID)
    }

    /// 错误队列所在的 plist，位于扩展沙盒容器内，两个进程都可写。
    public static func extensionContainerErrorQueueURL(
        finderExtensionBundleID: String = RuntimeConfiguration.finderExtensionBundleID
    ) -> URL {
        extensionContainerDataDirectory(finderExtensionBundleID: finderExtensionBundleID)
            .appendingPathComponent("Library/Preferences")
            .appendingPathComponent("rcmm.errors")
            .appendingPathExtension("plist")
    }

    public static func extensionContainerDataDirectory(
        finderExtensionBundleID: String = RuntimeConfiguration.finderExtensionBundleID
    ) -> URL {
        realHomeDirectory()
            .appendingPathComponent("Library/Containers")
            .appendingPathComponent(finderExtensionBundleID)
            .appendingPathComponent("Data")
    }

    /// 扩展容器是否已由 containermanagerd 建立。
    ///
    /// 容器必须由系统创建（含 `.com.apple.containermanagerd.metadata.plist`）。主 App
    /// 抢先创建目录会让后续扩展启动时容器结构不完整，因此 App 侧写入前必须先确认。
    public static func extensionContainerExists(
        finderExtensionBundleID: String = RuntimeConfiguration.finderExtensionBundleID,
        fileManager: FileManager = .default
    ) -> Bool {
        var isDirectory = ObjCBool(false)
        let path = extensionContainerDataDirectory(
            finderExtensionBundleID: finderExtensionBundleID
        ).path
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }
}
