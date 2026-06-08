import AppKit
import SwiftUI

struct SettingsSidebar: View {
    @Binding var selection: SettingsDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("rcmm 设置")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 6)

            ForEach(SettingsDestination.allCases) { destination in
                Button {
                    selection = destination
                } label: {
                    Label(destination.title, systemImage: destination.systemImage)
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selection == destination ? Color.accentColor.opacity(0.14) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == destination ? .primary : .secondary)
                .accessibilityLabel(destination.title)
                .accessibilityAddTraits(selection == destination ? [.isSelected] : [])
            }

            Spacer()
        }
        .frame(width: 176)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
