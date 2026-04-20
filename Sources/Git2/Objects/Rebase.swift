import Cgit2

/// A libgit2 rebase session.
///
/// A `Rebase` handle wraps `git_rebase *`. It represents an in-progress
/// rebase: the operation list, the current index, and the reflog prefix.
/// Instances are produced by ``Repository/startRebase(branch:upstream:onto:options:)``
/// (start a fresh rebase) or ``Repository/openRebase(options:)`` (resume a
/// rebase started by this or another process via `.git/rebase-merge/`).
///
/// A typical single-process flow:
///
/// ```swift
/// let rebase = try repo.startRebase(
///     upstream: try repo.annotatedCommit(for: upstreamRef)
/// )
/// while let op = try rebase.next() {
///     // … resolve conflicts if any …
///     _ = try rebase.commit(committer: signature)
/// }
/// try rebase.finish()
/// ```
///
/// After ``finish(signature:)`` or ``abort()`` returns successfully, the
/// repository no longer has a rebase in progress. The Swift handle remains
/// valid until `deinit` frees it, but subsequent calls to iteration /
/// termination methods surface libgit2 errors unchanged — v0.5a-ii does
/// not add a Swift-side "consumed" guard.
public final class Rebase: @unchecked Sendable {
    internal let handle: OpaquePointer

    /// The repository this rebase belongs to.
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_rebase_free(handle)
    }
}

extension Rebase {
    // Stub added in Task 4; real implementation lands in Task 9.
    // Kept here so the disabled openRebase_afterStart_resumes test
    // type-checks once its body is re-enabled. Returns 0 until Task 9.
    internal var _operationCountStub: Int { 0 }
    public var operationCount: Int { _operationCountStub }
}

extension Rebase {
    /// Wraps `git_rebase_next`. Applies the next operation — for any
    /// non-``RebaseOperation/Kind/exec`` kind the patch is applied to the
    /// index and (unless ``Repository/RebaseOptions/inMemory`` is `true`)
    /// to the working tree. Conflicts, if any, land in the index; callers
    /// inspect ``Index/hasConflicts`` + ``Index/conflicts()`` before
    /// calling ``commit(author:committer:message:encoding:)``.
    ///
    /// - Returns: the next ``RebaseOperation``, or `nil` when all
    ///   operations have been applied (libgit2 `GIT_ITEROVER` translated to
    ///   `Optional.none`).
    public func next() throws(GitError) -> RebaseOperation? {
        try repository.lock.withLock { () throws(GitError) -> RebaseOperation? in
            var opPtr: UnsafeMutablePointer<git_rebase_operation>?
            let r = git_rebase_next(&opPtr, handle)
            if r == GIT_ITEROVER.rawValue {
                return nil
            }
            try check(r)
            guard let op = opPtr else { return nil }
            return RebaseOperation(copyingFrom: op)
        }
    }
}

extension Rebase {
    /// Wraps `git_rebase_commit`. Commits the current patch.
    ///
    /// - Parameters:
    ///   - author: the author for the rebased commit. Passing `nil` keeps
    ///     the author of the original commit.
    ///   - committer: the committer for the rebased commit. Required —
    ///     identifies the rebaser.
    ///   - message: the commit message. Passing `nil` keeps the original
    ///     commit's message.
    ///   - encoding: the message encoding, per libgit2's convention (`nil`
    ///     keeps the original; `"UTF-8"` is the common explicit value).
    /// - Throws:
    ///   - ``GitError/Code/unmerged`` when the index still contains
    ///     conflicts from the most recent ``next()``.
    ///   - ``GitError/Code/applied`` when the current patch is already in
    ///     `upstream` and there is nothing to commit.
    @discardableResult
    public func commit(
        author: Signature? = nil,
        committer: Signature,
        message: String? = nil,
        encoding: String? = nil
    ) throws(GitError) -> OID {
        try repository.lock.withLock { () throws(GitError) -> OID in
            let authorHandle: UnsafeMutablePointer<git_signature>?
            if let author {
                authorHandle = try repository.signatureHandle(for: author)
            } else {
                authorHandle = nil
            }
            defer { if let h = authorHandle { git_signature_free(h) } }

            let committerHandle = try repository.signatureHandle(for: committer)
            defer { git_signature_free(committerHandle) }

            var newOID = git_oid()
            let result: Int32 = try withOptionalCString(encoding) { encPtr throws(GitError) -> Int32 in
                try withOptionalCString(message) { msgPtr throws(GitError) -> Int32 in
                    git_rebase_commit(
                        &newOID,
                        handle,
                        authorHandle, committerHandle,
                        encPtr, msgPtr
                    )
                }
            }
            try check(result)
            return OID(raw: newOID)
        }
    }
}
