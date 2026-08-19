import AppKit
import RCMMShared
import SwiftUI
import UniformTypeIdentifiers

struct CompositeCommandsTab: View {
    @Environment(ApplicationDiscoveryCoordinator.self) private var applicationDiscovery
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(MenuConfigStore.self) private var configStore

    let focusCompositeID: String?

    @State private var pendingAppSelection: PendingAppSelection?
    @State private var pendingDeletion: CompositeMenuItemConfig?
    @State private var locallyFocusedCompositeID: String?

    private var composites: [CompositeMenuItemConfig] {
        configStore.menuEntries.compactMap { entry in
            guard case .composite(let config) = entry else { return nil }
            return config
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if composites.isEmpty {
                        emptyState
                    } else {
                        sectionHeader("我的组合命令", count: composites.count)
                        VStack(spacing: 12) {
                            ForEach(composites) { config in
                                commandCard(config)
                                    .id(config.id.uuidString)
                            }
                        }
                    }

                    sectionHeader("内置模板", count: nil)
                    if applicationDiscovery.isScanning {
                        Label("正在检查模板依赖…", systemImage: "hourglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let message = applicationDiscovery.presetMessage {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    templates
                }
                .padding(18)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .onAppear {
                scrollToFocused(proxy)
            }
            .onChange(of: focusCompositeID) { _, _ in
                locallyFocusedCompositeID = nil
                scrollToFocused(proxy)
            }
            .onChange(of: locallyFocusedCompositeID) { _, _ in
                scrollToFocused(proxy)
            }
            .task {
                await applicationDiscovery.refresh()
            }
        }
        .sheet(
            isPresented: Binding(
                get: { pendingAppSelection != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingAppSelection = nil
                    }
                }
            )
        ) {
            CompositeAppStepSelectionSheet(
                title: appSelectionTitle,
                subtitle: appSelectionSubtitle
            ) { appInfo in
                guard let selection = pendingAppSelection else { return }
                switch selection {
                case .addStep(let compositeID):
                    appCoordinator.edit { store in
                        store.addAppStep(to: compositeID, appInfo: appInfo)
                    }
                case .replaceStep(let compositeID, let stepID):
                    appCoordinator.edit { store in
                        store.replaceAppStep(
                            compositeId: compositeID,
                            stepId: stepID,
                            appInfo: appInfo
                        )
                    }
                case .appTerminalTemplate:
                    if let id = applicationDiscovery.addAppTerminalPreset(appInfo: appInfo) {
                        locallyFocusedCompositeID = id.uuidString
                    }
                }
                pendingAppSelection = nil
            }
            .environment(applicationDiscovery)
        }
        .confirmationDialog(
            deletionTitle,
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeletion = nil
                    }
                }
            )
        ) {
            Button("删除组合命令", role: .destructive) {
                guard let pendingDeletion else { return }
                appCoordinator.edit { $0.removeEntry(withID: pendingDeletion.id.uuidString) }
                self.pendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("删除后，该组合命令也会从 Finder 右键菜单中移除。")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("组合命令")
                    .font(.title3.weight(.bold))
                Text("把多个应用和 Shell 步骤组合成一个 Finder 菜单项")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                metric("\(composites.count) 个组合命令", systemImage: "rectangle.stack")
                metric("\(composites.filter(\.isEnabled).count) 个启用", systemImage: "checkmark.circle")
            }

            addMenu
        }
    }

    private var addMenu: some View {
        Menu {
            Button {
                createEmptyCommand()
            } label: {
                Label("空白组合命令", systemImage: "plus.rectangle")
            }

            Divider()

            Button {
                addEditorTerminalPreset()
            } label: {
                Label("编辑器 + Terminal", systemImage: "rectangle.split.2x1")
            }
            .disabled(applicationDiscovery.isScanning || !applicationDiscovery.editorTerminalPresetAvailable)

            Button {
                addEditorTerminalShellPreset()
            } label: {
                Label("编辑器 + Terminal + Shell", systemImage: "terminal")
            }
            .disabled(applicationDiscovery.isScanning || !applicationDiscovery.editorTerminalPresetAvailable)

            Button {
                pendingAppSelection = .appTerminalTemplate
            } label: {
                Label("应用 + Terminal", systemImage: "app.connected.to.app.below.fill")
            }
            .disabled(applicationDiscovery.isScanning || !applicationDiscovery.terminalPresetAvailable)
        } label: {
            Label("添加组合命令", systemImage: "plus")
        }
        .menuStyle(.button)
        .buttonStyle(AppPrimaryButtonStyle())
        .controlSize(.small)
    }

    private var templates: some View {
        VStack(spacing: 10) {
            CompositeCommandTemplateCard(
                title: "编辑器 + Terminal",
                description: "用首选编辑器打开目标，再打开 Terminal。",
                iconName: "rectangle.split.2x1",
                requirements: editorTerminalRequirements,
                isEnabled: !applicationDiscovery.isScanning && applicationDiscovery.editorTerminalPresetAvailable,
                action: addEditorTerminalPreset
            )

            CompositeCommandTemplateCard(
                title: "编辑器 + Terminal + Shell",
                description: "打开编辑器和 Terminal，并预留一个可编辑的 Shell 步骤。",
                iconName: "terminal",
                requirements: editorTerminalRequirements,
                isEnabled: !applicationDiscovery.isScanning && applicationDiscovery.editorTerminalPresetAvailable,
                action: addEditorTerminalShellPreset
            )

            CompositeCommandTemplateCard(
                title: "应用 + Terminal",
                description: "选择任意应用，与 Terminal 一起打开当前目标。",
                iconName: "app.connected.to.app.below.fill",
                requirements: applicationDiscovery.terminalPresetAvailable
                    ? "需要选择一个应用"
                    : "当前未找到可用的 Terminal",
                isEnabled: !applicationDiscovery.isScanning && applicationDiscovery.terminalPresetAvailable,
                action: { pendingAppSelection = .appTerminalTemplate }
            )
        }
    }

    private func commandCard(_ config: CompositeMenuItemConfig) -> some View {
        let summary = summary(for: config)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: config.iconName ?? "rectangle.stack.badge.play")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(config.name.nilIfBlank ?? "未命名组合命令")
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text("\(config.steps.count) 个步骤")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Menu {
                    ForEach(CompositeCommandIcon.allCases) { icon in
                        Button {
                            appCoordinator.edit {
                                $0.updateCompositeIcon(for: config.id, iconName: icon.rawValue)
                            }
                        } label: {
                            Label(icon.title, systemImage: icon.rawValue)
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("更换图标")

                FinderMenuStatusBadge(summary: summary)

                Toggle("", isOn: Binding(
                    get: { config.isEnabled },
                    set: { isEnabled in
                        appCoordinator.edit { $0.toggleEntry(for: config.id.uuidString, isEnabled: isEnabled) }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .help(config.isEnabled ? "停用此组合命令" : "启用此组合命令")

                Button {
                    if config.steps.isEmpty {
                        appCoordinator.edit { $0.removeEntry(withID: config.id.uuidString) }
                    } else {
                        pendingDeletion = config
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("删除组合命令")
            }

            CompositeCommandEditor(
                config: config,
                onRename: { name in
                    appCoordinator.edit { $0.updateCompositeName(for: config.id, name: name) }
                },
                onAddShellStep: {
                    appCoordinator.edit { $0.addShellStep(to: config.id) }
                },
                onAddAppStep: {
                    pendingAppSelection = .addStep(compositeID: config.id)
                },
                onReplaceAppStep: { step in
                    pendingAppSelection = .replaceStep(
                        compositeID: config.id,
                        stepID: step.id
                    )
                },
                onUpdateStep: { step, name, commandTemplate, appPath, bundleId, isEnabled in
                    appCoordinator.edit {
                        $0.updateCompositeStep(
                            compositeId: config.id,
                            stepId: step.id,
                            name: name,
                            commandTemplate: commandTemplate,
                            appPath: appPath,
                            bundleId: bundleId,
                            isEnabled: isEnabled
                        )
                    }
                },
                onDeleteStep: { stepID in
                    appCoordinator.edit { $0.removeCompositeStep(compositeId: config.id, stepId: stepID) }
                },
                onMoveStep: { source, destination in
                    appCoordinator.edit { $0.moveCompositeStep(compositeId: config.id, from: source, to: destination) }
                }
            )
        }
        .padding(12)
        .background(compositeCardBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
            Text("还没有组合命令")
                .font(.callout.weight(.semibold))
            Text("从下方模板开始，或创建一个空白组合命令。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(compositeCardBackground)
    }

    private func sectionHeader(_ title: String, count: Int?) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline.weight(.semibold))
            if let count {
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func metric(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.primary.opacity(0.055)))
    }

    private func summary(for config: CompositeMenuItemConfig) -> FinderMenuEntrySummary {
        FinderMenuEntrySummaryBuilder.summary(
            for: .composite(config),
            position: 1,
            total: max(composites.count, 1),
            publishStates: configStore.scriptPublishStates
        )
    }

    private var editorTerminalRequirements: String {
        if applicationDiscovery.isScanning {
            return "正在检查编辑器和 Terminal"
        }
        return applicationDiscovery.editorTerminalPresetAvailable
            ? "需要一个编辑器和 Terminal"
            : "当前未找到可用的编辑器和 Terminal"
    }

    private func scrollToFocused(_ proxy: ScrollViewProxy) {
        guard let targetID = locallyFocusedCompositeID ?? focusCompositeID else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(targetID, anchor: .top)
            }
        }
    }

    private var deletionTitle: String {
        guard let pendingDeletion else { return "删除组合命令？" }
        return "删除“\(pendingDeletion.name.nilIfBlank ?? "未命名组合命令")”？"
    }

    private var appSelectionTitle: String {
        if case .appTerminalTemplate = pendingAppSelection {
            return "选择要与 Terminal 组合的应用"
        }
        return "选择应用步骤"
    }

    private var appSelectionSubtitle: String {
        if case .appTerminalTemplate = pendingAppSelection {
            return "选择后会创建一个新的组合命令"
        }
        return "选择后会更新当前组合命令"
    }

    private func createEmptyCommand() {
        let id = appCoordinator.edit { $0.addEmptyCompositeCommand() }
        locallyFocusedCompositeID = id.uuidString
    }

    private func addEditorTerminalPreset() {
        Task { @MainActor in
            if let id = await applicationDiscovery.addEditorTerminalPreset() {
                locallyFocusedCompositeID = id.uuidString
            }
        }
    }

    private func addEditorTerminalShellPreset() {
        Task { @MainActor in
            if let id = await applicationDiscovery.addEditorTerminalShellPreset() {
                locallyFocusedCompositeID = id.uuidString
            }
        }
    }

}

private enum PendingAppSelection {
    case addStep(compositeID: UUID)
    case replaceStep(compositeID: UUID, stepID: UUID)
    case appTerminalTemplate
}

private struct CompositeCommandTemplateCard: View {
    let title: String
    let description: String
    let iconName: String
    let requirements: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(requirements)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            Button("使用模板", action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!isEnabled)
        }
        .padding(11)
        .background(compositeCardBackground)
    }
}

private enum CompositeCommandIcon: String, CaseIterable, Identifiable {
    case split = "rectangle.split.2x1"
    case terminal = "terminal"
    case stack = "rectangle.stack.badge.play"
    case gear = "gearshape.2"
    case bolt = "bolt.horizontal"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .split: return "分栏"
        case .terminal: return "终端"
        case .stack: return "步骤"
        case .gear: return "工具"
        case .bolt: return "快捷"
        }
    }
}

private struct CompositeAppStepSelectionSheet: View {
    @Environment(ApplicationDiscoveryCoordinator.self) private var applicationDiscovery
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String
    let onSelect: (AppInfo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if applicationDiscovery.isScanning {
                Spacer()
                ProgressView("正在扫描应用…")
                Spacer()
            } else if applicationDiscovery.apps.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Text("未发现可用应用")
                        .foregroundStyle(.secondary)
                    Button("选择其他应用") {
                        chooseOtherApplication()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else {
                List(applicationDiscovery.apps) { app in
                    Button {
                        onSelect(app)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                .resizable()
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                Text(app.path)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack {
                Button {
                    chooseOtherApplication()
                } label: {
                    Label("选择其他应用", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding()
        }
        .frame(width: 470, height: 460)
        .task {
            await applicationDiscovery.refresh()
        }
    }

    private func chooseOtherApplication() {
        let panel = NSOpenPanel()
        panel.title = "选择应用"
        panel.message = "选择一个 .app 作为组合命令步骤"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let bundle = Bundle(url: url)
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        onSelect(
            AppInfo(
                name: name,
                bundleId: bundle?.bundleIdentifier,
                path: url.path,
                category: .other
            )
        )
        dismiss()
    }
}

private var compositeCardBackground: some View {
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor))
        .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
}
