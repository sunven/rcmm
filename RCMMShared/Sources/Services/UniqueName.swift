import Foundation

/// 配置内的唯一名称：去空白、空值回退，冲突时追加从 2 开始的序号。
public enum UniqueName {
    public static func make(
        preferredName: String,
        fallbackName: String,
        existingNames: Set<String>
    ) -> String {
        let trimmedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedName.isEmpty ? fallbackName : trimmedName

        guard existingNames.contains(baseName) else {
            return baseName
        }

        var suffix = 2
        while existingNames.contains("\(baseName) \(suffix)") {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
    }
}
