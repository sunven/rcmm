import RCMMShared
import SwiftUI

struct ExtensionCleanupSheet: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(16)
        .frame(width: 540)
        .interactiveDismissDisabled(isCleanupRunning)
    }

    @ViewBuilder
    private var content: some View {
        switch appState.extensionCleanupFlowState {
        case .idle:
            Text("未开始清理。")

        case .planning:
            VStack(spacing: 12) {
                Spacer(minLength: 20)
                ProgressView("正在扫描旧扩展副本…")
                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity, alignment: .center)

        case .review(let plan):
            VStack(alignment: .leading, spacing: 12) {
                Text("清理旧扩展副本")
                    .font(.headline)

                Text(plan.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("不会处理 /Applications 中的正式安装版。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        GroupBox("待删除副本（\(plan.deleteCandidates.count)）") {
                            if plan.deleteCandidates.isEmpty {
                                Text("未发现可删除副本")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(plan.deleteCandidates) { candidate in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(candidate.appPath)
                                                .font(.system(.caption, design: .monospaced))
                                            Text(sourceLabel(for: candidate.source))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }

                        GroupBox("待结束进程（\(plan.processesToTerminate.count)）") {
                            if plan.processesToTerminate.isEmpty {
                                Text("未发现旧 rcmm 进程")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(plan.processesToTerminate) { process in
                                        Text("PID \(process.pid)  \(process.appPath)")
                                            .font(.system(.caption, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }

                        GroupBox("清理后命令（\(plan.postCleanupCommands.count)）") {
                            if plan.postCleanupCommands.isEmpty {
                                Text("无额外命令")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(plan.postCleanupCommands.enumerated()), id: \.offset) { _, command in
                                        Text(command)
                                            .font(.system(.caption, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(minHeight: 200, maxHeight: 320)

                HStack {
                    Button("取消") {
                        appState.dismissExtensionCleanupSheet()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("确认清理") {
                        appState.confirmExtensionCleanup(plan: plan)
                    }
                    .buttonStyle(.borderedProminent)
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
            VStack(alignment: .leading, spacing: 10) {
                Text("清理结果")
                    .font(.headline)

                Text(result.message)
                    .font(.subheadline)

                if !result.followUpAdvice.isEmpty {
                    GroupBox("后续建议") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(result.followUpAdvice.enumerated()), id: \.offset) { _, advice in
                                Text("• \(advice)")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HStack {
                    Spacer()
                    Button("完成") {
                        appState.dismissExtensionCleanupSheet()
                    }
                    .buttonStyle(.borderedProminent)
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

    private var isCleanupRunning: Bool {
        if case .running = appState.extensionCleanupFlowState {
            return true
        }
        return false
    }
}

#Preview("Planning") {
    let state = AppState(forPreview: true)
    state.isShowingExtensionCleanupSheet = true
    state.extensionCleanupFlowState = .planning
    return ExtensionCleanupSheet()
        .environment(state)
}
