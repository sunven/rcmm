import AppKit
import RCMMShared
import SwiftUI
import UniformTypeIdentifiers

struct CompositeCommandsTab: View {
    @Environment(SettingsDraftStore.self) private var drafts
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
                        VStack(spacing: 10) {
                            ForEach(composites) { config in
                                commandCard(config)
                                    .id(config.id.uuidString)
                            }
                        }
                    }

                    sectionHeader("内置模板", count: nil)
                    if applicationDiscovery.isScanning {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("正在检查模板依赖…")
                                .font(RCMMFont.caption)
                                .foregroundStyle(RCMMColor.textMuted)
                        }
                    } else if let message = applicationDiscovery.presetMessage {
                        RCMMInlineMessage(message, kind: .warning)
                    }
                    templates
                }
                .padding(18)
            }
            .background(RCMMColor.window)
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
                    editComposite(compositeID) { $0.steps.append(MenuConfigStore.makeAppStep(from: appInfo)) }
                case .replaceStep(let compositeID, let stepID):
                    editComposite(compositeID) { config in
                        guard let index = config.steps.firstIndex(where: { $0.id == stepID }) else { return }
                        let replacement = MenuConfigStore.makeAppStep(from: appInfo)
                        config.steps[index].name = replacement.name
                        config.steps[index].commandTemplate = replacement.commandTemplate
                        config.steps[index].appPath = replacement.appPath
                        config.steps[index].bundleId = replacement.bundleId
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
            Text("删除后，该组合命令也会从 Finder 右键菜单中移除，未保存的修改也会删除。")
        }
    }

    private var header: some View {
        RCMMPageHeader(
            title: "组合命令",
            subtitle: "把多个应用和 Shell 步骤组合成一个 Finder 菜单项"
        ) {
            HStack(alignment: .top, spacing: 16) {
                RCMMMetric(value: "\(composites.count)", label: "组合命令")
                RCMMMetric(value: "\(composites.filter(\.isEnabled).count)", label: "启用")
                addMenu
            }
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
        VStack(spacing: 8) {
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
        let draft = drafts.composite(for: config)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: draft.iconName ?? "rectangle.stack.badge.play")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(RCMMColor.textSecondary)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(draft.name.nilIfBlank ?? "未命名组合命令")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RCMMColor.textPrimary)
                            .lineLimit(1)

                        if drafts.hasChanges(.composite(config.id)) {
                            Circle()
                                .fill(RCMMColor.accent)
                                .frame(width: 5, height: 5)
                                .help("有未保存的修改")
                        }
                    }

                    Text("\(draft.steps.count) 个步骤")
                        .font(RCMMFont.caption)
                        .foregroundStyle(RCMMColor.textMuted)
                }

                Spacer(minLength: 8)

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
                .accessibilityLabel(config.isEnabled ? "停用组合命令" : "启用组合命令")
                .help(config.isEnabled ? "停用此组合命令" : "启用此组合命令")

                cardActionsMenu(for: config)
            }

            CompositeCommandEditor(
                config: Binding(get: { drafts.composite(for: config) }, set: { drafts.updateComposite($0) }),
                onAddShellStep: {
                    editComposite(config.id) { $0.steps.append(MenuConfigStore.makeShellStep()) }
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
                    editComposite(config.id) { draft in
                        guard let index = draft.steps.firstIndex(where: { $0.id == step.id }) else { return }
                        draft.steps[index].name = name
                        draft.steps[index].commandTemplate = commandTemplate
                        draft.steps[index].appPath = appPath
                        draft.steps[index].bundleId = bundleId
                        draft.steps[index].isEnabled = isEnabled
                    }
                },
                onDeleteStep: { stepID in
                    editComposite(config.id) { $0.steps.removeAll { $0.id == stepID } }
                },
                onMoveStep: { source, destination in
                    editComposite(config.id) { $0.steps.move(fromOffsets: source, toOffset: destination) }
                }
            )
            EditorSaveBar(key: .composite(config.id))
        }
        .padding(12)
        .background(compositeCardBackground)
    }

    private func cardActionsMenu(for config: CompositeMenuItemConfig) -> some View {
        Menu {
            Section("更换图标") {
                ForEach(CompositeCommandIcon.allCases) { icon in
                    Button {
                        editComposite(config.id) { $0.iconName = icon.rawValue }
                    } label: {
                        Label(icon.title, systemImage: icon.rawValue)
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                requestDeletion(of: config)
            } label: {
                Label("删除组合命令", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RCMMColor.textMuted)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("更多操作")
    }

    private func requestDeletion(of config: CompositeMenuItemConfig) {
        if config.steps.isEmpty && !drafts.hasChanges(.composite(config.id)) {
            appCoordinator.edit { $0.removeEntry(withID: config.id.uuidString) }
        } else {
            pendingDeletion = config
        }
    }

    private func editComposite(_ id: UUID, _ body: (inout CompositeMenuItemConfig) -> Void) {
        guard let saved = composites.first(where: { $0.id == id }) else { return }
        var draft = drafts.composite(for: saved)
        body(&draft)
        drafts.updateComposite(draft)
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(RCMMColor.textFaint)

            VStack(alignment: .leading, spacing: 2) {
                Text("还没有组合命令")
                    .font(RCMMFont.emptyTitle)
                    .foregroundStyle(RCMMColor.textPrimary)
                Text("从下方模板开始，或创建一个空白组合命令。")
                    .font(RCMMFont.secondary)
                    .foregroundStyle(RCMMColor.textMuted)
            }

            Spacer(minLength: 8)

            Button("创建空白命令") {
                createEmptyCommand()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(compositeCardBackground)
    }

    private func sectionHeader(_ title: String, count: Int?) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RCMMColor.textPrimary)

            if let count {
                Text("\(count)")
                    .font(RCMMFont.caption)
                    .monospacedDigit()
                    .foregroundStyle(RCMMColor.textMuted)
            }

            Spacer()
        }
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
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(RCMMColor.textSecondary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(RCMMFont.rowTitle)
                    .foregroundStyle(RCMMColor.textPrimary)
                Text(description)
                    .font(RCMMFont.caption)
                    .foregroundStyle(RCMMColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(requirements)
                    .font(RCMMFont.caption)
                    .foregroundStyle(isEnabled ? RCMMColor.textMuted : RCMMColor.warning)
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(RCMMFont.sheetTitle)
                        .foregroundStyle(RCMMColor.textPrimary)
                    Text(subtitle)
                        .font(RCMMFont.caption)
                        .foregroundStyle(RCMMColor.textMuted)
                }
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            RCMMDivider()

            if applicationDiscovery.isScanning {
                Spacer()
                ProgressView("正在扫描应用…")
                Spacer()
            } else if applicationDiscovery.apps.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Text("未发现可用应用")
                        .font(RCMMFont.secondary)
                        .foregroundStyle(RCMMColor.textMuted)
                    Button("选择其他应用") {
                        chooseOtherApplication()
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
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
                                .frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(RCMMFont.body)
                                Text(app.path)
                                    .font(RCMMFont.caption)
                                    .foregroundStyle(RCMMColor.textMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(RCMMColor.textFaint)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }

            RCMMDivider()

            HStack {
                Button {
                    chooseOtherApplication()
                } label: {
                    Label("选择其他应用", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding(16)
        }
        .frame(width: 470, height: 460)
        .background(RCMMColor.window)
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
        .fill(RCMMColor.surface)
}
