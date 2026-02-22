import SwiftUI

struct CommandEditor: View {
    /// 编辑中的命令文本（内部 state，避免每次按键触发持久化）
    @State private var editedCommand: String

    /// 初始命令值，用于判断是否有变更（避免无修改时触发 saveAndSync）
    private let originalCommand: String

    /// 当前生效的默认命令（内置映射或 open -a），作为 placeholder 显示
    let defaultCommand: String

    /// 应用路径，用于预览中替换 {app}
    let appPath: String

    /// 保存回调
    let onSave: (String?) -> Void

    init(editedCommand: String, defaultCommand: String, appPath: String, onSave: @escaping (String?) -> Void) {
        self._editedCommand = State(initialValue: editedCommand)
        self.originalCommand = editedCommand
        self.defaultCommand = defaultCommand
        self.appPath = appPath
        self.onSave = onSave
    }

    /// 实时预览：替换占位符后的完整命令
    private var previewCommand: String {
        let command = editedCommand
        return command
            .replacingOccurrences(of: "{app}", with: appPath)
            .replacingOccurrences(of: "{path}", with: "/Users/example/project")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自定义命令：")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(defaultCommand, text: $editedCommand)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Text("{app} = 应用路径，{path} = 目标目录")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if !editedCommand.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("预览：")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(previewCommand)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Button("重置为默认") {
                    editedCommand = ""
                    onSave(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("自定义命令编辑器")
        .accessibilityHint("输入命令模板，支持 {app} 和 {path} 占位符")
        .onDisappear {
            let newValue = editedCommand.isEmpty ? nil : editedCommand
            let oldValue = originalCommand.isEmpty ? nil : originalCommand
            if newValue != oldValue {
                onSave(newValue)
            }
        }
    }
}
