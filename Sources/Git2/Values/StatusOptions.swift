import Cgit2

/// Options forwarded to libgit2's `git_status_*` family. A default value
/// (`StatusOptions()`) matches what `git_status_options_init` installs plus
/// `GIT_STATUS_OPT_DEFAULTS`, which closely mirrors the `git status` CLI's
/// baseline behavior (include untracked + ignored + recurse untracked dirs).
public struct StatusOptions: Sendable {
    /// Which comparison the status scan performs.
    public enum Show: Sendable, Equatable {
        /// `GIT_STATUS_SHOW_INDEX_AND_WORKDIR` (default).
        case indexAndWorkdir
        /// `GIT_STATUS_SHOW_INDEX_ONLY` — HEAD↔index only.
        case indexOnly
        /// `GIT_STATUS_SHOW_WORKDIR_ONLY` — index↔workdir only.
        case workdirOnly
    }

    /// Flag bits controlling which files are reported and how. Mirrors
    /// `git_status_opt_t`.
    public struct Flags: OptionSet, Sendable, Hashable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        public static let includeUntracked             = Flags(rawValue: 1 << 0)
        public static let includeIgnored               = Flags(rawValue: 1 << 1)
        public static let includeUnmodified            = Flags(rawValue: 1 << 2)
        public static let excludeSubmodules            = Flags(rawValue: 1 << 3)
        public static let recurseUntrackedDirs         = Flags(rawValue: 1 << 4)
        public static let disablePathspecMatch         = Flags(rawValue: 1 << 5)
        public static let recurseIgnoredDirs           = Flags(rawValue: 1 << 6)
        public static let renamesHeadToIndex           = Flags(rawValue: 1 << 7)
        public static let renamesIndexToWorkdir        = Flags(rawValue: 1 << 8)
        public static let sortCaseSensitively          = Flags(rawValue: 1 << 9)
        public static let sortCaseInsensitively        = Flags(rawValue: 1 << 10)
        public static let renamesFromRewrites          = Flags(rawValue: 1 << 11)
        public static let noRefresh                    = Flags(rawValue: 1 << 12)
        public static let updateIndex                  = Flags(rawValue: 1 << 13)
        public static let includeUnreadable            = Flags(rawValue: 1 << 14)
        public static let includeUnreadableAsUntracked = Flags(rawValue: 1 << 15)

        /// Mirrors `GIT_STATUS_OPT_DEFAULTS`:
        /// `INCLUDE_IGNORED | INCLUDE_UNTRACKED | RECURSE_UNTRACKED_DIRS`.
        public static let defaults: Flags =
            [.includeIgnored, .includeUntracked, .recurseUntrackedDirs]
    }

    public var show: Show
    public var flags: Flags
    /// Empty array means "all paths". Entries are wildmatch patterns unless
    /// `.disablePathspecMatch` is set in ``flags``, in which case they are
    /// literal paths.
    public var pathspec: [String]
    /// Tree to compare against instead of HEAD. `nil` means HEAD.
    public var baseline: Tree?
    /// Rename-detection similarity threshold, 0–100. Default 50 matches
    /// libgit2.
    public var renameThreshold: UInt16

    public init(
        show: Show = .indexAndWorkdir,
        flags: Flags = .defaults,
        pathspec: [String] = [],
        baseline: Tree? = nil,
        renameThreshold: UInt16 = 50
    ) {
        self.show = show
        self.flags = flags
        self.pathspec = pathspec
        self.baseline = baseline
        self.renameThreshold = renameThreshold
    }
}

extension StatusOptions.Show {
    /// Map to the C enum. Internal — bridging only.
    internal var rawValue: git_status_show_t {
        switch self {
        case .indexAndWorkdir: return GIT_STATUS_SHOW_INDEX_AND_WORKDIR
        case .indexOnly:       return GIT_STATUS_SHOW_INDEX_ONLY
        case .workdirOnly:     return GIT_STATUS_SHOW_WORKDIR_ONLY
        }
    }
}
