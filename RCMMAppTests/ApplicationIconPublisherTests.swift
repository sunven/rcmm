import AppKit
import Foundation
import RCMMShared
import Testing
@testable import rcmm

@Suite("ApplicationIconPublisher tests", .serialized)
struct ApplicationIconPublisherTests {
    @Test("发布应用菜单项的图标快照")
    func publishesApplicationIconSnapshot() {
        let suiteName = "application.icon.publisher.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let entryID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let iconData = Data("code-icon".utf8)
        let iconStore = ApplicationIconStore(defaults: defaults)
        let publisher = ApplicationIconPublisher(
            iconStore: iconStore,
            loadIconData: { path in
                path == "/Applications/Visual Studio Code.app" ? iconData : nil
            }
        )
        let entry = MenuEntry.custom(MenuItemConfig(
            id: entryID,
            appName: "Code",
            appPath: "/Applications/Visual Studio Code.app"
        ))

        publisher.publishIcons(for: [entry])

        #expect(iconStore.loadIcons() == [entryID.uuidString: iconData])
    }

    @Test("生产发布器生成 Finder 可解码的 PNG 图标")
    func productionPublisherCreatesDecodablePNG() throws {
        let suiteName = "application.icon.publisher.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let appPath = "/System/Applications/Utilities/Terminal.app"
        #expect(FileManager.default.fileExists(atPath: appPath))

        let entryID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let iconStore = ApplicationIconStore(defaults: defaults)
        let publisher = ApplicationIconPublisher(iconStore: iconStore)
        let entry = MenuEntry.custom(MenuItemConfig(
            id: entryID,
            appName: "Terminal",
            appPath: appPath
        ))

        publisher.publishIcons(for: [entry])

        let iconData = try #require(iconStore.loadIcons()[entryID.uuidString])
        #expect(NSImage(data: iconData) != nil)
        let bitmap = try #require(NSBitmapImageRep(data: iconData))
        #expect(bitmap.pixelsWide == 32)
        #expect(bitmap.pixelsHigh == 32)
    }
}
