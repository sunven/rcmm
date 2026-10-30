import RCMMShared
import SwiftUI

struct EditorSaveBar: View {
    let key: SettingsDraftStore.Key
    @Environment(SettingsDraftStore.self) private var drafts
    @State private var isRetrying = false
    @State private var confirmsOverwrite = false

    private var hasChanges: Bool { drafts.hasChanges(key) }

    var body: some View {
        let savedStatus = drafts.savedStatus(for: key)

        return VStack(alignment: .leading, spacing: 8) {
            if drafts.hasConflict(key) {
                RCMMInlineMessage("已保存内容发生变化，草稿已保留。", kind: .warning)

                HStack(spacing: 8) {
                    Button("载入最新，放弃草稿") { drafts.discard(key) }
                    Button("用草稿覆盖") { confirmsOverwrite = true }
                        .disabled(!drafts.canSave(key, overwrite: true))
                }
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusDotColor(savedStatus: savedStatus))
                        .frame(width: 5, height: 5)
                    Text(statusText(savedStatus: savedStatus))
                        .font(RCMMFont.caption)
                        .foregroundStyle(RCMMColor.textMuted)
                }

                Spacer(minLength: 0)

                Button("放弃修改") { drafts.discard(key) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!hasChanges)

                Button("保存") { drafts.save(key) }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .controlSize(.small)
                    .disabled(!drafts.canSave(key))
            }
            .padding(.top, 2)

            if hasChanges, drafts.issues(for: key).contains(where: { $0.severity == .error }) {
                RCMMInlineMessage("请修正错误后保存；草稿会在本次运行期间保留。", kind: .warning)
            }

            if let savedStatus, savedStatus.kind == .failed {
                if let detail = savedStatus.detail {
                    RCMMCodeBlock(text: detail)
                }

                Button(isRetrying ? "正在重新同步…" : "重新同步") {
                    isRetrying = true
                    Task { @MainActor in
                        await drafts.retrySync()
                        isRetrying = false
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRetrying)
            }
        }
        .confirmationDialog("用草稿覆盖最新的已保存内容？", isPresented: $confirmsOverwrite) {
            Button("用草稿覆盖", role: .destructive) { drafts.save(key, overwrite: true) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只覆盖当前对象的编辑内容，保留最新的菜单启停和排序。")
        }
    }

    private func statusText(savedStatus: MenuEntryStatus?) -> String {
        if hasChanges {
            return "未保存修改"
        }
        guard let savedStatus else {
            return "已保存"
        }
        return "已保存 · \(savedStatus.text)"
    }

    private func statusDotColor(savedStatus: MenuEntryStatus?) -> Color {
        if hasChanges {
            return RCMMColor.accent
        }
        if let savedStatus {
            return FinderMenuStatusStyle.color(for: savedStatus.kind)
        }
        return RCMMColor.success
    }
}
