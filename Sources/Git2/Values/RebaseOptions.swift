import Cgit2

extension Repository {
    /// Options forwarded to libgit2's `git_rebase_init` and `git_rebase_open`.
    ///
    /// The default value (`RebaseOptions()`) maps to libgit2's defaults —
    /// `quiet = false`, `inMemory = false`, no rewrite-notes ref, default
    /// merge / checkout options.
    public struct RebaseOptions: Sendable, Equatable {
        /// Advisory "quiet" hint. libgit2 itself does not act on this flag;
        /// it is passed through for interoperability with other Git tools.
        public var quiet: Bool

        /// When `true`, runs the rebase entirely in memory — HEAD is not
        /// rewound, `.git/rebase-merge/` is not written, and the working
        /// tree is not touched. Pair with ``Rebase/inMemoryIndex()`` to read
        /// the per-operation result.
        public var inMemory: Bool

        /// When non-nil, `git_rebase_finish` rewrites notes (in the named
        /// ref) for the rebased commits. When `nil`, libgit2 consults the
        /// `notes.rewriteRef` / `notes.rewrite.rebase` config keys and
        /// defaults to not rewriting.
        public var rewriteNotesRef: String?

        /// Passed to `git_rebase_next` to control the 3-way merge used
        /// during each patch application.
        public var merge: MergeOptions

        /// Passed to `git_rebase_init`, `git_rebase_next`, and
        /// `git_rebase_abort`. libgit2 implicitly adds `GIT_CHECKOUT_FORCE`
        /// on `abort` to match `git` semantics, regardless of the value set
        /// here.
        public var checkout: CheckoutOptions

        public init(
            quiet: Bool = false,
            inMemory: Bool = false,
            rewriteNotesRef: String? = nil,
            merge: MergeOptions = MergeOptions(),
            checkout: CheckoutOptions = CheckoutOptions()
        ) {
            self.quiet = quiet
            self.inMemory = inMemory
            self.rewriteNotesRef = rewriteNotesRef
            self.merge = merge
            self.checkout = checkout
        }
    }
}
