import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    override init() {
        super.init()
        // Set up the directory URLs that this extension provides
        let finderSync = FIFinderSyncController.default()
        finderSync.directoryURLs = [URL(fileURLWithPath: "/")]
    }

    // MARK: - Menu and Toolbar Item

    override var toolbarItemName: String {
        return "rcmm"
    }

    override var toolbarItemToolTip: String {
        return "rcmm Finder Extension"
    }

    override var toolbarItemImage: NSImage {
        return NSImage(systemSymbolName: "contextualmenu.and.cursorarrow", accessibilityDescription: "rcmm")!
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        menu.addItem(withTitle: "rcmm Action", action: #selector(rcmmAction(_:)), keyEquivalent: "")
        return menu
    }

    @IBAction func rcmmAction(_ sender: AnyObject?) {
        // Placeholder action
    }
}
