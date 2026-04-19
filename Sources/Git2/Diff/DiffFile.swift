import Cgit2

/// One side of a ``DiffDelta`` — the "old" or "new" file.
///
/// For one-sided deltas (added / deleted) the absent side's ``oid`` is
/// ``OID/zero`` and its ``path`` mirrors the other side's path, per libgit2's
/// convention.
public struct DiffFile: Sendable, Equatable {
    public let oid: OID
    public let path: String
    public let size: UInt64
    public let mode: TreeEntry.FileMode
}

extension DiffFile {
    internal init(raw: git_diff_file) {
        self.oid  = OID(raw: raw.id)
        self.path = raw.path.map(String.init(cString:)) ?? ""
        self.size = raw.size
        self.mode = DiffFile.mode(from: raw.mode)
    }

    /// Lenient filemode conversion. Unlike ``TreeEntry/FileMode/from(_:)``,
    /// diff files can carry `0` (GIT_FILEMODE_UNREADABLE-ish sentinel) for
    /// one-sided deltas. We map that to `.blob` to keep a non-optional type;
    /// callers look at ``DiffDelta/status`` to tell which side is real.
    private static func mode(from raw: UInt16) -> TreeEntry.FileMode {
        switch git_filemode_t(UInt32(raw)) {
        case GIT_FILEMODE_TREE:            return .tree
        case GIT_FILEMODE_BLOB:            return .blob
        case GIT_FILEMODE_BLOB_EXECUTABLE: return .blobExecutable
        case GIT_FILEMODE_LINK:            return .link
        case GIT_FILEMODE_COMMIT:          return .commit
        default:                           return .blob
        }
    }
}
