import Cgit2

extension Index {
    /// Materializes this index into the parent repository's working tree.
    /// Sugar for ``Repository/checkoutIndex(_:options:)`` with `self`.
    public func checkout(
        options: Repository.CheckoutOptions = Repository.CheckoutOptions()
    ) throws(GitError) {
        try repository.checkoutIndex(self, options: options)
    }
}
