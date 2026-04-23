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

    /// Returns a snapshot of every file matching `options`.
    ///
    /// Internally: `statusList(options:)` → materialize via `count` +
    /// `subscript(_:)` → drop the list (freeing the libgit2 handle) before
    /// returning.
    ///
    /// - Throws: ``GitError`` — notably ``GitError/Code/bareRepo`` on a bare
    ///   repository.
    public func statusEntries(
        options: Repository.StatusOptions = Repository.StatusOptions()
    ) throws(GitError) -> [StatusEntry] {
        let list = try statusList(options: options)
        return (0..<list.count).map { list[$0] }
    }

    /// Status for a single exact path, relative to the working directory.
    ///
    /// Does **not** do rename detection — libgit2's `git_status_file`
    /// cannot. Use ``statusEntries(options:)`` with
    /// ``Repository/StatusOptions/Flags/renamesHeadToIndex`` /
    /// ``Repository/StatusOptions/Flags/renamesIndexToWorkdir`` if you need renames.
    ///
    /// - Throws: ``GitError``.
    ///   - ``GitError/Code/notFound`` if `path` is not in HEAD, the index,
    ///     or the workdir.
    ///   - ``GitError/Code/ambiguous`` if `path` matches multiple files or
    ///     refers to a directory.
    ///   - ``GitError/Code/bareRepo`` on a bare repository.
    public func status(forPath path: String) throws(GitError) -> StatusFlags {
        try lock.withLock { () throws(GitError) -> StatusFlags in
            var flags: UInt32 = 0
            // withCString doesn't forward typed throws; shuttle via Result.
            let result: Result<UInt32, GitError> = path.withCString { cpath in
                do {
                    try check(git_status_file(&flags, handle, cpath))
                    return .success(flags)
                } catch let error as GitError {
                    return .failure(error)
                } catch {
                    fatalError("unreachable: typed throws guarantees GitError")
                }
            }
            return StatusFlags(rawValue: try result.get())
        }
    }
}
