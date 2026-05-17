import Foundation
import Testing
@testable import RCMMShared

@Suite("CompositeMenuItemConfig 测试")
struct CompositeMenuItemConfigTests {
    @Test("CompositeCommandStep 解码缺失 isEnabled 时默认启用")
    func commandStepDecodesMissingEnabledAsTrue() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "kind": "shell",
          "name": "Terminal",
          "commandTemplate": "open -a Terminal {path}"
        }
        """

        let step = try JSONDecoder().decode(
            CompositeCommandStep.self,
            from: Data(json.utf8)
        )

        #expect(step.isEnabled == true)
        #expect(step.appPath == nil)
        #expect(step.bundleId == nil)
    }

    @Test("CompositeMenuItemConfig 解码缺失可选字段时使用安全默认值")
    func compositeConfigDecodesMissingOptionalFields() throws {
        let json = """
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "name": "VS Code + Terminal"
        }
        """

        let config = try JSONDecoder().decode(
            CompositeMenuItemConfig.self,
            from: Data(json.utf8)
        )

        #expect(config.iconName == nil)
        #expect(config.steps.isEmpty)
        #expect(config.isEnabled == true)
    }

    @Test("CompositeMenuItemConfig round-trip 保持步骤顺序")
    func compositeRoundTripPreservesStepOrder() throws {
        let steps = [
            CompositeCommandStep(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                kind: .app,
                name: "VS Code",
                commandTemplate: "open -a {app} {path}",
                appPath: "/Applications/Visual Studio Code.app",
                bundleId: "com.microsoft.VSCode"
            ),
            CompositeCommandStep(
                id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                kind: .shell,
                name: "Terminal",
                commandTemplate: "open -a Terminal {path}",
                isEnabled: false
            ),
        ]
        let config = CompositeMenuItemConfig(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "VS Code + Terminal",
            iconName: "rectangle.split.2x1",
            steps: steps
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(CompositeMenuItemConfig.self, from: data)

        #expect(decoded == config)
        #expect(decoded.steps.map(\.id) == steps.map(\.id))
    }
}
