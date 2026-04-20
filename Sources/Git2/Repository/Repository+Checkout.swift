import Cgit2

extension Repository {
    /// Updates the working tree and index to match the commit HEAD points at.
    /// Equivalent to `git_checkout_head`.
    ///
    /// - Parameter options: Defaults to safe + no path filter.
    /// - Throws: ``GitError`` —
    ///   - ``GitError/Code/unbornBranch`` when HEAD is unborn.
    ///   - On a bare repository, libgit2 fails during HEAD resolution
    ///     before reaching the checkout engine; in practice this surfaces
    ///     as ``GitError/Code/unbornBranch`` with
    ///     ``GitError/Class/reference``. The exact class may change across
    ///     libgit2 versions.
    ///   - Checkout conflict errors (class ``GitError/Class/checkout``) when
    ///     `options.strategy` is safe and the working tree has divergent
    ///     changes.
    public func checkoutHead(
        options: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            try options.withCOptions { optsPtr throws(GitError) in
                try check(git_checkout_head(handle, optsPtr))
            }
        }
    }
}

extension Repository {
    /// Updates the working tree (and, by default, the index) to match `tree`.
    /// Equivalent to `git_checkout_tree`.
    ///
    /// Does **not** move HEAD. Pair with ``setHead(to:)`` (the `Commit`
    /// overload) or use ``checkout(branch:options:)`` when switching
    /// branches.
    public func checkoutTree(
        _ tree: Tree,
        options: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            try options.withCOptions { optsPtr throws(GitError) in
                try check(git_checkout_tree(handle, tree.handle, optsPtr))
            }
        }
    }

    /// Updates the working tree to match the tree pointed at by `commit`.
    /// Equivalent to `git_checkout_tree` with a commit treeish.
    ///
    /// Does **not** move HEAD. See the `Tree` overload of
    /// ``checkoutTree(_:options:)``.
    public func checkoutTree(
        _ commit: Commit,
        options: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            try options.withCOptions { optsPtr throws(GitError) in
                try check(git_checkout_tree(handle, commit.handle, optsPtr))
            }
        }
    }
}
