import Foundation
import Testing
@testable import RCMMShared

@Suite("MenuEntryEnvelope 测试")
struct MenuEntryEnvelopeTests {
    @Test("Envelope round-trip known composite")
    func knownCompositeRoundTrip() throws {
        let config = CompositeMenuItemConfig(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "VS Code + Terminal",
            steps: [
                CompositeCommandStep(
                    kind: .shell,
                    name: "Terminal",
                    commandTemplate: "open -a Terminal {path}"
                ),
            ]
        )
        let envelope = MenuEntryEnvelope(entry: .composite(config))

        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(MenuEntryEnvelope.self, from: data)

        #expect(decoded == envelope)
        #expect(decoded.entry == .composite(config))
        #expect(decoded.type == "composite")
    }

    @Test("Envelope 保留未知类型 payload")
    func unknownEnvelopePreservesPayload() throws {
        let json = """
        {
          "type": "future",
          "payload": {
            "id": "future-id",
            "nested": { "enabled": true },
            "items": [1, "two", null]
          }
        }
        """

        let envelope = try JSONDecoder().decode(MenuEntryEnvelope.self, from: Data(json.utf8))
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(MenuEntryEnvelope.self, from: data)

        #expect(decoded == envelope)
        #expect(decoded.entry == nil)
        #expect(decoded.type == "future")
    }

    @Test("Envelope 可读取旧 enum 编码格式")
    func envelopeDecodesLegacyMenuEntryShape() throws {
        let entry = MenuEntry.custom(
            MenuItemConfig(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                appName: "Terminal",
                appPath: "/Applications/Utilities/Terminal.app"
            )
        )
        let data = try JSONEncoder().encode(entry)
        let envelope = try JSONDecoder().decode(MenuEntryEnvelope.self, from: data)

        #expect(envelope.entry == entry)
        #expect(envelope.type == "custom")
    }
}
