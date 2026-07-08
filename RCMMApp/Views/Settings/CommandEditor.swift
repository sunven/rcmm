import RCMMShared
import SwiftUI

struct CommandEditor: View {
    @State private var editedName: String

    /// 编辑中的命令文本（内部 state，避免每次按键触发持久化）
    @State private var editedCommand: String

    /// 最后保存的命令值，用于去重（避免重复调用 onSave）
    @State private var lastSavedCommand: String
    @State private var lastSavedName: String
    @State private var executionMode: CustomCommandExecutionMode
    @State private var lastSavedExecutionMode: CustomCommandExecutionMode
    @State private var saveFeedbackID = 0
    @State private var showsSaveFeedback = false

    /// 当前生效的默认命令（内置映射或 open -a），作为 placeholder 显示
    let defaultCommand: String

    /// 应用路径，用于预览中替换 {app}
    let appPath: String

    /// 保存回调
    let onSave: (String, String?, CustomCommandExecutionMode) -> Void

    init(
        name: String,
        editedCommand: String,
        executionMode: CustomCommandExecutionMode,
        defaultCommand: String,
        appPath: String,
        onSave: @escaping (String, String?, CustomCommandExecutionMode) -> Void
    ) {
        self._editedName = State(initialValue: name)
        self._editedCommand = State(initialValue: editedCommand)
        self._lastSavedCommand = State(initialValue: editedCommand)
        self._lastSavedName = State(initialValue: name)
        self._executionMode = State(initialValue: executionMode)
        self._lastSavedExecutionMode = State(initialValue: executionMode)
        self.defaultCommand = defaultCommand
        self.appPath = appPath
        self.onSave = onSave
    }

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

    /// 是否正在使用默认命令（editedCommand 为空时回退）
    private var isUsingDefault: Bool {
        executionMode == .selectedPath && editedCommand.isEmpty
    }

    /// 自定义命令非空但缺少 {path} 占位符
    private var isMissingPathPlaceholder: Bool {
        executionMode == .selectedPath && !editedCommand.isEmpty && !editedCommand.contains("{path}")
    }

    private var validationIssues: [CustomCommandValidationIssue] {
        let item = MenuItemConfig(
            appName: editedName,
            appPath: appPath,
            customCommand: editedCommand.isEmpty ? nil : editedCommand,
            executionMode: executionMode
        )
        return CustomCommandValidator.validate(item).issues
    }

    private var hasChanges: Bool {
        editedName != lastSavedName
            || editedCommand != lastSavedCommand
            || executionMode != lastSavedExecutionMode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("菜单名称", text: $editedName)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)

            Picker("执行模式", selection: $executionMode) {
                ForEach(CustomCommandExecutionMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .accessibilityLabel("执行模式")

            TextField(defaultCommand, text: $editedCommand)
                .font(.system(.callout, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .autocorrectionDisabled()

            Text(helpText)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 3) {
                Text(isUsingDefault ? "当前生效命令：" : "预览：")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(previewCommand)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(isUsingDefault ? "默认命令" : "自定义命令")

            if !validationIssues.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(validationIssues.prefix(4)) { issue in
                        ValidationIssueRow(
                            isError: issue.severity == .error,
                            message: issue.message,
                            warningColor: .orange,
                            colorText: true,
                            spacing: 4,
                            smallIcon: true
                        )
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            if isMissingPathPlaceholder {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("命令中未包含 {path}，目标目录可能不会被传递")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("警告：命令中未包含路径占位符")
            }

            HStack(spacing: 8) {
                if executionMode == .selectedPath && !editedCommand.isEmpty {
                    Button("重置为默认") {
                        editedCommand = ""
                        commitChanges()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                if showsSaveFeedback {
                    SaveConfirmationLabel()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                Button("保存") {
                    commitChanges()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!hasChanges)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
        .accessibilityLabel("自定义命令编辑器")
        .accessibilityHint("输入命令并选择执行模式")
        .onDisappear {
            if hasChanges {
                commitChanges()
            }
        }
    }

    private var helpText: String {
        switch executionMode {
        case .selectedPath:
            return "{app} = 应用路径，{path} = 目标路径"
        case .currentDirectory:
            return "在 Finder 当前目录执行普通 shell 命令；文件目标会使用父目录"
        }
    }

    private func commitChanges() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedName = trimmedName.isEmpty ? editedName : trimmedName
        let command = editedCommand.isEmpty ? nil : editedCommand
        onSave(savedName, command, executionMode)
        lastSavedName = savedName
        editedName = savedName
        lastSavedCommand = editedCommand
        lastSavedExecutionMode = executionMode
        showSaveFeedback()
    }

    private func showSaveFeedback() {
        saveFeedbackID += 1
        let currentID = saveFeedbackID
        withAnimation(.easeOut(duration: 0.12)) {
            showsSaveFeedback = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard currentID == saveFeedbackID else { return }
            withAnimation(.easeIn(duration: 0.12)) {
                showsSaveFeedback = false
            }
        }
    }

    private func shellPreview(_ command: String) -> String {
        guard !command.isEmpty else {
            return "''"
        }

        return "'\(command.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

// MARK: - Previews

#Preview("默认命令回退") {
    CommandEditor(
        name: "Terminal",
        editedCommand: "",
        executionMode: .selectedPath,
        defaultCommand: "open -a \"{app}\" \"{path}\"",
        appPath: "/Applications/Terminal.app",
        onSave: { _, _, _ in }
    )
    .frame(width: 400)
    .padding()
}

#Preview("自定义命令 + 预览") {
    CommandEditor(
        name: "kitty",
        editedCommand: "{app} --single-instance --directory {path}",
        executionMode: .selectedPath,
        defaultCommand: "open -a \"{app}\" \"{path}\"",
        appPath: "/Applications/kitty.app/Contents/MacOS/kitty",
        onSave: { _, _, _ in }
    )
    .frame(width: 400)
    .padding()
}

#Preview("缺少 {path} 警告") {
    CommandEditor(
        name: "版本",
        editedCommand: "{app} --version",
        executionMode: .selectedPath,
        defaultCommand: "open -a \"{app}\" \"{path}\"",
        appPath: "/Applications/kitty.app/Contents/MacOS/kitty",
        onSave: { _, _, _ in }
    )
    .frame(width: 400)
    .padding()
}

#Preview("当前目录命令") {
    CommandEditor(
        name: "Git Pull",
        editedCommand: "git pull",
        executionMode: .currentDirectory,
        defaultCommand: "git pull",
        appPath: "",
        onSave: { _, _, _ in }
    )
    .frame(width: 400)
    .padding()
}
