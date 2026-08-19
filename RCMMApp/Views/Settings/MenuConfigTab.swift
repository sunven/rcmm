import RCMMShared
import SwiftUI

struct MenuConfigTab: View {
    @Environment(ApplicationDiscoveryCoordinator.self) private var applicationDiscovery
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(MenuConfigStore.self) private var configStore

    @Binding var selectedEntryID: String?
    var onOpenNewFileSettings: () -> Void = {}

    @State private var showingAppSelection = false
    @State private var reorderSession: MenuReorderSession?
    @State private var rowFrames: [String: CGRect] = [:]
    @State private var dragLocation: CGPoint?
    @State private var dragOverlaySize: CGSize = .zero
    @State private var dragGrabOffset: CGSize = .zero
    @State private var entryPendingDeletion: EntryDeletionRequest?

    private enum Layout {
        static let rowInsets = EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10)
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
                    appCoordinator.edit {
                        $0.updateCustomCommand(
                            for: config.id,
                            name: name,
                            command: command,
                            executionMode: executionMode
                        )
                    }
                },
                onRenameComposite: { config, name in
                    appCoordinator.edit { $0.updateCompositeName(for: config.id, name: name) }
                },
                onAddCompositeShellStep: { config in
                    appCoordinator.edit { $0.addShellStep(to: config.id) }
                },
                onUpdateCompositeStep: { config, step, name, commandTemplate, appPath, bundleId, isEnabled in
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
                onDeleteCompositeStep: { config, stepID in
                    appCoordinator.edit { $0.removeCompositeStep(compositeId: config.id, stepId: stepID) }
                },
                onMoveCompositeStep: { config, source, destination in
                    appCoordinator.edit { $0.moveCompositeStep(compositeId: config.id, from: source, to: destination) }
                }
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingAppSelection) {
            AppSelectionSheet { addedIDs in
                if let id = addedIDs.first {
                    selectEntry(id.uuidString)
                }
            }
        }
        .confirmationDialog(
            deletionDialogTitle,
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        entryPendingDeletion = nil
                    }
                }
            )
        ) {
            Button("删除菜单项", role: .destructive) {
                guard let request = entryPendingDeletion else { return }
                removeItem(withID: request.id)
                entryPendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                entryPendingDeletion = nil
            }
        } message: {
            Text("删除后，该菜单项及其配置将不再出现在 Finder 右键菜单中。")
        }
        .onAppear {
            reconcileSelection()
        }
        .onChange(of: configStore.menuEntries) { _, _ in
            reconcileSelection()
        }
    }

    private var summaries: [FinderMenuEntrySummary] {
        FinderMenuEntrySummaryBuilder.summaries(
            for: configStore.menuEntries,
            publishStates: configStore.scriptPublishStates
        )
    }

    private var selectedEntry: MenuEntry? {
        guard let selectedEntryID else { return nil }
        return configStore.menuEntries.first { $0.id == selectedEntryID }
    }

    private var selectedSummary: FinderMenuEntrySummary? {
        guard let selectedEntryID else { return nil }
        return summaries.first { $0.id == selectedEntryID }
    }

    private var enabledCount: Int {
        summaries.filter(\.isEnabled).count
    }

    private var issueCount: Int {
        summaries.filter { summary in
            switch summary.statusKind {
            case .failed, .unavailable, .partiallyAvailable, .warning, .syncing:
                return true
            case .ready, .disabled, .system:
                return false
            }
        }.count
    }

    private var centerPane: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if configStore.menuEntries.isEmpty {
                emptyState
            } else {
                menuList
            }

            Divider()

            toolbar
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Finder 菜单")
                    .font(.title3.weight(.semibold))
                Text("按 Finder 右键出现顺序排列")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                headerMetric("\(summaries.count)", label: "菜单项", systemImage: "list.bullet")
                headerMetric("\(enabledCount)", label: "启用", systemImage: "checkmark.circle")
                if issueCount > 0 {
                    headerMetric("\(issueCount)", label: "待处理", systemImage: "exclamationmark.triangle")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 4) {
                Text("暂无 Finder 菜单项")
                    .font(.callout.weight(.semibold))
                Text("先添加应用或命令，Finder 右键菜单会按这里的顺序显示。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                Button {
                    showingAppSelection = true
                } label: {
                    Label("添加应用", systemImage: "plus")
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .controlSize(.small)

                Button {
                    let id = appCoordinator.edit { $0.addGitPullCommand() }
                    selectEntry(id.uuidString)
                } label: {
                    Label("Git Pull 命令", systemImage: "terminal")
                }
                .controlSize(.small)
            }
        }
        .padding(24)
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func headerMetric(_ value: String, label: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.055))
        )
    }

    private var menuList: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(configStore.menuEntries.enumerated()), id: \.element.id) { index, entry in
                        SelectableMenuRow(isSelected: selectedEntryID == entry.id) {
                            row(for: entry, at: index)
                        }
                        .padding(Layout.rowInsets)
                        .opacity(reorderSession?.draggedID == entry.id ? 0.28 : 1)
                        .menuRowFrame(id: entry.id)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            dragOverlay
        }
        .coordinateSpace(name: MenuListCoordinateSpace.name)
        .onPreferenceChange(MenuRowFramePreferenceKey.self) { frames in
            rowFrames = frames
        }
    }

    @ViewBuilder
    private var dragOverlay: some View {
        if let session = reorderSession,
           let location = dragLocation,
           let entry = configStore.menuEntries.first(where: { $0.id == session.draggedID }) {
            SelectableMenuRow(isSelected: true) {
                row(
                    for: entry,
                    at: configStore.menuEntries.firstIndex(where: { $0.id == session.draggedID }) ?? 0
                )
            }
            .padding(Layout.rowInsets)
            .frame(
                width: dragOverlaySize.width,
                height: dragOverlaySize.height,
                alignment: .leading
            )
            .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
            .position(
                x: location.x - dragGrabOffset.width + dragOverlaySize.width / 2,
                y: location.y - dragGrabOffset.height + dragOverlaySize.height / 2
            )
            .allowsHitTesting(false)
            .zIndex(10)
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
                        get: { configStore.menuPresentationMode },
                        set: { appCoordinator.updateMenuPresentationMode($0) }
                    )
                ) {
                    ForEach(MenuPresentationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)

                Spacer()
            }

            HStack(spacing: 8) {
                Menu {
                    Button("添加应用") {
                        showingAppSelection = true
                    }
                    Button("VS Code + Terminal") {
                        Task { @MainActor in
                            if let id = await applicationDiscovery.addEditorTerminalPreset() {
                                selectEntry(id.uuidString)
                            }
                        }
                    }
                    Button("Git Pull 命令") {
                        let id = appCoordinator.edit { $0.addGitPullCommand() }
                        selectEntry(id.uuidString)
                    }
                    Button("新组合命令") {
                        let id = appCoordinator.edit { $0.addEmptyCompositeCommand() }
                        selectEntry(id.uuidString)
                    }
                } label: {
                    Label("添加", systemImage: "plus")
                }
                .menuStyle(.button)
                .buttonStyle(AppPrimaryButtonStyle())
                .controlSize(.small)

                Spacer()
            }

            if let message = applicationDiscovery.presetMessage {
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
        .background(.bar)
    }

    @ViewBuilder
    private func row(for entry: MenuEntry, at index: Int) -> some View {
        let summary = summary(for: entry, at: index)

        switch entry {
        case .builtIn(let item):
            AlignedMenuRow(dragGesture: dragGesture(for: entry)) {
                BuiltInListRow(
                    item: item,
                    summary: summary,
                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                    onMoveDown: index < configStore.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                    onToggle: { isEnabled in
                        appCoordinator.edit { $0.toggleEntry(for: entry.id, isEnabled: isEnabled) }
                    }
                )
            }
            .onTapGesture {
                selectedEntryID = entry.id
            }
        case .custom(let config):
            AlignedMenuRow(dragGesture: dragGesture(for: entry)) {
                AppListRow(
                    menuItem: config,
                    summary: summary,
                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                    onMoveDown: index < configStore.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                    onDelete: { requestDeletion(of: entry, title: summary.title) },
                    onToggle: { isEnabled in
                        appCoordinator.edit { $0.toggleEntry(for: entry.id, isEnabled: isEnabled) }
                    }
                )
            }
            .onTapGesture {
                selectedEntryID = entry.id
            }
        case .composite(let config):
            AlignedMenuRow(dragGesture: dragGesture(for: entry)) {
                CompositeListRow(
                    config: config,
                    summary: summary,
                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                    onMoveDown: index < configStore.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                    onDelete: { requestDeletion(of: entry, title: summary.title) },
                    onToggle: { isEnabled in
                        appCoordinator.edit { $0.toggleEntry(for: entry.id, isEnabled: isEnabled) }
                    }
                )
            }
            .onTapGesture {
                selectedEntryID = entry.id
            }
        case .newFile(let config):
            AlignedMenuRow(dragGesture: dragGesture(for: entry)) {
                NewFileListRow(
                    config: config,
                    summary: summary,
                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                    onMoveDown: index < configStore.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                    onToggle: { isEnabled in
                        appCoordinator.edit { $0.toggleEntry(for: entry.id, isEnabled: isEnabled) }
                    }
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
            total: max(configStore.menuEntries.count, 1),
            publishStates: configStore.scriptPublishStates
        )
    }

    private func dragGesture(for entry: MenuEntry) -> AnyGesture<DragGesture.Value> {
        AnyGesture(DragGesture(minimumDistance: 4, coordinateSpace: .named(MenuListCoordinateSpace.name))
            .onChanged { value in
                startDragIfNeeded(for: entry.id, startLocation: value.startLocation)
                dragLocation = value.location

                guard var session = reorderSession else { return }
                if let newOrder = session.drag(toY: value.location.y, rows: currentRowBounds()) {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        appCoordinator.preview { $0.reorderEntries(toOrder: newOrder) }
                    }
                    selectedEntryID = session.draggedID
                }
                reorderSession = session
            }
            .onEnded { _ in
                defer {
                    reorderSession = nil
                    clearDragOverlay()
                }

                guard let session = reorderSession, session.hasReordered else { return }
                appCoordinator.commitPreview()
                selectedEntryID = session.draggedID
            }
        )
    }

    private func startDragIfNeeded(for entryID: String, startLocation: CGPoint) {
        if reorderSession?.draggedID == entryID {
            return
        }

        if reorderSession != nil {
            cancelReorder()
        }

        reorderSession = MenuReorderSession(
            draggedID: entryID,
            order: configStore.menuEntries.map(\.id)
        )
        if let frame = rowFrames[entryID] {
            dragOverlaySize = frame.size
            dragGrabOffset = CGSize(
                width: startLocation.x - frame.minX,
                height: startLocation.y - frame.minY
            )
        } else {
            dragOverlaySize = .zero
            dragGrabOffset = .zero
        }
        dragLocation = startLocation
        selectEntry(entryID)
    }

    private func clearDragOverlay() {
        dragLocation = nil
        dragOverlaySize = .zero
        dragGrabOffset = .zero
    }

    /// 按纵向位置从上到下取行边界。
    ///
    /// 必须按 `minY` 排序而不是按当前顺序：preview 改变顺序后 `rowFrames` 仍是上一帧的，
    /// 按顺序取会得到非单调的几何序列，命中就会落到错误的位置上。
    /// 任何一行的边界尚未回传则整体作废，避免行数对不上导致索引错位。
    private func currentRowBounds() -> [MenuRowBounds] {
        var frames: [CGRect] = []
        for entry in configStore.menuEntries {
            guard let frame = rowFrames[entry.id] else { return [] }
            frames.append(frame)
        }

        return frames
            .sorted { $0.minY < $1.minY }
            .map { MenuRowBounds(minY: $0.minY, maxY: $0.maxY) }
    }

    private func cancelReorder() {
        guard let session = reorderSession else { return }

        appCoordinator.preview { $0.reorderEntries(toOrder: session.cancelled()) }
        reorderSession = nil
        selectedEntryID = FinderMenuSelection.reconciledSelection(
            currentID: selectedEntryID,
            entries: configStore.menuEntries
        )
    }

    private func moveItem(at index: Int, direction: Int) {
        let movedID = configStore.menuEntries.indices.contains(index) ? configStore.menuEntries[index].id : nil
        let destination = direction < 0 ? index - 1 : index + 2
        appCoordinator.edit { $0.moveEntry(from: IndexSet(integer: index), to: destination) }
        if let movedID {
            selectedEntryID = movedID
        }
    }

    private var deletionDialogTitle: String {
        guard let request = entryPendingDeletion else {
            return "删除菜单项？"
        }
        return "删除“\(request.title)”？"
    }

    private func requestDeletion(of entry: MenuEntry, title: String) {
        entryPendingDeletion = EntryDeletionRequest(id: entry.id, title: title)
    }

    private func removeItem(withID id: String) {
        guard let index = configStore.menuEntries.firstIndex(where: { $0.id == id }) else { return }
        guard configStore.menuEntries.indices.contains(index) else { return }
        let removedID = configStore.menuEntries[index].id
        appCoordinator.edit { $0.removeEntry(at: IndexSet(integer: index)) }
        selectedEntryID = FinderMenuSelection.reconciledSelection(
            currentID: selectedEntryID == removedID ? nil : selectedEntryID,
            entries: configStore.menuEntries,
            deletedIndex: index
        )
    }

    private func selectEntry(_ id: String) {
        selectedEntryID = id
    }

    private func reconcileSelection() {
        selectedEntryID = FinderMenuSelection.reconciledSelection(
            currentID: selectedEntryID,
            entries: configStore.menuEntries
        )
    }

}

private enum MenuRowAlignment {
    static let leadingSlotWidth: CGFloat = 18
    static let rowHeight: CGFloat = 40
}

private struct EntryDeletionRequest {
    let id: String
    let title: String
}

private enum MenuListCoordinateSpace {
    static let name = "finder-menu-list"
}

private struct MenuRowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private extension View {
    func menuRowFrame(id: String) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: MenuRowFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named(MenuListCoordinateSpace.name))]
                )
            }
        }
    }
}

private struct AlignedMenuRow<Label: View>: View {
    let dragGesture: AnyGesture<DragGesture.Value>
    @ViewBuilder var label: Label

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: MenuRowAlignment.leadingSlotWidth, height: MenuRowAlignment.rowHeight)
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .help("拖动调整 Finder 菜单顺序")

            label
        }
    }
}

private struct SelectableMenuRow<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder var content: Content

    @State private var isHovered = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .animation(.easeOut(duration: 0.1), value: isHovered)
            .animation(.easeOut(duration: 0.12), value: isSelected)
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.13)
        }
        if isHovered {
            return Color.primary.opacity(0.055)
        }
        return .clear
    }
}
