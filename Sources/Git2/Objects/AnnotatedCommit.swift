import Cgit2

/// A libgit2 annotated commit.
///
/// An annotated commit carries both a commit OID and *provenance* — how the
/// commit was resolved (from a local ref, from FETCH_HEAD, from a revspec).
/// The provenance is what drives reflog messages and `ORIG_HEAD` recording
/// when the annotated commit is passed to ``Repository/merge(_:mergeOptions:checkoutOptions:)-<AnnotatedCommit-array-overload>``
/// / ``Repository/setHead(detachedAtAnnotated:)`` / (in v0.5a-ii)
/// `rebase`.
///
/// Instances are produced by ``Repository/annotatedCommit(for:)`` (reference
/// or OID) and ``Repository/annotatedCommit(from:)`` (commit).
///
/// An `AnnotatedCommit` is typically used for a single merge / analysis call
/// and then released. Re-using the same handle across multiple operations is
/// not explicitly supported by libgit2's documentation; callers who need
/// deterministic reflog behavior should create a fresh handle per operation.
public final class AnnotatedCommit: @unchecked Sendable {
    internal let handle: OpaquePointer

    /// The repository this annotated commit belongs to.
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_annotated_commit_free(handle)
    }

    /// The OID of the underlying commit.
    public var oid: OID {
        repository.lock.withLock {
            // libgit2 contract: git_annotated_commit_id is non-NULL for a valid handle.
            OID(raw: git_annotated_commit_id(handle)!.pointee)
        }
    }

    /// The ref name this annotated commit was resolved from, if any.
    /// Returns `nil` when the handle was created via OID lookup.
    public var refName: String? {
        repository.lock.withLock {
            guard let cStr = git_annotated_commit_ref(handle) else { return nil }
            let s = String(cString: cStr)
            return s.isEmpty ? nil : s
        }
    }
}
