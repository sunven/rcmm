import AppKit
import RCMMShared
import SwiftUI

struct NewFileMenuEditor: View {
    @Environment(SettingsDraftStore.self) private var drafts
    let config: NewFileMenuConfig
    let onDeleteTemplate: (UUID) -> Void
    let onMoveTemplate: (IndexSet, Int) -> Void

    @State private var templatePendingDeletion: NewFileTemplateConfig?

    var body: some View {
        VStack(spacing: 10) {
            if config.templates.isEmpty {
                emptyState
            } else {
                ForEach(Array(config.templates.enumerated()), id: \.element.id) { index, template in
                    NewFileTemplateCard(
                        savedTemplate: template,
                        menuID: config.id,
                        template: Binding(
                            get: { drafts.template(for: template, menuID: config.id) },
                            set: { drafts.updateTemplate($0, menuID: config.id) }
                        ),
                        canMoveUp: index > 0,
                        canMoveDown: index < config.templates.count - 1,
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
            Text("删除后，该模板将不再出现在 Finder 的新建文件菜单中，未保存的修改也会删除。")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "document.badge.plus")
                .font(.system(size: 22))
                .foregroundStyle(RCMMColor.textFaint)
                .symbolRenderingMode(.hierarchical)

            Text("暂无模板")
                .font(RCMMFont.emptyTitle)
                .foregroundStyle(RCMMColor.textPrimary)

            Text("使用右上角的“添加模板”创建第一个文件模板。")
                .font(RCMMFont.secondary)
                .foregroundStyle(RCMMColor.textMuted)
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

}

private struct NewFileTemplateCard: View {
    @Environment(SettingsDraftStore.self) private var drafts
    let savedTemplate: NewFileTemplateConfig
    let menuID: UUID
    @Binding var template: NewFileTemplateConfig
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onRequestDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    private var displayName: String { template.displayName }
    private var fileExtension: String { template.fileExtension }
    private var creationMode: NewFileCreationMode { template.creationMode }
    private var templatePath: String { template.templatePath ?? "" }
    private var isEnabled: Bool { template.isEnabled }
    @State private var isRenaming = false
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField: Hashable {
        case displayName
        case baseName
        case fileExtension
        case initialContent
        case templatePath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader

            HStack(alignment: .top, spacing: 10) {
                RCMMField("基础文件名") {
                    TextField("例如 未命名", text: $template.baseName)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.regular)
                        .focused($focusedField, equals: .baseName)
                }
                .frame(maxWidth: .infinity)

                RCMMField("扩展名") {
                    TextField(".txt", text: extensionBinding)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.regular)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 86)
                        .focused($focusedField, equals: .fileExtension)
                }

                RCMMField("创建方式") {
                    Picker("创建方式", selection: $template.creationMode) {
                        ForEach(NewFileCreationMode.allCases) { mode in
                            Text(creationModeTitle(for: mode)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.regular)
                    .frame(width: 116)
                }
            }

            creationModeEditor

            if !currentIssues.isEmpty {
                issueList
            }

            EditorSaveBar(key: .template(menuID: menuID, templateID: template.id))
        }
        .padding(12)
        .background(templateCardBackground)
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue == .displayName, newValue != .displayName {
                isRenaming = false
            }
        }
    }

    private var cardHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            TemplateFileBadge(fileExtension: fileExtension)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if isRenaming {
                        TextField("模板名称", text: $template.displayName)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                            .frame(maxWidth: 160)
                            .focused($focusedField, equals: .displayName)
                            .onSubmit {
                                finishRenaming()
                            }
                    } else {
                        Text(displayName.nilIfBlank ?? "未命名模板")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RCMMColor.textPrimary)
                            .lineLimit(1)

                        Button {
                            isRenaming = true
                            focusedField = .displayName
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(RCMMColor.textMuted)
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                        .help("重命名模板")
                    }

                    if drafts.hasChanges(.template(menuID: menuID, templateID: template.id)) {
                        Circle()
                            .fill(RCMMColor.accent)
                            .frame(width: 5, height: 5)
                            .help("有未保存的修改")
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: templateStatusPresentation.symbol)
                        .font(.system(size: 9, weight: .semibold))
                    Text(templateStatusPresentation.label)
                        .lineLimit(1)
                }
                .font(RCMMFont.caption)
                .foregroundStyle(templateStatusPresentation.color)
                .help(templateStatusPresentation.label)
            }

            Spacer(minLength: 6)

            Toggle("", isOn: $template.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel(isEnabled ? "停用 \(displayName) 模板" : "启用 \(displayName) 模板")
                .help(isEnabled ? "停用此模板" : "启用此模板")

            MenuRowActionsMenu(
                onMoveUp: canMoveUp ? onMoveUp : nil,
                onMoveDown: canMoveDown ? onMoveDown : nil,
                onDelete: onRequestDelete,
                deleteLabel: "删除模板"
            )
        }
    }

    @ViewBuilder
    private var creationModeEditor: some View {
        switch creationMode {
        case .emptyFile:
            EmptyView()

        case .textContent:
            RCMMField("初始内容") {
                TextEditor(text: Binding(get: { template.initialContent ?? "" }, set: { template.initialContent = $0 }))
                    .font(.system(.caption, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(5)
                    .frame(minHeight: 68)
                    .background(RCMMColor.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(fieldBorder)
                    .focused($focusedField, equals: .initialContent)
            }

        case .copyTemplate:
            RCMMField("模板文件") {
                HStack(spacing: 7) {
                    TextField("选择模板文件", text: Binding(get: { templatePath }, set: { template.templatePath = $0 }))
                        .font(.system(.caption, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.regular)
                        .focused($focusedField, equals: .templatePath)

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
    }

    private var issueList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(currentIssues) { issue in
                ValidationIssueRow(
                    isError: issue.severity == .error,
                    message: issue.message
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(issueTint.opacity(0.10))
        )
    }

    private var currentIssues: [MenuEntryIssue] {
        drafts.issues(for: .template(menuID: menuID, templateID: template.id))
    }

    private var templateStatusPresentation: TemplateStatusPresentation {
        if let issue = currentIssues.first(where: { $0.severity == .error }) {
            return TemplateStatusPresentation(
                label: issue.message,
                symbol: "xmark.octagon.fill",
                color: RCMMColor.error
            )
        }
        if let issue = currentIssues.first(where: { $0.severity == .warning }) {
            return TemplateStatusPresentation(
                label: issue.message,
                symbol: "exclamationmark.triangle.fill",
                color: RCMMColor.warning
            )
        }
        if copyTemplateResourceHasChanged {
            return TemplateStatusPresentation(
                label: "模板文件已变化",
                symbol: "exclamationmark.triangle.fill",
                color: RCMMColor.warning
            )
        }
        return TemplateStatusPresentation(
            label: "配置有效",
            symbol: "checkmark.circle.fill",
            color: RCMMColor.success
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

    private var extensionBinding: Binding<String> {
        Binding(
            get: {
                fileExtension.isEmpty ? "" : ".\(fileExtension)"
            },
            set: { value in
                template.fileExtension = value.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            }
        )
    }

    private var issueTint: Color {
        currentIssues.contains { $0.severity == .error }
            ? RCMMColor.error
            : RCMMColor.warning
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(RCMMColor.line, lineWidth: 1)
    }

    private func finishRenaming() {
        isRenaming = false
        focusedField = nil
    }

    private func chooseTemplateFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            template.templatePath = url.path
            if fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !url.pathExtension.isEmpty {
                template.fileExtension = url.pathExtension
            }
        }
    }
}

private struct TemplateFileBadge: View {
    let fileExtension: String

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "doc")
                .font(.system(size: 9, weight: .semibold))
            Text(badgeText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(RCMMColor.textSecondary)
        .frame(width: 32, height: 32)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(RCMMColor.surfaceSoft)
        )
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
        .fill(RCMMColor.surface)
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
