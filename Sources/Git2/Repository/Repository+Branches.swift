import Cgit2

extension Repository {
    /// Creates a local branch `refs/heads/<name>` pointing at `target`.
    ///
    /// - Parameters:
    ///   - name: The short branch name (e.g. `"feature"`). No `refs/heads/` prefix.
    ///   - target: The commit the branch should point at.
    ///   - force: If `true`, overwrite an existing branch of the same name.
    /// - Returns: A ``Reference`` for the newly created branch.
    /// - Throws: ``GitError`` — ``GitError/Code/exists`` if the branch exists
    ///   and `force == false`; ``GitError/Code/invalidSpec`` for invalid names.
    public func createBranch(
        named name: String,
        at target: Commit,
        force: Bool = false
    ) throws(GitError) -> Reference {
        try lock.withLock { () throws(GitError) -> Reference in
            var out: OpaquePointer?
            let result: Int32 = name.withCString { namePtr in
                git_branch_create(&out, handle, namePtr, target.handle, force ? 1 : 0)
            }
            try check(result)
            return Reference(handle: out!, repository: self)
        }
    }

    /// Deletes the local branch `refs/heads/<name>`.
    ///
    /// libgit2 refuses to delete the branch currently checked out through HEAD.
    ///
    /// - Throws: ``GitError`` — ``GitError/Code/notFound`` if the branch does
    ///   not exist.
    public func deleteBranch(named name: String) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            var ref: OpaquePointer?
            let resultLookup: Int32 = name.withCString { namePtr in
                git_branch_lookup(&ref, handle, namePtr, GIT_BRANCH_LOCAL)
            }
            try check(resultLookup)
            defer { git_reference_free(ref) }
            try check(git_branch_delete(ref))
        }
    }
}
