import Cgit2

extension Repository {
    /// Looks up an object of any kind.
    ///
    /// - Parameter oid: The object identifier.
    /// - Returns: The object wrapped in the appropriate ``Object`` case, or
    ///   `nil` if no object with that OID exists.
    /// - Throws: ``GitError`` only for genuine failures (I/O, ODB corruption).
    public func object(for oid: OID) throws(GitError) -> Object? {
        try lock.withLock { () throws(GitError) -> Object? in
            var raw: OpaquePointer?
            var oidCopy = oid.raw
            let result = git_object_lookup(&raw, handle, &oidCopy, GIT_OBJECT_ANY)
            if result == GIT_ENOTFOUND.rawValue {
                return nil
            }
            try check(result)
            return try Object.wrap(handle: raw!, repository: self)
        }
    }
}
