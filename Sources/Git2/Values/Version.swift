import Cgit2

/// A semantic `major.minor.patch` version identifier for the bundled libgit2 runtime.
public struct Version: Sendable, Equatable, Comparable, CustomStringConvertible {
    /// The major component.
    public let major: Int
    /// The minor component.
    public let minor: Int
    /// The patch component.
    public let patch: Int

    /// Creates a version from explicit components.
    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// The libgit2 runtime version bundled with this build of Git2.
    ///
    /// Available without calling ``Git/bootstrap()`` first.
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
