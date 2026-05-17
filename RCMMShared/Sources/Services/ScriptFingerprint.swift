import Foundation

public enum ScriptFingerprint: Sendable {
    public static func make(fields: [String]) -> String {
        let canonical = fields
            .map { "\($0.utf8.count):\($0)" }
            .joined(separator: "|")
        return fnv1a64Hex(canonical)
    }

    private static func fnv1a64Hex(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}
