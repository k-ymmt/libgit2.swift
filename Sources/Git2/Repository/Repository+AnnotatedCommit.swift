import Cgit2

extension Repository {
    /// Wraps `git_annotated_commit_from_ref`. The resulting handle carries
    /// the ref name as provenance — observable via
    /// ``AnnotatedCommit/refName``.
    public func annotatedCommit(
        for reference: Reference
    ) throws(GitError) -> AnnotatedCommit {
        try lock.withLock { () throws(GitError) -> AnnotatedCommit in
            try annotatedCommitLocked(for: reference)
        }
    }

    /// No-lock sibling of ``annotatedCommit(for:)-Reference``. Caller must
    /// hold `lock`.
    internal func annotatedCommitLocked(
        for reference: Reference
    ) throws(GitError) -> AnnotatedCommit {
        var out: OpaquePointer?
        try check(git_annotated_commit_from_ref(&out, handle, reference.handle))
        return AnnotatedCommit(handle: out!, repository: self)
    }

    /// Wraps `git_annotated_commit_lookup`. The resulting handle has no ref
    /// provenance (``AnnotatedCommit/refName`` returns `nil`).
    ///
    /// - Throws: ``GitError/Code/notFound`` when no object with the given
    ///   OID exists.
    public func annotatedCommit(
        for oid: OID
    ) throws(GitError) -> AnnotatedCommit {
        try lock.withLock { () throws(GitError) -> AnnotatedCommit in
            var out: OpaquePointer?
            var raw = oid.raw
            try check(git_annotated_commit_lookup(&out, handle, &raw))
            return AnnotatedCommit(handle: out!, repository: self)
        }
    }

    /// Convenience over ``annotatedCommit(for:)`` with an OID. The resulting
    /// handle has no ref provenance.
    public func annotatedCommit(
        from commit: Commit
    ) throws(GitError) -> AnnotatedCommit {
        try annotatedCommit(for: commit.oid)
    }
}

extension Repository {
    /// Wraps `git_annotated_commit_from_fetchhead`.
    ///
    /// Reconstructs an ``AnnotatedCommit`` for a ref the remote
    /// advertised during a fetch, carrying fetch-origin provenance so
    /// subsequent merges / rebases produce meaningful reflog messages.
    /// Only meaningful after a ``fetch(remoteNamed:refspecs:options:reflogMessage:)``
    /// call wrote `FETCH_HEAD`.
    ///
    /// - Parameters:
    ///   - branchName: the ref name the remote used, e.g. `"main"`.
    ///   - remoteURL: the URL the fetch was against.
    ///   - oid: the commit the fetch resolved the ref to.
    public func annotatedCommit(
        fromFetchHead branchName: String,
        remoteURL: String,
        oid: OID
    ) throws(GitError) -> AnnotatedCommit {
        try lock.withLock { () throws(GitError) -> AnnotatedCommit in
            try annotatedCommitLocked(
                fromFetchHead: branchName,
                remoteURL: remoteURL,
                oid: oid
            )
        }
    }

    /// No-lock sibling of
    /// ``annotatedCommit(fromFetchHead:remoteURL:oid:)``. Caller must
    /// hold `lock`.
    internal func annotatedCommitLocked(
        fromFetchHead branchName: String,
        remoteURL: String,
        oid: OID
    ) throws(GitError) -> AnnotatedCommit {
        var rawOID = oid.raw
        var raw: OpaquePointer?
        try check(git_annotated_commit_from_fetchhead(
            &raw,
            handle,
            branchName,
            remoteURL,
            &rawOID
        ))
        return AnnotatedCommit(handle: raw!, repository: self)
    }
}
