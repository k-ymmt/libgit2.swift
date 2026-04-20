import Cgit2

extension Repository {
    /// Options forwarded to libgit2's `git_checkout_*` family.
    ///
    /// The default value (`CheckoutOptions()`) maps to `GIT_CHECKOUT_SAFE`
    /// with no path filter — the same as what libgit2 uses when you pass
    /// `NULL` for the options.
    public struct CheckoutOptions: Sendable, Equatable {
        /// Checkout strategy flags. Empty set == `GIT_CHECKOUT_SAFE`.
        public var strategy: Strategy

        /// Optional pathspec. Empty array (default) means "all paths".
        ///
        /// Each entry is a wildmatch pattern against repository-relative
        /// paths (forward slashes, no leading separator). Pass
        /// ``Strategy/disablePathspecMatch`` in ``strategy`` to treat the
        /// list as exact matches.
        public var paths: [String]

        public init(strategy: Strategy = [], paths: [String] = []) {
            self.strategy = strategy
            self.paths = paths
        }
    }
}

extension Repository.CheckoutOptions {
    /// Checkout strategy flags. Bit values match `git_checkout_strategy_t`.
    public struct Strategy: OptionSet, Sendable, Equatable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        public static let force                  = Strategy(rawValue: 1 << 1)
        public static let recreateMissing        = Strategy(rawValue: 1 << 2)
        public static let allowConflicts         = Strategy(rawValue: 1 << 4)
        public static let removeUntracked        = Strategy(rawValue: 1 << 5)
        public static let removeIgnored          = Strategy(rawValue: 1 << 6)
        public static let updateOnly             = Strategy(rawValue: 1 << 7)
        public static let dontUpdateIndex        = Strategy(rawValue: 1 << 8)
        public static let noRefresh              = Strategy(rawValue: 1 << 9)
        public static let disablePathspecMatch   = Strategy(rawValue: 1 << 13)
        public static let skipLockedDirectories  = Strategy(rawValue: 1 << 18)
        public static let dontOverwriteIgnored   = Strategy(rawValue: 1 << 19)
        public static let conflictStyleMerge     = Strategy(rawValue: 1 << 20)
        public static let conflictStyleDiff3     = Strategy(rawValue: 1 << 21)
        public static let dontRemoveExisting     = Strategy(rawValue: 1 << 22)
        public static let dontWriteIndex         = Strategy(rawValue: 1 << 23)
        public static let dryRun                 = Strategy(rawValue: 1 << 24)
        public static let conflictStyleZdiff3    = Strategy(rawValue: 1 << 25)
    }
}
