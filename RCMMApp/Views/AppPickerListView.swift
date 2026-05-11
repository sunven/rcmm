import AppKit
import RCMMShared
import SwiftUI

enum AppPickerItemMatcher {
    static func isAlreadyAdded(_ app: AppInfo, in entries: [MenuEntry]) -> Bool {
        for entry in entries {
            guard case .custom(let item) = entry else { continue }
            if let bundleId = app.bundleId, item.bundleId == bundleId {
                return true
            }
            if item.appPath == app.path {
                return true
            }
        }
        return false
    }
}

struct AppPickerListView<EmptyAction: View>: View {
    let apps: [AppInfo]
    let existingEntries: [MenuEntry]
    @Binding var selectedAppIds: Set<UUID>
    let isLoading: Bool
    let loadingTitle: String
    let emptyTitle: String
    let emptySubtitle: String?
    let emptyAction: EmptyAction

    init(
        apps: [AppInfo],
        existingEntries: [MenuEntry],
        selectedAppIds: Binding<Set<UUID>>,
        isLoading: Bool,
        loadingTitle: String,
        emptyTitle: String,
        emptySubtitle: String? = nil,
        @ViewBuilder emptyAction: () -> EmptyAction
    ) {
        self.apps = apps
        self.existingEntries = existingEntries
        _selectedAppIds = selectedAppIds
        self.isLoading = isLoading
        self.loadingTitle = loadingTitle
        self.emptyTitle = emptyTitle
        self.emptySubtitle = emptySubtitle
        self.emptyAction = emptyAction()
    }

    var body: some View {
        if isLoading {
            Spacer()
            ProgressView(loadingTitle)
                .accessibilityLabel(loadingTitle)
            Spacer()
        } else if apps.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Text(emptyTitle)
                    .foregroundStyle(.secondary)

                if let emptySubtitle {
                    Text(emptySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                emptyAction
            }
            Spacer()
        } else {
            List {
                ForEach(groupedApps, id: \.category) { group in
                    Section(header: Text(group.category.displayName)) {
                        ForEach(group.apps) { app in
                            appRow(for: app)
                        }
                    }
                }
            }
        }
    }

    private var groupedApps: [AppPickerGroup] {
        let grouped = Dictionary(grouping: apps) { app in
            app.category ?? .other
        }
        return grouped
            .map { AppPickerGroup(category: $0.key, apps: $0.value) }
            .sorted { $0.category < $1.category }
    }

    @ViewBuilder
    private func appRow(for app: AppInfo) -> some View {
        let alreadyAdded = AppPickerItemMatcher.isAlreadyAdded(app, in: existingEntries)

        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 24, height: 24)
            Text(app.name)
                .font(.body)
            Spacer()

            if alreadyAdded {
                Text("已添加")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Toggle("", isOn: Binding(
                    get: { selectedAppIds.contains(app.id) },
                    set: { isSelected in
                        if isSelected {
                            selectedAppIds.insert(app.id)
                        } else {
                            selectedAppIds.remove(app.id)
                        }
                    }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(app.name)
        .accessibilityHint(alreadyAdded ? "已添加到菜单" : "勾选以添加到右键菜单")
    }
}

extension AppPickerListView where EmptyAction == EmptyView {
    init(
        apps: [AppInfo],
        existingEntries: [MenuEntry],
        selectedAppIds: Binding<Set<UUID>>,
        isLoading: Bool,
        loadingTitle: String,
        emptyTitle: String,
        emptySubtitle: String? = nil
    ) {
        self.init(
            apps: apps,
            existingEntries: existingEntries,
            selectedAppIds: selectedAppIds,
            isLoading: isLoading,
            loadingTitle: loadingTitle,
            emptyTitle: emptyTitle,
            emptySubtitle: emptySubtitle
        ) {
            EmptyView()
        }
    }
}

private struct AppPickerGroup {
    let category: AppCategory
    let apps: [AppInfo]
}

private extension AppCategory {
    var displayName: String {
        switch self {
        case .terminal: return "终端"
        case .editor: return "编辑器"
        case .other: return "其他"
        }
    }
}
