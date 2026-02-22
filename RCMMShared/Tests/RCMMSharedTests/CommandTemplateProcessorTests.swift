import Foundation
import Testing
@testable import RCMMShared

@Suite("CommandTemplateProcessor 测试")
struct CommandTemplateProcessorTests {

    // MARK: - Task 4.4: customCommand 包含 {app} 和 {path} 的占位符替换

    @Test("同时包含 {app} 和 {path} 的自定义命令")
    func customCommandWithAppAndPath() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "{app} --directory {path}",
            appPath: "/Applications/kitty.app/Contents/MacOS/kitty"
        )
        #expect(result == "do shell script \"/Applications/kitty.app/Contents/MacOS/kitty --directory \" & quoted form of thePath")
    }

    @Test("{app} 替换为包含空格的路径")
    func customCommandWithSpacesInAppPath() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "{app} --working-directory {path}",
            appPath: "/Applications/My App.app/Contents/MacOS/myapp"
        )
        #expect(result == "do shell script \"/Applications/My App.app/Contents/MacOS/myapp --working-directory \" & quoted form of thePath")
    }

    @Test("{app} 替换为包含双引号和反斜杠的路径")
    func customCommandWithSpecialCharsInAppPath() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "{app} --open {path}",
            appPath: "/Applications/My \"App\".app/Contents/MacOS/test\\bin"
        )
        #expect(result == "do shell script \"/Applications/My \\\"App\\\".app/Contents/MacOS/test\\\\bin --open \" & quoted form of thePath")
    }

    // MARK: - Task 4.5: customCommand 仅包含 {path} 的占位符替换

    @Test("仅包含 {path} 的自定义命令")
    func customCommandWithPathOnly() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "/usr/local/bin/code {path}",
            appPath: "/Applications/Visual Studio Code.app"
        )
        #expect(result == "do shell script \"/usr/local/bin/code \" & quoted form of thePath")
    }

    @Test("{path} 在命令中间位置")
    func customCommandWithPathInMiddle() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "/usr/bin/open {path} --new-window",
            appPath: "/Applications/Test.app"
        )
        #expect(result == "do shell script \"/usr/bin/open \" & quoted form of thePath & \" --new-window\"")
    }

    // MARK: - Task 4.6: customCommand 不包含任何占位符的静态命令

    @Test("不包含任何占位符的静态命令")
    func customCommandWithNoPlaceholders() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "/usr/bin/open -a Terminal",
            appPath: "/Applications/Terminal.app"
        )
        #expect(result == "do shell script \"/usr/bin/open -a Terminal\"")
    }

    @Test("静态命令中包含需要转义的双引号")
    func customCommandWithQuotes() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "/usr/bin/open -a \"My App\"",
            appPath: "/Applications/MyApp.app"
        )
        #expect(result == "do shell script \"/usr/bin/open -a \\\"My App\\\"\"")
    }

    // MARK: - escapeForAppleScript 测试

    @Test("转义反斜杠")
    func escapeBackslash() {
        let result = CommandTemplateProcessor.escapeForAppleScript("path\\to\\file")
        #expect(result == "path\\\\to\\\\file")
    }

    @Test("转义双引号")
    func escapeDoubleQuotes() {
        let result = CommandTemplateProcessor.escapeForAppleScript("say \"hello\"")
        #expect(result == "say \\\"hello\\\"")
    }

    @Test("无需转义的字符串保持不变")
    func noEscapeNeeded() {
        let result = CommandTemplateProcessor.escapeForAppleScript("/usr/bin/open -a Terminal")
        #expect(result == "/usr/bin/open -a Terminal")
    }
}
