import Cgit2

public final class Reference: @unchecked Sendable {
    internal let handle: OpaquePointer
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_reference_free(handle)
    }

    public var name: String {
        repository.lock.withLock {
            String(cString: git_reference_name(handle)!)
        }
    }

    public var shorthand: String {
        repository.lock.withLock {
            String(cString: git_reference_shorthand(handle)!)
        }
    }

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

    public func resolveToCommit() throws(GitError) -> Commit {
        try repository.lock.withLock { () throws(GitError) -> Commit in
            var raw: OpaquePointer?
            try check(git_reference_peel(&raw, handle, GIT_OBJECT_COMMIT))
            return Commit(handle: raw!, repository: repository)
        }
    }
}
