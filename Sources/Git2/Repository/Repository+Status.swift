import Cgit2

extension Repository {
    /// Opens a live handle over a `git_status_list`. The entry set is
    /// frozen at creation time — later workdir mutations require a fresh
    /// call.
    ///
    /// - Parameter options: Filter / display options. See ``Repository/StatusOptions``.
    /// - Throws: ``GitError`` — notably ``GitError/Code/bareRepo`` on a
    ///   bare repository.
    public func statusList(
        options: Repository.StatusOptions = Repository.StatusOptions()
    ) throws(GitError) -> StatusList {
        try lock.withLock { () throws(GitError) -> StatusList in
            try options.withCOptions { optsPtr throws(GitError) in
                var raw: OpaquePointer?
                try check(git_status_list_new(&raw, handle, optsPtr))
                return StatusList(handle: raw!, repository: self)
            }
        }
    }
}
