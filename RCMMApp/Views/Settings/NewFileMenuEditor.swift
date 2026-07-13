import AppKit
import RCMMShared
import SwiftUI

struct NewFileMenuEditor: View {
    let config: NewFileMenuConfig
    let onRename: (String) -> Void
    let onAddTemplate: () -> Void
    let onUpdateTemplate: (NewFileTemplateConfig) -> Void
    let onDeleteTemplate: (UUID) -> Void
    let onMoveTemplate: (IndexSet, Int) -> Void

    @State private var editedName: String
    @State private var draftTemplatesByID: [UUID: NewFileTemplateConfig]
    @State private var selectedTemplateID: UUID?
    @State private var templatePendingDeletion: NewFileTemplateConfig?
    @State private var shouldSelectNewestTemplate = false
    @State private var nameSaveFeedbackID = 0
    @State private var showsNameSaveFeedback = false

    init(
        config: NewFileMenuConfig,
        onRename: @escaping (String) -> Void,
        onAddTemplate: @escaping () -> Void,
        onUpdateTemplate: @escaping (NewFileTemplateConfig) -> Void,
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
        _selectedTemplateID = State(initialValue: config.templates.first?.id)
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
        VStack(alignment: .leading, spacing: 12) {
            menuNameEditor

            if !parentIssues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(parentIssues.prefix(5)) { issue in
                        ValidationIssueRow(
                            isError: issue.severity == .error,
                            message: issue.message,
                            warningColor: NewFileSemanticColor.warning
                        )
                    }
                }
            }

            templateWorkspace
        }
        .onAppear {
            reconcileDraftTemplates(with: config.templates)
            normalizeSelection(in: config.templates)
        }
        .onChange(of: config.name) { _, newValue in
            if editedName != newValue {
                editedName = newValue
            }
        }
        .onChange(of: config.templates) { _, templates in
            let previousIDs = Set(draftTemplatesByID.keys)
            reconcileDraftTemplates(with: templates)

            if shouldSelectNewestTemplate {
                selectedTemplateID = templates.first { !previousIDs.contains($0.id) }?.id
                    ?? templates.last?.id
                shouldSelectNewestTemplate = false
            } else {
                normalizeSelection(in: templates)
            }
        }
        .confirmationDialog(
            deletionDialogTitle,
            isPresented: Binding(
                get: { templatePendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        templatePendingDeletion = nil
                    }
                }
            )
        ) {
            Button("删除模板", role: .destructive) {
                guard let template = templatePendingDeletion else { return }
                onDeleteTemplate(template.id)
                templatePendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                templatePendingDeletion = nil
            }
        } message: {
            Text("删除后，该模板将不再出现在 Finder 的新建文件菜单中。")
        }
    }

    private var menuNameEditor: some View {
        HStack(spacing: 10) {
            Image(systemName: "contextualmenu.and.cursorarrow")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("Finder 菜单名称")
                    .font(.caption.weight(.semibold))
                Text("显示在右键菜单中的一级名称")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            TextField("菜单名称", text: $editedName)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .frame(maxWidth: 210)
                .onSubmit {
                    commitName()
                }

            Button("保存") {
                commitName()
            }
            .controlSize(.small)
            .disabled(trimmedEditedName.isEmpty || trimmedEditedName == config.name)

            if showsNameSaveFeedback {
                SaveConfirmationLabel()
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private var templateWorkspace: some View {
        templateList
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
    }

    private var templateList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("文件模板")
                    .font(.callout.weight(.semibold))

                Text(templateCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button {
                    addTemplate()
                } label: {
                    Label("添加", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("添加新模板")
            }
            .padding(.horizontal, 12)
            .frame(height: 42)

            Divider()

            if config.templates.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "document.badge.plus")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)

                    Text("暂无模板")
                        .font(.callout.weight(.semibold))

                    Text("添加一个模板，即可从 Finder 快速创建文件。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        addTemplate()
                    } label: {
                        Label("添加模板", systemImage: "plus")
                    }
                    .controlSize(.small)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(Array(config.templates.enumerated()), id: \.element.id) { index, template in
                        templateListRow(template, at: index)

                        if selectedTemplateID == template.id {
                            Divider()
                                .padding(.horizontal, 8)

                            templateDetail(for: template, at: index)
                                .padding(14)
                                .transition(.opacity.combined(with: .move(edge: .top)))

                            if index < config.templates.count - 1 {
                                Divider()
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                }
                .padding(6)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
    }

    private func templateDetail(
        for template: NewFileTemplateConfig,
        at index: Int
    ) -> some View {
        NewFileTemplateEditor(
            savedTemplate: template,
            initialDraft: draftTemplatesByID[template.id] ?? template,
            liveIssues: validation.issues.filter { $0.templateID == template.id },
            canMoveUp: index > 0,
            canMoveDown: index < config.templates.count - 1,
            onDraftChange: { draft in
                draftTemplatesByID[draft.id] = draft
            },
            onUpdate: onUpdateTemplate,
            onRequestDelete: {
                templatePendingDeletion = draftTemplatesByID[template.id] ?? template
            },
            onMoveUp: {
                onMoveTemplate(IndexSet(integer: index), index - 1)
            },
            onMoveDown: {
                onMoveTemplate(IndexSet(integer: index), index + 2)
            }
        )
        .id(template.id)
    }

    private func templateListRow(_ savedTemplate: NewFileTemplateConfig, at index: Int) -> some View {
        let draft = draftTemplatesByID[savedTemplate.id] ?? savedTemplate
        let issues = templateIssues(for: draft)
        let isSelected = selectedTemplateID == savedTemplate.id

        return Button {
            guard !isSelected else { return }
            withAnimation(.easeInOut(duration: 0.14)) {
                selectedTemplateID = savedTemplate.id
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: creationModePresentation(for: draft.creationMode).symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.displayName.nilIfBlank ?? "未命名模板")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(draft.isEnabled ? .primary : .secondary)
                        .lineLimit(1)

                    Text("\(generatedFilename(for: draft)) · \(creationModePresentation(for: draft.creationMode).title)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                templateStatus(
                    for: draft,
                    savedTemplate: savedTemplate,
                    issues: issues
                )

                Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.13) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "正在编辑此模板" : "按下以编辑此模板")
    }

    @ViewBuilder
    private func templateStatus(
        for template: NewFileTemplateConfig,
        savedTemplate: NewFileTemplateConfig,
        issues: [NewFileValidationIssue]
    ) -> some View {
        let hasUnsavedChanges = hasUserChanges(template, comparedWith: savedTemplate)
        let resourceStatus = templateResourceStatus(
            for: template,
            savedTemplate: savedTemplate,
            issues: issues
        )
        let error = issues.first { $0.severity == .error }
        let warning = issues.first { $0.severity == .warning }

        HStack(spacing: 6) {
            if hasUnsavedChanges {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(NewFileSemanticColor.info)
                    .help("有未保存的更改")
                    .accessibilityLabel("未保存")
            }

            Image(systemName: template.isEnabled ? "eye.fill" : "eye.slash.fill")
                .foregroundStyle(.secondary)
                .help(template.isEnabled ? "已启用" : "已停用")
                .accessibilityLabel(template.isEnabled ? "已启用" : "已停用")

            if let resourceStatus {
                Label(resourceStatus.label, systemImage: resourceStatus.symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(resourceStatus.color)
                    .lineLimit(1)
            } else if let error {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(NewFileSemanticColor.error)
                    .help(error.message)
                    .accessibilityLabel("不可用：\(error.message)")
            } else if let warning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(NewFileSemanticColor.warning)
                    .help(warning.message)
                    .accessibilityLabel("有警告：\(warning.message)")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(NewFileSemanticColor.success)
                    .help("配置有效")
                    .accessibilityLabel("配置有效")
            }
        }
    }

    private var deletionDialogTitle: String {
        guard let template = templatePendingDeletion else {
            return "删除模板？"
        }
        let displayName = template.displayName.nilIfBlank ?? "未命名模板"
        return "删除“\(displayName)”模板？"
    }

    private var templateCountText: String {
        let enabledCount = draftMenu.templates.filter(\.isEnabled).count
        return "\(enabledCount) 个启用，共 \(config.templates.count) 个"
    }

    private func templateIssues(
        for template: NewFileTemplateConfig
    ) -> [NewFileValidationIssue] {
        if template.isEnabled {
            return validation.issues.filter { $0.templateID == template.id }
        }

        var menu = draftMenu
        guard let index = menu.templates.firstIndex(where: { $0.id == template.id }) else {
            return []
        }
        menu.templates[index].isEnabled = true
        return NewFileMenuValidator.validate(menu).issues.filter { $0.templateID == template.id }
    }

    private func templateResourceStatus(
        for template: NewFileTemplateConfig,
        savedTemplate: NewFileTemplateConfig,
        issues: [NewFileValidationIssue]
    ) -> TemplateResourceStatus? {
        if issues.contains(where: { $0.code == .missingTemplatePath }) {
            return TemplateResourceStatus(
                label: "未选择模板文件",
                symbol: "xmark.octagon.fill",
                color: NewFileSemanticColor.error
            )
        }
        if issues.contains(where: { $0.code == .templatePathMissing }) {
            return TemplateResourceStatus(
                label: "模板文件缺失",
                symbol: "xmark.octagon.fill",
                color: NewFileSemanticColor.error
            )
        }
        if issues.contains(where: { $0.code == .templatePathIsDirectory }) {
            return TemplateResourceStatus(
                label: "模板文件不可用",
                symbol: "xmark.octagon.fill",
                color: NewFileSemanticColor.error
            )
        }
        if template.creationMode == .copyTemplate,
           template.templatePath == savedTemplate.templatePath,
           template.templateFingerprint != savedTemplate.templateFingerprint {
            return TemplateResourceStatus(
                label: "模板文件已变化",
                symbol: "exclamationmark.triangle.fill",
                color: NewFileSemanticColor.warning
            )
        }
        return nil
    }

    private func hasUserChanges(
        _ template: NewFileTemplateConfig,
        comparedWith savedTemplate: NewFileTemplateConfig
    ) -> Bool {
        var comparableTemplate = template
        comparableTemplate.templateFingerprint = savedTemplate.templateFingerprint
        return comparableTemplate != savedTemplate
    }

    private func addTemplate() {
        shouldSelectNewestTemplate = true
        onAddTemplate()
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

    private func normalizeSelection(in templates: [NewFileTemplateConfig]) {
        guard let selectedTemplateID,
              templates.contains(where: { $0.id == selectedTemplateID }) else {
            self.selectedTemplateID = templates.first?.id
            return
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

private struct NewFileTemplateEditor: View {
    let savedTemplate: NewFileTemplateConfig
    let liveIssues: [NewFileValidationIssue]
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onDraftChange: (NewFileTemplateConfig) -> Void
    let onUpdate: (NewFileTemplateConfig) -> Void
    let onRequestDelete: () -> Void
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
        savedTemplate: NewFileTemplateConfig,
        initialDraft: NewFileTemplateConfig,
        liveIssues: [NewFileValidationIssue],
        canMoveUp: Bool,
        canMoveDown: Bool,
        onDraftChange: @escaping (NewFileTemplateConfig) -> Void,
        onUpdate: @escaping (NewFileTemplateConfig) -> Void,
        onRequestDelete: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void
    ) {
        self.savedTemplate = savedTemplate
        self.liveIssues = liveIssues
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onDraftChange = onDraftChange
        self.onUpdate = onUpdate
        self.onRequestDelete = onRequestDelete
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        _displayName = State(initialValue: initialDraft.displayName)
        _baseName = State(initialValue: initialDraft.baseName)
        _fileExtension = State(initialValue: initialDraft.fileExtension)
        _creationMode = State(initialValue: initialDraft.creationMode)
        _templatePath = State(initialValue: initialDraft.templatePath ?? "")
        _initialContent = State(initialValue: initialDraft.initialContent ?? "")
        _isEnabled = State(initialValue: initialDraft.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            editorHeader

            Divider()

            editorSection("基本信息") {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        fieldLabel("显示名称")
                        TextField("例如：Markdown", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }

                    GridRow(alignment: .center) {
                        fieldLabel("生成文件名")
                        HStack(spacing: 6) {
                            TextField("基础文件名", text: $baseName)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)

                            Text(".")
                                .foregroundStyle(.secondary)

                            TextField("扩展名", text: $fileExtension)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)
                                .frame(width: 82)
                        }
                    }
                }

                HStack(spacing: 5) {
                    Image(systemName: "doc")
                    Text("示例：\(generatedFilename(for: editedTemplate))")
                        .monospaced()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 82)
            }

            editorSection("创建方式") {
                Picker("创建方式", selection: $creationMode) {
                    ForEach(NewFileCreationMode.allCases) { mode in
                        Text(creationModePresentation(for: mode).title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                creationModeEditor
            }

            if !liveIssues.isEmpty {
                editorSection("需要处理") {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(liveIssues) { issue in
                            ValidationIssueRow(
                                isError: issue.severity == .error,
                                message: issue.message,
                                warningColor: NewFileSemanticColor.warning
                            )
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(issueTint.opacity(0.08))
                    )
                }
            }

            Divider()

            editorFooter
        }
        .onAppear {
            onDraftChange(editedTemplate)
        }
        .onChange(of: editedTemplate) { _, draft in
            onDraftChange(draft)
        }
        .onChange(of: savedTemplate) { _, newValue in
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

    private var editorHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: creationModePresentation(for: creationMode).symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.11))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName.nilIfBlank ?? "未命名模板")
                    .font(.headline)
                    .lineLimit(1)
                Text(generatedFilename(for: editedTemplate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Toggle("在 Finder 菜单中显示", isOn: $isEnabled)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .help(isEnabled ? "保存后继续在 Finder 菜单中显示" : "保存后从 Finder 菜单中隐藏")
        }
    }

    @ViewBuilder
    private var creationModeEditor: some View {
        switch creationMode {
        case .emptyFile:
            Label("创建不包含任何内容的空文件。", systemImage: "doc")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .textContent:
            VStack(alignment: .leading, spacing: 5) {
                Text("默认内容")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                TextEditor(text: $initialContent)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 100)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.primary.opacity(0.14))
                    )
            }

        case .copyTemplate:
            VStack(alignment: .leading, spacing: 5) {
                Text("模板文件")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    TextField("选择一个本地文件", text: $templatePath)
                        .font(.system(.caption, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)

                    Button {
                        chooseTemplateFile()
                    } label: {
                        Label("选择…", systemImage: "folder")
                    }
                    .controlSize(.small)
                }

                Text("创建文件时会复制该文件的内容。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var editorFooter: some View {
        HStack(spacing: 8) {
            Menu {
                Button("上移", systemImage: "chevron.up", action: onMoveUp)
                    .disabled(!canMoveUp)
                Button("下移", systemImage: "chevron.down", action: onMoveDown)
                    .disabled(!canMoveDown)
                Divider()
                Button("删除模板", systemImage: "trash", role: .destructive, action: onRequestDelete)
            } label: {
                Label("更多", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .controlSize(.small)
            .fixedSize()

            Spacer(minLength: 8)

            if showsSaveFeedback {
                SaveConfirmationLabel()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else if hasChanges {
                Text("有未保存的更改")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button("保存并同步") {
                saveTemplate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!hasChanges || hasBlockingIssues)
        }
    }

    private func editorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 72, alignment: .trailing)
    }

    private var issueTint: Color {
        liveIssues.contains { $0.severity == .error }
            ? NewFileSemanticColor.error
            : NewFileSemanticColor.warning
    }

    private var hasBlockingIssues: Bool {
        liveIssues.contains { $0.severity == .error }
    }

    private var editedTemplate: NewFileTemplateConfig {
        var copy = savedTemplate
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
        displayName != savedTemplate.displayName
            || baseName != savedTemplate.baseName
            || fileExtension != savedTemplate.fileExtension
            || creationMode != savedTemplate.creationMode
            || templatePath.nilIfBlank != savedTemplate.templatePath
            || initialContent.nilIfBlank != savedTemplate.initialContent
            || isEnabled != savedTemplate.isEnabled
    }

    private func saveTemplate() {
        onUpdate(editedTemplate)
        showSaveFeedback()
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

private struct TemplateResourceStatus {
    let label: String
    let symbol: String
    let color: Color
}

private struct NewFileCreationModePresentation {
    let title: String
    let symbol: String
}

private enum NewFileSemanticColor {
    static let success = Color(red: 47 / 255, green: 158 / 255, blue: 68 / 255)
    static let warning = Color(red: 183 / 255, green: 121 / 255, blue: 31 / 255)
    static let error = Color(red: 217 / 255, green: 45 / 255, blue: 32 / 255)
    static let info = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)
}

private func creationModePresentation(
    for mode: NewFileCreationMode
) -> NewFileCreationModePresentation {
    switch mode {
    case .emptyFile:
        return NewFileCreationModePresentation(title: "空白文件", symbol: "doc")
    case .textContent:
        return NewFileCreationModePresentation(title: "预填文本", symbol: "doc.text")
    case .copyTemplate:
        return NewFileCreationModePresentation(title: "复制现有文件", symbol: "doc.on.doc")
    }
}

private func generatedFilename(for template: NewFileTemplateConfig) -> String {
    let baseName = template.baseName.trimmingCharacters(in: .whitespacesAndNewlines)
    let fileExtension = template.fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)

    if baseName.isEmpty, fileExtension.isEmpty {
        return "文件名未设置"
    }
    if fileExtension.isEmpty {
        return baseName
    }
    if baseName.isEmpty {
        return ".\(fileExtension)"
    }
    return "\(baseName).\(fileExtension)"
}
