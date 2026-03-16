import AppKit
import RCMMShared
import SwiftUI

struct SelectAppsStepView: View {
    @Binding var selectedAppIds: Set<UUID>
    @Environment(AppState.self) private var appState
    @State private var isLoading = true

    private let preselectBundleIds: Set<String> = [
        "com.apple.Terminal",
        "com.microsoft.VSCode",
        "com.googlecode.iterm2",
    ]

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("正在扫描已安装应用...")
                    .accessibilityLabel("正在扫描已安装应用")
                Spacer()
            } else if appState.discoveredApps.isEmpty {
                Spacer()
                Text("未发现可用应用")
                    .foregroundStyle(.secondary)
                Button("手动添加") {
                    Task {
                        await addManually()
                    }
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
                .accessibilityLabel("手动添加应用")
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

                HStack {
                    Text("已选择 \(selectedAppIds.count) 个应用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("已选择 \(selectedAppIds.count) 个应用")

                    Spacer()

                    Button("手动添加") {
                        Task {
                            await addManually()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .font(.caption)
                    .accessibilityLabel("手动添加应用")
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
        }
        .task {
            await loadAndPreselectApps()
        }
    }

    // MARK: - Data

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
        let grouped = Dictionary(grouping: appState.discoveredApps) { app in
            app.category ?? .other
        }
        return grouped
            .map { AppGroup(category: $0.key, apps: $0.value) }
            .sorted { $0.category < $1.category }
    }

    // MARK: - Views

    @ViewBuilder
    private func appRow(for app: AppInfo) -> some View {
        let alreadyAdded = isAlreadyAdded(app)

        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 28, height: 28)
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

    // MARK: - Actions

    private func loadAndPreselectApps() async {
        isLoading = true
        let discoveryService = AppDiscoveryService()
        let apps = await Task.detached {
            discoveryService.scanApplications()
        }.value
        appState.discoveredApps = apps

        for app in apps {
            if let bundleId = app.bundleId,
               preselectBundleIds.contains(bundleId),
               !isAlreadyAdded(app) {
                selectedAppIds.insert(app.id)
            }
        }

        isLoading = false
    }

    private func addManually() async {
        let discoveryService = AppDiscoveryService()
        if let app = await discoveryService.selectApplicationManually() {
            if let existing = appState.discoveredApps.first(where: { existing in
                if let bid = app.bundleId, let eid = existing.bundleId { return bid == eid }
                return existing.path == app.path
            }) {
                selectedAppIds.insert(existing.id)
            } else {
                appState.discoveredApps.append(app)
                selectedAppIds.insert(app.id)
            }
        }
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

#Preview("加载中") {
    SelectAppsStepView(selectedAppIds: .constant([]))
        .environment(AppState())
        .frame(width: 480, height: 500)
}

#Preview("列表状态") {
    let appState = AppState()
    appState.discoveredApps = [
        AppInfo(name: "Terminal", bundleId: "com.apple.Terminal", path: "/System/Applications/Utilities/Terminal.app", category: .terminal),
        AppInfo(name: "iTerm", bundleId: "com.googlecode.iterm2", path: "/Applications/iTerm.app", category: .terminal),
        AppInfo(name: "Visual Studio Code", bundleId: "com.microsoft.VSCode", path: "/Applications/Visual Studio Code.app", category: .editor),
    ]
    let sampleId = appState.discoveredApps.first!.id
    return SelectAppsStepView(selectedAppIds: .constant([sampleId]))
        .environment(appState)
        .frame(width: 480, height: 500)
}
