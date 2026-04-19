import Cgit2

/// One file-level change in a ``Diff``.
public struct DiffDelta: Sendable, Equatable {
    public let status: Status
    public let oldFile: DiffFile
    public let newFile: DiffFile

    /// The kind of change this delta represents.
    public enum Status: Sendable, Equatable {
        case unmodified
        case added
        case deleted
        case modified
        case renamed
        case copied
        case ignored
        case untracked
        case typeChange
        case unreadable
        case conflicted
    }
}

extension DiffDelta {
    internal init(raw: git_diff_delta) {
        self.status  = Status.from(raw.status)
        self.oldFile = DiffFile(raw: raw.old_file)
        self.newFile = DiffFile(raw: raw.new_file)
    }
}

extension DiffDelta.Status {
    internal static func from(_ raw: git_delta_t) -> DiffDelta.Status {
        switch raw {
        case GIT_DELTA_UNMODIFIED: return .unmodified
        case GIT_DELTA_ADDED:      return .added
        case GIT_DELTA_DELETED:    return .deleted
        case GIT_DELTA_MODIFIED:   return .modified
        case GIT_DELTA_RENAMED:    return .renamed
        case GIT_DELTA_COPIED:     return .copied
        case GIT_DELTA_IGNORED:    return .ignored
        case GIT_DELTA_UNTRACKED:  return .untracked
        case GIT_DELTA_TYPECHANGE: return .typeChange
        case GIT_DELTA_UNREADABLE: return .unreadable
        case GIT_DELTA_CONFLICTED: return .conflicted
        default:                   return .unmodified
        }
    }
}
