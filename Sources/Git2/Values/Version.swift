import Cgit2

public struct Version: Sendable, Equatable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static var current: Version {
        var maj: Int32 = 0
        var min: Int32 = 0
        var pat: Int32 = 0
        _ = git_libgit2_version(&maj, &min, &pat)
        return Version(major: Int(maj), minor: Int(min), patch: Int(pat))
    }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }
}
