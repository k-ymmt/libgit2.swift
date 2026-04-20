import Cgit2

extension Repository {
    /// Wraps `git_cherrypick_commit`. Pure calculation: applies `commit` on
    /// top of `ourCommit` and returns the resulting ``Index`` (possibly
    /// conflicting) without touching the working tree.
    ///
    /// For a merge commit, `mainline` must be `1` or `2` (1-indexed — the
    /// parent to treat as the mainline). For a non-merge commit, `mainline`
    /// must be `0`.
    public func cherrypickCommit(
        _ commit: Commit,
        onto ourCommit: Commit,
        mainline: Int = 0,
        mergeOptions: MergeOptions = MergeOptions()
    ) throws(GitError) -> Index {
        try lock.withLock { () throws(GitError) -> Index in
            try mergeOptions.withCOptions { optsPtr throws(GitError) -> Index in
                var out: OpaquePointer?
                try check(git_cherrypick_commit(
                    &out, handle,
                    commit.handle, ourCommit.handle,
                    UInt32(mainline),
                    optsPtr
                ))
                return Index(handle: out!, repository: self)
            }
        }
    }
}
