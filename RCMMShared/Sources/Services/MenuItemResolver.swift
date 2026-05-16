import Foundation

public enum MenuItemResolver: Sendable {
    public static func customItem(
        in items: [MenuItemConfig],
        representedObject: Any?,
        tag: Int,
        title: String
    ) -> MenuItemConfig? {
        if let itemID = representedObject as? String,
           let item = item(withID: itemID, in: items) {
            return item
        }

        if let appName = appName(fromMenuTitle: title) {
            let titleMatchedItem = items.first { $0.appName == appName }

            if tag >= 0, tag < items.count, items[tag].appName != appName {
                return titleMatchedItem
            }

            if let titleMatchedItem {
                return titleMatchedItem
            }
        }

        if tag >= 0, tag < items.count {
            return items[tag]
        }

        return nil
    }

    public static func appName(fromMenuTitle title: String) -> String? {
        let prefix = "用 "
        let suffix = " 打开"

        guard title.hasPrefix(prefix), title.hasSuffix(suffix) else {
            return nil
        }

        let start = title.index(title.startIndex, offsetBy: prefix.count)
        let end = title.index(title.endIndex, offsetBy: -suffix.count)
        guard start < end else {
            return nil
        }

        return String(title[start..<end])
    }

    private static func item(
        withID itemID: String,
        in items: [MenuItemConfig]
    ) -> MenuItemConfig? {
        items.first { $0.id.uuidString == itemID }
    }
}
