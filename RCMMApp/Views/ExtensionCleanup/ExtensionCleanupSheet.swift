import RCMMShared
import SwiftUI

struct ExtensionCleanupSheet: View {
    @Environment(ExtensionCleanupCoordinator.self) private var cleanupCoordinator
    let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(18)
        .frame(width: 560)
        .background(RCMMColor.window)
        .interactiveDismissDisabled(true)
    }

    @ViewBuilder
    private var content: some View {
        switch cleanupCoordinator.state {
        case .idle:
            Text("未开始清理。")
                .font(RCMMFont.secondary)
                .foregroundStyle(RCMMColor.textMuted)

        case .planning:
            VStack(spacing: 12) {
                Spacer(minLength: 20)
                ProgressView("正在扫描旧扩展副本…")
                Spacer(minLength: 20)

                Button("取消") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }
            .frame(maxWidth: .infinity, alignment: .center)

        case .review(let plan):
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("清理旧扩展副本")
                        .font(RCMMFont.sheetTitle)
                        .foregroundStyle(RCMMColor.textPrimary)

                    Text(plan.summary)
                        .font(RCMMFont.secondary)
                        .foregroundStyle(RCMMColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("不会处理 /Applications 中的正式安装版。")
                        .font(RCMMFont.caption)
                        .foregroundStyle(RCMMColor.textFaint)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        CleanupSection(title: "待删除副本", count: plan.deleteCandidates.count) {
                            if plan.deleteCandidates.isEmpty {
                                CleanupEmptyRow(text: "未发现可删除副本")
                            } else {
                                ForEach(plan.deleteCandidates) { candidate in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.appPath)
                                            .font(RCMMFont.code)
                                            .foregroundStyle(RCMMColor.textSecondary)
                                            .textSelection(.enabled)
                                        Text(sourceLabel(for: candidate.source))
                                            .font(RCMMFont.caption)
                                            .foregroundStyle(RCMMColor.textMuted)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        CleanupSection(title: "待结束进程", count: plan.processesToTerminate.count) {
                            if plan.processesToTerminate.isEmpty {
                                CleanupEmptyRow(text: "未发现旧 rcmm 进程")
                            } else {
                                ForEach(plan.processesToTerminate) { process in
                                    Text("PID \(process.pid)  \(process.appPath)")
                                        .font(RCMMFont.code)
                                        .foregroundStyle(RCMMColor.textSecondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        CleanupSection(
                            title: "清理后命令",
                            count: plan.postCleanupCommands.count,
                            trailingAction: plan.postCleanupCommands.isEmpty ? nil : {
                                copyCommands(plan.postCleanupCommands)
                            }
                        ) {
                            if plan.postCleanupCommands.isEmpty {
                                CleanupEmptyRow(text: "无额外命令")
                            } else {
                                ForEach(Array(plan.postCleanupCommands.enumerated()), id: \.offset) { _, command in
                                    Text(command)
                                        .font(RCMMFont.code)
                                        .foregroundStyle(RCMMColor.textSecondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(minHeight: 190, maxHeight: 300)

                HStack {
                    Button("取消") {
                        onDismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("确认清理") {
                        cleanupCoordinator.confirm(plan: plan)
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(!plan.hasWork)
                    .keyboardShortcut(.defaultAction)
                }
            }

        case .running(let step):
            VStack(spacing: 12) {
                Spacer(minLength: 20)
                ProgressView(step.title)
                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity, alignment: .center)

        case .finished(let result):
            VStack(alignment: .leading, spacing: 12) {
                Text("清理结果")
                    .font(RCMMFont.sheetTitle)
                    .foregroundStyle(RCMMColor.textPrimary)

                Text(result.message)
                    .font(RCMMFont.secondary)
                    .foregroundStyle(RCMMColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !result.followUpAdvice.isEmpty {
                    CleanupSection(title: "后续建议", count: nil) {
                        ForEach(Array(result.followUpAdvice.enumerated()), id: \.offset) { _, advice in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 3))
                                    .foregroundStyle(RCMMColor.textFaint)
                                    .padding(.top, 5)
                                Text(advice)
                                    .font(RCMMFont.caption)
                                    .foregroundStyle(RCMMColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("完成") {
                        onDismiss()
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private func sourceLabel(for source: ExtensionCleanupCandidateSource) -> String {
        switch source {
        case .pluginKit:
            return "来源：PluginKit"
        case .derivedData:
            return "来源：DerivedData"
        case .devRelease:
            return "来源：dev-release"
        case .unsupported:
            return "来源：不支持目录"
        }
    }

    private func copyCommands(_ commands: [String]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(commands.joined(separator: "\n"), forType: .string)
    }
}

private struct CleanupSection<Content: View>: View {
    let title: String
    let count: Int?
    var trailingAction: (() -> Void)?
    @ViewBuilder let content: Content

    init(
        title: String,
        count: Int?,
        trailingAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.count = count
        self.trailingAction = trailingAction
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(RCMMFont.sectionTitle)
                    .foregroundStyle(RCMMColor.textMuted)

                if let count {
                    Text("\(count)")
                        .font(RCMMFont.caption)
                        .monospacedDigit()
                        .foregroundStyle(RCMMColor.textFaint)
                }

                Spacer()

                if let trailingAction {
                    Button(action: trailingAction) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(RCMMColor.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("复制清理后命令")
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                content
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(RCMMColor.surface)
            )
        }
    }
}

private struct CleanupEmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(RCMMFont.caption)
            .foregroundStyle(RCMMColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Planning") {
    let plan = ExtensionCleanupPlan(
        currentAppPath: nil,
        deleteCandidates: [],
        skippedCandidates: [],
        processesToTerminate: [],
        postCleanupCommands: []
    )!
    let coordinator = ExtensionCleanupCoordinator(
        initialState: .planning,
        preparePlan: { plan },
        execute: { _, _ in
            ExtensionCleanupResult.noOp(message: "", followUpAdvice: [])
        }
    )
    return ExtensionCleanupSheet()
        .environment(coordinator)
}
