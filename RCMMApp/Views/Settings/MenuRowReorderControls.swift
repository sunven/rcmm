import SwiftUI

struct MenuRowActionsMenu: View {
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var deleteLabel = "删除"

    @ViewBuilder
    var body: some View {
        if onMoveUp != nil || onMoveDown != nil || onDelete != nil {
            Menu {
                if let onMoveUp {
                    Button(action: onMoveUp) {
                        Label("上移", systemImage: "arrow.up")
                    }
                }

                if let onMoveDown {
                    Button(action: onMoveDown) {
                        Label("下移", systemImage: "arrow.down")
                    }
                }

                if let onDelete {
                    Divider()
                    Button(role: .destructive, action: onDelete) {
                        Label(deleteLabel, systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RCMMColor.textMuted)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("更多操作")
            .accessibilityLabel("更多操作")
        }
    }
}
