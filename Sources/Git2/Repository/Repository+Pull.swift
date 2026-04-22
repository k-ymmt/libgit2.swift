import Cgit2

extension Repository {
    /// Fetches a branch from a remote and merges the fetched tip into
    /// HEAD. Thin merge-style pull porcelain.
    ///
    /// Pull fetches a single branch from `remoteName` using an explicit
    /// refspec `refs/heads/<branchName>:refs/remotes/<remoteName>/<branchName>`
    /// so that the post-fetch state has a predictable remote-tracking
    /// ref. The merge phase reads that tracking ref for the OID, builds
    /// an ``AnnotatedCommit`` via
    /// ``annotatedCommit(fromFetchHead:remoteURL:oid:)`` so the reflog
    /// entry records the merge as originating from `FETCH_HEAD`
    /// (matching `git pull` CLI semantics), and dispatches via the
    /// shared analysis + dispatch path.
    ///
    /// - Important: The fetch and merge phases are **not atomic**
    ///   relative to each other. The per-repository lock is released
    ///   between them. Another task operating on the same
    ///   ``Repository`` handle may observe the repository in a
    ///   "fetched but not yet merged" state. Callers requiring a
    ///   stronger guarantee should serialize at the call site.
    ///
    /// - Parameters:
    ///   - remoteName: Remote configured on this repository
    ///     (e.g. `"origin"`).
    ///   - branchName: Branch on the remote to pull (e.g. `"main"`).
    ///     No `refs/heads/` prefix.
    ///   - options: See ``PullOptions``.
    /// - Returns: The ``MergeAnalysis`` result of the merge phase.
    /// - Throws: ``GitError``. Fetch-phase errors propagate unchanged.
    ///   ``GitError/Code/notFound`` / ``GitError/Class/reference`` when
    ///   `refs/remotes/<remoteName>/<branchName>` is absent after the
    ///   fetch.
    @discardableResult
    public func pull(
        remoteNamed remoteName: String,
        branchNamed branchName: String,
        options: PullOptions = PullOptions()
    ) throws(GitError) -> MergeAnalysis {
        // Phase 1: fetch (lock held inside Remote.fetch).
        let refspec = Refspec("refs/heads/\(branchName):refs/remotes/\(remoteName)/\(branchName)")
        let remote = try lookupRemote(named: remoteName)
        try remote.fetch(
            refspecs: [refspec],
            options: options.fetch,
            reflogMessage: options.reflogMessage
        )
        let remoteURL = remote.url ?? ""

        // Phase 2: merge (re-enter the lock).
        return try lock.withLock { () throws(GitError) -> MergeAnalysis in
            let trackingRefName = "refs/remotes/\(remoteName)/\(branchName)"
            guard let trackingRef = try referenceLocked(named: trackingRefName) else {
                throw GitError(
                    code: .notFound, class: .reference,
                    message: "no tracking ref \(trackingRefName) after fetch"
                )
            }
            let oid = try trackingRef.targetLocked()

            let annotated = try annotatedCommitLocked(
                fromFetchHead: branchName,
                remoteURL: remoteURL,
                oid: oid
            )

            return try performMerge(
                annotated: annotated,
                mergeOptions: options.merge,
                checkoutOptions: options.checkout
            )
        }
    }
}
