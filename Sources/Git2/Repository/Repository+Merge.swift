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
    /// Shared body for ``merge(_:mergeOptions:checkoutOptions:)``,
    /// ``merge(branchNamed:mergeOptions:checkoutOptions:)``, and
    /// ``merge(against:mergeOptions:checkoutOptions:)``. Assumes the
    /// caller already holds the lock.
    ///
    /// - Parameters:
    ///   - annotated: a pre-built ``AnnotatedCommit`` naming the merge
    ///     target. Caller retains ownership (the handle must stay live
    ///     until this call returns).
    ///   - mergeOptions / checkoutOptions: forwarded unchanged.
    /// - Returns: the analysis bits describing which dispatch path ran.
    private func performMerge(
        annotated: AnnotatedCommit,
        mergeOptions: MergeOptions,
        checkoutOptions: CheckoutOptions
    ) throws(GitError) -> MergeAnalysis {
        // 1. Analyze.
        var analysisRaw = git_merge_analysis_t(0)
        var prefRaw = git_merge_preference_t(0)
        var heads: [OpaquePointer?] = [annotated.handle]
        let analysisResult: Int32 = heads.withUnsafeMutableBufferPointer { buf in
            git_merge_analysis(&analysisRaw, &prefRaw, handle, buf.baseAddress, buf.count)
        }
        try check(analysisResult)
        let analysis = MergeAnalysis(rawValue: analysisRaw.rawValue)

        // 2. Dispatch.
        if analysis.contains(.upToDate) {
            return analysis
        }

        if analysis.contains(.unborn) {
            // HEAD is unborn. Read HEAD's symbolic target (e.g.
            // "refs/heads/main"), create that branch at the fetched OID,
            // then attach HEAD + checkout.
            var headRef: OpaquePointer?
            try check(git_reference_lookup(&headRef, handle, "HEAD"))
            defer { git_reference_free(headRef) }
            guard git_reference_type(headRef) == GIT_REFERENCE_SYMBOLIC,
                  let symbolicTargetPtr = git_reference_symbolic_target(headRef) else {
                throw GitError(
                    code: .unbornBranch, class: .reference,
                    message: "cannot resolve unborn HEAD's symbolic target"
                )
            }
            let targetName = String(cString: symbolicTargetPtr)

            let oidPtr = git_annotated_commit_id(annotated.handle)!
            var branchRef: OpaquePointer?
            try check(targetName.withCString { namePtr in
                git_reference_create(&branchRef, handle, namePtr, oidPtr, 0, nil)
            })
            git_reference_free(branchRef)

            try check(targetName.withCString { namePtr in
                git_repository_set_head(handle, namePtr)
            })
            try checkoutOptions.withCOptions { optsPtr throws(GitError) in
                try check(git_checkout_head(handle, optsPtr))
            }
            return analysis
        }

        if analysis.contains(.fastForward) {
            // Peel via the AnnotatedCommit's OID, checkout the tree, then
            // update HEAD's ref (attached) or move detached HEAD. Mirrors
            // libgit2's examples/merge.c pattern.
            //
            // Dispatch strategy:
            // • If the annotated commit carries ref provenance (created from a
            //   Reference), update the current branch's target so HEAD stays
            //   attached and the symbolic ref advances with the fast-forward.
            // • If there is no ref provenance (OID-only lookup, FETCH_HEAD
            //   origin, etc.), use set_head_detached_from_annotated so that
            //   the reflog records the provenance correctly and HEAD detaches.
            let oidPtr = git_annotated_commit_id(annotated.handle)!
            var commitPtr: OpaquePointer?
            try check(git_object_lookup(&commitPtr, handle, oidPtr, GIT_OBJECT_COMMIT))
            defer { git_object_free(commitPtr) }

            try checkoutOptions.withCOptions { optsPtr throws(GitError) in
                try check(git_checkout_tree(handle, commitPtr, optsPtr))
            }

            let hasRefProvenance = git_annotated_commit_ref(annotated.handle) != nil
            if hasRefProvenance {
                // HEAD is symbolic → update the current branch's target.
                let currentHeadDetached = git_repository_head_detached(handle)
                try check(currentHeadDetached)
                if currentHeadDetached == 1 {
                    // Already detached — use set_head_detached_from_annotated.
                    try check(git_repository_set_head_detached_from_annotated(handle, annotated.handle))
                } else {
                    var currentHead: OpaquePointer?
                    try check(git_repository_head(&currentHead, handle))
                    defer { git_reference_free(currentHead) }
                    var newRef: OpaquePointer?
                    var oidCopy = oidPtr.pointee
                    try check(git_reference_set_target(&newRef, currentHead, &oidCopy, nil))
                    git_reference_free(newRef)
                }
            } else {
                // No ref provenance (OID lookup / FETCH_HEAD): detach HEAD at
                // the annotated commit so reflog entries use the correct origin.
                try check(git_repository_set_head_detached_from_annotated(handle, annotated.handle))
            }
            return analysis
        }

        // Normal: git_merge updates working tree + index + writes MERGE_HEAD/MSG.
        try mergeOptions.withCOptions { mPtr throws(GitError) in
            try checkoutOptions.withCOptions { cPtr throws(GitError) in
                var headPtrs: [OpaquePointer?] = [annotated.handle]
                let r: Int32 = headPtrs.withUnsafeMutableBufferPointer { buf in
                    git_merge(handle, buf.baseAddress, buf.count, mPtr, cPtr)
                }
                try check(r)
            }
        }
        return analysis
    }

    /// Porcelain merge. Analyzes the requested merge, then dispatches:
    /// - ``MergeAnalysis/upToDate`` — no-op
    /// - ``MergeAnalysis/unborn`` — attach HEAD + checkout
    /// - ``MergeAnalysis/fastForward`` — checkout + move HEAD
    /// - ``MergeAnalysis/normal`` — call `git_merge` (conflicts land in the
    ///   index; state becomes ``State/merge``)
    ///
    /// The entire analysis → dispatch sequence runs inside a single lock
    /// section — no other task observes a mid-merge state.
    ///
    /// - Returns: the analysis bits describing which path ran.
    @discardableResult
    public func merge(
        _ branch: Reference,
        mergeOptions: MergeOptions = MergeOptions(),
        checkoutOptions: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) -> MergeAnalysis {
        try lock.withLock { () throws(GitError) -> MergeAnalysis in
            let annotated = try annotatedCommitLocked(for: branch)
            return try performMerge(
                annotated: annotated,
                mergeOptions: mergeOptions,
                checkoutOptions: checkoutOptions
            )
        }
    }

    /// Porcelain convenience: resolve `refs/heads/<name>` and forward to
    /// ``merge(_:mergeOptions:checkoutOptions:)``.
    /// Local branches only (`GIT_BRANCH_LOCAL`).
    @discardableResult
    public func merge(
        branchNamed name: String,
        mergeOptions: MergeOptions = MergeOptions(),
        checkoutOptions: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) -> MergeAnalysis {
        try lock.withLock { () throws(GitError) -> MergeAnalysis in
            var refHandle: OpaquePointer?
            let lookup: Int32 = name.withCString { namePtr in
                git_branch_lookup(&refHandle, handle, namePtr, GIT_BRANCH_LOCAL)
            }
            try check(lookup)
            // Wrap in Reference so deinit frees the handle.
            let reference = Reference(handle: refHandle!, repository: self)

            let annotated = try annotatedCommitLocked(for: reference)
            return try performMerge(
                annotated: annotated,
                mergeOptions: mergeOptions,
                checkoutOptions: checkoutOptions
            )
        }
    }

    /// Porcelain merge against a pre-built ``AnnotatedCommit``. Analyzes
    /// the merge, then dispatches on the analysis bits the same way as
    /// ``merge(_:mergeOptions:checkoutOptions:)-Reference``. Closes the
    /// surface gap where ``AnnotatedCommit`` was the only merge input
    /// that could not drive analysis + dispatch.
    ///
    /// The entire analysis → dispatch sequence runs inside a single lock
    /// section — no other task observes a mid-merge state.
    ///
    /// - Parameters:
    ///   - annotated: The merge target. Typically produced by
    ///     ``annotatedCommit(for:)-Reference``,
    ///     ``annotatedCommit(for:)-OID``, ``annotatedCommit(from:)``, or
    ///     ``annotatedCommit(fromFetchHead:remoteURL:oid:)``.
    ///   - mergeOptions: Merge rename / favor / recursion options.
    ///   - checkoutOptions: Checkout options applied on the
    ///     `.fastForward`, `.unborn`, and `.normal` dispatch paths.
    /// - Returns: The analysis bits describing which dispatch path ran.
    @discardableResult
    public func merge(
        against annotated: AnnotatedCommit,
        mergeOptions: MergeOptions = MergeOptions(),
        checkoutOptions: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) -> MergeAnalysis {
        try lock.withLock { () throws(GitError) -> MergeAnalysis in
            try performMerge(
                annotated: annotated,
                mergeOptions: mergeOptions,
                checkoutOptions: checkoutOptions
            )
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
