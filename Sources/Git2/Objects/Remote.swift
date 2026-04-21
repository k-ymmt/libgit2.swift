import Cgit2

/// A libgit2 remote handle.
///
/// ``Remote`` wraps `git_remote *`. Instances are produced by
/// ``Repository/createRemote(named:url:)``,
/// ``Repository/createRemote(named:url:fetchspec:)``, or
/// ``Repository/lookupRemote(named:)``. Serialization is the parent
/// repository's ``HandleLock`` — methods on ``Remote`` take
/// `repository.lock.withLock` once at the top.
///
/// ``fetch(refspecs:options:reflogMessage:)`` holds the lock across the
/// entire network round-trip, including the synchronous callbacks. A
/// callback that reaches back into `repository.*` will deadlock; see
/// ``Repository/FetchOptions`` for the full rule.
public final class Remote: @unchecked Sendable {
    internal let handle: OpaquePointer

    /// The repository this remote belongs to.
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_remote_free(handle)
    }
}

extension Remote {
    /// Wraps `git_remote_name`. `nil` for in-memory / anonymous remotes
    /// (v0.5b-i does not produce these; nullability mirrors libgit2).
    public var name: String? {
        repository.lock.withLock {
            guard let cstr = git_remote_name(handle) else { return nil }
            return String(cString: cstr)
        }
    }

    /// Wraps `git_remote_url`.
    public var url: String? {
        repository.lock.withLock {
            guard let cstr = git_remote_url(handle) else { return nil }
            return String(cString: cstr)
        }
    }

    /// Wraps `git_remote_pushurl`. `nil` means "push uses the same URL
    /// as fetch".
    public var pushURL: String? {
        repository.lock.withLock {
            guard let cstr = git_remote_pushurl(handle) else { return nil }
            return String(cString: cstr)
        }
    }
}
