import Foundation
import Testing
@testable import RCMMShared

@Suite("NewFileMenuStatus 测试")
struct NewFileMenuStatusTests {
    @Test("停用菜单状态为 disabled")
    func disabledStatus() {
        let config = NewFileMenuConfig(isEnabled: false)

        let status = NewFileMenuStatusResolver.resolve(
            config: config,
            publishStates: [:]
        )

        #expect(status.kind == .disabled)
        #expect(status.displayName == "已停用")
    }

    @Test("无可执行模板状态为 unavailable")
    func unavailableStatus() {
        let config = NewFileMenuConfig(templates: [])

        let status = NewFileMenuStatusResolver.resolve(
            config: config,
            publishStates: [:]
        )

        #expect(status.kind == .unavailable)
        #expect(status.displayName == "不可用")
    }

    @Test("有错误但仍有可执行模板状态为 partiallyAvailable")
    func partiallyAvailableStatus() {
        let config = NewFileMenuConfig(
            templates: [
                NewFileTemplateConfig(
                    displayName: "txt",
                    fileExtension: "txt",
                    creationMode: .emptyFile
                ),
                NewFileTemplateConfig(
                    displayName: "",
                    fileExtension: "md",
                    creationMode: .emptyFile
                ),
            ]
        )

        let status = NewFileMenuStatusResolver.resolve(
            config: config,
            validation: NewFileMenuValidator.validate(config),
            publishedTemplateCount: 1
        )

        #expect(status.kind == .partiallyAvailable)
        #expect(status.displayName == "部分可用")
    }

    @Test("只有警告状态为 warning")
    func warningStatus() {
        let config = NewFileMenuConfig(
            templates: [
                NewFileTemplateConfig(
                    displayName: "word",
                    fileExtension: "docx",
                    creationMode: .copyTemplate,
                    templatePath: "/tmp/template.dotx"
                ),
            ]
        )
        let validation = NewFileMenuValidator.validate(config) { _ in
            NewFileTemplateFileInfo(isDirectory: false, pathExtension: "dotx")
        }

        let status = NewFileMenuStatusResolver.resolve(
            config: config,
            validation: validation,
            publishedTemplateCount: 1
        )

        #expect(status.kind == .warning)
        #expect(status.displayName == "有警告")
    }

    @Test("可执行模板未全部发布状态为 syncing")
    func syncingStatus() {
        let config = NewFileMenuConfig(
            templates: [
                NewFileTemplateConfig(
                    displayName: "txt",
                    fileExtension: "txt",
                    creationMode: .emptyFile
                ),
            ]
        )

        let status = NewFileMenuStatusResolver.resolve(
            config: config,
            validation: NewFileMenuValidator.validate(config),
            publishedTemplateCount: 0
        )

        #expect(status.kind == .syncing)
        #expect(status.displayName == "同步中")
    }

    @Test("可执行模板全部发布状态为 ready")
    func readyStatus() {
        let config = NewFileMenuConfig(
            templates: [
                NewFileTemplateConfig(
                    displayName: "txt",
                    fileExtension: "txt",
                    creationMode: .emptyFile
                ),
            ]
        )

        let status = NewFileMenuStatusResolver.resolve(
            config: config,
            validation: NewFileMenuValidator.validate(config),
            publishedTemplateCount: 1
        )

        #expect(status.kind == .ready)
        #expect(status.displayName == "就绪")
    }
}
