import Foundation

public enum FinderMenuSelection: Sendable {
    public static func reconciledSelection(
        currentID: String?,
        entries: [MenuEntry],
        preferredID: String? = nil,
        deletedIndex: Int? = nil
    ) -> String? {
        let ids = entries.map(\.id)
        let idSet = Set(ids)

        if let currentID, idSet.contains(currentID) {
            return currentID
        }

        if let preferredID, idSet.contains(preferredID) {
            return preferredID
        }

        if let deletedIndex, !ids.isEmpty {
            if ids.indices.contains(deletedIndex) {
                return ids[deletedIndex]
            }

            let previousIndex = deletedIndex - 1
            if ids.indices.contains(previousIndex) {
                return ids[previousIndex]
            }
        }

        return ids.first
    }
}
