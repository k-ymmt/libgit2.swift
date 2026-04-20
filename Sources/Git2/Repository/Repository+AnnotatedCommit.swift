import Cgit2

extension Repository {
    /// Wraps `git_annotated_commit_from_ref`. The resulting handle carries
    /// the ref name as provenance — observable via
    /// ``AnnotatedCommit/refName``.
    public func annotatedCommit(
        for reference: Reference
    ) throws(GitError) -> AnnotatedCommit {
        try lock.withLock { () throws(GitError) -> AnnotatedCommit in
            var out: OpaquePointer?
            try check(git_annotated_commit_from_ref(&out, handle, reference.handle))
            return AnnotatedCommit(handle: out!, repository: self)
        }
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
