import SwiftUI

struct SettingsView: View {
    @Environment(SettingsDraftStore.self) private var drafts
    @State private var selectedDestination: SettingsDestination = .finderMenu
    @State private var selectedFinderEntryID: String?
    @State private var focusedCompositeID: String?

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selectedDestination)

            content
        }
        .background(RCMMColor.window)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if drafts.count > 0 {
                draftsBar
            }
        }
        .frame(minWidth: 880, idealWidth: 940, minHeight: 540, idealHeight: 600)
    }

    private var draftsBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(RCMMColor.accentText)

            Text("\(drafts.count) 项未保存的修改")
                .font(RCMMFont.caption)
                .foregroundStyle(RCMMColor.textSecondary)
                .monospacedDigit()

            Text("草稿仅在本次运行期间保留")
                .font(RCMMFont.caption)
                .foregroundStyle(RCMMColor.textMuted)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RCMMColor.surfaceSoft)
        .overlay(alignment: .top) {
            RCMMDivider()
        }
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
