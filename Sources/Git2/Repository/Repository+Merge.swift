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
