import Foundation

public enum NewFileMenuStatusKind: String, Codable, Hashable, Sendable {
    case disabled
    case unavailable
    case partiallyAvailable
    case warning
    case syncing
    case ready
}

public struct NewFileMenuStatus: Codable, Hashable, Sendable {
    public let kind: NewFileMenuStatusKind
    public let displayName: String

    public init(kind: NewFileMenuStatusKind, displayName: String) {
        self.kind = kind
        self.displayName = displayName
    }
}

public enum NewFileMenuStatusResolver: Sendable {
    public static func resolve(
        config: NewFileMenuConfig,
        publishStates: [String: ScriptPublishState]
    ) -> NewFileMenuStatus {
        let validation = NewFileMenuValidator.validate(config)
        return resolve(
            config: config,
            validation: validation,
            publishedTemplateCount: FinderMenuPresenter
                .visibleNewFileTemplates(for: config, publishStates: publishStates)
                .count
        )
    }

    public static func resolve(
        config: NewFileMenuConfig,
        validation: NewFileValidationResult,
        publishedTemplateCount: Int
    ) -> NewFileMenuStatus {
        if !config.isEnabled {
            return NewFileMenuStatus(kind: .disabled, displayName: "已停用")
        }
        if validation.hasErrors && validation.executableTemplateIDs.isEmpty {
            return NewFileMenuStatus(kind: .unavailable, displayName: "不可用")
        }
        if validation.hasErrors {
            return NewFileMenuStatus(kind: .partiallyAvailable, displayName: "部分可用")
        }
        if validation.hasWarnings {
            return NewFileMenuStatus(kind: .warning, displayName: "有警告")
        }
        if publishedTemplateCount < validation.executableTemplateIDs.count {
            return NewFileMenuStatus(kind: .syncing, displayName: "同步中")
        }
        return NewFileMenuStatus(kind: .ready, displayName: "就绪")
    }
}
