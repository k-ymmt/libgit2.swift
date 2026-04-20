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

extension Index {
    /// A point-in-time snapshot of every entry currently in the index.
    ///
    /// Entries are returned in libgit2's internal order (path-sorted with
    /// stage tiebreaking). Mutating the index through another operation
    /// invalidates this snapshot — re-read the property to get fresh data.
    public var entries: [IndexEntry] {
        repository.lock.withLock {
            let count = git_index_entrycount(handle)
            var out: [IndexEntry] = []
            out.reserveCapacity(count)
            for i in 0..<count {
                guard let raw = git_index_get_byindex(handle, i) else { continue }
                out.append(IndexEntry(raw))
            }
            return out
        }
    }
}

extension Index {
    /// Looks up a single entry by path and stage.
    ///
    /// - Parameter stage: Defaults to `.normal`. For conflicted paths, pass
    ///   `.ancestor` / `.ours` / `.theirs` to reach the specific side — or
    ///   use ``conflict(for:)`` / ``conflicts`` to retrieve all three at once.
    /// - Returns: The matching entry, or `nil` if no entry exists at that
    ///   path and stage.
    public func entry(
        at path: String,
        stage: IndexEntry.Stage = .normal
    ) -> IndexEntry? {
        let stageValue: Int32 = switch stage {
        case .normal:   0
        case .ancestor: 1
        case .ours:     2
        case .theirs:   3
        }
        return repository.lock.withLock {
            path.withCString { p in
                guard let raw = git_index_get_bypath(handle, p, stageValue) else {
                    return nil as IndexEntry?
                }
                return IndexEntry(raw)
            }
        }
    }
}

extension Index {
    /// Stages the file at `path` (relative to the repository working
    /// directory) into the index.
    ///
    /// - Parameter path: Path relative to the repository working directory.
    ///   Forward slashes only, no leading separator.
    /// - Throws: ``GitError`` — typically ``GitError/Code/notFound`` if the
    ///   file doesn't exist, or a ``GitError/Class/repository`` error on a
    ///   bare repository.
    public func addPath(_ path: String) throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            try check(path.withCString { git_index_add_bypath(handle, $0) })
        }
    }
}

extension Index {
    /// Removes the entry at `path` from the index.
    ///
    /// Does not touch the working directory. For conflicted paths, removes
    /// every stage (ancestor / ours / theirs) in one call.
    public func removePath(_ path: String) throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            try check(path.withCString { git_index_remove_bypath(handle, $0) })
        }
    }
}

extension Index {
    /// Persists the in-memory index to the on-disk `.git/index` file.
    public func save() throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            try check(git_index_write(handle))
        }
    }
}

extension Index {
    /// Reloads the index from the on-disk `.git/index` file, discarding any
    /// unsaved in-memory changes.
    ///
    /// - Parameter force: If `true` (default), reload unconditionally,
    ///   discarding all unsaved in-memory changes. If `false`, libgit2 may
    ///   short-circuit when the on-disk file's modification-time stamp matches
    ///   the cached one; purely in-memory changes are then left untouched.
    public func reload(force: Bool = true) throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            try check(git_index_read(handle, force ? 1 : 0))
        }
    }
}
