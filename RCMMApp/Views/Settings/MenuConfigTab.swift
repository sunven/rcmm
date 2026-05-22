import RCMMShared
import SwiftUI

struct MenuConfigTab: View {
    @Environment(AppState.self) private var appState

    @State private var showingAppSelection = false
    @State private var expandedItems: Set<String> = []

    private enum Layout {
        static let rowInsets = EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10)
        static let footerPadding = EdgeInsets(top: 10, leading: 12, bottom: 12, trailing: 12)
    }

    var body: some View {
        VStack(spacing: 0) {
            if appState.menuEntries.isEmpty {
                VStack(spacing: 4) {
                    Text("暂无菜单项")
                        .foregroundStyle(.secondary)
                    Text("点击下方按钮添加应用")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(appState.menuEntries.enumerated()), id: \.element.id) { index, entry in
                        switch entry {
                        case .builtIn(let item):
                            AlignedMenuRow {
                                BuiltInListRow(
                                    item: item,
                                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                                    onMoveDown: index < appState.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                                    onToggle: { isEnabled in
                                        appState.toggleEntry(for: entry.id, isEnabled: isEnabled)
                                    },
                                    position: index + 1,
                                    total: appState.menuEntries.count
                                )
                            }
                            .listRowInsets(Layout.rowInsets)
                            .listRowSeparator(.hidden)
                        case .custom(let config):
                            ExpandableMenuRow(isExpanded: expandedBinding(for: entry.id)) {
                                AppListRow(
                                    menuItem: config,
                                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                                    onMoveDown: index < appState.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                                    onDelete: { appState.removeEntry(at: IndexSet(integer: index)) },
                                    onToggle: { isEnabled in
                                        appState.toggleEntry(for: entry.id, isEnabled: isEnabled)
                                    },
                                    position: index + 1,
                                    total: appState.menuEntries.count
                                )
                            } expandedContent: {
                                CommandEditor(
                                    name: config.appName,
                                    editedCommand: config.customCommand ?? "",
                                    executionMode: config.executionMode,
                                    defaultCommand: resolveDefaultCommand(for: config),
                                    appPath: config.appPath,
                                    onSave: { name, command, executionMode in
                                        appState.updateCustomCommand(
                                            for: config.id,
                                            name: name,
                                            command: command,
                                            executionMode: executionMode
                                        )
                                    }
                                )
                                .padding(.top, 4)
                            }
                            .listRowInsets(Layout.rowInsets)
                            .listRowSeparator(.hidden)
                        case .composite(let config):
                            ExpandableMenuRow(isExpanded: expandedBinding(for: entry.id)) {
                                CompositeListRow(
                                    config: config,
                                    publishState: appState.scriptPublishStates[config.id.uuidString],
                                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                                    onMoveDown: index < appState.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                                    onDelete: { appState.removeEntry(at: IndexSet(integer: index)) },
                                    onToggle: { isEnabled in
                                        appState.toggleEntry(for: entry.id, isEnabled: isEnabled)
                                    },
                                    position: index + 1,
                                    total: appState.menuEntries.count
                                )
                            } expandedContent: {
                                CompositeCommandEditor(
                                    config: config,
                                    onRename: { name in
                                        appState.updateCompositeName(for: config.id, name: name)
                                    },
                                    onAddShellStep: {
                                        appState.addShellStep(to: config.id)
                                    },
                                    onUpdateStep: { step, name, commandTemplate, appPath, bundleId, isEnabled in
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
                                    onDeleteStep: { stepId in
                                        appState.removeCompositeStep(compositeId: config.id, stepId: stepId)
                                    },
                                    onMoveStep: { source, destination in
                                        appState.moveCompositeStep(
                                            compositeId: config.id,
                                            from: source,
                                            to: destination
                                        )
                                    }
                                )
                            }
                            .listRowInsets(Layout.rowInsets)
                            .listRowSeparator(.hidden)
                        case .newFile(let config):
                            ExpandableMenuRow(isExpanded: expandedBinding(for: entry.id)) {
                                NewFileListRow(
                                    config: config,
                                    publishStates: appState.scriptPublishStates,
                                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                                    onMoveDown: index < appState.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                                    onDelete: { appState.removeEntry(at: IndexSet(integer: index)) },
                                    onToggle: { isEnabled in
                                        appState.toggleEntry(for: entry.id, isEnabled: isEnabled)
                                    },
                                    position: index + 1,
                                    total: appState.menuEntries.count
                                )
                            } expandedContent: {
                                NewFileMenuEditor(
                                    config: config,
                                    onRename: { name in
                                        appState.updateNewFileMenuName(for: config.id, name: name)
                                    },
                                    onAddTemplate: {
                                        appState.addNewFileTemplate(to: config.id)
                                    },
                                    onUpdateTemplate: { template, displayName, baseName, fileExtension, creationMode, templatePath, initialContent, isEnabled in
                                        appState.updateNewFileTemplate(
                                            menuID: config.id,
                                            templateID: template.id,
                                            displayName: displayName,
                                            baseName: baseName,
                                            fileExtension: fileExtension,
                                            creationMode: creationMode,
                                            templatePath: templatePath,
                                            initialContent: initialContent,
                                            isEnabled: isEnabled
                                        )
                                    },
                                    onDeleteTemplate: { templateID in
                                        appState.removeNewFileTemplate(
                                            menuID: config.id,
                                            templateID: templateID
                                        )
                                    },
                                    onMoveTemplate: { source, destination in
                                        appState.moveNewFileTemplate(
                                            menuID: config.id,
                                            from: source,
                                            to: destination
                                        )
                                    }
                                )
                            }
                            .listRowInsets(Layout.rowInsets)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .onMove { source, destination in
                        appState.moveEntry(from: source, to: destination)
                    }
                }
            }

            Divider()

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
                            appState.addEditorTerminalPreset()
                        }
                        Button("自定义命令") {
                            let id = appState.addGitPullCommand()
                            expandedItems.insert(id.uuidString)
                        }
                        Button("新组合命令") {
                            appState.addEmptyCompositeCommand()
                        }
                        Button("新建文件菜单") {
                            let id = appState.addNewFileMenu()
                            expandedItems.insert(id.uuidString)
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
        .sheet(isPresented: $showingAppSelection) {
            AppSelectionSheet()
        }
    }

    private func moveItem(at index: Int, direction: Int) {
        let destination = direction < 0 ? index - 1 : index + 2
        appState.moveEntry(from: IndexSet(integer: index), to: destination)
    }

    private func expandedBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedItems.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedItems.insert(id)
                } else {
                    expandedItems.remove(id)
                }
            }
        )
    }

    private func resolveDefaultCommand(for item: MenuItemConfig) -> String {
        if item.executionMode == .currentDirectory {
            return "git pull"
        }
        if let builtIn = CommandMappingService.command(for: item.bundleId) {
            return builtIn
        }
        return "open -a \"\(item.appPath)\" {path}"
    }
}

private enum MenuRowAlignment {
    static let disclosureSlotWidth: CGFloat = 18
    static let rowHeight: CGFloat = 34
}

private struct AlignedMenuRow<Label: View>: View {
    @ViewBuilder var label: Label

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Color.clear
                .frame(width: MenuRowAlignment.disclosureSlotWidth, height: MenuRowAlignment.rowHeight)

            label
        }
    }
}

private struct ExpandableMenuRow<Label: View, ExpandedContent: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder var label: Label
    @ViewBuilder var expandedContent: ExpandedContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(
                            width: MenuRowAlignment.disclosureSlotWidth,
                            height: MenuRowAlignment.rowHeight
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "收起命令配置" : "展开命令配置")

                label
            }

            if isExpanded {
                expandedContent
                    .padding(.leading, MenuRowAlignment.disclosureSlotWidth)
            }
        }
    }
}
