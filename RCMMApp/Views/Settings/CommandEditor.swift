import RCMMShared
import SwiftUI

struct CommandEditor: View {
    @Binding var config: MenuItemConfig
    let defaultCommand: String
    @Environment(SettingsDraftStore.self) private var drafts

    private var editedCommand: String { config.customCommand ?? "" }
    private var executionMode: CustomCommandExecutionMode { config.executionMode }
    private var appPath: String { config.appPath }

    /// 当前生效的命令：自定义命令优先，空则回退到默认命令
    private var effectiveCommand: String {
        if executionMode == .currentDirectory {
            return editedCommand
        }
        return editedCommand.isEmpty ? defaultCommand : editedCommand
    }

    /// 实时预览：替换占位符后的完整命令
    private var previewCommand: String {
        if executionMode == .currentDirectory {
            return "cd /Users/example/project && /bin/zsh -lc \(shellPreview(editedCommand))"
        }
        return effectiveCommand
            .replacingOccurrences(of: "{app}", with: appPath)
            .replacingOccurrences(of: "{path}", with: "/Users/example/project")
    }

    /// 自定义命令非空但缺少 {path} 占位符
    private var isMissingPathPlaceholder: Bool {
        executionMode == .selectedPath && !editedCommand.isEmpty && !editedCommand.contains("{path}")
    }

    private var validationIssues: [MenuEntryIssue] {
        drafts.issues(for: .command(config.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RCMMField("菜单名称") {
                TextField("菜单名称", text: $config.appName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }

            RCMMField("执行方式") {
                Picker("执行方式", selection: $config.executionMode) {
                    ForEach(CustomCommandExecutionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .labelsHidden()
            }

            RCMMField(executionMode == .currentDirectory ? "Shell 命令" : "启动命令") {
                TextField(defaultCommand, text: Binding(get: { editedCommand }, set: { config.customCommand = $0.isEmpty ? nil : $0 }))
                    .font(.system(.callout, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .autocorrectionDisabled()

                Text(helpText)
                    .font(RCMMFont.caption)
                    .foregroundStyle(RCMMColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                RCMMFieldLabel(drafts.hasChanges(.command(config.id)) ? "草稿预览" : "已保存命令预览")
                RCMMCodeBlock(text: previewCommand)
            }

            if !validationIssues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(validationIssues.prefix(4)) { issue in
                        ValidationIssueRow(
                            isError: issue.severity == .error,
                            message: issue.message
                        )
                    }
                }
            }

            if isMissingPathPlaceholder {
                RCMMInlineMessage("命令中未包含 {path}，目标目录可能不会被传递", kind: .warning)
            }

            if executionMode == .selectedPath && !editedCommand.isEmpty {
                Button("重置为默认命令") { config.customCommand = nil }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            EditorSaveBar(key: .command(config.id))
        }
        .padding(.top, 2)
    }

    private var helpText: String {
        switch executionMode {
        case .selectedPath:
            return "{app} = 应用路径，{path} = 目标路径"
        case .currentDirectory:
            return "在 Finder 当前目录执行普通 shell 命令；文件目标会使用父目录"
        }
    }

    private func shellPreview(_ command: String) -> String {
        guard !command.isEmpty else {
            return "''"
        }

        return "'\(command.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

#Preview("命令草稿") {
    let model = AppModel(forPreview: true)
    CommandEditor(
        config: .constant(MenuItemConfig(appName: "Terminal", appPath: "/System/Applications/Utilities/Terminal.app")),
        defaultCommand: "open -a {app} {path}"
    )
    .environment(model.settingsDraftStore)
    .frame(width: 320)
    .padding()
}
