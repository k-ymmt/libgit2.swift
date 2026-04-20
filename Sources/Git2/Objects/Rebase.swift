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
    /// Wraps `git_rebase_operation_entrycount`. Total operation count.
    public var operationCount: Int {
        repository.lock.withLock { git_rebase_operation_entrycount(handle) }
    }

    /// Wraps `git_rebase_operation_current`. The index of the currently
    /// applying operation, or `nil` before the first ``next()`` call
    /// (libgit2's `GIT_REBASE_NO_OPERATION` sentinel = `SIZE_MAX`, which
    /// bridges to `-1` when the `size_t` return value is imported as `Int`).
    public var currentOperationIndex: Int? {
        repository.lock.withLock {
            let raw = git_rebase_operation_current(handle)
            // `size_t` bridges to `Int` here, and `GIT_REBASE_NO_OPERATION`
            // (`SIZE_MAX`) imports as `UInt`. Compare via the signed bit
            // pattern so the sentinel matches regardless of Clang's import
            // choice for the macro type.
            return raw == Int(bitPattern: GIT_REBASE_NO_OPERATION) ? nil : raw
        }
    }

    /// Wraps `git_rebase_operation_byindex`. Returns `nil` when `index` is
    /// out of bounds.
    public func operation(at index: Int) -> RebaseOperation? {
        repository.lock.withLock {
            guard let opPtr = git_rebase_operation_byindex(handle, index) else {
                return nil
            }
            return RebaseOperation(copyingFrom: opPtr)
        }
    }

    /// Wraps `git_rebase_orig_head_name`. `nil` when HEAD was detached at
    /// rebase start (no ref name to record).
    public var origHeadName: String? {
        repository.lock.withLock {
            guard let c = git_rebase_orig_head_name(handle) else { return nil }
            let s = String(cString: c)
            return s.isEmpty ? nil : s
        }
    }

    /// Wraps `git_rebase_orig_head_id`. `nil` when the rebase has no
    /// recorded original HEAD id.
    public var origHeadOid: OID? {
        repository.lock.withLock {
            guard let p = git_rebase_orig_head_id(handle) else { return nil }
            return OID(raw: p.pointee)
        }
    }

    /// Wraps `git_rebase_onto_name`.
    public var ontoName: String? {
        repository.lock.withLock {
            guard let c = git_rebase_onto_name(handle) else { return nil }
            let s = String(cString: c)
            return s.isEmpty ? nil : s
        }
    }

    /// Wraps `git_rebase_onto_id`.
    public var ontoOid: OID? {
        repository.lock.withLock {
            guard let p = git_rebase_onto_id(handle) else { return nil }
            return OID(raw: p.pointee)
        }
    }
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

extension Rebase {
    /// Wraps `git_rebase_finish`. Finalizes a rebase after every operation
    /// has been applied. Removes `.git/rebase-merge/`. Optionally writes a
    /// reflog signature line.
    public func finish(signature: Signature? = nil) throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            let sigHandle: UnsafeMutablePointer<git_signature>?
            if let signature {
                sigHandle = try repository.signatureHandle(for: signature)
            } else {
                sigHandle = nil
            }
            defer { if let h = sigHandle { git_signature_free(h) } }

            try check(git_rebase_finish(handle, sigHandle))
        }
    }

    /// Wraps `git_rebase_abort`. Aborts the rebase and restores the
    /// repository + working tree to their state before rebase began.
    /// libgit2 implicitly applies `GIT_CHECKOUT_FORCE` during this restore.
    public func abort() throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            try check(git_rebase_abort(handle))
        }
    }
}

extension Rebase {
    /// Wraps `git_rebase_inmemory_index`. Returns the index produced by the
    /// last ``next()``.
    ///
    /// Only valid when the rebase was initialized with
    /// ``Repository/RebaseOptions/inMemory`` set to `true`. Calling this on
    /// an on-disk rebase surfaces libgit2's error unchanged.
    public func inMemoryIndex() throws(GitError) -> Index {
        try repository.lock.withLock { () throws(GitError) -> Index in
            var out: OpaquePointer?
            try check(git_rebase_inmemory_index(&out, handle))
            return Index(handle: out!, repository: repository)
        }
    }
}
