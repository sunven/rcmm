import Foundation
import Testing
@testable import rcmm

@Suite("AppBundleUpdateInfo tests")
struct AppBundleUpdateInfoTests {
    @Test("disabled updates do not require a feed URL")
    func disabledUpdatesDoNotRequireFeedURL() throws {
        let bundle = makeBundle(info: [
            "CFBundleVersion": "1.2.3.0",
            "RCMMDisplayVersion": "1.2.3",
            "RCMMUpdatesEnabled": "NO",
            "SUFeedURL": "",
            "RCMMReleasePageURL": "https://github.com/sunven/rcmm/releases"
        ])

        let info = try AppBundleUpdateInfo.current(bundle: bundle)

        #expect(!info.updatesEnabled)
        #expect(info.feedURL == nil)
        #expect(info.displayVersion == "1.2.3")
    }

    @Test("enabled updates require a feed URL")
    func enabledUpdatesRequireFeedURL() throws {
        let bundle = makeBundle(info: [
            "CFBundleVersion": "1.2.3.4",
            "RCMMDisplayVersion": "1.2.3-dev.4",
            "RCMMUpdatesEnabled": "YES",
            "SUFeedURL": "",
            "RCMMReleasePageURL": "https://github.com/sunven/rcmm/releases"
        ])

        do {
            _ = try AppBundleUpdateInfo.current(bundle: bundle)
            Issue.record("Expected missing SUFeedURL error")
        } catch AppBundleUpdateInfoError.missingValue(let key) {
            #expect(key == "SUFeedURL")
        }
    }

    private func makeBundle(info: [String: String]) -> Bundle {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        let contents = root.appendingPathComponent("Contents", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: contents,
            withIntermediateDirectories: true
        )
        let infoURL = contents.appendingPathComponent("Info.plist")
        let plist = NSMutableDictionary(dictionary: info)
        plist["CFBundleIdentifier"] = info["CFBundleIdentifier"] ?? UUID().uuidString
        plist["CFBundleExecutable"] = "TestBundle"
        plist.write(to: infoURL, atomically: true)
        return Bundle(url: root) ?? .main
    }
}
