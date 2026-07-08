import Foundation
import Testing
@testable import RCMMShared

@Suite("NewFileTemplateMetadataPolicy 测试")
struct NewFileTemplateMetadataPolicyTests {
    @Test("refreshingTemplateFingerprints 标准化复制模板元数据并清理非复制模板")
    func refreshingTemplateFingerprintsNormalizesTemplateMetadata() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent("NewFileTemplateMetadataPolicyTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)

        let templateURL = temporaryRoot.appendingPathComponent("template.docx")
        try Data("template".utf8).write(to: templateURL)

        let copyID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let textID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let staleFingerprint = NewFileTemplateFingerprint(
            path: "/stale",
            fileSize: 1,
            modificationTime: 2
        )
        let entries: [MenuEntry] = [
            .newFile(NewFileMenuConfig(
                templates: [
                    NewFileTemplateConfig(
                        id: copyID,
                        displayName: "word",
                        fileExtension: "docx",
                        creationMode: .copyTemplate,
                        templatePath: " \(templateURL.path) "
                    ),
                    NewFileTemplateConfig(
                        id: textID,
                        displayName: "md",
                        fileExtension: "md",
                        creationMode: .textContent,
                        templatePath: "/should/clear",
                        templateFingerprint: staleFingerprint,
                        initialContent: "# Untitled\n"
                    ),
                ]
            )),
        ]

        let refreshed = NewFileTemplateMetadataPolicy.refreshingTemplateFingerprints(in: entries)

        guard case .newFile(let config) = refreshed.first else {
            Issue.record("Expected new file menu")
            return
        }
        #expect(config.templates[0].templatePath == templateURL.path)
        #expect(config.templates[0].templateFingerprint == NewFileTemplateFingerprint.fileFingerprint(at: templateURL.path))
        #expect(config.templates[1].templatePath == nil)
        #expect(config.templates[1].templateFingerprint == nil)
    }

    @Test("mergingTemplateFingerprints 只合并同一模板同一路径的 fingerprint")
    func mergingTemplateFingerprintsPreservesCurrentUserEdits() {
        let menuID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let matchingTemplateID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let changedPathTemplateID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let deletedTemplateID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let textTemplateID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let newTemplateID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let oldPath = "/tmp/old.docx"
        let newPath = "/tmp/new.docx"
        let mergedFingerprint = NewFileTemplateFingerprint(
            path: oldPath,
            fileSize: 10,
            modificationTime: 20
        )
        let wrongPathFingerprint = NewFileTemplateFingerprint(
            path: oldPath,
            fileSize: 30,
            modificationTime: 40
        )
        let staleFingerprint = NewFileTemplateFingerprint(
            path: "/tmp/stale.md",
            fileSize: 50,
            modificationTime: 60
        )
        let refreshedEntries: [MenuEntry] = [
            .newFile(NewFileMenuConfig(
                id: menuID,
                name: "旧菜单名",
                templates: [
                    NewFileTemplateConfig(
                        id: matchingTemplateID,
                        displayName: "旧模板名",
                        fileExtension: "docx",
                        creationMode: .copyTemplate,
                        templatePath: oldPath,
                        templateFingerprint: mergedFingerprint
                    ),
                    NewFileTemplateConfig(
                        id: changedPathTemplateID,
                        displayName: "路径旧值",
                        fileExtension: "docx",
                        creationMode: .copyTemplate,
                        templatePath: oldPath,
                        templateFingerprint: wrongPathFingerprint
                    ),
                    NewFileTemplateConfig(
                        id: deletedTemplateID,
                        displayName: "已删除",
                        fileExtension: "docx",
                        creationMode: .copyTemplate,
                        templatePath: oldPath,
                        templateFingerprint: mergedFingerprint
                    ),
                ]
            )),
        ]
        let currentEntries: [MenuEntry] = [
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
            .newFile(NewFileMenuConfig(
                id: menuID,
                name: "用户改名",
                templates: [
                    NewFileTemplateConfig(
                        id: matchingTemplateID,
                        displayName: "用户模板名",
                        fileExtension: "docx",
                        creationMode: .copyTemplate,
                        templatePath: " \(oldPath) ",
                        isEnabled: false
                    ),
                    NewFileTemplateConfig(
                        id: changedPathTemplateID,
                        displayName: "路径新值",
                        fileExtension: "docx",
                        creationMode: .copyTemplate,
                        templatePath: newPath
                    ),
                    NewFileTemplateConfig(
                        id: textTemplateID,
                        displayName: "md",
                        fileExtension: "md",
                        creationMode: .textContent,
                        templatePath: "/tmp/stale.md",
                        templateFingerprint: staleFingerprint
                    ),
                    NewFileTemplateConfig(
                        id: newTemplateID,
                        displayName: "新增",
                        fileExtension: "txt",
                        creationMode: .emptyFile
                    ),
                ]
            )),
            .custom(MenuItemConfig(appName: "用户新增", appPath: "/Applications/User.app")),
        ]

        let merged = NewFileTemplateMetadataPolicy.mergingTemplateFingerprints(
            from: refreshedEntries,
            into: currentEntries
        )

        #expect(merged.map(\.displayName) == ["拷贝路径", "用户改名", "用户新增"])
        guard case .newFile(let config) = merged[1] else {
            Issue.record("Expected new file menu")
            return
        }
        #expect(config.templates.map(\.id) == [
            matchingTemplateID,
            changedPathTemplateID,
            textTemplateID,
            newTemplateID,
        ])
        #expect(config.templates[0].displayName == "用户模板名")
        #expect(config.templates[0].isEnabled == false)
        #expect(config.templates[0].templatePath == oldPath)
        #expect(config.templates[0].templateFingerprint == mergedFingerprint)
        #expect(config.templates[1].templatePath == newPath)
        #expect(config.templates[1].templateFingerprint != wrongPathFingerprint)
        #expect(config.templates[2].templatePath == nil)
        #expect(config.templates[2].templateFingerprint == nil)
    }
}
