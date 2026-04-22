import Cgit2

extension Repository {
    /// Configuration for ``pull(remoteNamed:branchNamed:options:)``.
    ///
    /// Composite of the sub-option value types used by the fetch, merge,
    /// and checkout phases. Mirror of the `RebaseOptions` composition
    /// pattern.
    public struct PullOptions: Sendable {
        /// Fetch-phase options (credentials / certificate check /
        /// transfer progress / prune / depth / etc). See
        /// ``FetchOptions``.
        public var fetch: FetchOptions

        /// Merge-phase options (rename threshold, file favor, recursion).
        /// Forwarded verbatim to the merge dispatch.
        public var merge: MergeOptions

        /// Checkout-phase options applied when the analysis resolves to
        /// `.fastForward`, `.unborn`, or `.normal`. Forwarded verbatim.
        public var checkout: CheckoutOptions

        /// When `false`, the pull aborts with
        /// ``GitError/Code/nonFastForward`` / ``GitError/Class/merge``
        /// if the merge analysis returns `.normal` (i.e. a real merge
        /// commit would be required). The fetch phase has already
        /// completed at that point; the remote-tracking ref and
        /// `FETCH_HEAD` are updated but HEAD and the working tree are
        /// untouched. `.fastForward`, `.upToDate`, and `.unborn` are
        /// unaffected. Default `true`.
        public var allowNonFastForward: Bool

        /// Reflog message written by the fetch phase on the
        /// remote-tracking ref and `FETCH_HEAD`. `nil` delegates to
        /// libgit2's default (`"fetch"`). The merge phase's reflog
        /// message is libgit2's automatic `"merge FETCH_HEAD: …"`
        /// string and is not controllable through this option.
        public var reflogMessage: String?

        public init(
            fetch: FetchOptions = FetchOptions(),
            merge: MergeOptions = MergeOptions(),
            checkout: CheckoutOptions = CheckoutOptions(),
            allowNonFastForward: Bool = true,
            reflogMessage: String? = nil
        ) {
            self.fetch = fetch
            self.merge = merge
            self.checkout = checkout
            self.allowNonFastForward = allowNonFastForward
            self.reflogMessage = reflogMessage
        }
    }
}
