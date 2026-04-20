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

extension Repository {
    /// Low-level merge. Writes MERGE_HEAD / MERGE_MSG, updates the index,
    /// updates the working tree. Does **not** fast-forward — callers who
    /// want fast-forward on applicable histories should use
    /// ``merge(_:mergeOptions:checkoutOptions:)-<Reference-overload>`` or
    /// analyze first with ``mergeAnalysis(against:)``.
    ///
    /// `heads.count` must equal 1 in v0.5a-i; octopus merge is deferred.
    /// Passing 0 or >1 heads throws ``GitError/Code/invalid`` /
    /// ``GitError/Class/invalid``.
    ///
    /// Conflicts are surfaced through the index (inspect
    /// ``Index/hasConflicts`` / ``Index/conflicts``) and
    /// ``Repository/state``, not as Swift errors. Set
    /// ``MergeOptions/Flags/failOnConflict`` to opt into throwing on
    /// conflicts.
    public func merge(
        _ heads: [AnnotatedCommit],
        mergeOptions: MergeOptions = MergeOptions(),
        checkoutOptions: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) {
        guard heads.count == 1 else {
            throw GitError(
                code: .invalid, class: .invalid,
                message: "v0.5a-i merge() requires exactly one head; octopus merge is deferred"
            )
        }

        try lock.withLock { () throws(GitError) in
            try mergeOptions.withCOptions { mPtr throws(GitError) in
                try checkoutOptions.withCOptions { cPtr throws(GitError) in
                    var headPtrs: [OpaquePointer?] = heads.map { $0.handle }
                    let r: Int32 = headPtrs.withUnsafeMutableBufferPointer { buf in
                        git_merge(handle, buf.baseAddress, buf.count, mPtr, cPtr)
                    }
                    try check(r)
                }
            }
        }
    }
}
