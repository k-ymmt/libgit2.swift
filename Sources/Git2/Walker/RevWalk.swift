import Cgit2

/// Commit-graph traversal with full error reporting.
///
/// Unlike ``CommitSequence`` — which conforms to `Sequence` and therefore
/// cannot report iteration errors — `RevWalk.next()` throws. Use it when
/// you need to distinguish normal termination from a mid-walk failure, or
/// when you need control over push / hide / sorting / simplification.
public final class RevWalk: @unchecked Sendable {
    internal let handle: OpaquePointer

    /// The repository this walker traverses.
    public let repository: Repository

    /// Creates a new walker with no push points. Call one of the `push*`
    /// methods before `next()`, otherwise iteration terminates immediately.
    public init(repository: Repository) throws(GitError) {
        self.repository = repository
        var raw: OpaquePointer?
        try repository.lock.withLock { () throws(GitError) in
            try check(git_revwalk_new(&raw, repository.handle))
        }
        // libgit2 contract: on GIT_OK raw is non-nil.
        self.handle = raw!
    }

    deinit {
        git_revwalk_free(handle)
    }

    // MARK: - Push

    /// Push a commit so the walk emits it and all of its ancestors.
    public func push(_ commit: Commit) throws(GitError) {
        try push(oid: commit.oid)
    }

    /// Push an OID.
    public func push(oid: OID) throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            var copy = oid.raw
            try check(git_revwalk_push(handle, &copy))
        }
    }

    /// Push every commit reachable from the given reference.
    public func push(refName: String) throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            try check(refName.withCString { git_revwalk_push_ref(handle, $0) })
        }
    }

    /// Push every commit reachable from `HEAD`.
    public func pushHead() throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            try check(git_revwalk_push_head(handle))
        }
    }

    // MARK: - Hide

    /// Hide a commit and all of its ancestors — they will not be emitted.
    public func hide(_ commit: Commit) throws(GitError) {
        try hide(oid: commit.oid)
    }

    /// Hide an OID.
    public func hide(oid: OID) throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            var copy = oid.raw
            try check(git_revwalk_hide(handle, &copy))
        }
    }

    // MARK: - Options

    /// Restrict the walk to first parents only (skip merge side branches).
    public func simplifyFirstParent() throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            try check(git_revwalk_simplify_first_parent(handle))
        }
    }

    /// Reset the walker. Clears push / hide / sorting state.
    public func reset() {
        repository.lock.withLock { () -> Void in
            git_revwalk_reset(handle)
        }
    }

    // MARK: - Iterate

    /// Advance the walk.
    ///
    /// - Returns: The next commit, or `nil` when the walk completes normally
    ///   (libgit2's `GIT_ITEROVER`).
    /// - Throws: ``GitError`` on any other failure during iteration.
    public func next() throws(GitError) -> Commit? {
        try repository.lock.withLock { () throws(GitError) -> Commit? in
            var oid = git_oid()
            let r = git_revwalk_next(&oid, handle)
            if r == GIT_ITEROVER.rawValue {
                return nil
            }
            try check(r)
            var commitHandle: OpaquePointer?
            try check(git_commit_lookup(&commitHandle, repository.handle, &oid))
            return Commit(handle: commitHandle!, repository: repository)
        }
    }
}
