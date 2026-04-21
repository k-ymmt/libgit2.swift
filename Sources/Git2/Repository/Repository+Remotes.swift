import Cgit2

extension Repository {
    /// Wraps `git_remote_create`. The default fetch refspec
    /// `+refs/heads/*:refs/remotes/<name>/*` is installed automatically.
    public func createRemote(named name: String, url: String) throws(GitError) -> Remote {
        try lock.withLock { () throws(GitError) -> Remote in
            var raw: OpaquePointer?
            try check(git_remote_create(&raw, handle, name, url))
            return Remote(handle: raw!, repository: self)
        }
    }

    /// Wraps `git_remote_create_with_fetchspec`.
    public func createRemote(
        named name: String,
        url: String,
        fetchspec: String
    ) throws(GitError) -> Remote {
        try lock.withLock { () throws(GitError) -> Remote in
            var raw: OpaquePointer?
            try check(git_remote_create_with_fetchspec(&raw, handle, name, url, fetchspec))
            return Remote(handle: raw!, repository: self)
        }
    }

    /// Wraps `git_remote_lookup`. Throws ``GitError/Code/notFound`` when
    /// the remote is not configured.
    public func lookupRemote(named name: String) throws(GitError) -> Remote {
        try lock.withLock { () throws(GitError) -> Remote in
            var raw: OpaquePointer?
            try check(git_remote_lookup(&raw, handle, name))
            return Remote(handle: raw!, repository: self)
        }
    }

    /// Wraps `git_remote_list`. Order matches libgit2's return.
    public func remotes() throws(GitError) -> [String] {
        try lock.withLock { () throws(GitError) -> [String] in
            var arr = git_strarray()
            try check(git_remote_list(&arr, handle))
            defer { git_strarray_dispose(&arr) }
            return (0..<arr.count).compactMap { i -> String? in
                guard let cstr = arr.strings[i] else { return nil }
                return String(cString: cstr)
            }
        }
    }

    /// Wraps `git_remote_name_is_valid`. Pure validation; does not touch
    /// config.
    public static func isValidRemoteName(_ name: String) -> Bool {
        var out: Int32 = 0
        let rc = git_remote_name_is_valid(&out, name)
        return rc == 0 && out != 0
    }
}

extension Repository {
    /// Wraps `git_remote_delete`. Removes the `[remote "<name>"]` config
    /// block and any `refs/remotes/<name>/*` tracking refs.
    public func deleteRemote(named name: String) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            try check(git_remote_delete(handle, name))
        }
    }

    /// Wraps `git_remote_rename`. Returns refspecs libgit2 could not
    /// rewrite automatically (typically refspecs that do not mention
    /// the old name). Empty array means a clean rename.
    @discardableResult
    public func renameRemote(from oldName: String, to newName: String)
        throws(GitError) -> [String]
    {
        try lock.withLock { () throws(GitError) -> [String] in
            var arr = git_strarray()
            try check(git_remote_rename(&arr, handle, oldName, newName))
            defer { git_strarray_dispose(&arr) }
            return (0..<arr.count).compactMap { i -> String? in
                guard let cstr = arr.strings[i] else { return nil }
                return String(cString: cstr)
            }
        }
    }
}
