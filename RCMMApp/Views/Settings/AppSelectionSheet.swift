import AppKit
import RCMMShared
import SwiftUI

struct AppSelectionSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var discoveredApps: [AppInfo] = []
    @State private var selectedAppIds: Set<UUID> = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("选择应用")
                    .font(.headline)
                Text("仅显示 /Applications 和 ~/Applications 中的应用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            if isLoading {
                Spacer()
                ProgressView("正在扫描应用…")
                Spacer()
            } else if discoveredApps.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Text("未发现可添加应用")
                        .font(.body)
                    Text("仅支持从 /Applications 和 ~/Applications 添加应用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

            Divider()

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("确认添加") {
                    addSelectedApps()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedAppIds.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .task {
            await loadApps()
        }
    }

    private var existingAppIdentifiers: Set<String> {
        var identifiers = Set<String>()
        for entry in appState.menuEntries {
            if case .custom(let item) = entry {
                if let bundleId = item.bundleId {
                    identifiers.insert(bundleId)
                } else {
                    identifiers.insert(item.appPath)
                }
            }
        }
        return identifiers
    }

    private func isAlreadyAdded(_ app: AppInfo) -> Bool {
        if let bundleId = app.bundleId {
            return existingAppIdentifiers.contains(bundleId)
        }
        return existingAppIdentifiers.contains(app.path)
    }

    private var groupedApps: [AppGroup] {
        let grouped = Dictionary(grouping: discoveredApps) { app in
            app.category ?? .other
        }
        return grouped
            .map { AppGroup(category: $0.key, apps: $0.value) }
            .sorted { $0.category < $1.category }
    }

    @ViewBuilder
    private func appRow(for app: AppInfo) -> some View {
        let alreadyAdded = isAlreadyAdded(app)

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

    private func loadApps() async {
        isLoading = true
        let discoveryService = AppDiscoveryService()
        let apps = await Task.detached {
            discoveryService.scanApplications()
        }.value
        discoveredApps = apps
        isLoading = false
    }

    private func addSelectedApps() {
        let appsToAdd = discoveredApps.filter { selectedAppIds.contains($0.id) }
        appState.addMenuItems(from: appsToAdd)
    }
}

private struct AppGroup {
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
