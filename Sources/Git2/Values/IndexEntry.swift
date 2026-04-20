import Cgit2

/// A single entry in the repository index.
///
/// Snapshot value. Does not retain a libgit2 handle.
public struct IndexEntry: Sendable, Equatable {
    /// The entry path, relative to the repository working directory.
    public let path: String

    /// The OID of the staged blob (or sub-tree / submodule commit).
    public let oid: OID

    /// The entry filemode.
    public let filemode: TreeEntry.FileMode

    /// The merge stage.
    public let stage: Stage

    public init(
        path: String,
        oid: OID,
        filemode: TreeEntry.FileMode,
        stage: Stage
    ) {
        self.path = path
        self.oid = oid
        self.filemode = filemode
        self.stage = stage
    }
}

extension IndexEntry {
    /// Merge stage of an index entry.
    public enum Stage: Sendable, Equatable {
        /// stage 0 — resolved / non-conflicted.
        case normal
        /// stage 1 — common ancestor side during a merge.
        case ancestor
        /// stage 2 — "our" side during a merge.
        case ours
        /// stage 3 — "their" side during a merge.
        case theirs
    }
}

extension IndexEntry.Stage {
    /// Extracts the stage bits from a raw `git_index_entry.flags` value.
    ///
    /// libgit2 encodes the stage in bits 12–13. Any value outside 0…3 is a
    /// libgit2 contract violation and traps — it cannot occur against a
    /// well-formed index.
    internal init(flags: UInt16) {
        let mask = UInt16(GIT_INDEX_ENTRY_STAGEMASK)
        let shift = UInt16(GIT_INDEX_ENTRY_STAGESHIFT)
        switch (flags & mask) >> shift {
        case 0: self = .normal
        case 1: self = .ancestor
        case 2: self = .ours
        case 3: self = .theirs
        default:
            preconditionFailure("libgit2 returned out-of-range index stage")
        }
    }
}

extension IndexEntry {
    /// Converts a raw libgit2 entry pointer into an `IndexEntry` snapshot.
    internal init(_ raw: UnsafePointer<git_index_entry>) {
        let r = raw.pointee
        self.path = String(cString: r.path)
        self.oid = OID(raw: r.id)
        self.filemode = TreeEntry.FileMode.from(git_filemode_t(r.mode))
        self.stage = Stage(flags: r.flags)
    }
}
