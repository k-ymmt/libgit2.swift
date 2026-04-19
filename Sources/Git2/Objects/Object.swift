import Cgit2

/// A polymorphic reference to a single object in the repository's object
/// database.
///
/// Obtained via ``Repository/object(for:)``. Each case owns a concrete handle
/// (``Commit`` / ``Tree`` / ``Blob`` / ``Tag``).
public enum Object: Sendable {
    case commit(Commit)
    case tree(Tree)
    case blob(Blob)
    case tag(Tag)

    /// The kind of the wrapped object. Constant-time — no ODB access.
    public var kind: ObjectKind {
        switch self {
        case .commit: return .commit
        case .tree:   return .tree
        case .blob:   return .blob
        case .tag:    return .tag
        }
    }

    /// The wrapped object's OID.
    public var oid: OID {
        switch self {
        case .commit(let c): return c.oid
        case .tree(let t):   return t.oid
        case .blob(let b):   return b.oid
        case .tag(let t):    return t.oid
        }
    }
}

extension Object {
    /// Wraps a `git_object *` handle of unknown kind into the appropriate
    /// ``Object`` case. Takes ownership of the handle — on success the handle
    /// is moved into the returned object and must not be freed by the caller.
    ///
    /// - Throws: ``GitError`` if the handle's `git_object_type` is not a
    ///   user-level kind (in practice unreachable).
    internal static func wrap(
        handle: OpaquePointer,
        repository: Repository
    ) throws(GitError) -> Object {
        let raw = git_object_type(handle)
        switch raw {
        case GIT_OBJECT_COMMIT: return .commit(Commit(handle: handle, repository: repository))
        case GIT_OBJECT_TREE:   return .tree(Tree(handle: handle, repository: repository))
        case GIT_OBJECT_BLOB:   return .blob(Blob(handle: handle, repository: repository))
        case GIT_OBJECT_TAG:    return .tag(Tag(handle: handle, repository: repository))
        default:
            git_object_free(handle)
            throw GitError(
                code: .invalid,
                class: .object,
                message: "Unexpected git_object_t \(raw.rawValue)"
            )
        }
    }
}
