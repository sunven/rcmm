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

    @Test("多个 {path} 占位符全部保留")
    func customCommandWithMultiplePathPlaceholders() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "/bin/cp {path} {path}.bak",
            appPath: "/Applications/Test.app"
        )
        #expect(result == "do shell script \"/bin/cp \" & quoted form of thePath & \" \" & quoted form of thePath & \".bak\"")
    }

    @Test("{path} 可出现在命令开头")
    func customCommandWithPathAtBeginning() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "{path} --flag",
            appPath: "/Applications/Test.app"
        )
        #expect(result == "do shell script quoted form of thePath & \" --flag\"")
    }

    @Test("连续 {path} 占位符不会丢失")
    func customCommandWithAdjacentPathPlaceholders() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "{path}{path}",
            appPath: "/Applications/Test.app"
        )
        #expect(result == "do shell script quoted form of thePath & quoted form of thePath")
    }

    @Test("app 占位符可生成 shell 安全引用")
    func appPlaceholderCanBeShellQuoted() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "open -a {app} {path}",
            appPath: "/Applications/Visual Studio Code.app",
            quoteAppPlaceholder: true
        )
        #expect(result == "do shell script \"open -a \" & quoted form of \"/Applications/Visual Studio Code.app\" & \" \" & quoted form of thePath")
    }

    @Test("app 和 path 占位符可多次安全引用")
    func appAndPathPlaceholdersCanRepeatWhenShellQuoted() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "{app} --open {path} --reuse {app}",
            appPath: "/Applications/My \"App\".app",
            quoteAppPlaceholder: true
        )
        #expect(result == "do shell script quoted form of \"/Applications/My \\\"App\\\".app\" & \" --open \" & quoted form of thePath & \" --reuse \" & quoted form of \"/Applications/My \\\"App\\\".app\"")
    }

    @Test("app 占位符后接路径片段时保持 shell 安全引用")
    func appPlaceholderCanBeQuotedBeforePathSuffix() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "{app}/Contents/Resources/app/bin/code -n {path}",
            appPath: "/Applications/Visual Studio Code.app",
            quoteAppPlaceholder: true
        )
        #expect(result == "do shell script quoted form of \"/Applications/Visual Studio Code.app\" & \"/Contents/Resources/app/bin/code -n \" & quoted form of thePath")
    }

    @Test("bundle 占位符可生成 shell 安全引用")
    func bundlePlaceholderCanBeShellQuoted() {
        let result = CommandTemplateProcessor.buildAppleScriptCommand(
            template: "open -b {bundle} {path}",
            appPath: "/Applications/Visual Studio Code.app",
            bundleId: "com.microsoft.VSCode",
            quoteAppPlaceholder: true
        )
        #expect(result == "do shell script \"open -b \" & quoted form of \"com.microsoft.VSCode\" & \" \" & quoted form of thePath")
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
