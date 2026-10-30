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

    @State private var query = ""

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
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView(loadingTitle)
                Spacer()
            } else if apps.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text(emptyTitle)
                        .font(RCMMFont.secondary)
                        .foregroundStyle(RCMMColor.textMuted)

                    if let emptySubtitle {
                        Text(emptySubtitle)
                            .font(RCMMFont.caption)
                            .foregroundStyle(RCMMColor.textFaint)
                            .multilineTextAlignment(.center)
                    }

                    emptyAction
                }
                Spacer()
            } else {
                searchField
                    .padding(.bottom, 8)

                if filteredGroups.isEmpty {
                    Spacer()
                    VStack(spacing: 6) {
                        Text("没有匹配“\(query)”的应用")
                            .font(RCMMFont.secondary)
                            .foregroundStyle(RCMMColor.textMuted)
                        Button("清除搜索") { query = "" }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredGroups, id: \.category) { group in
                            Section(header: Text(group.category.displayName)) {
                                ForEach(group.apps) { app in
                                    appRow(for: app)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RCMMColor.textFaint)

            TextField("搜索应用", text: $query)
                .textFieldStyle(.plain)
                .font(RCMMFont.body)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(RCMMColor.textFaint)
                }
                .buttonStyle(.plain)
                .help("清除搜索")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(RCMMColor.surfaceSoft)
        )
    }

    private var filteredGroups: [AppPickerGroup] {
        let matching = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? apps
            : apps.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.path.localizedCaseInsensitiveContains(query)
            }
        let grouped = Dictionary(grouping: matching) { app in
            app.category ?? .other
        }
        return grouped
            .map { AppPickerGroup(category: $0.key, apps: $0.value) }
            .sorted { $0.category < $1.category }
    }

    @ViewBuilder
    private func appRow(for app: AppInfo) -> some View {
        let alreadyAdded = AppPickerItemMatcher.isAlreadyAdded(app, in: existingEntries)

        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(RCMMFont.body)
                    .foregroundStyle(RCMMColor.textPrimary)

                Text(app.path)
                    .font(RCMMFont.caption)
                    .foregroundStyle(RCMMColor.textFaint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if alreadyAdded {
                Text("已添加")
                    .font(RCMMFont.caption)
                    .foregroundStyle(RCMMColor.textFaint)
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
                .accessibilityLabel("选择 \(app.name)")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
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
