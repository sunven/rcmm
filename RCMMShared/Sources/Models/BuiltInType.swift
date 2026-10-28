import Foundation

public enum BuiltInType: String, Codable, Sendable, CaseIterable {
    case copyPath
    case cleanNodeModules
    case cleanJavaTarget
    case cleanRustTarget

    public var requiresPublishedScript: Bool {
        isCleanup
    }

    /// 清理型内置项：点击后先扫描候选目录，确认后移到废纸篓。
    public var isCleanup: Bool {
        cleanupProfile != nil
    }

    public var cleanupProfile: BuiltInCleanupProfile? {
        switch self {
        case .copyPath:
            return nil
        case .cleanNodeModules:
            return BuiltInCleanupProfile(
                noun: "node_modules",
                emptyResultHint: nil
            )
        case .cleanJavaTarget:
            return BuiltInCleanupProfile(
                noun: "Java target",
                emptyResultHint: "同级存在 pom.xml / build.gradle / build.gradle.kts / build.xml"
            )
        case .cleanRustTarget:
            return BuiltInCleanupProfile(
                noun: "Rust target",
                emptyResultHint: "同级存在 Cargo.toml"
            )
        }
    }
}

public struct BuiltInCleanupProfile: Hashable, Sendable {
    /// 展示在确认面板与结果文案里的清理对象名词。
    public let noun: String
    /// 扫描无结果时解释匹配条件；nil 表示无需额外说明。
    public let emptyResultHint: String?

    public init(noun: String, emptyResultHint: String?) {
        self.noun = noun
        self.emptyResultHint = emptyResultHint
    }
}
