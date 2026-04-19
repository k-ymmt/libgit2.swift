import Cgit2

/// Internal helper that centralizes `git_object_lookup` / `git_object_peel`
/// calls used by ``Tree``, ``Blob``, ``Tag``, and ``Repository/object(for:)``.
///
/// Callers are responsible for:
///  1. Holding `repository.lock` across the call.
///  2. Freeing the returned handle with the appropriate `git_*_free` function
///     (or `git_object_free` for an `OpaquePointer` obtained as any kind).
internal enum ObjectHandle {
    /// Looks up an object in `repository`'s object database.
    ///
    /// - Parameters:
    ///   - repository: The owning repository. Caller holds its lock.
    ///   - oid: The OID to look up.
    ///   - kind: `GIT_OBJECT_ANY` to accept any type, or one of
    ///     `GIT_OBJECT_COMMIT` / `_TREE` / `_BLOB` / `_TAG` to constrain.
    /// - Returns: A newly owned handle. Caller must free.
    /// - Throws: ``GitError``. `.notFound` is reported verbatim — the caller
    ///   decides whether to translate it to Optional.
    static func lookup(
        repository: Repository,
        oid: OID,
        kind: git_object_t
    ) throws(GitError) -> OpaquePointer {
        var raw: OpaquePointer?
        var oidCopy = oid.raw
        try check(git_object_lookup(&raw, repository.handle, &oidCopy, kind))
        // libgit2 contract: on GIT_OK raw is non-nil.
        return raw!
    }

    /// Peels `handle` to an object of `kind`. Typical use: peel a `git_tag`
    /// handle to its target commit.
    ///
    /// - Returns: A newly owned handle. Caller must free.
    static func peelToKind(
        repository: Repository,
        handle: OpaquePointer,
        kind: git_object_t
    ) throws(GitError) -> OpaquePointer {
        var raw: OpaquePointer?
        try check(git_object_peel(&raw, handle, kind))
        return raw!
    }
}
