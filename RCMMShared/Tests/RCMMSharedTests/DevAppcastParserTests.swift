import Foundation
import Testing
@testable import RCMMShared

@Suite("DevAppcastParser 测试")
struct DevAppcastParserTests {

    @Test("从 appcast 中选择最新的开发版条目")
    func parseLatestItem() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <item>
              <title>Version 1.2.3-dev.4</title>
              <sparkle:releaseNotesLink>https://github.com/sunven/rcmm/releases/tag/v1.2.3-dev.4</sparkle:releaseNotesLink>
              <enclosure
                url="https://github.com/sunven/rcmm/releases/download/v1.2.3-dev.4/rcmm-dev-1.2.3-dev.4.zip"
                sparkle:version="1.2.3.4"
                sparkle:shortVersionString="1.2.3-dev.4"
                length="12345"
                type="application/octet-stream"
                sparkle:edSignature="sig-4" />
            </item>
            <item>
              <title>Version 1.2.3-dev.10</title>
              <sparkle:releaseNotesLink>https://github.com/sunven/rcmm/releases/tag/v1.2.3-dev.10</sparkle:releaseNotesLink>
              <enclosure
                url="https://github.com/sunven/rcmm/releases/download/v1.2.3-dev.10/rcmm-dev-1.2.3-dev.10.zip"
                sparkle:version="1.2.3.10"
                sparkle:shortVersionString="1.2.3-dev.10"
                length="67890"
                type="application/octet-stream"
                sparkle:edSignature="sig-10" />
            </item>
          </channel>
        </rss>
        """

        let item = try DevAppcastParser.latestItem(from: Data(xml.utf8))

        #expect(item.version.displayVersion == "1.2.3-dev.10")
        #expect(item.archiveURL.absoluteString.contains("1.2.3-dev.10.zip"))
        #expect(item.releaseNotesURL?.absoluteString.contains("v1.2.3-dev.10") == true)
    }
}
