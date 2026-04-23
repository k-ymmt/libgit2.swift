import Cgit2

/// One file's status, materialized from a `git_status_entry`. Values are
/// copied out of libgit2's buffers at read time, so the entry can outlive
/// the originating ``StatusList``.
public struct StatusEntry: Sendable, Equatable {
    /// UTF-8 path relative to the working directory. Resolved from the
    /// first non-NULL of `headToIndex.newFile` / `indexToWorkdir.newFile` /
    /// `indexToWorkdir.oldFile`. Empty string only if libgit2 returned
    /// both deltas NULL — which should not happen for any non-`.current`
    /// entry in practice.
    public let path: String

    /// Combined status flags. Empty set for `GIT_STATUS_CURRENT`, which
    /// appears only when ``Repository/StatusOptions/Flags/includeUnmodified`` is set.
    public let flags: StatusFlags

    /// HEAD→index delta, if present (any index-side flag set).
    public let headToIndex: DiffDelta?

    /// Index→workdir delta, if present (any workdir-side flag set).
    public let indexToWorkdir: DiffDelta?
}

extension StatusEntry {
    internal init(raw: git_status_entry) {
        let headToIndex = raw.head_to_index.map { DiffDelta(raw: $0.pointee) }
        let indexToWorkdir = raw.index_to_workdir.map { DiffDelta(raw: $0.pointee) }
        self.path =
            headToIndex?.newFile.path.nonEmpty
            ?? indexToWorkdir?.newFile.path.nonEmpty
            ?? indexToWorkdir?.oldFile.path.nonEmpty
            ?? ""
        self.flags = StatusFlags(rawValue: UInt32(raw.status.rawValue))
        self.headToIndex = headToIndex
        self.indexToWorkdir = indexToWorkdir
    }
}

private extension String {
    /// Returns `self` if non-empty, otherwise `nil`. Used in the path
    /// fallback so an empty `DiffFile.path` doesn't short-circuit the
    /// chain to the wrong side.
    var nonEmpty: String? { isEmpty ? nil : self }
}
