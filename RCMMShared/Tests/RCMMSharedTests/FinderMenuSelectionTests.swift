import Foundation
import Testing
@testable import RCMMShared

@Suite("FinderMenuSelection 测试")
struct FinderMenuSelectionTests {
    @Test("空选择默认选中第一项")
    func nilSelectionDefaultsToFirstEntry() {
        let entries = makeEntries()

        let selectedID = FinderMenuSelection.reconciledSelection(
            currentID: nil,
            entries: entries
        )

        #expect(selectedID == entries[0].id)
    }

    @Test("有效选择保持不变")
    func validSelectionIsPreserved() {
        let entries = makeEntries()

        let selectedID = FinderMenuSelection.reconciledSelection(
            currentID: entries[1].id,
            entries: entries
        )

        #expect(selectedID == entries[1].id)
    }

    @Test("preferredID 有效时优先选择")
    func preferredIDIsUsedWhenCurrentSelectionIsInvalid() {
        let entries = makeEntries()

        let selectedID = FinderMenuSelection.reconciledSelection(
            currentID: "missing",
            entries: entries,
            preferredID: entries[2].id
        )

        #expect(selectedID == entries[2].id)
    }

    @Test("删除选中项后优先选择同 index 的下一项")
    func deletedSelectionPrefersNextEntry() {
        let original = makeEntries()
        let remaining = [original[0], original[2]]

        let selectedID = FinderMenuSelection.reconciledSelection(
            currentID: original[1].id,
            entries: remaining,
            deletedIndex: 1
        )

        #expect(selectedID == original[2].id)
    }

    @Test("删除最后一项后选择前一项")
    func deletedLastSelectionFallsBackToPreviousEntry() {
        let original = makeEntries()
        let remaining = [original[0], original[1]]

        let selectedID = FinderMenuSelection.reconciledSelection(
            currentID: original[2].id,
            entries: remaining,
            deletedIndex: 2
        )

        #expect(selectedID == original[1].id)
    }

    @Test("列表为空时选择为空")
    func emptyEntriesReturnNil() {
        let selectedID = FinderMenuSelection.reconciledSelection(
            currentID: "missing",
            entries: []
        )

        #expect(selectedID == nil)
    }

    private func makeEntries() -> [MenuEntry] {
        [
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
            .custom(
                MenuItemConfig(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    appName: "Terminal",
                    bundleId: "com.apple.Terminal",
                    appPath: "/System/Applications/Utilities/Terminal.app"
                )
            ),
            .composite(
                CompositeMenuItemConfig(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    name: "Editor",
                    steps: []
                )
            ),
        ]
    }
}
