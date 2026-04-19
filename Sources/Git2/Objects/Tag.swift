import Cgit2

/// An annotated Git tag — a full object in the database with its own OID,
/// tagger signature, message, and target.
///
/// Lightweight tags (references in `refs/tags/` that point directly at a
/// commit) are not ``Tag`` values; they are represented by ``Reference``.
public final class Tag: @unchecked Sendable {
    internal let handle: OpaquePointer

    /// The repository this tag belongs to.
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_tag_free(handle)
    }

    /// The tag object's OID (distinct from ``targetOID``).
    public var oid: OID {
        repository.lock.withLock {
            // libgit2 contract: git_tag_id is non-NULL for a valid handle.
            OID(raw: git_tag_id(handle)!.pointee)
        }
    }

    /// The tag's short name, e.g. `"v1.0"`.
    public var name: String {
        repository.lock.withLock {
            String(cString: git_tag_name(handle)!)
        }
    }

    /// The tag message.
    public var message: String {
        repository.lock.withLock {
            guard let cstr = git_tag_message(handle) else { return "" }
            return String(cString: cstr)
        }
    }

    /// The tagger signature. Theoretically `nil` for some exotic tags.
    public var tagger: Signature? {
        repository.lock.withLock {
            guard let raw = git_tag_tagger(handle) else { return nil }
            return Signature(copyingFrom: raw)
        }
    }

    /// The OID the tag points at.
    public var targetOID: OID {
        repository.lock.withLock {
            OID(raw: git_tag_target_id(handle)!.pointee)
        }
    }

    /// The kind of object the tag points at — typically `.commit`, but
    /// occasionally another tag (tag-of-tag) or a tree / blob.
    public var targetKind: ObjectKind {
        repository.lock.withLock {
            let raw = git_tag_target_type(handle)
            // libgit2 only reports one of the four user-level kinds here for
            // valid tags. Trap on anything else.
            guard let kind = ObjectKind.from(raw) else {
                preconditionFailure("Unexpected git_tag_target_type: \(raw.rawValue)")
            }
            return kind
        }
    }

    /// Resolves the tag's target object. For tag-of-tag chains the caller can
    /// switch on the returned ``Object`` and call `target()` again, or use
    /// ``Reference/resolveToCommit()`` to reach the terminal commit in one step.
    public func target() throws(GitError) -> Object {
        try repository.lock.withLock { () throws(GitError) -> Object in
            var raw: OpaquePointer?
            try check(git_tag_target(&raw, handle))
            return try Object.wrap(handle: raw!, repository: repository)
        }
    }
}
