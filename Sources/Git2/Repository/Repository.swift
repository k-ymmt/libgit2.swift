import Cgit2
import Foundation

/// An open Git repository.
///
/// ``Repository`` owns a libgit2 repository handle and frees it when the instance
/// is deallocated. All libgit2 operations against a repository — including those
/// performed through its child objects (``Reference``, ``Commit``) — are
/// serialized by an internal lock, so the repository is safe to share between
/// tasks.
///
/// Child objects hold a strong reference to their owning ``Repository``, which
/// means the repository stays alive at least as long as any reference or commit
/// derived from it. In practice you keep one ``Repository`` per open Git repo for
/// the lifetime of your app.
///
/// Call ``Git/bootstrap()`` before opening a repository. Forgetting to do so
/// trips a `preconditionFailure`.
public final class Repository: @unchecked Sendable {
    internal let handle: OpaquePointer
    internal let lock: HandleLock

    internal init(handle: OpaquePointer) {
        self.handle = handle
        self.lock = HandleLock()
    }

    deinit {
        git_repository_free(handle)
    }

    /// Opens an existing repository.
    ///
    /// - Parameter url: Either the working-tree directory of a non-bare repository
    ///   (the directory that contains `.git`) or the root of a bare repository.
    /// - Returns: An opened ``Repository``.
    /// - Throws: ``GitError`` — most commonly ``GitError/Code/notFound`` when
    ///   `url` is not a Git repository.
    /// - Precondition: ``Git/bootstrap()`` has been called.
    public static func open(at url: URL) throws(GitError) -> Repository {
        GitRuntime.shared.requireBootstrapped()
        var raw: OpaquePointer?
        let result: Int32 = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return GIT_EINVALIDSPEC.rawValue }
            return git_repository_open(&raw, path)
        }
        try check(result)
        return Repository(handle: raw!)
    }

    /// The working tree directory, or `nil` for bare repositories.
    public var workingDirectory: URL? {
        lock.withLock {
            guard let cstr = git_repository_workdir(handle) else { return nil }
            return URL(fileURLWithPath: String(cString: cstr), isDirectory: true)
        }
    }

    /// The `.git` directory for a non-bare repository, or the repository root for
    /// a bare repository.
    public var gitDirectory: URL {
        lock.withLock {
            // libgit2 contract: git_repository_path is non-NULL for a valid handle.
            let cstr = git_repository_path(handle)
            return URL(fileURLWithPath: String(cString: cstr!), isDirectory: true)
        }
    }

    /// Whether the repository is bare (no working tree).
    public var isBare: Bool {
        lock.withLock { git_repository_is_bare(handle) != 0 }
    }

    /// Whether HEAD currently points at a branch that has no commits yet.
    ///
    /// Newly initialized repositories start out with an unborn HEAD until the
    /// first commit is made.
    public var isHeadUnborn: Bool {
        lock.withLock { git_repository_head_unborn(handle) != 0 }
    }

    /// Resolves the repository's HEAD to a ``Reference``.
    ///
    /// - Returns: The reference HEAD currently points at (direct or symbolic).
    /// - Throws: ``GitError`` — notably ``GitError/Code/unbornBranch`` when the
    ///   repository has no commits yet.
    public func head() throws(GitError) -> Reference {
        try lock.withLock { () throws(GitError) -> Reference in
            var raw: OpaquePointer?
            try check(git_repository_head(&raw, handle))
            return Reference(handle: raw!, repository: self)
        }
    }

    /// Looks up a commit by its OID.
    ///
    /// - Parameter oid: The object identifier of the commit.
    /// - Returns: A ``Commit`` handle to that commit.
    /// - Throws: ``GitError`` — typically ``GitError/Code/notFound`` when no
    ///   object exists with the given OID, or when the object exists but is not
    ///   a commit.
    public func commit(for oid: OID) throws(GitError) -> Commit {
        try lock.withLock { () throws(GitError) -> Commit in
            var oidCopy = oid.raw
            var raw: OpaquePointer?
            try check(git_commit_lookup(&raw, handle, &oidCopy))
            return Commit(handle: raw!, repository: self)
        }
    }
}
