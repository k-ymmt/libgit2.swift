import Cgit2

extension Repository {
    /// Computes the file-level diff between two trees.
    ///
    /// - Parameters:
    ///   - old: The "from" tree, or `nil` for the empty tree (useful for the
    ///     initial commit — every file appears as an addition).
    ///   - new: The "to" tree, or `nil` for the empty tree (useful for
    ///     computing a full-deletion set).
    /// - Returns: A ``Diff`` describing file-level changes.
    /// - Throws: ``GitError``. If both `old` and `new` are `nil` the call
    ///   throws ``GitError/Code/invalid`` without calling libgit2.
    public func diff(from old: Tree?, to new: Tree?) throws(GitError) -> Diff {
        if old == nil, new == nil {
            throw GitError(
                code: .invalid,
                class: .invalid,
                message: "diff requires at least one tree"
            )
        }
        return try lock.withLock { () throws(GitError) -> Diff in
            var raw: OpaquePointer?
            try check(git_diff_tree_to_tree(
                &raw,
                handle,
                old?.handle,
                new?.handle,
                nil
            ))
            return Diff(handle: raw!, repository: self)
        }
    }
}
