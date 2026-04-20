import Cgit2

extension Repository {
    /// Options forwarded to libgit2's `git_merge`, `git_merge_trees`, and
    /// `git_merge_commits`.
    ///
    /// The default value (`MergeOptions()`) maps to libgit2's defaults —
    /// flags empty, file favor `.normal`, rename threshold 50%, target limit
    /// 200.
    public struct MergeOptions: Sendable, Equatable {
        public var flags: Flags
        public var fileFavor: FileFavor
        public var renameThreshold: Int
        public var targetLimit: Int

        public init(
            flags: Flags = [],
            fileFavor: FileFavor = .normal,
            renameThreshold: Int = 50,
            targetLimit: Int = 200
        ) {
            self.flags = flags
            self.fileFavor = fileFavor
            self.renameThreshold = renameThreshold
            self.targetLimit = targetLimit
        }

        /// Merge strategy flags. Bit values match `git_merge_flag_t`.
        public struct Flags: OptionSet, Sendable, Equatable {
            public let rawValue: UInt32
            public init(rawValue: UInt32) { self.rawValue = rawValue }

            public static let findRenames    = Flags(rawValue: UInt32(GIT_MERGE_FIND_RENAMES.rawValue))
            public static let failOnConflict = Flags(rawValue: UInt32(GIT_MERGE_FAIL_ON_CONFLICT.rawValue))
            public static let skipReuc       = Flags(rawValue: UInt32(GIT_MERGE_SKIP_REUC.rawValue))
            public static let noRecursive    = Flags(rawValue: UInt32(GIT_MERGE_NO_RECURSIVE.rawValue))
            public static let virtualBase    = Flags(rawValue: UInt32(GIT_MERGE_VIRTUAL_BASE.rawValue))
        }

        /// Which side to prefer on file-content conflicts.
        public enum FileFavor: Sendable, Equatable {
            case normal    // GIT_MERGE_FILE_FAVOR_NORMAL
            case ours      // GIT_MERGE_FILE_FAVOR_OURS
            case theirs    // GIT_MERGE_FILE_FAVOR_THEIRS
            case union     // GIT_MERGE_FILE_FAVOR_UNION
        }
    }
}
