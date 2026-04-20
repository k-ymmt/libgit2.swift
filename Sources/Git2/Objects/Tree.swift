import Cgit2

/// A Git tree — the snapshot of a directory's contents at a point in history.
///
/// ``Tree`` owns a libgit2 `git_tree *` handle. All property and subscript
/// access is serialized through the parent ``Repository``'s internal lock.
///
/// The tree exposes its top-level entries only. Sub-directories (entries with
/// ``TreeEntry/kind`` `.tree`) can be reached by looking up their OID through
/// ``Repository/object(for:)``. v0.3 does not ship a recursive walk helper.
public final class Tree: @unchecked Sendable {
    internal let handle: OpaquePointer

    /// The repository this tree belongs to.
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_tree_free(handle)
    }

    /// This tree's OID.
    public var oid: OID {
        repository.lock.withLock {
            // libgit2 contract: git_tree_id is non-NULL for a valid handle.
            OID(raw: git_tree_id(handle)!.pointee)
        }
    }

    /// The number of top-level entries in this tree.
    public var count: Int {
        repository.lock.withLock {
            Int(git_tree_entrycount(handle))
        }
    }

    /// Returns the entry at `index` (0-based, in libgit2's name-sorted order).
    /// Out-of-range access traps, matching `Array`'s contract.
    public subscript(index: Int) -> TreeEntry {
        repository.lock.withLock {
            // libgit2 contract: git_tree_entry_byindex returns NULL only on
            // out-of-range. We trap to match the documented subscript contract.
            guard let rawEntry = git_tree_entry_byindex(handle, index) else {
                preconditionFailure("Tree subscript out of range: \(index)")
            }
            return TreeEntry(rawEntry: rawEntry)
        }
    }

    /// Returns the entry with the given name, or `nil` if no such entry exists.
    public subscript(name name: String) -> TreeEntry? {
        repository.lock.withLock {
            guard let rawEntry = name.withCString({ git_tree_entry_byname(handle, $0) }) else {
                return nil
            }
            return TreeEntry(rawEntry: rawEntry)
        }
    }
}

/// A single entry inside a ``Tree`` — a snapshot of name, OID, kind, and
/// filemode. Independent of any libgit2 handle once constructed, so it is
/// safely `Sendable` and `Equatable`.
public struct TreeEntry: Sendable, Equatable {
    /// The entry's basename (no path separators).
    public let name: String

    /// The OID of the object the entry points at.
    public let oid: OID

    /// Whether the entry references a blob, a sub-tree, or (rarely) a tag /
    /// submodule commit. Use ``Repository/object(for:)`` to hydrate into a
    /// concrete handle.
    public let kind: ObjectKind

    /// The Git filemode — distinguishes regular blob, executable blob,
    /// symbolic link, sub-tree, and submodule.
    public let filemode: FileMode

    /// The Git filemode for a tree entry.
    public enum FileMode: Sendable, Equatable {
        case tree
        case blob
        case blobExecutable
        case link
        case commit
    }

    /// Borrowed-pointer initializer. Copies every field out so the result does
    /// not depend on the lifetime of the underlying `git_tree *`.
    internal init(rawEntry: OpaquePointer) {
        // libgit2 contract: git_tree_entry_name / _id / _type / _filemode are
        // non-NULL for a valid entry.
        let namePtr = git_tree_entry_name(rawEntry)!
        self.name = String(cString: namePtr)
        self.oid  = OID(raw: git_tree_entry_id(rawEntry)!.pointee)
        let rawKind = git_tree_entry_type(rawEntry)
        // Within a well-formed tree, the kind is always one of the four
        // user-level kinds. Trap if libgit2 ever reports something we don't
        // recognise — that would be a library contract violation.
        guard let kind = ObjectKind.from(rawKind) else {
            preconditionFailure("Unknown git_object_t in tree entry: \(rawKind.rawValue)")
        }
        self.kind = kind
        self.filemode = FileMode.from(git_tree_entry_filemode(rawEntry))
    }
}

extension TreeEntry.FileMode {
    internal static func from(_ raw: git_filemode_t) -> TreeEntry.FileMode {
        switch raw {
        case GIT_FILEMODE_TREE:            return .tree
        case GIT_FILEMODE_BLOB:            return .blob
        case GIT_FILEMODE_BLOB_EXECUTABLE: return .blobExecutable
        case GIT_FILEMODE_LINK:            return .link
        case GIT_FILEMODE_COMMIT:          return .commit
        default:
            // GIT_FILEMODE_UNREADABLE (0) is libgit2's sentinel; it should not
            // appear in a loaded tree entry. Trap rather than synthesizing a
            // fallback — surfacing this as a data issue is more useful than
            // hiding it.
            preconditionFailure("Unexpected git_filemode_t in tree entry: \(raw.rawValue)")
        }
    }
}

extension TreeEntry.FileMode {
    /// Round-trip the case back into libgit2's `git_filemode_t`.
    internal var raw: git_filemode_t {
        switch self {
        case .tree:            return GIT_FILEMODE_TREE
        case .blob:            return GIT_FILEMODE_BLOB
        case .blobExecutable:  return GIT_FILEMODE_BLOB_EXECUTABLE
        case .link:            return GIT_FILEMODE_LINK
        case .commit:          return GIT_FILEMODE_COMMIT
        }
    }
}
