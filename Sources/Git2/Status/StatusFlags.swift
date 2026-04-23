/// Status flags for a single file — a bitmask combining index-vs-HEAD,
/// workdir-vs-index, and special `IGNORED` / `CONFLICTED` bits. Mirrors
/// `git_status_t` (see `libgit2/include/git2/status.h`).
///
/// Convenience properties (`hasIndexChanges`, `hasWorkdirChanges`,
/// `isConflicted`, `isIgnored`, `isCurrent`) cover the most common
/// discriminations without callers having to spell out unions themselves.
public struct StatusFlags: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    // Index vs HEAD (GIT_STATUS_INDEX_*).
    public static let indexNew        = StatusFlags(rawValue: 1 << 0)
    public static let indexModified   = StatusFlags(rawValue: 1 << 1)
    public static let indexDeleted    = StatusFlags(rawValue: 1 << 2)
    public static let indexRenamed    = StatusFlags(rawValue: 1 << 3)
    public static let indexTypeChange = StatusFlags(rawValue: 1 << 4)

    // Workdir vs index (GIT_STATUS_WT_*).
    public static let wtNew           = StatusFlags(rawValue: 1 << 7)
    public static let wtModified      = StatusFlags(rawValue: 1 << 8)
    public static let wtDeleted       = StatusFlags(rawValue: 1 << 9)
    public static let wtTypeChange    = StatusFlags(rawValue: 1 << 10)
    public static let wtRenamed       = StatusFlags(rawValue: 1 << 11)
    public static let wtUnreadable    = StatusFlags(rawValue: 1 << 12)

    public static let ignored         = StatusFlags(rawValue: 1 << 14)
    public static let conflicted      = StatusFlags(rawValue: 1 << 15)

    /// Union of every `INDEX_*` flag.
    public static let indexChanges: StatusFlags =
        [.indexNew, .indexModified, .indexDeleted, .indexRenamed, .indexTypeChange]

    /// Union of every `WT_*` flag.
    public static let workdirChanges: StatusFlags =
        [.wtNew, .wtModified, .wtDeleted, .wtTypeChange, .wtRenamed, .wtUnreadable]

    public var hasIndexChanges: Bool   { !isDisjoint(with: .indexChanges) }
    public var hasWorkdirChanges: Bool { !isDisjoint(with: .workdirChanges) }
    public var isConflicted: Bool      { contains(.conflicted) }
    public var isIgnored: Bool         { contains(.ignored) }
    /// Matches `GIT_STATUS_CURRENT` (no bits set).
    public var isCurrent: Bool         { rawValue == 0 }
}
