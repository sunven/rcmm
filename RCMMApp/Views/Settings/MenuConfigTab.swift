import RCMMShared
import SwiftUI
import UniformTypeIdentifiers

struct MenuConfigTab: View {
    @Environment(AppState.self) private var appState

    @Binding var selectedEntryID: String?
    var onOpenNewFileSettings: () -> Void = {}

    @State private var showingAppSelection = false
    @State private var activeDrag: FinderMenuDrag?
    @State private var dragPreviewEntries: [MenuEntry]?

    private enum Layout {
        static let rowInsets = EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10)
        static let footerPadding = EdgeInsets(top: 10, leading: 12, bottom: 12, trailing: 12)
    }

    var body: some View {
        HStack(spacing: 0) {
            centerPane
                .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            FinderMenuInspector(
                summary: selectedSummary,
                entry: selectedEntry,
                onOpenNewFileSettings: onOpenNewFileSettings,
                onUpdateCustomCommand: { config, name, command, executionMode in
                    appState.updateCustomCommand(
                        for: config.id,
                        name: name,
                        command: command,
                        executionMode: executionMode
                    )
                },
                onRenameComposite: { config, name in
                    appState.updateCompositeName(for: config.id, name: name)
                },
                onAddCompositeShellStep: { config in
                    appState.addShellStep(to: config.id)
                },
                onUpdateCompositeStep: { config, step, name, commandTemplate, appPath, bundleId, isEnabled in
                    appState.updateCompositeStep(
                        compositeId: config.id,
                        stepId: step.id,
                        name: name,
                        commandTemplate: commandTemplate,
                        appPath: appPath,
                        bundleId: bundleId,
                        isEnabled: isEnabled
                    )
                },
                onDeleteCompositeStep: { config, stepID in
                    appState.removeCompositeStep(compositeId: config.id, stepId: stepID)
                },
                onMoveCompositeStep: { config, source, destination in
                    appState.moveCompositeStep(compositeId: config.id, from: source, to: destination)
                }
            )
        }
        .sheet(isPresented: $showingAppSelection) {
            AppSelectionSheet { addedIDs in
                if let id = addedIDs.first {
                    selectEntry(id.uuidString)
                }
            }
        }
        .onAppear {
            reconcileSelection()
        }
        .onChange(of: appState.menuEntries) { _, _ in
            reconcileSelection()
        }
    }

    private var summaries: [FinderMenuEntrySummary] {
        FinderMenuEntrySummaryBuilder.summaries(
            for: displayedEntries,
            publishStates: appState.scriptPublishStates
        )
    }

    private var displayedEntries: [MenuEntry] {
        dragPreviewEntries ?? appState.menuEntries
    }

    private var selectedEntry: MenuEntry? {
        guard let selectedEntryID else { return nil }
        return displayedEntries.first { $0.id == selectedEntryID }
    }

    private var selectedSummary: FinderMenuEntrySummary? {
        guard let selectedEntryID else { return nil }
        return summaries.first { $0.id == selectedEntryID }
    }

    private var centerPane: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if appState.menuEntries.isEmpty {
                emptyState
            } else {
                menuList
            }

            Divider()

            toolbar
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Finder 菜单")
                    .font(.title3.weight(.semibold))
                Text("按 Finder 右键出现顺序排列")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Text("暂无 Finder 菜单项")
                .foregroundStyle(.secondary)
            Text("点击下方按钮添加应用或自定义命令")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var menuList: some View {
        List {
            ForEach(Array(displayedEntries.enumerated()), id: \.element.id) { index, entry in
                SelectableMenuRow(isSelected: selectedEntryID == entry.id) {
                    row(for: entry, at: index)
                }
                .onDrag {
                    let drag = FinderMenuDrag(
                        entryID: entry.id,
                        originalEntries: appState.menuEntries
                    )
                    activeDrag = drag
                    dragPreviewEntries = appState.menuEntries
                    selectEntry(entry.id)
                    return NSItemProvider(object: drag.payload as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: FinderMenuRowDropDelegate(
                        targetID: entry.id,
                        activeDrag: $activeDrag,
                        previewEntry: previewDraggedEntry,
                        commitEntry: commitDraggedEntry,
                        cancelDrag: cancelDragPreview
                    )
                )
                    .listRowInsets(Layout.rowInsets)
                    .listRowSeparator(.hidden)
            }
        }
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("右键菜单")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(
                    "右键菜单显示方式",
                    selection: Binding(
                        get: { appState.menuPresentationMode },
                        set: { appState.updateMenuPresentationMode($0) }
                    )
                ) {
                    ForEach(MenuPresentationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .accessibilityLabel("右键菜单显示方式")

                Spacer()
            }

            HStack(spacing: 8) {
                Menu {
                    Button("添加应用") {
                        showingAppSelection = true
                    }
                    Button("VS Code + Terminal") {
                        appState.addEditorTerminalPreset { id in
                            selectEntry(id.uuidString)
                        }
                    }
                    Button("自定义命令") {
                        let id = appState.addGitPullCommand()
                        selectEntry(id.uuidString)
                    }
                    Button("新组合命令") {
                        let id = appState.addEmptyCompositeCommand()
                        selectEntry(id.uuidString)
                    }
                } label: {
                    Label("添加", systemImage: "plus")
                }
                .menuStyle(.button)
                .buttonStyle(AppPrimaryButtonStyle())
                .controlSize(.small)
                .accessibilityLabel("添加右键菜单项")

                Spacer()
            }

            if let message = appState.compositePresetMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.yellow)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Layout.footerPadding)
    }

    @ViewBuilder
    private func row(for entry: MenuEntry, at index: Int) -> some View {
        let summary = summary(for: entry, at: index)

        switch entry {
        case .builtIn(let item):
            AlignedMenuRow {
                BuiltInListRow(
                    item: item,
                    summary: summary,
                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                    onMoveDown: index < appState.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                    onToggle: { isEnabled in
                        appState.toggleEntry(for: entry.id, isEnabled: isEnabled)
                    },
                    position: index + 1,
                    total: appState.menuEntries.count
                )
            }
            .onTapGesture {
                selectedEntryID = entry.id
            }
        case .custom(let config):
            AlignedMenuRow {
                AppListRow(
                    menuItem: config,
                    summary: summary,
                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                    onMoveDown: index < appState.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                    onDelete: { removeItem(at: index) },
                    onToggle: { isEnabled in
                        appState.toggleEntry(for: entry.id, isEnabled: isEnabled)
                    },
                    position: index + 1,
                    total: appState.menuEntries.count
                )
            }
            .onTapGesture {
                selectedEntryID = entry.id
            }
        case .composite(let config):
            AlignedMenuRow {
                CompositeListRow(
                    config: config,
                    summary: summary,
                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                    onMoveDown: index < appState.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                    onDelete: { removeItem(at: index) },
                    onToggle: { isEnabled in
                        appState.toggleEntry(for: entry.id, isEnabled: isEnabled)
                    },
                    position: index + 1,
                    total: appState.menuEntries.count
                )
            }
            .onTapGesture {
                selectedEntryID = entry.id
            }
        case .newFile(let config):
            AlignedMenuRow {
                NewFileListRow(
                    config: config,
                    summary: summary,
                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                    onMoveDown: index < appState.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                    onToggle: { isEnabled in
                        appState.toggleEntry(for: entry.id, isEnabled: isEnabled)
                    },
                    position: index + 1,
                    total: appState.menuEntries.count
                )
            }
            .onTapGesture {
                selectedEntryID = entry.id
            }
        }
    }

    private func summary(for entry: MenuEntry, at index: Int) -> FinderMenuEntrySummary {
        summaries.first { $0.id == entry.id } ?? FinderMenuEntrySummaryBuilder.summary(
            for: entry,
            position: index + 1,
            total: max(displayedEntries.count, 1),
            publishStates: appState.scriptPublishStates
        )
    }

    private func moveItem(at index: Int, direction: Int) {
        let movedID = appState.menuEntries.indices.contains(index) ? appState.menuEntries[index].id : nil
        let destination = direction < 0 ? index - 1 : index + 2
        appState.moveEntry(from: IndexSet(integer: index), to: destination)
        if let movedID {
            selectedEntryID = movedID
        }
    }

    private func previewDraggedEntry(_ draggedID: String, to targetID: String) {
        guard draggedID != targetID,
              let sourceIndex = appState.menuEntries.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = appState.menuEntries.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.12)) {
            appState.moveEntry(
                from: IndexSet(integer: sourceIndex),
                to: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex,
                sync: false
            )
            dragPreviewEntries = appState.menuEntries
        }
        selectedEntryID = draggedID
    }

    private func commitDraggedEntry(_ drag: FinderMenuDrag) -> Bool {
        guard appState.menuEntries.map(\.id) != drag.originalEntries.map(\.id) else {
            dragPreviewEntries = nil
            return true
        }

        dragPreviewEntries = nil
        appState.saveAndSync()
        selectedEntryID = drag.entryID
        return true
    }

    private func cancelDragPreview(_ drag: FinderMenuDrag?) {
        guard let drag else {
            dragPreviewEntries = nil
            return
        }

        appState.menuEntries = drag.originalEntries
        dragPreviewEntries = nil
        selectedEntryID = FinderMenuSelection.reconciledSelection(
            currentID: selectedEntryID,
            entries: appState.menuEntries
        )
    }

    private func removeItem(at index: Int) {
        guard appState.menuEntries.indices.contains(index) else { return }
        let removedID = appState.menuEntries[index].id
        appState.removeEntry(at: IndexSet(integer: index))
        selectedEntryID = FinderMenuSelection.reconciledSelection(
            currentID: selectedEntryID == removedID ? nil : selectedEntryID,
            entries: appState.menuEntries,
            deletedIndex: index
        )
    }

    private func selectEntry(_ id: String) {
        selectedEntryID = id
    }

    private func reconcileSelection() {
        selectedEntryID = FinderMenuSelection.reconciledSelection(
            currentID: selectedEntryID,
            entries: appState.menuEntries
        )
    }

}

private struct FinderMenuDrag: Equatable {
    let entryID: String
    let token: UUID
    let startedAt: Date
    let originalEntries: [MenuEntry]

    init(
        entryID: String,
        token: UUID = UUID(),
        startedAt: Date = Date(),
        originalEntries: [MenuEntry]
    ) {
        self.entryID = entryID
        self.token = token
        self.startedAt = startedAt
        self.originalEntries = originalEntries
    }

    var payload: String {
        "rcmm-finder-menu-entry:\(token.uuidString):\(entryID)"
    }

    var isExpired: Bool {
        Date().timeIntervalSince(startedAt) > 120
    }
}

private enum MenuRowAlignment {
    static let leadingSlotWidth: CGFloat = 18
    static let rowHeight: CGFloat = 34
}

private struct AlignedMenuRow<Label: View>: View {
    @ViewBuilder var label: Label

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: MenuRowAlignment.leadingSlotWidth, height: MenuRowAlignment.rowHeight)

            label
        }
    }
}

private struct FinderMenuRowDropDelegate: DropDelegate {
    let targetID: String
    @Binding var activeDrag: FinderMenuDrag?
    let previewEntry: (String, String) -> Void
    let commitEntry: (FinderMenuDrag) -> Bool
    let cancelDrag: (FinderMenuDrag?) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        guard let drag = activeDrag else {
            return false
        }
        guard !drag.isExpired else {
            activeDrag = nil
            return false
        }
        return info.hasItemsConforming(to: [.text])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let drag = activeDrag,
              !drag.isExpired,
              drag.entryID != targetID else {
            return
        }

        previewEntry(drag.entryID, targetID)
    }

    func dropExited(info: DropInfo) {
        guard let drag = activeDrag, drag.isExpired else {
            return
        }
        cancelDrag(drag)
        activeDrag = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let drag = activeDrag, !drag.isExpired else {
            cancelDrag(activeDrag)
            activeDrag = nil
            return false
        }

        guard let provider = info.itemProviders(for: [.text]).first else {
            cancelDrag(drag)
            activeDrag = nil
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            Task { @MainActor in
                defer { activeDrag = nil }
                guard let payload = object as? String,
                      payload == drag.payload else {
                    cancelDrag(drag)
                    return
                }
                _ = commitEntry(drag)
            }
        }

        return true
    }
}

private struct SelectableMenuRow<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder var content: Content

    @State private var isHovered = false

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        if isHovered {
            return Color.primary.opacity(0.08)
        }
        return .clear
    }
}
