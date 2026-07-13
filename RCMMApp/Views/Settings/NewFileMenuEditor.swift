import AppKit
import RCMMShared
import SwiftUI

struct NewFileMenuEditor: View {
    let config: NewFileMenuConfig
    let onUpdateTemplate: (NewFileTemplateConfig) -> Void
    let onDeleteTemplate: (UUID) -> Void
    let onMoveTemplate: (IndexSet, Int) -> Void

    @State private var templatePendingDeletion: NewFileTemplateConfig?

    var body: some View {
        VStack(spacing: 12) {
            if config.templates.isEmpty {
                emptyState
            } else {
                ForEach(Array(config.templates.enumerated()), id: \.element.id) { index, template in
                    NewFileTemplateCard(
                        savedTemplate: template,
                        canMoveUp: index > 0,
                        canMoveDown: index < config.templates.count - 1,
                        validateDraft: { draft in
                            issues(for: draft)
                        },
                        onUpdate: onUpdateTemplate,
                        onRequestDelete: {
                            templatePendingDeletion = template
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

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(systemName: "document.badge.plus")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text("暂无模板")
                .font(.callout.weight(.semibold))
            Text("使用右上角的“添加模板”创建第一个文件模板。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(templateCardBackground)
    }

    private var deletionDialogTitle: String {
        guard let template = templatePendingDeletion else {
            return "删除模板？"
        }
        return "删除“\(template.displayName.nilIfBlank ?? "未命名模板")”模板？"
    }

    private func issues(for draft: NewFileTemplateConfig) -> [NewFileValidationIssue] {
        var menu = config
        guard let index = menu.templates.firstIndex(where: { $0.id == draft.id }) else {
            return []
        }

        menu.templates[index] = draft
        menu.templates[index].isEnabled = true
        return NewFileMenuValidator.validate(menu).issues.filter { $0.templateID == draft.id }
    }
}

private struct NewFileTemplateCard: View {
    let savedTemplate: NewFileTemplateConfig
    let canMoveUp: Bool
    let canMoveDown: Bool
    let validateDraft: (NewFileTemplateConfig) -> [NewFileValidationIssue]
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
    @State private var isRenaming = false
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField: Hashable {
        case displayName
        case baseName
        case fileExtension
        case initialContent
        case templatePath
    }

    init(
        savedTemplate: NewFileTemplateConfig,
        canMoveUp: Bool,
        canMoveDown: Bool,
        validateDraft: @escaping (NewFileTemplateConfig) -> [NewFileValidationIssue],
        onUpdate: @escaping (NewFileTemplateConfig) -> Void,
        onRequestDelete: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void
    ) {
        self.savedTemplate = savedTemplate
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.validateDraft = validateDraft
        self.onUpdate = onUpdate
        self.onRequestDelete = onRequestDelete
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        _displayName = State(initialValue: savedTemplate.displayName)
        _baseName = State(initialValue: savedTemplate.baseName)
        _fileExtension = State(initialValue: savedTemplate.fileExtension)
        _creationMode = State(initialValue: savedTemplate.creationMode)
        _templatePath = State(initialValue: savedTemplate.templatePath ?? "")
        _initialContent = State(initialValue: savedTemplate.initialContent ?? "")
        _isEnabled = State(initialValue: savedTemplate.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader

            HStack(spacing: 8) {
                TextField("基础文件名", text: $baseName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.regular)
                    .focused($focusedField, equals: .baseName)
                    .onSubmit(saveIfValid)

                TextField(".txt", text: extensionBinding)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.regular)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 100)
                    .focused($focusedField, equals: .fileExtension)
                    .onSubmit(saveIfValid)
            }

            creationModeEditor

            if !currentIssues.isEmpty {
                issueList
            }
        }
        .padding(11)
        .background(templateCardBackground)
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue == .displayName, newValue != .displayName {
                isRenaming = false
            }
            if oldValue != nil, oldValue != newValue {
                saveIfValid()
            }
        }
        .onChange(of: creationMode) { _, _ in
            saveIfValid()
        }
        .onChange(of: isEnabled) { oldValue, newValue in
            if newValue,
               currentIssues.contains(where: { $0.severity == .error }) {
                isEnabled = oldValue
                return
            }
            saveIfValid()
        }
        .onDisappear {
            saveIfValid()
        }
    }

    private var cardHeader: some View {
        HStack(spacing: 9) {
            TemplateFileBadge(fileExtension: fileExtension)

            if isRenaming {
                TextField("模板名称", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(maxWidth: 150)
                    .focused($focusedField, equals: .displayName)
                    .onSubmit {
                        finishRenaming()
                    }
            } else {
                Text(displayName.nilIfBlank ?? "未命名模板")
                    .font(.headline)
                    .lineLimit(1)

                Button {
                    isRenaming = true
                    focusedField = .displayName
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("重命名模板")
            }

            Spacer(minLength: 6)

            Text("创建方式")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("创建方式", selection: $creationMode) {
                ForEach(NewFileCreationMode.allCases) { mode in
                    Text(creationModeTitle(for: mode)).tag(mode)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 122)

            templateStatus

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(isEnabled ? "停用此模板" : "启用此模板")

            compactActionButton("chevron.up", help: "上移", disabled: !canMoveUp, action: onMoveUp)
            compactActionButton("chevron.down", help: "下移", disabled: !canMoveDown, action: onMoveDown)
            compactActionButton("trash", help: "删除模板", role: .destructive, action: onRequestDelete)
        }
    }

    private var templateStatus: some View {
        let status = templateStatusPresentation

        return Image(systemName: status.symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(status.color)
            .frame(width: 16, height: 18)
            .help(status.label)
            .accessibilityLabel("模板状态：\(status.label)")
    }

    @ViewBuilder
    private var creationModeEditor: some View {
        switch creationMode {
        case .emptyFile:
            EmptyView()

        case .textContent:
            TextEditor(text: $initialContent)
                .font(.system(.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(5)
                .frame(minHeight: 64)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(fieldBorder)
                .focused($focusedField, equals: .initialContent)

        case .copyTemplate:
            HStack(spacing: 7) {
                TextField("选择模板文件", text: $templatePath)
                    .font(.system(.caption, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.regular)
                    .focused($focusedField, equals: .templatePath)
                    .onSubmit(saveIfValid)

                Button {
                    chooseTemplateFile()
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 18, height: 18)
                }
                .controlSize(.regular)
                .help("选择模板文件")
            }
        }
    }

    private var issueList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(currentIssues) { issue in
                ValidationIssueRow(
                    isError: issue.severity == .error,
                    message: issue.message,
                    warningColor: NewFileSettingsColor.warning
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(issueTint.opacity(0.08))
        )
    }

    private var currentIssues: [NewFileValidationIssue] {
        validateDraft(editedTemplate)
    }

    private var templateStatusPresentation: TemplateStatusPresentation {
        if let issue = currentIssues.first(where: { $0.severity == .error }) {
            return TemplateStatusPresentation(
                label: issue.message,
                symbol: "xmark.octagon.fill",
                color: NewFileSettingsColor.error
            )
        }
        if let issue = currentIssues.first(where: { $0.severity == .warning }) {
            return TemplateStatusPresentation(
                label: issue.message,
                symbol: "exclamationmark.triangle.fill",
                color: NewFileSettingsColor.warning
            )
        }
        if copyTemplateResourceHasChanged {
            return TemplateStatusPresentation(
                label: "模板文件已变化",
                symbol: "exclamationmark.triangle.fill",
                color: NewFileSettingsColor.warning
            )
        }
        return TemplateStatusPresentation(
            label: "配置有效",
            symbol: "checkmark.circle.fill",
            color: NewFileSettingsColor.success
        )
    }

    private var copyTemplateResourceHasChanged: Bool {
        guard creationMode == .copyTemplate,
              templatePath.nilIfBlank == savedTemplate.templatePath else {
            return false
        }
        return NewFileTemplateFingerprint.fileFingerprint(at: templatePath)
            != savedTemplate.templateFingerprint
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

    private var extensionBinding: Binding<String> {
        Binding(
            get: {
                fileExtension.isEmpty ? "" : ".\(fileExtension)"
            },
            set: { value in
                fileExtension = value.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            }
        )
    }

    private var issueTint: Color {
        currentIssues.contains { $0.severity == .error }
            ? NewFileSettingsColor.error
            : NewFileSettingsColor.warning
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(Color.primary.opacity(0.14), lineWidth: 1)
    }

    private func compactActionButton(
        _ systemName: String,
        help: String,
        disabled: Bool = false,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? NewFileSettingsColor.error : Color.secondary)
        .disabled(disabled)
        .help(help)
    }

    private func finishRenaming() {
        isRenaming = false
        focusedField = nil
        saveIfValid()
    }

    private func saveIfValid() {
        let draft = editedTemplate
        guard draft != savedTemplate else {
            return
        }
        guard !draft.isEnabled
                || !validateDraft(draft).contains(where: { $0.severity == .error }) else {
            return
        }
        onUpdate(draft)
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
            saveIfValid()
        }
    }
}

private struct TemplateFileBadge: View {
    let fileExtension: String

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "doc")
                .font(.system(size: 9, weight: .semibold))
            Text(badgeText)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(Color.accentColor)
        .frame(width: 34, height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
        .accessibilityHidden(true)
    }

    private var badgeText: String {
        let normalized = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "FILE" : String(normalized.prefix(4)).uppercased()
    }
}

private struct TemplateStatusPresentation {
    let label: String
    let symbol: String
    let color: Color
}

private var templateCardBackground: some View {
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor))
        .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
}

enum NewFileSettingsColor {
    static let success = Color(red: 47 / 255, green: 158 / 255, blue: 68 / 255)
    static let warning = Color(red: 183 / 255, green: 121 / 255, blue: 31 / 255)
    static let error = Color(red: 217 / 255, green: 45 / 255, blue: 32 / 255)
    static let info = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)
}

private func creationModeTitle(
    for mode: NewFileCreationMode
) -> String {
    switch mode {
    case .emptyFile:
        return "空文件"
    case .textContent:
        return "文本模板"
    case .copyTemplate:
        return "复制文件"
    }
}
