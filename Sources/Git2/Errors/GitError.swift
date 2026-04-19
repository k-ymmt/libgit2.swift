/// Every failure raised by the Git2 wrapper.
///
/// ``GitError`` carries the libgit2 return code (see ``Code``), the broad category
/// of subsystem that raised it (see ``Class``), and a human-readable message.
///
/// The full breadth of libgit2's error taxonomy is exposed via the two nested enums
/// rather than a deep `enum` hierarchy. This keeps `catch` sites concise:
///
/// ```swift
/// do {
///     _ = try repo.reference(named: "refs/heads/missing")
/// } catch let error as GitError where error.code == .notFound {
///     // Branch on the code you care about; let others propagate.
/// }
/// ```
///
/// Every public failing API in Git2 uses typed throws (`throws(GitError)`), so the
/// concrete type is already known at the `catch` site.
public struct GitError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The libgit2 return code.
    public let code: Code

    /// The libgit2 subsystem that raised the error.
    public let `class`: Class

    /// The human-readable message reported by libgit2.
    ///
    /// Messages are English-only; Git2 does not localize them.
    public let message: String

    /// Creates a `GitError` from explicit components. Intended primarily for tests;
    /// production code receives errors from libgit2 through the wrapper.
    public init(code: Code, class: Class, message: String) {
        self.code = code
        self.class = `class`
        self.message = message
    }

    public var description: String {
        "GitError(\(code), \(`class`)): \(message)"
    }

    /// The libgit2 return code.
    ///
    /// New codes introduced by future libgit2 releases are surfaced via ``unknown(_:)``
    /// so Git2 does not need to be rebuilt to accept them.
    public enum Code: Sendable, Equatable {
        /// No error. Not normally thrown; included for completeness.
        case ok
        /// The requested object or reference was not found.
        case notFound
        /// The object or reference already exists.
        case exists
        /// Ambiguous short OID or reference name.
        case ambiguous
        /// An output buffer was too small to hold the result.
        case bufferTooShort
        /// A user-supplied callback returned a non-zero status.
        case user
        /// Operation requires a non-bare repository.
        case bareRepo
        /// The repository's HEAD points at a branch with no commits yet.
        case unbornBranch
        /// Working tree is unmerged (there is an in-progress merge).
        case unmerged
        /// Attempted non-fast-forward update without forcing.
        case nonFastForward
        /// A reference name or refspec is syntactically invalid.
        case invalidSpec
        /// A merge or checkout conflict prevents the operation.
        case conflict
        /// Lock file already held; another process is modifying the repo.
        case locked
        /// Reference has been modified since the operation began.
        case modified
        /// Authentication failed or is required.
        case auth
        /// A certificate was invalid or could not be verified.
        case certificate
        /// The patch is already applied.
        case applied
        /// Unable to peel the reference to the requested object type.
        case peel
        /// Unexpected end of file while reading.
        case endOfFile
        /// An argument or value is invalid.
        case invalid
        /// The working tree has uncommitted changes blocking the operation.
        case uncommitted
        /// A path refers to a directory when a file was expected (or vice versa).
        case directory
        /// A merge operation ended in conflict.
        case mergeConflict
        /// A libgit2 operation elected to pass through to default handling.
        case passthrough
        /// Iteration completed (returned by walker-style APIs). Treated as a normal
        /// terminating condition by ``CommitIterator``.
        case iterationOver
        /// A retryable condition was encountered.
        case retry
        /// Object or data mismatch.
        case mismatch
        /// The index has uncommitted dirty changes.
        case indexDirty
        /// Applying a patch failed.
        case applyFail
        /// Object ownership / safe-directory check failed.
        case owner
        /// An operation timed out.
        case timeout
        /// The object or state is unchanged; no work was performed.
        case unchanged
        /// A requested feature is not supported by this libgit2 build.
        case notSupported
        /// Attempted to modify something that is read-only.
        case readOnly
        /// A libgit2 return code this version of Git2 does not have a named case for.
        case unknown(Int32)
    }

    /// The libgit2 subsystem that raised an error.
    ///
    /// New classes introduced by future libgit2 releases are surfaced via
    /// ``unknown(_:)``.
    public enum Class: Sendable, Equatable {
        case none
        case noMemory
        case os
        case invalid
        case reference
        case zlib
        case repository
        case config
        case regex
        case odb
        case index
        case object
        case net
        case tag
        case tree
        case indexer
        case ssl
        case submodule
        case thread
        case stash
        case checkout
        case fetchHead
        case merge
        case ssh
        case filter
        case revert
        case callback
        case cherrypick
        case describe
        case rebase
        case filesystem
        case patch
        case worktree
        case sha
        case http
        case `internal`
        case grafts
        /// A libgit2 error class this version of Git2 does not have a named case for.
        case unknown(Int32)
    }
}
