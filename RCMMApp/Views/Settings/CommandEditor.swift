import SwiftUI

struct CommandEditor: View {
    /// 编辑中的命令文本（内部 state，避免每次按键触发持久化）
    @State private var editedCommand: String

    /// 最后保存的命令值，用于去重（避免重复调用 onSave）
    @State private var lastSavedCommand: String

    /// 当前生效的默认命令（内置映射或 open -a），作为 placeholder 显示
    let defaultCommand: String

    /// 应用路径，用于预览中替换 {app}
    let appPath: String

    /// 保存回调
    let onSave: (String?) -> Void

    init(editedCommand: String, defaultCommand: String, appPath: String, onSave: @escaping (String?) -> Void) {
        self._editedCommand = State(initialValue: editedCommand)
        self._lastSavedCommand = State(initialValue: editedCommand)
        self.defaultCommand = defaultCommand
        self.appPath = appPath
        self.onSave = onSave
    }

    /// 当前生效的命令：自定义命令优先，空则回退到默认命令
    private var effectiveCommand: String {
        editedCommand.isEmpty ? defaultCommand : editedCommand
    }

    /// 实时预览：替换占位符后的完整命令
    private var previewCommand: String {
        effectiveCommand
            .replacingOccurrences(of: "{app}", with: appPath)
            .replacingOccurrences(of: "{path}", with: "/Users/example/project")
    }

    /// 是否正在使用默认命令（editedCommand 为空时回退）
    private var isUsingDefault: Bool {
        editedCommand.isEmpty
    }

    /// 自定义命令非空但缺少 {path} 占位符
    private var isMissingPathPlaceholder: Bool {
        !editedCommand.isEmpty && !editedCommand.contains("{path}")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("自定义命令：")
                .font(.caption2)
                .foregroundStyle(.secondary)

            TextField(defaultCommand, text: $editedCommand)
                .font(.system(.callout, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .autocorrectionDisabled()

            Text("{app} = 应用路径，{path} = 目标目录")
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

            if !editedCommand.isEmpty {
                Button("重置为默认") {
                    editedCommand = ""
                    lastSavedCommand = ""
                    onSave(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
        .accessibilityLabel("自定义命令编辑器")
        .accessibilityHint("输入命令模板，支持 {app} 和 {path} 占位符")
        .onDisappear {
            let newValue = editedCommand.isEmpty ? nil : editedCommand
            let oldValue = lastSavedCommand.isEmpty ? nil : lastSavedCommand
            if newValue != oldValue {
                onSave(newValue)
            }
        }
    }
}

// MARK: - Previews

#Preview("默认命令回退") {
    CommandEditor(
        editedCommand: "",
        defaultCommand: "open -a \"{app}\" \"{path}\"",
        appPath: "/Applications/Terminal.app",
        onSave: { _ in }
    )
    .frame(width: 400)
    .padding()
}

#Preview("自定义命令 + 预览") {
    CommandEditor(
        editedCommand: "{app} --single-instance --directory {path}",
        defaultCommand: "open -a \"{app}\" \"{path}\"",
        appPath: "/Applications/kitty.app/Contents/MacOS/kitty",
        onSave: { _ in }
    )
    .frame(width: 400)
    .padding()
}

#Preview("缺少 {path} 警告") {
    CommandEditor(
        editedCommand: "{app} --version",
        defaultCommand: "open -a \"{app}\" \"{path}\"",
        appPath: "/Applications/kitty.app/Contents/MacOS/kitty",
        onSave: { _ in }
    )
    .frame(width: 400)
    .padding()
}
