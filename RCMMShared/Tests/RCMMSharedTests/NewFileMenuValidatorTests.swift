import Foundation
import Testing
@testable import RCMMShared

@Suite("NewFileMenuValidator 测试")
struct NewFileMenuValidatorTests {
    @Test("有效空文件模板可执行并生成 fingerprint")
    func validEmptyFileTemplateIsExecutable() throws {
        let templateID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let menu = NewFileMenuConfig(
            name: "新建",
            templates: [
                NewFileTemplateConfig(
                    id: templateID,
                    displayName: "txt",
                    baseName: "新建文本",
                    fileExtension: "txt",
                    creationMode: .emptyFile
                ),
            ]
        )

        let result = NewFileMenuValidator.validate(menu)

        #expect(result.isExecutable)
        #expect(result.executableTemplateIDs == [templateID])
        #expect(result.fingerprintByTemplateID[templateID] != nil)
    }

    @Test("重复模板名阻止对应模板执行")
    func duplicateTemplateNamesBlockTemplates() {
        let menu = NewFileMenuConfig(
            name: "新建",
            templates: [
                NewFileTemplateConfig(
                    displayName: "txt",
                    fileExtension: "txt",
                    creationMode: .emptyFile
                ),
                NewFileTemplateConfig(
                    displayName: "txt",
                    fileExtension: "md",
                    creationMode: .emptyFile
                ),
            ]
        )

        let result = NewFileMenuValidator.validate(menu)

        #expect(!result.isExecutable)
        #expect(result.errors.contains { $0.code == .duplicateTemplateName })
    }

    @Test("复制模板需要存在的文件路径")
    func copyTemplateRequiresExistingFile() {
        let templateID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let menu = NewFileMenuConfig(
            name: "新建",
            templates: [
                NewFileTemplateConfig(
                    id: templateID,
                    displayName: "word",
                    fileExtension: "docx",
                    creationMode: .copyTemplate,
                    templatePath: "/tmp/template.docx"
                ),
            ]
        )

        let missing = NewFileMenuValidator.validate(menu) { _ in nil }
        #expect(!missing.isExecutable)
        #expect(missing.errors.contains { $0.code == .templatePathMissing })

        let valid = NewFileMenuValidator.validate(menu) { _ in
            NewFileTemplateFileInfo(isDirectory: false, pathExtension: "docx")
        }
        #expect(valid.isExecutable)
        #expect(valid.executableTemplateIDs == [templateID])
    }

    @Test("复制模板扩展名不一致是警告")
    func copyTemplateExtensionMismatchIsWarning() {
        let menu = NewFileMenuConfig(
            name: "新建",
            templates: [
                NewFileTemplateConfig(
                    displayName: "word",
                    fileExtension: "docx",
                    creationMode: .copyTemplate,
                    templatePath: "/tmp/template.dotx"
                ),
            ]
        )

        let result = NewFileMenuValidator.validate(menu) { _ in
            NewFileTemplateFileInfo(isDirectory: false, pathExtension: "dotx")
        }

        #expect(result.isExecutable)
        #expect(result.warnings.contains { $0.code == .templateExtensionMismatch })
    }
}
