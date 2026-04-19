import Cgit2

public struct OID: Sendable, Hashable, CustomStringConvertible {
    public static let length = 20

    internal let raw: git_oid

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
