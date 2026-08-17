import Foundation
@testable import RCMMShared

/// Golden 基线与新旧等价性测试共用的 Menu Entry 语料。
///
/// 所有 UUID 与字段都是固定值 —— fingerprint 直接由这些字段算出，语料一变 golden 就得重录。
/// 新增语料请往后追加，不要修改既有条目。
enum MenuEntryCorpus {
    static func uuid(_ suffix: String) -> UUID {
        UUID(uuidString: "00000000-0000-4000-8000-\(suffix)")!
    }

    // MARK: - custom

    /// 正常的应用启动项。
    static let customApp = MenuItemConfig(
        id: uuid("000000000001"),
        appName: "Visual Studio Code",
        bundleId: "com.microsoft.VSCode",
        appPath: "/Applications/Visual Studio Code.app"
    )

    /// 正常的当前目录命令项。
    static let customShell = MenuItemConfig(
        id: uuid("000000000002"),
        appName: "Git Pull",
        appPath: "",
        customCommand: "git pull",
        executionMode: .currentDirectory
    )

    /// 名称为空 —— blankName error，不可执行。
    static let customBlankName = MenuItemConfig(
        id: uuid("000000000003"),
        appName: "",
        appPath: "/Applications/Foo.app"
    )

    /// 当前目录模式下带占位符与危险片段 —— 全是 warning，仍可执行。
    static let customWarnings = MenuItemConfig(
        id: uuid("000000000004"),
        appName: "Danger",
        appPath: "",
        customCommand: "sudo rm -rf {path}",
        executionMode: .currentDirectory
    )

    /// 已停用 —— 无 error 但不可执行。
    static let customDisabled = MenuItemConfig(
        id: uuid("000000000005"),
        appName: "Disabled",
        appPath: "/Applications/Bar.app",
        isEnabled: false
    )

    // MARK: - composite

    static let compositeValid = CompositeMenuItemConfig(
        id: uuid("000000000101"),
        name: "编辑器 + 终端",
        iconName: "rectangle.stack.badge.play",
        steps: [
            CompositeCommandStep(
                id: uuid("000000000111"),
                kind: .app,
                name: "VS Code",
                commandTemplate: "open -a {app} {path}",
                appPath: "/Applications/Visual Studio Code.app",
                bundleId: "com.microsoft.VSCode"
            ),
            CompositeCommandStep(
                id: uuid("000000000112"),
                kind: .shell,
                name: "Terminal",
                commandTemplate: "open -a Terminal {path}"
            ),
        ]
    )

    /// 一个有效步骤 + 一个缺 {app} 的无效 app 步骤 + 一个已停用步骤。
    /// 有 error 但 executableStepIDs 非空 —— 「部分可用」那一档。
    static let compositePartial = CompositeMenuItemConfig(
        id: uuid("000000000102"),
        name: "部分可用",
        steps: [
            CompositeCommandStep(
                id: uuid("000000000121"),
                kind: .shell,
                name: "有效",
                commandTemplate: "echo {path}"
            ),
            CompositeCommandStep(
                id: uuid("000000000122"),
                kind: .app,
                name: "缺占位符",
                commandTemplate: "open {path}",
                appPath: "/Applications/Baz.app"
            ),
            CompositeCommandStep(
                id: uuid("000000000123"),
                kind: .shell,
                name: "已停用",
                commandTemplate: "",
                isEnabled: false
            ),
        ]
    )

    /// composite 级 blocking error（名称为空）但步骤级 executableStepIDs 非空。
    ///
    /// 这一格是 `isExecutable` 与 `executableStepIDs.isEmpty` 语义分叉的地方：
    /// 前者为 false（无脚本产出），后者非空。徽章阶梯读的是后者。
    static let compositeBlankName = CompositeMenuItemConfig(
        id: uuid("000000000103"),
        name: "   ",
        steps: [
            CompositeCommandStep(
                id: uuid("000000000131"),
                kind: .shell,
                name: "有效",
                commandTemplate: "echo {path}"
            ),
        ]
    )

    /// 一个步骤都没有 —— 不可用。
    static let compositeNoSteps = CompositeMenuItemConfig(
        id: uuid("000000000104"),
        name: "空组合",
        steps: []
    )

    // MARK: - newFile

    static let newFileValid = NewFileMenuConfig(
        id: uuid("000000000201"),
        name: "新建",
        templates: [
            NewFileTemplateConfig(
                id: uuid("000000000211"),
                displayName: "txt",
                fileExtension: "txt",
                creationMode: .emptyFile
            ),
            NewFileTemplateConfig(
                id: uuid("000000000212"),
                displayName: "md",
                fileExtension: "md",
                creationMode: .textContent,
                initialContent: "# Untitled\n"
            ),
        ]
    )

    /// copyTemplate 指向一个不存在的文件。
    ///
    /// **两种 environment 在这里分叉**：`.configurationOnly` 不碰文件系统，模板照样可执行；
    /// `.filesystemAware` 会给出 templatePathMissing error。
    static let newFileMissingTemplateFile = NewFileMenuConfig(
        id: uuid("000000000202"),
        name: "复制模板",
        templates: [
            NewFileTemplateConfig(
                id: uuid("000000000221"),
                displayName: "docx",
                fileExtension: "docx",
                creationMode: .copyTemplate,
                templatePath: "/tmp/rcmm-does-not-exist-9f3a2b/template.docx"
            ),
        ]
    )

    /// 两个启用模板同名 —— duplicateTemplateName，双双不可执行。
    static let newFileDuplicateNames = NewFileMenuConfig(
        id: uuid("000000000203"),
        name: "重名",
        templates: [
            NewFileTemplateConfig(
                id: uuid("000000000231"),
                displayName: "same",
                fileExtension: "txt",
                creationMode: .emptyFile
            ),
            NewFileTemplateConfig(
                id: uuid("000000000232"),
                displayName: "same",
                fileExtension: "md",
                creationMode: .emptyFile
            ),
        ]
    )

    /// 一个模板都没有 —— noTemplates error。
    static let newFileNoTemplates = NewFileMenuConfig(
        id: uuid("000000000204"),
        name: "空菜单",
        templates: []
    )

    // MARK: - builtIn

    static let builtInEnabled = BuiltInMenuItem(type: .copyPath, isEnabled: true)
    static let builtInDisabled = BuiltInMenuItem(type: .copyPath, isEnabled: false)

    // MARK: - 全量语料

    /// 名字与 entry 成对，断言失败时能直接看出是哪一格。
    static let all: [(name: String, entry: MenuEntry)] = [
        ("customApp", .custom(customApp)),
        ("customShell", .custom(customShell)),
        ("customBlankName", .custom(customBlankName)),
        ("customWarnings", .custom(customWarnings)),
        ("customDisabled", .custom(customDisabled)),
        ("compositeValid", .composite(compositeValid)),
        ("compositePartial", .composite(compositePartial)),
        ("compositeBlankName", .composite(compositeBlankName)),
        ("compositeNoSteps", .composite(compositeNoSteps)),
        ("newFileValid", .newFile(newFileValid)),
        ("newFileMissingTemplateFile", .newFile(newFileMissingTemplateFile)),
        ("newFileDuplicateNames", .newFile(newFileDuplicateNames)),
        ("newFileNoTemplates", .newFile(newFileNoTemplates)),
        ("builtInEnabled", .builtIn(builtInEnabled)),
        ("builtInDisabled", .builtIn(builtInDisabled)),
    ]
}
