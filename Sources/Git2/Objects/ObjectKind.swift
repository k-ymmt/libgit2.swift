import Cgit2

/// The kind of a Git object in the object database.
///
/// Mirrors the four object types that appear at the user level — commit, tree,
/// blob, and annotated tag. Delta types (`GIT_OBJECT_OFS_DELTA`,
/// `GIT_OBJECT_REF_DELTA`), `GIT_OBJECT_ANY`, and `GIT_OBJECT_INVALID` exist
/// only inside packfile machinery and never reach the public API; they map to
/// `nil` via ``from(_:)``.
public enum ObjectKind: Sendable, Equatable {
    case commit
    case tree
    case blob
    case tag
}

extension ObjectKind {
    /// Maps a libgit2 `git_object_t` to an ``ObjectKind``, or `nil` if the value
    /// is not one of the four user-level types.
    internal static func from(_ raw: git_object_t) -> ObjectKind? {
        switch raw {
        case GIT_OBJECT_COMMIT: return .commit
        case GIT_OBJECT_TREE:   return .tree
        case GIT_OBJECT_BLOB:   return .blob
        case GIT_OBJECT_TAG:    return .tag
        default:                return nil
        }
    }

    /// The libgit2 `git_object_t` corresponding to this kind.
    internal var raw: git_object_t {
        switch self {
        case .commit: return GIT_OBJECT_COMMIT
        case .tree:   return GIT_OBJECT_TREE
        case .blob:   return GIT_OBJECT_BLOB
        case .tag:    return GIT_OBJECT_TAG
        }
    }
}
