import Foundation
import Testing
@testable import RCMMShared

@Suite("MenuPresentationMode 测试")
struct MenuPresentationModeTests {

    @Test("flat 是平铺展示")
    func flatDisplayName() {
        #expect(MenuPresentationMode.flat.rawValue == "flat")
        #expect(MenuPresentationMode.flat.displayName == "平铺")
    }

    @Test("nestedUnderRCMM 是收进 RCMM")
    func nestedDisplayName() {
        #expect(MenuPresentationMode.nestedUnderRCMM.rawValue == "nestedUnderRCMM")
        #expect(MenuPresentationMode.nestedUnderRCMM.displayName == "收进 RCMM")
    }

    @Test("Round-trip 编解码保持值一致")
    func roundTrip() throws {
        let data = try JSONEncoder().encode(MenuPresentationMode.nestedUnderRCMM)
        let decoded = try JSONDecoder().decode(MenuPresentationMode.self, from: data)
        #expect(decoded == .nestedUnderRCMM)
    }
}
