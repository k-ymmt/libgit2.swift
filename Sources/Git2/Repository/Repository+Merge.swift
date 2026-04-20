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
