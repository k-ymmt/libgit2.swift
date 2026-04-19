import Cgit2

/// A Git object identifier — the 20-byte SHA-1 hash that names every object in a
/// repository's object database.
///
/// ``OID`` is a value type: copying it is cheap and safe across threads.
///
/// SHA-256 repositories are not supported in this release. See `TODO.md` for the
/// follow-up that enables `EXPERIMENTAL_SHA256`.
public struct OID: Sendable, Hashable, CustomStringConvertible {
    /// The byte length of an OID. SHA-1 is always 20 bytes.
    public static let length = 20

    internal let raw: git_oid

    /// Parses an OID from its 40-character hexadecimal form.
    ///
    /// - Parameter hex: A 40-character hexadecimal string.
    /// - Throws: ``GitError`` if `hex` is not exactly 40 hexadecimal characters.
    public init(hex: String) throws(GitError) {
        var oid = git_oid()
        let result = hex.withCString { cstr in
            git_oid_fromstr(&oid, cstr)
        }
        try check(result)
        self.raw = oid
    }

    internal init(raw: git_oid) {
        self.raw = raw
    }

    /// The OID formatted as a 40-character lowercase hexadecimal string.
    public var hex: String {
        var buffer = [CChar](repeating: 0, count: 41)
        withUnsafePointer(to: raw) { p in
            _ = git_oid_tostr(&buffer, 41, p)
        }
        return String(cString: buffer)
    }

    public var description: String { hex }

    public static func == (lhs: OID, rhs: OID) -> Bool {
        withUnsafePointer(to: lhs.raw) { l in
            withUnsafePointer(to: rhs.raw) { r in
                git_oid_equal(l, r) != 0
            }
        }
    }

    public func hash(into hasher: inout Hasher) {
        withUnsafePointer(to: raw) { p in
            let bytes = UnsafeRawBufferPointer(start: p, count: MemoryLayout<git_oid>.size)
            hasher.combine(bytes: bytes)
        }
    }
}
