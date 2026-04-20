import Cgit2

/// One step in a rebase operation list. Value-type snapshot of
/// `git_rebase_operation`.
///
/// Each libgit2 operation-list entry is copied into Swift storage at the
/// moment it is observed (by ``Rebase/next()`` or ``Rebase/operation(at:)``),
/// so the value's lifetime is independent of the parent ``Rebase`` handle.
public struct RebaseOperation: Sendable, Equatable {
    /// The operation kind.
    public let kind: Kind

    /// The commit being cherry-picked. Compares equal to ``OID/zero`` for
    /// ``Kind/exec`` operations — libgit2's `git_rebase_operation.id` is
    /// undefined in that case. Callers should branch on ``kind`` rather than
    /// inspect `oid` for `.exec`.
    public let oid: OID

    /// The executable command string for ``Kind/exec`` operations; `nil` for
    /// every other kind.
    public let exec: String?

    internal init(kind: Kind, oid: OID, exec: String?) {
        self.kind = kind
        self.oid = oid
        self.exec = exec
    }

    /// Operation kind. Mirrors `git_rebase_operation_t`.
    public enum Kind: Sendable, Equatable {
        case pick        // GIT_REBASE_OPERATION_PICK
        case reword      // GIT_REBASE_OPERATION_REWORD
        case edit        // GIT_REBASE_OPERATION_EDIT
        case squash      // GIT_REBASE_OPERATION_SQUASH
        case fixup       // GIT_REBASE_OPERATION_FIXUP
        case exec        // GIT_REBASE_OPERATION_EXEC

        internal init(_ raw: git_rebase_operation_t) {
            switch raw {
            case GIT_REBASE_OPERATION_PICK:   self = .pick
            case GIT_REBASE_OPERATION_REWORD: self = .reword
            case GIT_REBASE_OPERATION_EDIT:   self = .edit
            case GIT_REBASE_OPERATION_SQUASH: self = .squash
            case GIT_REBASE_OPERATION_FIXUP:  self = .fixup
            case GIT_REBASE_OPERATION_EXEC:   self = .exec
            default:                          self = .pick
            }
        }
    }
}

extension RebaseOperation {
    /// Copies a `git_rebase_operation` into Swift storage. The pointer's
    /// contents must be valid for the call. Caller is expected to already
    /// hold the parent repository lock when the pointer was resolved.
    internal init(copyingFrom raw: UnsafePointer<git_rebase_operation>) {
        let kind = Kind(raw.pointee.type)
        // libgit2's `git_rebase_operation.id` is undefined for .exec operations;
        // normalize to OID.zero so the public doc contract on `oid` holds
        // regardless of how libgit2 initialized the field.
        let oid: OID = kind == .exec ? .zero : OID(raw: raw.pointee.id)
        let exec: String? = kind == .exec
            ? raw.pointee.exec.flatMap { String(cString: $0) }
            : nil
        self.init(kind: kind, oid: oid, exec: exec)
    }
}
