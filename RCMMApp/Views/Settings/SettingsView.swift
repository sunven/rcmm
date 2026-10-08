import SwiftUI

struct SettingsView: View {
    @Environment(SettingsDraftStore.self) private var drafts
    @State private var selectedDestination: SettingsDestination = .finderMenu
    @State private var selectedFinderEntryID: String?
    @State private var focusedCompositeID: String?

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selectedDestination)

            Divider()

            content
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if drafts.count > 0 {
                Text("\(drafts.count) 项未保存 · 草稿仅在本次运行期间保留，退出应用后不保留。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
            }
        }
        .frame(minWidth: 820, idealWidth: 820, minHeight: 500, idealHeight: 540)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedDestination {
        case .finderMenu:
            MenuConfigTab(
                selectedEntryID: $selectedFinderEntryID,
                onOpenNewFileSettings: {
                    selectedDestination = .newFile
                },
                onOpenCompositeSettings: { id in
                    focusedCompositeID = id
                    selectedDestination = .compositeCommands
                }
            )
        case .newFile:
            NewFileSettingsTab()
        case .compositeCommands:
            CompositeCommandsTab(focusCompositeID: focusedCompositeID)
        case .general:
            GeneralTab()
        case .about:
            AboutTab()
        }
    }
}
