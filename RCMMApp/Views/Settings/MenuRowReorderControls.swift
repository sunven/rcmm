import SwiftUI

struct MenuRowReorderControls: View {
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    var body: some View {
        HStack(spacing: 2) {
            Button {
                onMoveUp?()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 16, height: 18)
            }
            .buttonStyle(.plain)
            .disabled(onMoveUp == nil)
            .opacity(onMoveUp == nil ? 0.28 : 1)
            .help("上移")
            .accessibilityLabel("上移")

            Button {
                onMoveDown?()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 16, height: 18)
            }
            .buttonStyle(.plain)
            .disabled(onMoveDown == nil)
            .opacity(onMoveDown == nil ? 0.28 : 1)
            .help("下移")
            .accessibilityLabel("下移")
        }
        .foregroundStyle(.secondary)
        .frame(width: 36)
    }
}
