import AppKit
import RCMMShared
import SwiftUI

struct NewFileMenuEditor: View {
    let config: NewFileMenuConfig
    let onRename: (String) -> Void
    let onAddTemplate: () -> Void
    let onUpdateTemplate: (NewFileTemplateConfig, String, String, String, NewFileCreationMode, String?, String?, Bool) -> Void
    let onDeleteTemplate: (UUID) -> Void
    let onMoveTemplate: (IndexSet, Int) -> Void

    @State private var editedName: String
    @State private var draftTemplatesByID: [UUID: NewFileTemplateConfig]
    @State private var nameSaveFeedbackID = 0
    @State private var showsNameSaveFeedback = false

    init(
        config: NewFileMenuConfig,
        onRename: @escaping (String) -> Void,
        onAddTemplate: @escaping () -> Void,
        onUpdateTemplate: @escaping (NewFileTemplateConfig, String, String, String, NewFileCreationMode, String?, String?, Bool) -> Void,
        onDeleteTemplate: @escaping (UUID) -> Void,
        onMoveTemplate: @escaping (IndexSet, Int) -> Void
    ) {
        self.config = config
        self.onRename = onRename
        self.onAddTemplate = onAddTemplate
        self.onUpdateTemplate = onUpdateTemplate
        self.onDeleteTemplate = onDeleteTemplate
        self.onMoveTemplate = onMoveTemplate
        _editedName = State(initialValue: config.name)
        _draftTemplatesByID = State(
            initialValue: Dictionary(
                uniqueKeysWithValues: config.templates.map { ($0.id, $0) }
            )
        )
    }

    private var validation: NewFileValidationResult {
        NewFileMenuValidator.validate(draftMenu)
    }

    private var parentIssues: [NewFileValidationIssue] {
        validation.issues.filter { $0.templateID == nil }
    }

    private var trimmedEditedName: String {
        editedName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var draftMenu: NewFileMenuConfig {
        var draft = config
        draft.name = editedName
        draft.templates = config.templates.map { template in
            draftTemplatesByID[template.id] ?? template
        }
        return draft
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("菜单名称", text: $editedName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onSubmit {
                        commitName()
                    }
                    .onChange(of: config.name) { _, newValue in
                        if editedName != newValue {
                            editedName = newValue
                        }
                    }

                Button("保存名称") {
                    commitName()
                }
                .controlSize(.small)
                .disabled(trimmedEditedName.isEmpty || trimmedEditedName == config.name)

                if showsNameSaveFeedback {
                    SaveConfirmationLabel()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                Button {
                    onAddTemplate()
                } label: {
                    Label("添加模板", systemImage: "plus")
                }
                .controlSize(.small)
            }

            if !parentIssues.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(parentIssues.prefix(5)) { issue in
                        ValidationIssueRow(isError: issue.severity == .error, message: issue.message)
                    }
                }
            }

            if config.templates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("还没有模板", systemImage: "document.badge.plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("添加模板后，Finder 右键菜单就能创建常用文件。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button {
                        onAddTemplate()
                    } label: {
                        Label("添加第一个模板", systemImage: "plus")
                    }
                    .controlSize(.small)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(config.templates.enumerated()), id: \.element.id) { index, template in
                        NewFileTemplateEditorRow(
                            template: template,
                            liveIssues: validation.issues.filter { $0.templateID == template.id },
                            canMoveUp: index > 0,
                            canMoveDown: index < config.templates.count - 1,
                            onDraftChange: { draft in
                                draftTemplatesByID[draft.id] = draft
                            },
                            onUpdate: { displayName, baseName, fileExtension, creationMode, templatePath, initialContent, isEnabled in
                                onUpdateTemplate(
                                    template,
                                    displayName,
                                    baseName,
                                    fileExtension,
                                    creationMode,
                                    templatePath,
                                    initialContent,
                                    isEnabled
                                )
                            },
                            onDelete: {
                                onDeleteTemplate(template.id)
                            },
                            onMoveUp: {
                                onMoveTemplate(IndexSet(integer: index), index - 1)
                            },
                            onMoveDown: {
                                onMoveTemplate(IndexSet(integer: index), index + 2)
                            }
                        )
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            reconcileDraftTemplates(with: config.templates)
        }
        .onChange(of: config.templates) { _, templates in
            reconcileDraftTemplates(with: templates)
        }
    }

    private func commitName() {
        guard !trimmedEditedName.isEmpty,
              trimmedEditedName != config.name else {
            return
        }
        onRename(trimmedEditedName)
        showNameSaveFeedback()
    }

    private func showNameSaveFeedback() {
        nameSaveFeedbackID += 1
        let currentID = nameSaveFeedbackID
        withAnimation(.easeOut(duration: 0.12)) {
            showsNameSaveFeedback = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard currentID == nameSaveFeedbackID else { return }
            withAnimation(.easeIn(duration: 0.12)) {
                showsNameSaveFeedback = false
            }
        }
    }

    private func reconcileDraftTemplates(with templates: [NewFileTemplateConfig]) {
        var nextDrafts: [UUID: NewFileTemplateConfig] = [:]
        for template in templates {
            nextDrafts[template.id] = draftTemplatesByID[template.id] ?? template
        }
        draftTemplatesByID = nextDrafts
    }
}

private struct NewFileTemplateEditorRow: View {
    let template: NewFileTemplateConfig
    let liveIssues: [NewFileValidationIssue]
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onDraftChange: (NewFileTemplateConfig) -> Void
    let onUpdate: (String, String, String, NewFileCreationMode, String?, String?, Bool) -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @State private var displayName: String
    @State private var baseName: String
    @State private var fileExtension: String
    @State private var creationMode: NewFileCreationMode
    @State private var templatePath: String
    @State private var initialContent: String
    @State private var isEnabled: Bool
    @State private var saveFeedbackID = 0
    @State private var showsSaveFeedback = false

    init(
        template: NewFileTemplateConfig,
        liveIssues: [NewFileValidationIssue],
        canMoveUp: Bool,
        canMoveDown: Bool,
        onDraftChange: @escaping (NewFileTemplateConfig) -> Void,
        onUpdate: @escaping (String, String, String, NewFileCreationMode, String?, String?, Bool) -> Void,
        onDelete: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void
    ) {
        self.template = template
        self.liveIssues = liveIssues
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onDraftChange = onDraftChange
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        _displayName = State(initialValue: template.displayName)
        _baseName = State(initialValue: template.baseName)
        _fileExtension = State(initialValue: template.fileExtension)
        _creationMode = State(initialValue: template.creationMode)
        _templatePath = State(initialValue: template.templatePath ?? "")
        _initialContent = State(initialValue: template.initialContent ?? "")
        _isEnabled = State(initialValue: template.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                TextField("菜单名", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(minWidth: 70)

                Picker("创建方式", selection: $creationMode) {
                    ForEach(NewFileCreationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 110)

                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()

                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .disabled(!canMoveUp)
                .help("上移")

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .disabled(!canMoveDown)
                .help("下移")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("删除模板")
            }

            HStack(spacing: 6) {
                TextField("基础文件名", text: $baseName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)

                Text(".")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("扩展名", text: $fileExtension)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(width: 80)
            }

            switch creationMode {
            case .emptyFile:
                EmptyView()
            case .textContent:
                TextEditor(text: $initialContent)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary.opacity(0.12))
                    )
            case .copyTemplate:
                HStack(spacing: 6) {
                    TextField("模板文件路径", text: $templatePath)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    Button {
                        chooseTemplateFile()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .controlSize(.small)
                    .help("选择模板文件")
                }
            }

            if !liveIssues.isEmpty {
                ForEach(liveIssues) { issue in
                    ValidationIssueRow(isError: issue.severity == .error, message: issue.message)
                }
            }

            HStack {
                if showsSaveFeedback {
                    SaveConfirmationLabel()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }

                Spacer()

                Button("保存模板") {
                    onUpdate(
                        displayName,
                        baseName,
                        fileExtension,
                        creationMode,
                        templatePath.nilIfBlank,
                        initialContent.nilIfBlank,
                        isEnabled
                    )
                    showSaveFeedback()
                }
                .controlSize(.small)
                .disabled(!hasChanges || hasBlockingIssues)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.04))
        )
        .onAppear {
            onDraftChange(editedTemplate)
        }
        .onChange(of: editedTemplate) { _, draft in
            onDraftChange(draft)
        }
        .onChange(of: template) { _, newValue in
            displayName = newValue.displayName
            baseName = newValue.baseName
            fileExtension = newValue.fileExtension
            creationMode = newValue.creationMode
            templatePath = newValue.templatePath ?? ""
            initialContent = newValue.initialContent ?? ""
            isEnabled = newValue.isEnabled
            onDraftChange(newValue)
        }
    }

    private var hasBlockingIssues: Bool {
        liveIssues.contains { $0.severity == .error }
    }

    private var editedTemplate: NewFileTemplateConfig {
        var copy = template
        copy.displayName = displayName
        copy.baseName = baseName
        copy.fileExtension = fileExtension
        copy.creationMode = creationMode
        copy.templatePath = creationMode == .copyTemplate ? templatePath.nilIfBlank : nil
        copy.templateFingerprint = NewFileTemplateFingerprint.fileFingerprint(at: copy.templatePath)
        copy.initialContent = creationMode == .textContent ? initialContent.nilIfBlank : nil
        copy.isEnabled = isEnabled
        return copy
    }

    private var hasChanges: Bool {
        displayName != template.displayName
            || baseName != template.baseName
            || fileExtension != template.fileExtension
            || creationMode != template.creationMode
            || templatePath.nilIfBlank != template.templatePath
            || initialContent.nilIfBlank != template.initialContent
            || isEnabled != template.isEnabled
    }

    private func chooseTemplateFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            templatePath = url.path
            if fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !url.pathExtension.isEmpty {
                fileExtension = url.pathExtension
            }
        }
    }

    private func showSaveFeedback() {
        saveFeedbackID += 1
        let currentID = saveFeedbackID
        withAnimation(.easeOut(duration: 0.12)) {
            showsSaveFeedback = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard currentID == saveFeedbackID else { return }
            withAnimation(.easeIn(duration: 0.12)) {
                showsSaveFeedback = false
            }
        }
    }
}
