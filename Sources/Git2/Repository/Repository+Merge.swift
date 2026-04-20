import Cgit2

extension Repository {
    /// Wraps `git_merge_base`. Returns the OID of the single best common
    /// ancestor of `a` and `b`.
    ///
    /// - Throws: ``GitError/Code/notFound`` when the histories are unrelated.
    public func mergeBase(of a: OID, and b: OID) throws(GitError) -> OID {
        try lock.withLock { () throws(GitError) -> OID in
            var out = git_oid()
            var ra = a.raw
            var rb = b.raw
            try check(git_merge_base(&out, handle, &ra, &rb))
            return OID(raw: out)
        }
    }
}

extension Repository {
    /// Wraps `git_merge_base_many`. Returns the OID of the best octopus
    /// ancestor among the given OIDs.
    ///
    /// - Throws: ``GitError/Code/notFound`` when no common ancestor exists,
    ///   or when `oids` is empty.
    public func mergeBase(among oids: [OID]) throws(GitError) -> OID {
        try lock.withLock { () throws(GitError) -> OID in
            var out = git_oid()
            let raw = oids.map(\.raw)
            let r: Int32 = raw.withUnsafeBufferPointer { buf in
                git_merge_base_many(&out, handle, buf.count, buf.baseAddress)
            }
            try check(r)
            return OID(raw: out)
        }
    }
}

extension Repository {
    /// Wraps `git_merge_analysis`. Analyzes merging the given heads into HEAD.
    ///
    /// Returns the analysis bitfield (possibly combined — e.g.
    /// `[.fastForward, .normal]`) and the repository's `merge.ff` preference
    /// (as-configured via `.git/config`; defaults to `.none`).
    public func mergeAnalysis(
        against heads: [AnnotatedCommit]
    ) throws(GitError) -> (analysis: MergeAnalysis, preference: MergePreference) {
        try lock.withLock { () throws(GitError) -> (MergeAnalysis, MergePreference) in
            var analysisRaw = git_merge_analysis_t(0)
            var prefRaw = git_merge_preference_t(0)
            var headPtrs: [OpaquePointer?] = heads.map { $0.handle }
            let r: Int32 = headPtrs.withUnsafeMutableBufferPointer { buf in
                git_merge_analysis(&analysisRaw, &prefRaw, handle, buf.baseAddress, buf.count)
            }
            try check(r)
            return (
                MergeAnalysis(rawValue: analysisRaw.rawValue),
                MergePreference(prefRaw)
            )
        }
    }
}

extension Repository {
    /// Wraps `git_merge_trees`. Produces a possibly-conflicting ``Index``
    /// without touching the working tree.
    ///
    /// - Parameter ancestor: Common ancestor tree, or `nil` to run a 2-way
    ///   merge (libgit2 treats a NULL ancestor as "no common base").
    public func mergeTrees(
        ancestor: Tree?,
        ours: Tree,
        theirs: Tree,
        options: MergeOptions = MergeOptions()
    ) throws(GitError) -> Index {
        try lock.withLock { () throws(GitError) -> Index in
            try options.withCOptions { optsPtr throws(GitError) -> Index in
                var out: OpaquePointer?
                try check(git_merge_trees(
                    &out, handle,
                    ancestor?.handle, ours.handle, theirs.handle,
                    optsPtr
                ))
                return Index(handle: out!, repository: self)
            }
        }
    }
}

extension Repository {
    /// Wraps `git_merge_commits`. libgit2 computes the merge base internally
    /// (recursively when the commits have multiple bases). Returns a
    /// possibly-conflicting ``Index`` without touching the working tree.
    public func mergeCommits(
        ours: Commit,
        theirs: Commit,
        options: MergeOptions = MergeOptions()
    ) throws(GitError) -> Index {
        try lock.withLock { () throws(GitError) -> Index in
            try options.withCOptions { optsPtr throws(GitError) -> Index in
                var out: OpaquePointer?
                try check(git_merge_commits(
                    &out, handle,
                    ours.handle, theirs.handle,
                    optsPtr
                ))
                return Index(handle: out!, repository: self)
            }
        }
    }
}
