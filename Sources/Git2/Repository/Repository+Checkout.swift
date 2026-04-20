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
