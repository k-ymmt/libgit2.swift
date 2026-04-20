import Cgit2

/// The repository index (the staging area between the working tree and the ODB).
///
/// ``Index`` owns a libgit2 `git_index *` handle. It is a mutable, long-lived
/// handle — unlike ``Tree`` and ``Commit``, which are immutable snapshots. All
/// access is serialized through the parent ``Repository``'s internal lock.
///
/// libgit2 refcounts a single index object per repository, so two ``Index``
/// values obtained from the same ``Repository`` share their underlying mutable
/// state: a mutation through one is visible through the other. If another
/// process may have rewritten the on-disk `.git/index` file, call
/// ``reload(force:)``.
public final class Index: @unchecked Sendable {
    internal let handle: OpaquePointer

    /// The repository this index belongs to.
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_index_free(handle)
    }
}

extension Index {
    /// Whether the index currently records any merge conflicts
    /// (i.e. entries with stage other than `.normal`).
    public var hasConflicts: Bool {
        repository.lock.withLock {
            git_index_has_conflicts(handle) != 0
        }
    }
}
