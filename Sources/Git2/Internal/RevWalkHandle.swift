import Cgit2

internal final class RevWalkHandle {
    private let repository: Repository
    private var walker: OpaquePointer?
    private var initialized = false

    init(repository: Repository, startOID: OID) {
        self.repository = repository
        repository.lock.withLock {
            var raw: OpaquePointer?
            guard git_revwalk_new(&raw, repository.handle) == 0, let created = raw else {
                return
            }
            var oidCopy = startOID.raw
            guard git_revwalk_push(created, &oidCopy) == 0 else {
                git_revwalk_free(created)
                return
            }
            self.walker = created
            self.initialized = true
        }
    }

    deinit {
        if let walker {
            git_revwalk_free(walker)
        }
    }

    func nextCommit() -> Commit? {
        guard initialized, let walker else { return nil }
        return repository.lock.withLock {
            var oid = git_oid()
            guard git_revwalk_next(&oid, walker) == 0 else { return nil }
            var commitHandle: OpaquePointer?
            guard git_commit_lookup(&commitHandle, repository.handle, &oid) == 0 else {
                return nil
            }
            return Commit(handle: commitHandle!, repository: repository)
        }
    }
}
