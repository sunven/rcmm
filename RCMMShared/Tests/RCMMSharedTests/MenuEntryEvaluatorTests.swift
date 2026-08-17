import Foundation
import Testing
@testable import RCMMShared

@Suite("MenuEntryEvaluator")
struct MenuEntryEvaluatorTests {
    // MARK: - Built-in Entry

    @Test("启用的 Built-in Entry 可执行，但不产出脚本")
    func enabledBuiltInIsExecutableWithoutScripts() {
        let evaluation = MenuEntryEvaluator.evaluate(.builtIn(MenuEntryCorpus.builtInEnabled))

        // isExecutable 不能从 scriptBacked.isEmpty 派生 —— 内置项没有脚本却是 Finder 里真实
        // 可见的菜单项，派生会让它读成不可用。
        #expect(evaluation.isExecutable)
        #expect(evaluation.scriptBacked.isEmpty)
        #expect(evaluation.issues.isEmpty)
    }

    @Test("停用的 Built-in Entry 不可执行")
    func disabledBuiltInIsNotExecutable() {
        let evaluation = MenuEntryEvaluator.evaluate(.builtIn(MenuEntryCorpus.builtInDisabled))

        #expect(!evaluation.isExecutable)
        #expect(evaluation.issues.isEmpty)
    }

    // MARK: - environment 默认值

    @Test("默认 environment 是 configurationOnly", arguments: MenuEntryCorpus.all)
    func defaultEnvironmentIsConfigurationOnly(named name: String, entry: MenuEntry) {
        // 忘记传参的后果不对称：设置界面漏传只是少一条提示，发布门漏传会让扩展进程
        // 每次右键做文件系统 IO。安全的那一侧必须是默认值。
        #expect(
            MenuEntryEvaluatorGoldenTests.render(MenuEntryEvaluator.evaluate(entry))
                == MenuEntryEvaluatorGoldenTests.render(
                    MenuEntryEvaluator.evaluate(entry, environment: .configurationOnly)
                ),
            "语料 \(name) 的默认 environment 不是 configurationOnly"
        )
    }

    @Test("configurationOnly 探针对确定不存在的路径仍给出文件信息")
    func configurationOnlyNeverTouchesDisk() {
        let missingPath = "/tmp/rcmm-does-not-exist-9f3a2b/template.docx"
        #expect(!FileManager.default.fileExists(atPath: missingPath))

        // 碰磁盘就只能返回 nil。返回非 nil 即证明它只解析了路径字符串。
        let info = MenuEntryFileProbe.configurationOnly.templateFileInfo(missingPath)
        #expect(info == NewFileTemplateFileInfo(isDirectory: false, pathExtension: "docx"))

        // 对照：真实探针在同一路径上返回 nil。
        #expect(MenuEntryFileProbe.filesystem.templateFileInfo(missingPath) == nil)
    }

    // MARK: - 探针注入

    @Test("模板路径是目录时报 templatePathIsDirectory")
    func directoryTemplatePathIsRejected() {
        let evaluation = MenuEntryEvaluator.evaluate(
            .newFile(MenuEntryCorpus.newFileMissingTemplateFile),
            probe: MenuEntryFileProbe { _ in
                NewFileTemplateFileInfo(isDirectory: true, pathExtension: "docx")
            }
        )

        #expect(evaluation.errors.map(\.code) == [.templatePathIsDirectory])
        #expect(!evaluation.isExecutable)
        #expect(evaluation.scriptBacked.isEmpty)
    }

    @Test("模板扩展名与配置不一致时只是警告")
    func mismatchedTemplateExtensionIsWarningOnly() {
        let evaluation = MenuEntryEvaluator.evaluate(
            .newFile(MenuEntryCorpus.newFileMissingTemplateFile),
            probe: MenuEntryFileProbe { _ in
                NewFileTemplateFileInfo(isDirectory: false, pathExtension: "rtf")
            }
        )

        #expect(evaluation.errors.isEmpty)
        #expect(evaluation.warnings.map(\.code) == [.templateExtensionMismatch])
        #expect(evaluation.warnings.first?.detail == "rtf")
        #expect(evaluation.isExecutable)
        #expect(evaluation.scriptBacked.count == 1)
    }

    // MARK: - 批量重载

    @Test("批量重载按输入顺序拼接 scriptBacked")
    func batchOverloadConcatenatesInOrder() {
        let scriptBacked = MenuEntryEvaluator.evaluate([
            .custom(MenuEntryCorpus.customApp),
            .builtIn(MenuEntryCorpus.builtInEnabled),
            .newFile(MenuEntryCorpus.newFileValid),
            .custom(MenuEntryCorpus.customBlankName),
            .composite(MenuEntryCorpus.compositeValid),
        ])

        #expect(
            scriptBacked.map(\.kind) == [
                .custom,
                .newFileTemplate,
                .newFileTemplate,
                .composite,
            ]
        )
    }

    // MARK: - Issue 身份

    @Test("同 code 同 detail 但不同子项的 issue 身份不冲突")
    func issueIdentityDistinguishesChildren() {
        let issues = MenuEntryEvaluator
            .evaluate(.newFile(MenuEntryCorpus.newFileDuplicateNames))
            .issues

        // 两条 duplicateTemplateName 的 code 与 detail 完全相同，只有 childID 不同。
        // id 若不带 childID，SwiftUI 的 ForEach 会把它们当成同一行。
        #expect(issues.count == 2)
        #expect(Set(issues.map(\.code)) == [.duplicateTemplateName])
        #expect(Set(issues.map(\.detail)) == ["same"])
        #expect(Set(issues.map(\.id)).count == 2)
    }

    @Test("条目级 issue 的身份用 entry 占位")
    func entryLevelIssueIdentityUsesPlaceholder() {
        let issues = MenuEntryEvaluator
            .evaluate(.custom(MenuEntryCorpus.customBlankName))
            .issues

        #expect(issues.map(\.id) == ["entry:blankName:"])
        #expect(issues.allSatisfy { $0.childID == nil })
    }
}
