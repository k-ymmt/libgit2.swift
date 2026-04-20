import Cgit2

extension Repository {
    /// Points HEAD at a reference by canonical name.
    /// Equivalent to `git_repository_set_head`.
    ///
    /// libgit2 accepts a not-yet-existing branch name — HEAD becomes
    /// attached to an unborn branch. This is **not** an error and does not
    /// throw. libgit2 rejects names that resolve to a tree or blob.
    ///
    /// Does **not** touch the working tree. Pair with
    /// ``checkoutHead(options:)`` (or use ``checkout(branch:options:)`` /
    /// ``checkout(branchNamed:options:)``) when switching branches.
    public func setHead(referenceName: String) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            try check(referenceName.withCString { namePtr in
                git_repository_set_head(handle, namePtr)
            })
        }
    }

    /// Points HEAD directly at the commit with the given OID (detached).
    /// Equivalent to `git_repository_set_head_detached`.
    ///
    /// - Throws: ``GitError`` —
    ///   - ``GitError/Code/notFound`` if no object with that OID exists in
    ///     the ODB.
    ///   - ``GitError/Code/invalidSpec`` with
    ///     ``GitError/Class/object`` if the OID exists but peels to a
    ///     non-commit (e.g. a tree or blob).
    public func setHead(detachedAt oid: OID) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            var oidCopy = oid.raw
            try check(git_repository_set_head_detached(handle, &oidCopy))
        }
    }
}

extension Repository {
    /// Sugar for ``setHead(referenceName:)`` using `reference.name`.
    ///
    /// Takes the lock once and calls libgit2 directly — does **not** delegate
    /// to ``setHead(referenceName:)`` so a reentrant `withLock` cannot occur.
    public func setHead(to reference: Reference) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            // libgit2 contract: git_reference_name is non-NULL for a valid handle.
            let namePtr = git_reference_name(reference.handle)!
            try check(git_repository_set_head(handle, namePtr))
        }
    }

    /// Sugar for ``setHead(detachedAt:)`` using `commit.oid` (detached).
    ///
    /// Takes the lock once and calls libgit2 directly — does **not** delegate
    /// to ``setHead(detachedAt:)`` so a reentrant `withLock` cannot occur.
    public func setHead(to commit: Commit) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            // libgit2 contract: git_commit_id is non-NULL for a valid handle.
            var oidCopy = git_commit_id(commit.handle)!.pointee
            try check(git_repository_set_head_detached(handle, &oidCopy))
        }
    }
}
