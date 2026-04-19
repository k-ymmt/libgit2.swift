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
}
