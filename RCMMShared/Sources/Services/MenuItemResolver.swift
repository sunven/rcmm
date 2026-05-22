import Foundation

public enum MenuItemResolver: Sendable {
    public static func scriptBackedEntry(
        in scriptBackedEntries: [ScriptBackedMenuEntry],
        customItems: [MenuItemConfig],
        representedObject: Any?,
        identifier: String?,
        tag: Int,
        title: String,
        parentMenuTitle: String? = nil
    ) -> ScriptBackedMenuEntry? {
        if let titleMatchedEntry = uniqueScriptBackedEntry(
            in: scriptBackedEntries,
            title: title,
            parentMenuTitle: parentMenuTitle
        ) {
            return titleMatchedEntry
        }

        if let representedID = representedObject as? String,
           let match = scriptBackedEntries.first(where: { $0.id == representedID }) {
            return match
        }

        if let identifier,
           let match = scriptBackedEntries.first(where: { $0.id == identifier }) {
            return match
        }

        if let customItem = customItem(
            in: customItems,
            representedObject: representedObject,
            tag: tag,
            title: title
        ) {
            return scriptBackedEntries.first { $0.id == customItem.id.uuidString }
        }

        return nil
    }

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

        guard let appName = appName(fromMenuTitle: title) else {
            return nil
        }

        let titleMatchedItem = items.first { $0.appName == appName }

        if tag >= 0, tag < items.count, items[tag].appName != appName {
            return titleMatchedItem
        }

        if let titleMatchedItem {
            return titleMatchedItem
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

    private static func uniqueScriptBackedEntry(
        in entries: [ScriptBackedMenuEntry],
        title: String,
        parentMenuTitle: String?
    ) -> ScriptBackedMenuEntry? {
        let matches = entries.filter { entry in
            switch entry.kind {
            case .custom:
                return appName(fromMenuTitle: title) == entry.displayName
            case .composite:
                return title == entry.displayName
            case .newFileTemplate:
                guard title == entry.displayName else { return false }
                if let parentMenuTitle {
                    return entry.parentDisplayName == parentMenuTitle
                }
                return true
            }
        }

        guard matches.count == 1 else {
            return nil
        }

        return matches[0]
    }
}
