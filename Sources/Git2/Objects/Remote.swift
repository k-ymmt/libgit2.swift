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
    /// Wraps `git_remote_get_fetch_refspecs`.
    public var fetchRefspecs: [Refspec] {
        get throws(GitError) {
            try readRefspecs(via: git_remote_get_fetch_refspecs)
        }
    }

    /// Wraps `git_remote_get_push_refspecs`.
    public var pushRefspecs: [Refspec] {
        get throws(GitError) {
            try readRefspecs(via: git_remote_get_push_refspecs)
        }
    }

    private func readRefspecs(
        via libgit2Call: (UnsafeMutablePointer<git_strarray>, OpaquePointer) -> Int32
    ) throws(GitError) -> [Refspec] {
        try repository.lock.withLock { () throws(GitError) -> [Refspec] in
            var arr = git_strarray()
            try check(libgit2Call(&arr, handle))
            defer { git_strarray_dispose(&arr) }
            return (0..<arr.count).compactMap { i -> Refspec? in
                guard let cstr = arr.strings[i] else { return nil }
                return Refspec(String(cString: cstr))
            }
        }
    }
}

extension Remote {
    /// Wraps `git_remote_fetch`. Downloads new objects from the remote
    /// into the local ODB and updates the configured remote-tracking
    /// refs. Holds the repository lock across the entire network
    /// round-trip.
    ///
    /// - Parameters:
    ///   - refspecs: Override the remote's configured fetch refspecs.
    ///     Pass `nil` (default) to use the configured list.
    ///   - options: Callbacks and scalar settings. Callbacks are
    ///     invoked synchronously on the fetch thread; do not reach
    ///     back into `repository.*` from inside them.
    ///   - reflogMessage: Custom reflog message for any ref updates
    ///     this fetch causes. `nil` (default) lets libgit2 generate
    ///     the default `"fetch"` message.
    public func fetch(
        refspecs: [Refspec]? = nil,
        options: Repository.FetchOptions = Repository.FetchOptions(),
        reflogMessage: String? = nil
    ) throws(GitError) {
        try repository.lock.withLock { () throws(GitError) in
            try withRemoteCallbacks(options) { cbsPtr, ctx throws(GitError) in
                var fetchOpts = git_fetch_options()
                let initRC = git_fetch_options_init(&fetchOpts, UInt32(GIT_FETCH_OPTIONS_VERSION))
                precondition(initRC == 0)
                fetchOpts.callbacks        = cbsPtr.pointee
                fetchOpts.prune            = options.prune.asGit
                fetchOpts.update_fetchhead = options.updateFetchHead
                    ? UInt32(GIT_REMOTE_UPDATE_FETCHHEAD.rawValue)
                    : 0
                fetchOpts.download_tags    = options.downloadTags.asGit
                fetchOpts.depth            = Int32(truncatingIfNeeded: options.depth)
                fetchOpts.follow_redirects = options.followRedirects.asGit

                let specs = refspecs?.map(\.string) ?? []
                let rc: Int32 = try withGitStrArray(specs) { (specsPtr: UnsafePointer<git_strarray>?) throws(GitError) -> Int32 in
                    return try withGitStrArray(options.customHeaders) { (headersPtr: UnsafePointer<git_strarray>?) throws(GitError) -> Int32 in
                        if let headersPtr {
                            fetchOpts.custom_headers = headersPtr.pointee
                        }
                        // Pass refspecs pointer (may be nil for "use configured").
                        return git_remote_fetch(
                            self.handle,
                            specsPtr,
                            &fetchOpts,
                            reflogMessage
                        )
                    }
                }

                if let captured = ctx.capturedError {
                    if let gitErr = captured as? GitError { throw gitErr }
                    throw GitError(
                        code: .user,
                        class: .callback,
                        message: String(describing: captured)
                    )
                }
                try check(rc)
            }
        }
    }
}

// MARK: - FetchOptions enum ↔ libgit2 bridges

extension Repository.FetchOptions.PruneSetting {
    internal var asGit: git_fetch_prune_t {
        switch self {
        case .unspecified: return GIT_FETCH_PRUNE_UNSPECIFIED
        case .prune:       return GIT_FETCH_PRUNE
        case .noPrune:     return GIT_FETCH_NO_PRUNE
        }
    }
}

extension Repository.FetchOptions.AutotagOption {
    internal var asGit: git_remote_autotag_option_t {
        switch self {
        case .unspecified: return GIT_REMOTE_DOWNLOAD_TAGS_UNSPECIFIED
        case .auto:        return GIT_REMOTE_DOWNLOAD_TAGS_AUTO
        case .none:        return GIT_REMOTE_DOWNLOAD_TAGS_NONE
        case .all:         return GIT_REMOTE_DOWNLOAD_TAGS_ALL
        }
    }
}

extension Repository.FetchOptions.RedirectPolicy {
    internal var asGit: git_remote_redirect_t {
        switch self {
        case .none:    return GIT_REMOTE_REDIRECT_NONE
        case .initial: return GIT_REMOTE_REDIRECT_INITIAL
        case .all:     return GIT_REMOTE_REDIRECT_ALL
        }
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
