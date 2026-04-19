import Cgit2
import Foundation

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

    public var workingDirectory: URL? {
        lock.withLock {
            guard let cstr = git_repository_workdir(handle) else { return nil }
            return URL(fileURLWithPath: String(cString: cstr), isDirectory: true)
        }
    }

    public var gitDirectory: URL {
        lock.withLock {
            let cstr = git_repository_path(handle)
            return URL(fileURLWithPath: String(cString: cstr!), isDirectory: true)
        }
    }

    public var isBare: Bool {
        lock.withLock { git_repository_is_bare(handle) != 0 }
    }

    public var isHeadUnborn: Bool {
        lock.withLock { git_repository_head_unborn(handle) != 0 }
    }

    public func head() throws(GitError) -> Reference {
        try lock.withLock { () throws(GitError) -> Reference in
            var raw: OpaquePointer?
            try check(git_repository_head(&raw, handle))
            return Reference(handle: raw!, repository: self)
        }
    }

    public func commit(for oid: OID) throws(GitError) -> Commit {
        try lock.withLock { () throws(GitError) -> Commit in
            var oidCopy = oid.raw
            var raw: OpaquePointer?
            try check(git_commit_lookup(&raw, handle, &oidCopy))
            return Commit(handle: raw!, repository: self)
        }
    }
}
