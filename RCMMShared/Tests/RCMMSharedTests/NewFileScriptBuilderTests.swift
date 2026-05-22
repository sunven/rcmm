import Foundation
import Testing
@testable import RCMMShared

@Suite("NewFileScriptBuilder 测试")
struct NewFileScriptBuilderTests {
    @Test("复制模板资源名包含脚本 ID 和扩展名")
    func templateResourceNameIncludesScriptIDAndExtension() {
        let name = NewFileScriptBuilder.templateResourceName(
            for: "menu.template",
            fileExtension: ".docx"
        )

        #expect(name == "menu.template.template.docx")
    }

    @Test("文本内容以 base64 写入避免 AppleScript here-doc 转义问题")
    func textContentUsesBase64() {
        let template = NewFileTemplateConfig(
            displayName: "md",
            fileExtension: "md",
            creationMode: .textContent,
            initialContent: "# Untitled\n"
        )

        let source = NewFileScriptBuilder.source(
            for: template,
            scriptID: "script-id"
        )

        #expect(source.contains("/usr/bin/base64 -D"))
        #expect(source.contains(Data("# Untitled\n".utf8).base64EncodedString()))
    }

    @Test("从菜单和脚本项找到对应模板生成 copyTemplate 脚本")
    func sourceFindsTemplateFromMenu() throws {
        let menuID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let templateID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let menu = NewFileMenuConfig(
            id: menuID,
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
        let entry = ScriptBackedMenuEntry(
            id: MenuEntryScriptPolicy.newFileScriptID(menuID: menuID, templateID: templateID),
            kind: .newFileTemplate,
            displayName: "word",
            fingerprint: "fingerprint",
            source: .newFileTemplate(menuID: menuID, templateID: templateID),
            targetPolicy: .containingDirectory,
            parentDisplayName: "新建"
        )

        let source = try NewFileScriptBuilder.source(
            for: menu,
            scriptBackedEntry: entry
        )

        #expect(source.contains(".template.docx"))
        #expect(source.contains("/bin/cp -p"))
    }
}
