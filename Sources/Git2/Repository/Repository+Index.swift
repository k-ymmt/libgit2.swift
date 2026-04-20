import Cgit2

extension Repository {
    /// Opens the repository's index (`.git/index`).
    ///
    /// libgit2 refcounts a single index object per repository. Two ``Index``
    /// values obtained from the same ``Repository`` share the underlying
    /// mutable state — a mutation through one is visible through the other.
    /// Call ``Index/reload(force:)`` if another process may have rewritten
    /// `.git/index` after your last call.
    public func index() throws(GitError) -> Index {
        try lock.withLock { () throws(GitError) -> Index in
            var raw: OpaquePointer?
            try check(git_repository_index(&raw, handle))
            return Index(handle: raw!, repository: self)
        }
    }
}
