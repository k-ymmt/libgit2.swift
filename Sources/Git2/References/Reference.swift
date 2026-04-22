import Cgit2

/// A named pointer to an object in the repository (a branch, a tag, or HEAD).
///
/// ``Reference`` owns a libgit2 reference handle. Child objects like ``Reference``
/// hold a strong reference to their parent ``Repository``, ensuring the repo
/// outlives anything derived from it.
///
/// All access to the reference is serialized through the parent repository's
/// internal lock.
public final class Reference: @unchecked Sendable {
    internal let handle: OpaquePointer

    /// The repository this reference belongs to.
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_reference_free(handle)
    }

    /// The full reference name, e.g. `"refs/heads/main"`, `"refs/tags/v1.0"`, or
    /// `"HEAD"`.
    public var name: String {
        repository.lock.withLock {
            // libgit2 contract: git_reference_name is non-NULL for a valid handle.
            String(cString: git_reference_name(handle)!)
        }
    }

    /// The shortened reference name, e.g. `"main"` or `"v1.0"`.
    public var shorthand: String {
        repository.lock.withLock {
            // libgit2 contract: git_reference_shorthand is non-NULL for a valid handle.
            String(cString: git_reference_shorthand(handle)!)
        }
    }

    /// The OID the reference ultimately points at.
    ///
    /// Symbolic references (e.g. `HEAD` pointing at `refs/heads/main`) are
    /// resolved to their direct target first.
    ///
    /// - Throws: ``GitError`` if the reference is symbolic and cannot be
    ///   resolved, or if the resolved reference has no target.
    public var target: OID {
        get throws(GitError) {
            try repository.lock.withLock { () throws(GitError) -> OID in
                var resolved: OpaquePointer?
                try check(git_reference_resolve(&resolved, handle))
                defer { git_reference_free(resolved) }
                guard let oidPtr = git_reference_target(resolved) else {
                    throw GitError(code: .notFound, class: .reference, message: "symbolic reference has no target")
                }
                return OID(raw: oidPtr.pointee)
            }
        }
    }

    /// Resolves this reference to a ``Commit``, peeling through tags if necessary.
    ///
    /// Useful for resolving a branch or HEAD directly to the commit it points at,
    /// without having to manually peel annotated tags.
    ///
    /// - Throws: ``GitError`` if the reference cannot be peeled to a commit.
    public func resolveToCommit() throws(GitError) -> Commit {
        try repository.lock.withLock { () throws(GitError) -> Commit in
            var raw: OpaquePointer?
            try check(git_reference_peel(&raw, handle, GIT_OBJECT_COMMIT))
            return Commit(handle: raw!, repository: repository)
        }
    }

    /// Deletes this reference from the repository.
    ///
    /// Uses `git_reference_delete`, which does not touch reflog or config.
    /// For branches, prefer ``Repository/deleteBranch(named:)`` so reflog and
    /// tracking config are cleaned up too.
    ///
    /// After deletion, this ``Reference`` handle still exists in memory but
    /// further operations on it will throw or return stale data.
    public func delete() throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            try check(git_reference_delete(handle))
        }
    }

    /// Resolves this local branch's upstream tracking ref name
    /// (e.g. `"refs/remotes/origin/main"`). Thin wrapper over
    /// `git_branch_upstream_name`.
    ///
    /// Returns `nil` when:
    /// - the ref is not a local branch (remote-tracking refs, tags,
    ///   symbolic HEAD when detached),
    /// - the local branch has no `branch.<name>.remote` /
    ///   `branch.<name>.merge` configuration,
    /// - libgit2 returns `GIT_ENOTFOUND` for any other reason.
    ///
    /// Any other libgit2 error (e.g. a broken config file) propagates
    /// as ``GitError``.
    public func upstreamName() throws(GitError) -> String? {
        try repository.lock.withLock { () throws(GitError) -> String? in
            var buf = git_buf()
            defer { git_buf_dispose(&buf) }
            // Read ref name without re-entering the lock via
            // Reference.name (which would deadlock on the non-recursive
            // OSAllocatedUnfairLock).
            let namePtr = git_reference_name(handle)!
            let rc = git_branch_upstream_name(&buf, repository.handle, namePtr)
            if rc == GIT_ENOTFOUND.rawValue || rc == GIT_EINVALID.rawValue {
                return nil
            }
            // git_branch_upstream_name returns GIT_ERROR (-1) with class
            // GIT_ERROR_INVALID when the ref is not a local branch (e.g.
            // remote-tracking refs, tags, detached HEAD). Treat those as nil.
            if rc == GIT_ERROR.rawValue,
               let errPtr = git_error_last(),
               errPtr.pointee.klass == Int32(GIT_ERROR_INVALID.rawValue) {
                return nil
            }
            try check(rc)
            guard let ptr = buf.ptr else { return nil }
            return String(cString: ptr)
        }
    }
}
