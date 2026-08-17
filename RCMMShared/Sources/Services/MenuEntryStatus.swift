import Foundation

/// Menu Entry 的运行状态。
///
/// 词汇由 DESIGN.md「Finder Menu Row」一节规定：徽章必须映射真实的运行状态，
/// 不是类型标签。条目类型由 `FinderMenuEntrySummary.typeLabel` 单独承载。
public struct MenuEntryStatus: Hashable, Sendable {
    public let kind: FinderMenuEntryStatusKind
    public let text: String
    public let detail: String?

    public init(kind: FinderMenuEntryStatusKind, text: String, detail: String?) {
        self.kind = kind
        self.text = text
        self.detail = detail
    }
}

/// 状态阶梯 —— 全应用唯一一处。
///
/// 此前 composite 与 New File Menu 各写了一遍同形状的阶梯，custom 一条都没有：
/// 它只问「应用路径存在吗」，既不看校验结果也不看 Publish State，于是编译失败、
/// 配置刚改、名称超长的条目在设置界面全都显示「就绪」，而 Finder 里根本没有它们。
public enum MenuEntryStatusResolver: Sendable {
    public static func status(
        for entry: MenuEntry,
        evaluation: MenuEntryEvaluation,
        publishStates: [String: ScriptPublishState]
    ) -> MenuEntryStatus {
        guard entry.isEnabled else {
            return MenuEntryStatus(kind: .disabled, text: "已停用", detail: nil)
        }

        // Built-in Entry 没有脚本，也就没有发布状态可言 —— 阶梯从这里往下都不适用。
        if entry.isBuiltIn {
            return MenuEntryStatus(
                kind: .system,
                text: "系统",
                detail: "内置 Finder 菜单功能"
            )
        }

        if evaluation.hasErrors {
            return MenuEntryStatus(
                kind: evaluation.hasExecutableChildren ? .partiallyAvailable : .unavailable,
                text: evaluation.hasExecutableChildren ? "部分可用" : "不可用",
                detail: evaluation.errors.first?.message
            )
        }

        if evaluation.hasWarnings {
            return MenuEntryStatus(
                kind: .warning,
                text: "有警告",
                detail: evaluation.warnings.first?.message
            )
        }

        return publishStatus(for: evaluation, publishStates: publishStates)
    }

    private static func publishStatus(
        for evaluation: MenuEntryEvaluation,
        publishStates: [String: ScriptPublishState]
    ) -> MenuEntryStatus {
        var pendingDetail: String?

        for scriptBackedEntry in evaluation.scriptBacked {
            guard let publishState = publishStates[scriptBackedEntry.id] else {
                pendingDetail = pendingDetail ?? "等待脚本同步"
                continue
            }

            guard publishState.fingerprint == scriptBackedEntry.fingerprint else {
                pendingDetail = pendingDetail ?? "配置已变化，等待重新同步"
                continue
            }

            // 编译失败比「还在同步」更该被看见，直接返回。
            if publishState.status == .compileFailed {
                return MenuEntryStatus(
                    kind: .failed,
                    text: "同步失败",
                    detail: publishState.errorSummary
                )
            }
        }

        if let pendingDetail {
            return MenuEntryStatus(kind: .syncing, text: "同步中", detail: pendingDetail)
        }

        // 无 error、无 warning 却一个脚本都没产出 —— 理论上不可达，按等待同步处理而不是就绪。
        guard !evaluation.scriptBacked.isEmpty else {
            return MenuEntryStatus(kind: .syncing, text: "同步中", detail: "等待脚本同步")
        }

        return MenuEntryStatus(kind: .ready, text: "就绪", detail: "脚本已同步")
    }
}
