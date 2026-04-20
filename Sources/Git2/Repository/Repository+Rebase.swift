import Cgit2

extension Repository {
    /// Wraps `git_rebase_init`. Initializes a new rebase session.
    ///
    /// All three ``AnnotatedCommit`` arguments are optional, following
    /// libgit2's nullable semantics:
    /// - `branch: nil` → rebase the current branch
    /// - `upstream: nil` → rebase every commit reachable from `branch`
    /// - `onto: nil` → rebase onto `upstream`
    ///
    /// Call ``Rebase/next()`` to begin applying operations.
    public func startRebase(
        branch: AnnotatedCommit? = nil,
        upstream: AnnotatedCommit? = nil,
        onto: AnnotatedCommit? = nil,
        options: RebaseOptions = RebaseOptions()
    ) throws(GitError) -> Rebase {
        try lock.withLock { () throws(GitError) -> Rebase in
            try options.withCOptions { optsPtr throws(GitError) -> Rebase in
                var out: OpaquePointer?
                try check(git_rebase_init(
                    &out, handle,
                    branch?.handle, upstream?.handle, onto?.handle,
                    optsPtr
                ))
                return Rebase(handle: out!, repository: self)
            }
        }
    }

    /// Wraps `git_rebase_open`. Resumes an in-progress rebase that was
    /// started by this or another process (libgit2 persists rebase state
    /// under `.git/rebase-merge/`).
    ///
    /// - Throws: ``GitError/Code/notFound`` when no rebase is in progress.
    public func openRebase(
        options: RebaseOptions = RebaseOptions()
    ) throws(GitError) -> Rebase {
        try lock.withLock { () throws(GitError) -> Rebase in
            try options.withCOptions { optsPtr throws(GitError) -> Rebase in
                var out: OpaquePointer?
                try check(git_rebase_open(&out, handle, optsPtr))
                return Rebase(handle: out!, repository: self)
            }
        }
    }
}
