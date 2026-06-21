import Foundation

extension String {
    /// 去除首尾空白后返回；若结果为空则返回 nil。
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
