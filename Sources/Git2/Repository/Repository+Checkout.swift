import Cgit2

extension Repository {
    /// Updates the working tree and index to match the commit HEAD points at.
    /// Equivalent to `git_checkout_head`.
    ///
    /// - Parameter options: Defaults to safe + no path filter.
    /// - Throws: ``GitError`` — ``GitError/Code/unbornBranch`` when HEAD is
    ///   unborn, a ``GitError/Class/repository`` error on a bare repo, and
    ///   the usual conflict errors when `options.strategy` is safe and the
    ///   working tree has divergent changes.
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
