import Foundation

public struct DevBuildVersion: Comparable, Hashable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let build: Int

    public var shortVersion: String {
        "\(major).\(minor).\(patch)"
    }

    public var bundleVersion: String {
        "\(major).\(minor).\(patch).\(build)"
    }

    public var displayVersion: String {
        build == 0 ? "\(shortVersion)-dev" : "\(shortVersion)-dev.\(build)"
    }

    public init(major: Int, minor: Int, patch: Int, build: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.build = build
    }

    public static func parse(displayVersion value: String) -> Self? {
        let pattern = #"^([0-9]+)\.([0-9]+)\.([0-9]+)-dev(?:\.([0-9]+))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range) else { return nil }

        func component(_ index: Int, default fallback: Int = 0) -> Int? {
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: value) else {
                return fallback
            }
            return Int(value[swiftRange])
        }

        guard
            let major = component(1),
            let minor = component(2),
            let patch = component(3),
            let build = component(4, default: 0)
        else { return nil }

        return Self(major: major, minor: minor, patch: patch, build: build)
    }

    public static func parse(bundleVersion value: String) -> Self? {
        let parts = value.split(separator: ".")
        guard parts.count == 4 else { return nil }
        guard
            let major = Int(parts[0]),
            let minor = Int(parts[1]),
            let patch = Int(parts[2]),
            let build = Int(parts[3])
        else { return nil }
        return Self(major: major, minor: minor, patch: patch, build: build)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch, lhs.build) < (rhs.major, rhs.minor, rhs.patch, rhs.build)
    }
}
