import SwiftUI

struct SettingsView: View {
    @State private var selectedDestination: SettingsDestination = .finderMenu
    @State private var selectedFinderEntryID: String?

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selectedDestination)

            Divider()

            content
        }
        .frame(minWidth: 720, idealWidth: 820, minHeight: 500, idealHeight: 560)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedDestination {
        case .finderMenu:
            MenuConfigTab(
                selectedEntryID: $selectedFinderEntryID,
                onOpenNewFileSettings: {
                    selectedDestination = .newFile
                }
            )
        case .newFile:
            NewFileSettingsTab()
        case .general:
            GeneralTab()
        case .about:
            AboutTab()
        }
    }
}
