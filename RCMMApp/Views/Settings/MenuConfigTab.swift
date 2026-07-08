import RCMMShared
import SwiftUI

struct MenuConfigTab: View {
    @Environment(AppState.self) private var appState

    @Binding var selectedEntryID: String?
    var onOpenNewFileSettings: () -> Void = {}

    @State private var showingAppSelection = false
    @State private var activeDrag: FinderMenuDrag?
    @State private var dragPreviewEntries: [MenuEntry]?
    @State private var rowFrames: [String: CGRect] = [:]
    @State private var dragLocation: CGPoint?
    @State private var dragOverlaySize: CGSize = .zero
    @State private var dragGrabOffset: CGSize = .zero

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
        .background(Color(nsColor: .windowBackgroundColor))
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

    private var enabledCount: Int {
        summaries.filter(\.isEnabled).count
    }

    private var issueCount: Int {
        summaries.filter { summary in
            switch summary.statusKind {
            case .failed, .unavailable, .partiallyAvailable, .warning, .syncing:
                return true
            case .ready, .disabled, .command, .system:
                return false
            }
        }.count
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
                    let id = appState.addGitPullCommand()
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
        .accessibilityLabel("\(label)：\(value)")
    }

    private var menuList: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(displayedEntries.enumerated()), id: \.element.id) { index, entry in
                        SelectableMenuRow(isSelected: selectedEntryID == entry.id) {
                            row(for: entry, at: index)
                        }
                        .padding(Layout.rowInsets)
                        .opacity(activeDrag?.entryID == entry.id ? 0.28 : 1)
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
        if let drag = activeDrag,
           let location = dragLocation,
           let entry = drag.originalEntries.first(where: { $0.id == drag.entryID }) {
            SelectableMenuRow(isSelected: true) {
                row(
                    for: entry,
                    at: displayedEntries.firstIndex(where: { $0.id == drag.entryID }) ?? 0
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
                    Button("Git Pull 命令") {
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
            AlignedMenuRow(dragGesture: dragGesture(for: entry)) {
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
            AlignedMenuRow(dragGesture: dragGesture(for: entry)) {
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
            AlignedMenuRow(dragGesture: dragGesture(for: entry)) {
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

    private func dragGesture(for entry: MenuEntry) -> AnyGesture<DragGesture.Value> {
        AnyGesture(DragGesture(minimumDistance: 4, coordinateSpace: .named(MenuListCoordinateSpace.name))
            .onChanged { value in
                startDragIfNeeded(for: entry.id, startLocation: value.startLocation)
                dragLocation = value.location

                guard let drag = activeDrag, !drag.isExpired else {
                    cancelDragPreview(activeDrag)
                    activeDrag = nil
                    clearDragOverlay()
                    return
                }

                guard let targetID = targetEntryID(at: value.location),
                      targetID != drag.entryID else {
                    return
                }

                previewDraggedEntry(drag.entryID, to: targetID)
            }
            .onEnded { _ in
                guard let drag = activeDrag else { return }

                if drag.isExpired {
                    cancelDragPreview(drag)
                } else {
                    _ = commitDraggedEntry(drag)
                }
                activeDrag = nil
                clearDragOverlay()
            }
        )
    }

    private func startDragIfNeeded(for entryID: String, startLocation: CGPoint) {
        if activeDrag?.entryID == entryID {
            return
        }

        if let activeDrag {
            cancelDragPreview(activeDrag)
        }

        let drag = FinderMenuDrag(
            entryID: entryID,
            originalEntries: appState.menuEntries
        )
        activeDrag = drag
        dragPreviewEntries = appState.menuEntries
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

    private func targetEntryID(at location: CGPoint) -> String? {
        let orderedFrames: [(id: String, frame: CGRect)] = displayedEntries.compactMap { entry in
            guard let frame = rowFrames[entry.id] else { return nil }
            return (entry.id, frame)
        }

        guard let first = orderedFrames.first,
              let last = orderedFrames.last else {
            return nil
        }

        if location.y < first.frame.minY {
            return first.id
        }

        if location.y > last.frame.maxY {
            return last.id
        }

        return orderedFrames.first { _, frame in
            location.y >= frame.minY && location.y <= frame.maxY
        }?.id
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
    let startedAt: Date
    let originalEntries: [MenuEntry]

    init(
        entryID: String,
        startedAt: Date = Date(),
        originalEntries: [MenuEntry]
    ) {
        self.entryID = entryID
        self.startedAt = startedAt
        self.originalEntries = originalEntries
    }

    var isExpired: Bool {
        Date().timeIntervalSince(startedAt) > 120
    }
}

private enum MenuRowAlignment {
    static let leadingSlotWidth: CGFloat = 18
    static let rowHeight: CGFloat = 40
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
                .accessibilityLabel("拖动调整 Finder 菜单顺序")

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
