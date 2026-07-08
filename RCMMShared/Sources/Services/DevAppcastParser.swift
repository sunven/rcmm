import Foundation

public enum DevAppcastParserError: Error {
    case invalidXML
    case noUsableItems
}

public enum DevAppcastParser {
    public static func latestItem(from data: Data) throws -> DevAppcastItem {
        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else { throw DevAppcastParserError.invalidXML }
        guard let latest = delegate.items.max(by: { $0.version < $1.version }) else {
            throw DevAppcastParserError.noUsableItems
        }
        return latest
    }
}

private final class ParserDelegate: NSObject, XMLParserDelegate {
    private var currentItem: PendingItem?
    private var currentValue = ""
    private var currentLinkKind: ReleaseNotesLinkKind?

    var items: [DevAppcastItem] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        if elementName == "item" {
            currentItem = PendingItem()
        }

        if let linkKind = releaseNotesLinkKind(elementName: elementName, qualifiedName: qName) {
            currentLinkKind = linkKind
            currentValue = ""
        }

        guard elementName == "enclosure" else { return }
        guard currentItem != nil else { return }

        guard
            let urlString = attributeDict["url"],
            let url = URL(string: urlString),
            let bundleVersion = attributeDict["sparkle:version"],
            let version = DevBuildVersion.parse(bundleVersion: bundleVersion),
            let lengthString = attributeDict["length"],
            let length = Int(lengthString),
            let signature = attributeDict["sparkle:edSignature"]
        else { return }

        currentItem?.version = version
        currentItem?.displayVersion = attributeDict["sparkle:shortVersionString"]
        currentItem?.archiveURL = url
        currentItem?.archiveLength = length
        currentItem?.signature = signature
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard currentLinkKind != nil else { return }
        currentValue += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if let linkKind = releaseNotesLinkKind(elementName: elementName, qualifiedName: qName) {
            let releaseNotesValue = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
            switch linkKind {
            case .releaseNotes:
                currentItem?.releaseNotesURL = URL(string: releaseNotesValue)
            case .fullReleaseNotes:
                currentItem?.fullReleaseNotesURL = URL(string: releaseNotesValue)
            }
            currentLinkKind = nil
            currentValue = ""
            return
        }

        guard elementName == "item" else { return }
        defer { currentItem = nil }

        guard let item = currentItem?.build() else { return }
        items.append(item)
    }

    private func releaseNotesLinkKind(
        elementName: String,
        qualifiedName: String?
    ) -> ReleaseNotesLinkKind? {
        if qualifiedName == "sparkle:releaseNotesLink"
            || elementName == "releaseNotesLink"
            || elementName == "sparkle:releaseNotesLink" {
            return .releaseNotes
        }

        if qualifiedName == "sparkle:fullReleaseNotesLink"
            || elementName == "fullReleaseNotesLink"
            || elementName == "sparkle:fullReleaseNotesLink" {
            return .fullReleaseNotes
        }

        return nil
    }
}

private enum ReleaseNotesLinkKind {
    case releaseNotes
    case fullReleaseNotes
}

private struct PendingItem {
    var version: DevBuildVersion?
    var displayVersion: String?
    var archiveURL: URL?
    var releaseNotesURL: URL?
    var fullReleaseNotesURL: URL?
    var archiveLength: Int?
    var signature: String?

    func build() -> DevAppcastItem? {
        guard
            let version,
            let archiveURL,
            let archiveLength,
            let signature
        else { return nil }

        return DevAppcastItem(
            version: version,
            displayVersion: displayVersion,
            archiveURL: archiveURL,
            releaseNotesURL: releaseNotesURL ?? fullReleaseNotesURL,
            archiveLength: archiveLength,
            signature: signature
        )
    }
}
