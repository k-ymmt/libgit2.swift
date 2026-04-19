import Cgit2

extension Repository {
    /// Looks up a reference by its full name, e.g. `"refs/heads/main"` or
    /// `"refs/tags/v1.0"`.
    ///
    /// - Returns: The reference, or `nil` if no reference with that name exists.
    /// - Throws: ``GitError`` only for genuine failures — most notably
    ///   ``GitError/Code/invalidSpec`` when `name` is not syntactically
    ///   valid. Missing references are reported via `nil`, not a throw.
    public func reference(named name: String) throws(GitError) -> Reference? {
        try lock.withLock { () throws(GitError) -> Reference? in
            var raw: OpaquePointer?
            let result = name.withCString { git_reference_lookup(&raw, handle, $0) }
            if result == GIT_ENOTFOUND.rawValue {
                return nil
            }
            try check(result)
            return Reference(handle: raw!, repository: self)
        }
    }

    /// A lazy sequence over every reference in this repository.
    public func references() -> ReferenceSequence {
        ReferenceSequence(repository: self)
    }
}
