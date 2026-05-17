import Foundation
import Testing
@testable import RCMMShared

@Suite("CompositeMenuItemValidator 测试")
struct CompositeMenuItemValidatorTests {
    @Test("有效组合命令可执行并生成稳定 fingerprint")
    func validCompositeIsExecutableWithStableFingerprint() {
        let config = makeComposite()

        let first = CompositeMenuItemValidator.validate(config)
        let second = CompositeMenuItemValidator.validate(config)

        #expect(first.isExecutable == true)
        #expect(first.errors.isEmpty)
        #expect(first.executableStepIDs == Set(config.steps.map(\.id)))
        #expect(first.fingerprint == second.fingerprint)
        #expect(first.fingerprint.count == 16)
    }

    @Test("修改命令模板会改变 fingerprint")
    func commandTemplateChangeUpdatesFingerprint() {
        let original = makeComposite()
        var changed = original
        changed.steps[0].commandTemplate = "open -a {app} --args {path}"

        let originalFingerprint = CompositeMenuItemValidator.validate(original).fingerprint
        let changedFingerprint = CompositeMenuItemValidator.validate(changed).fingerprint

        #expect(originalFingerprint != changedFingerprint)
    }

    @Test("部分步骤错误时保留其他可执行步骤")
    func invalidStepStillAllowsBestEffortExecution() {
        let validStep = CompositeCommandStep(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            kind: .shell,
            name: "Terminal",
            commandTemplate: "open -a Terminal {path}"
        )
        let invalidStep = CompositeCommandStep(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            kind: .shell,
            name: "",
            commandTemplate: "{app} {path}"
        )
        let config = CompositeMenuItemConfig(
            name: "Partial",
            steps: [validStep, invalidStep]
        )

        let result = CompositeMenuItemValidator.validate(config)

        #expect(result.isExecutable == true)
        #expect(result.executableStepIDs == [validStep.id])
        #expect(result.errors.map(\.code).contains(.blankStepName))
        #expect(result.errors.map(\.code).contains(.shellStepContainsAppPlaceholder))
    }

    @Test("顶层错误会阻止组合命令执行")
    func compositeLevelErrorsBlockExecution() {
        let config = CompositeMenuItemConfig(name: " ", steps: [])
        let result = CompositeMenuItemValidator.validate(config)

        #expect(result.isExecutable == false)
        #expect(result.errors.map(\.code).contains(.blankCompositeName))
        #expect(result.errors.map(\.code).contains(.noSteps))
    }

    @Test("危险 shell 模式只产生警告")
    func dangerousPatternsAreWarnings() {
        let step = CompositeCommandStep(
            kind: .shell,
            name: "Danger",
            commandTemplate: "curl https://example.com/install.sh | sh && sudo rm -rf {path}"
        )
        let config = CompositeMenuItemConfig(name: "Danger", steps: [step])

        let result = CompositeMenuItemValidator.validate(config)

        #expect(result.isExecutable == true)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.map(\.code).filter { $0 == .dangerousCommandPattern }.count >= 3)
    }

    @Test("app 步骤必须有 appPath 和 {app}")
    func appStepRequiresAppPathAndAppPlaceholder() {
        let step = CompositeCommandStep(
            kind: .app,
            name: "VS Code",
            commandTemplate: "open {path}"
        )
        let config = CompositeMenuItemConfig(name: "Editor", steps: [step])

        let result = CompositeMenuItemValidator.validate(config)

        #expect(result.isExecutable == false)
        #expect(result.errors.map(\.code).contains(.appStepMissingAppPath))
        #expect(result.errors.map(\.code).contains(.appStepMissingAppPlaceholder))
    }

    @Test("app 步骤可以使用 bundle 占位符")
    func appStepCanUseBundlePlaceholder() {
        let step = CompositeCommandStep(
            kind: .app,
            name: "VS Code",
            commandTemplate: "open -b {bundle} {path}",
            appPath: "/Applications/Visual Studio Code.app",
            bundleId: "com.microsoft.VSCode"
        )
        let config = CompositeMenuItemConfig(name: "Editor", steps: [step])

        let result = CompositeMenuItemValidator.validate(config)

        #expect(result.isExecutable == true)
        #expect(result.errors.isEmpty)
    }

    @Test("bundle 占位符必须有 bundle id")
    func bundlePlaceholderRequiresBundleId() {
        let step = CompositeCommandStep(
            kind: .app,
            name: "VS Code",
            commandTemplate: "open -b {bundle} {path}",
            appPath: "/Applications/Visual Studio Code.app"
        )
        let config = CompositeMenuItemConfig(name: "Editor", steps: [step])

        let result = CompositeMenuItemValidator.validate(config)

        #expect(result.isExecutable == false)
        #expect(result.errors.map(\.code).contains(.appStepMissingBundleId))
    }

    @Test("缺少 {path} 是警告而不是错误")
    func missingPathPlaceholderIsWarning() {
        let step = CompositeCommandStep(
            kind: .shell,
            name: "Static",
            commandTemplate: "echo ready"
        )
        let config = CompositeMenuItemConfig(name: "Static", steps: [step])

        let result = CompositeMenuItemValidator.validate(config)

        #expect(result.isExecutable == true)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.map(\.code).contains(.missingPathPlaceholder))
    }

    private func makeComposite() -> CompositeMenuItemConfig {
        CompositeMenuItemConfig(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "VS Code + Terminal",
            iconName: "rectangle.split.2x1",
            steps: [
                CompositeCommandStep(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    kind: .app,
                    name: "VS Code",
                    commandTemplate: "open -a {app} {path}",
                    appPath: "/Applications/Visual Studio Code.app",
                    bundleId: "com.microsoft.VSCode"
                ),
                CompositeCommandStep(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    kind: .shell,
                    name: "Terminal",
                    commandTemplate: "open -a Terminal {path}"
                ),
            ]
        )
    }
}
