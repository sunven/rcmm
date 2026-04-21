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
    private var currentReleaseNotesURL: URL?
    private var currentValue = ""
    private var insideReleaseNotesLink = false

    var items: [DevAppcastItem] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        if isReleaseNotesLink(elementName: elementName, qualifiedName: qName) {
            insideReleaseNotesLink = true
            currentValue = ""
        }

        guard elementName == "enclosure" else { return }

        guard
            let urlString = attributeDict["url"],
            let url = URL(string: urlString),
            let bundleVersion = attributeDict["sparkle:version"],
            let version = DevBuildVersion.parse(bundleVersion: bundleVersion),
            let lengthString = attributeDict["length"],
            let length = Int(lengthString),
            let signature = attributeDict["sparkle:edSignature"]
        else { return }

        items.append(
            DevAppcastItem(
                version: version,
                archiveURL: url,
                releaseNotesURL: currentReleaseNotesURL,
                archiveLength: length,
                signature: signature
            )
        )
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideReleaseNotesLink else { return }
        currentValue += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard isReleaseNotesLink(elementName: elementName, qualifiedName: qName) else { return }
        insideReleaseNotesLink = false
        currentReleaseNotesURL = URL(string: currentValue.trimmingCharacters(in: .whitespacesAndNewlines))
        currentValue = ""
    }

    private func isReleaseNotesLink(elementName: String, qualifiedName: String?) -> Bool {
        qualifiedName == "sparkle:releaseNotesLink"
            || elementName == "releaseNotesLink"
            || elementName == "sparkle:releaseNotesLink"
    }
}
