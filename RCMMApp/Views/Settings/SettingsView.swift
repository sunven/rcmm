import SwiftUI

struct SettingsView: View {
    @State private var selectedDestination: SettingsDestination = .finderMenu
    @State private var selectedFinderEntryID: String?
    @State private var focusedCompositeID: String?

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selectedDestination)

            Divider()

            content
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
