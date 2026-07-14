import Foundation
import Testing
@testable import RCMMShared

@Suite("ApplicationIconStore tests", .serialized)
struct ApplicationIconStoreTests {
    @Test("图标快照可被另一个进程等价的 store 实例读取")
    func iconSnapshotsRoundTripAcrossStoreInstances() {
        let suiteName = "application.icon.store.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let entryID = "11111111-1111-1111-1111-111111111111"
        let iconData = Data("png-data".utf8)

        ApplicationIconStore(defaults: defaults).saveIcons([entryID: iconData])

        let reloadedIcons = ApplicationIconStore(defaults: defaults).loadIcons()
        #expect(reloadedIcons == [entryID: iconData])
    }
}
