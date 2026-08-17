import Foundation
import Testing
@testable import RCMMShared

/// 第①步的等价性网：这些 golden 是在合并之前、从 `MenuEntryScriptPolicy` 与三个校验器
/// 身上录下来的。它们守着「结构搬迁没有改变行为」这一条。
///
/// fingerprint 是其中最要命的部分 —— 它一变，全部 `.scpt` 会重编，已经发出的 Finder 菜单
/// 会因 tag 失配而集体点不动，而且没有任何编译错误会提醒你。
///
/// 第②步会有意改变行为（统一状态阶梯、新增 applicationMissing），届时按 ADR-0006 删除本文件。
@Suite("MenuEntryEvaluator golden 等价性")
struct MenuEntryEvaluatorGoldenTests {
    @Test("configurationOnly 下的输出与合并前逐位相同", arguments: MenuEntryCorpus.all)
    func configurationOnlyMatchesGolden(named name: String, entry: MenuEntry) {
        let rendered = Self.render(
            MenuEntryEvaluator.evaluate(entry, environment: .configurationOnly)
        )
        #expect(rendered == Self.configurationOnlyGolden[name], "语料 \(name) 与 golden 不符")
    }

    @Test(
        "configurationOnly 不产生任何依赖文件系统的问题",
        arguments: MenuEntryCorpus.all
    )
    func configurationOnlyReportsNoFilesystemIssues(named name: String, entry: MenuEntry) {
        // 直接断言不变量本身，而不是比对两种 environment 的输出 —— 后者会随开发机
        // /Applications 里装了什么而变化，是个假绿灯。
        let codes = Set(MenuEntryEvaluator.evaluate(entry, environment: .configurationOnly).issues.map(\.code))

        #expect(
            codes.intersection(Self.filesystemDerivedCodes).isEmpty,
            "语料 \(name) 在发布门路径上产生了依赖文件系统的问题"
        )
    }

    @Test("filesystemAware 才会报出文件系统层面的问题")
    func filesystemAwareSurfacesFilesystemIssues() {
        let missingApp = MenuEntry.custom(MenuEntryCorpus.customAppMissingBundle)
        let missingTemplate = MenuEntry.newFile(MenuEntryCorpus.newFileMissingTemplateFile)

        // 用注入探针给出确定答案，不依赖开发机上装了什么。
        let probe = MenuEntryFileProbe(
            templateFileInfo: { _ in nil },
            applicationExists: { _ in false }
        )

        #expect(
            MenuEntryEvaluator.evaluate(missingApp, probe: probe).errors.map(\.code)
                == [.applicationMissing]
        )
        #expect(
            MenuEntryEvaluator.evaluate(missingTemplate, probe: probe).errors.map(\.code)
                == [.templatePathMissing]
        )
        // 同样两个条目，发布门一个问题都不报，且照常产出脚本。
        #expect(MenuEntryEvaluator.evaluate(missingApp).issues.isEmpty)
        #expect(MenuEntryEvaluator.evaluate(missingApp).scriptBacked.count == 1)
        #expect(MenuEntryEvaluator.evaluate(missingTemplate).issues.isEmpty)
        #expect(MenuEntryEvaluator.evaluate(missingTemplate).scriptBacked.count == 1)
    }

    static let filesystemDerivedCodes: Set<MenuEntryIssueCode> = [
        .applicationMissing,
        .templatePathMissing,
        .templatePathIsDirectory,
        .templateExtensionMismatch,
    ]

    // MARK: - Rendering

    static func render(_ evaluation: MenuEntryEvaluation) -> String {
        var lines = ["EXEC \(evaluation.isExecutable)"]

        for entry in evaluation.scriptBacked {
            let steps = entry.executableStepIDs
                .map(\.uuidString)
                .sorted()
                .joined(separator: ",")
            lines.append(
                "SB \(entry.id) \(entry.kind.rawValue) \(entry.displayName) "
                    + "parent=\(entry.parentDisplayName ?? "-") fp=\(entry.fingerprint) "
                    + "target=\(entry.targetPolicy.rawValue) steps=[\(steps)]"
            )
        }

        for issue in evaluation.issues {
            lines.append(
                "ISSUE \(issue.code.rawValue) \(issue.severity.rawValue) "
                    + "child=\(issue.childID?.uuidString ?? "-") detail=\(issue.detail ?? "-")"
            )
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Golden

    static let configurationOnlyGolden: [String: String] = [
        "customApp": """
        EXEC true
        SB 00000000-0000-4000-8000-000000000001 custom Visual Studio Code parent=- fp=83f7849ae82263c6 target=selectedPath steps=[]
        """,

        "customShell": """
        EXEC true
        SB 00000000-0000-4000-8000-000000000002 custom Git Pull parent=- fp=e10077e84df7e4a4 target=containingDirectory steps=[]
        """,

        "customBlankName": """
        EXEC false
        ISSUE blankName error child=- detail=-
        """,

        "customWarnings": """
        EXEC true
        SB 00000000-0000-4000-8000-000000000004 custom Danger parent=- fp=e67a390d872e6a52 target=containingDirectory steps=[]
        ISSUE unsupportedPlaceholder warning child=- detail={path}
        ISSUE dangerousCommandPattern warning child=- detail=rm -rf
        ISSUE dangerousCommandPattern warning child=- detail=sudo
        """,

        "customDisabled": """
        EXEC false
        """,

        "compositeValid": """
        EXEC true
        SB 00000000-0000-4000-8000-000000000101 composite 编辑器 + 终端 parent=- fp=eba53b8490045bb6 target=selectedPath steps=[00000000-0000-4000-8000-000000000111,00000000-0000-4000-8000-000000000112]
        """,

        "compositePartial": """
        EXEC true
        SB 00000000-0000-4000-8000-000000000102 composite 部分可用 parent=- fp=c6c8f906de2f4c9e target=selectedPath steps=[00000000-0000-4000-8000-000000000121]
        ISSUE appStepMissingAppPlaceholder error child=00000000-0000-4000-8000-000000000122 detail=-
        """,

        // isExecutable=false 但 executableStepIDs 非空 —— 徽章阶梯读的是后者，
        // 所以第②步不能把阶梯建在 scriptBacked.isEmpty 上。
        "compositeBlankName": """
        EXEC false
        ISSUE blankCompositeName error child=- detail=-
        """,

        "compositeNoSteps": """
        EXEC false
        ISSUE noSteps error child=- detail=-
        """,

        "newFileValid": """
        EXEC true
        SB 00000000-0000-4000-8000-000000000201.00000000-0000-4000-8000-000000000211 newFileTemplate txt parent=新建 fp=2df5e9d9709b3499 target=containingDirectory steps=[]
        SB 00000000-0000-4000-8000-000000000201.00000000-0000-4000-8000-000000000212 newFileTemplate md parent=新建 fp=2e7bb29859c2b338 target=containingDirectory steps=[]
        """,

        "newFileMissingTemplateFile": """
        EXEC true
        SB 00000000-0000-4000-8000-000000000202.00000000-0000-4000-8000-000000000221 newFileTemplate docx parent=复制模板 fp=ed3fcc2c873388dc target=containingDirectory steps=[]
        """,

        "newFileDuplicateNames": """
        EXEC false
        ISSUE duplicateTemplateName error child=00000000-0000-4000-8000-000000000231 detail=same
        ISSUE duplicateTemplateName error child=00000000-0000-4000-8000-000000000232 detail=same
        """,

        "newFileNoTemplates": """
        EXEC false
        ISSUE noTemplates error child=- detail=-
        """,

        "builtInEnabled": """
        EXEC true
        """,

        "builtInDisabled": """
        EXEC false
        """,
    ]
}
