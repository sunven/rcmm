import RCMMShared
import SwiftUI

struct EditorSaveBar: View {
    let key: SettingsDraftStore.Key
    @Environment(SettingsDraftStore.self) private var drafts
    @State private var isRetrying = false
    @State private var confirmsOverwrite = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if drafts.hasConflict(key) {
                Label("已保存内容发生变化，草稿已保留。", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                HStack {
                    Button("载入最新，放弃草稿") { drafts.discard(key) }
                    Button("用草稿覆盖") { confirmsOverwrite = true }
                        .disabled(!drafts.canSave(key, overwrite: true))
                }
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                Label(drafts.hasChanges(key) ? "未保存修改" : "已保存", systemImage: drafts.hasChanges(key) ? "pencil" : "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button("放弃修改") { drafts.discard(key) }
                    .disabled(!drafts.hasChanges(key))
                Button("保存") { drafts.save(key) }
                    .disabled(!drafts.canSave(key))
            }
            .controlSize(.small)

            if drafts.hasChanges(key), drafts.issues(for: key).contains(where: { $0.severity == .error }) {
                Text("请修正错误后保存；草稿会在本次运行期间保留。")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if let status = drafts.savedStatus(for: key) {
                Label("已保存版本：\(status.text)", systemImage: FinderMenuStatusStyle.symbol(for: status.kind))
                    .font(.caption2)
                    .foregroundStyle(FinderMenuStatusStyle.color(for: status.kind))
                if status.kind == .failed {
                    if let detail = status.detail {
                        Text(detail).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Button(isRetrying ? "正在重新同步…" : "重新同步") {
                        isRetrying = true
                        Task { @MainActor in
                            await drafts.retrySync()
                            isRetrying = false
                        }
                    }
                    .controlSize(.small)
                    .disabled(isRetrying)
                }
            }
        }
        .confirmationDialog("用草稿覆盖最新的已保存内容？", isPresented: $confirmsOverwrite) {
            Button("用草稿覆盖", role: .destructive) { drafts.save(key, overwrite: true) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只覆盖当前对象的编辑内容，保留最新的菜单启停和排序。")
        }
    }
}
