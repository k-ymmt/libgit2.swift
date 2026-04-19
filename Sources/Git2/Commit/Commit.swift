import Cgit2

public final class Commit: @unchecked Sendable {
    internal let handle: OpaquePointer
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_commit_free(handle)
    }

    public var oid: OID {
        repository.lock.withLock {
            OID(raw: git_commit_id(handle)!.pointee)
        }
    }

    public var message: String {
        repository.lock.withLock {
            String(cString: git_commit_message(handle)!)
        }
    }

    public var summary: String {
        repository.lock.withLock {
            String(cString: git_commit_summary(handle)!)
        }
    }

    public var body: String? {
        repository.lock.withLock {
            guard let cstr = git_commit_body(handle) else { return nil }
            return String(cString: cstr)
        }
    }

    public var author: Signature {
        repository.lock.withLock {
            Signature(copyingFrom: git_commit_author(handle))
        }
    }

    public var committer: Signature {
        repository.lock.withLock {
            Signature(copyingFrom: git_commit_committer(handle))
        }
    }

    public var parentCount: Int {
        repository.lock.withLock {
            Int(git_commit_parentcount(handle))
        }
    }

    public func parents() throws(GitError) -> [Commit] {
        try repository.lock.withLock { () throws(GitError) -> [Commit] in
            let count = git_commit_parentcount(handle)
            var out: [Commit] = []
            out.reserveCapacity(Int(count))
            for index: UInt32 in 0..<count {
                var raw: OpaquePointer?
                try check(git_commit_parent(&raw, handle, index))
                out.append(Commit(handle: raw!, repository: repository))
            }
            return out
        }
    }
}
