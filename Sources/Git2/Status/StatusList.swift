import Cgit2

/// A live handle over `git_status_list`. Mirrors the ``Diff`` class shape.
///
/// The entry set is frozen at the moment the list is created — subsequent
/// working-tree mutations are not reflected until a fresh list is
/// requested from ``Repository/statusList(options:)``.
///
/// All reads serialize against the owning repository's lock.
public final class StatusList: @unchecked Sendable {
    internal let handle: OpaquePointer

    /// The repository the list was produced from. Strongly retained so the
    /// libgit2 `git_repository *` outlives the list's `git_status_list *`.
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_status_list_free(handle)
    }

    /// Number of status entries in the list.
    public var count: Int {
        repository.lock.withLock {
            git_status_list_entrycount(handle)
        }
    }

    /// Returns the entry at `index` (0-based). Out-of-range access traps
    /// — libgit2 returns `NULL`, which is a programmer error at the Swift
    /// layer.
    public subscript(index: Int) -> StatusEntry {
        repository.lock.withLock {
            guard let raw = git_status_byindex(handle, index) else {
                preconditionFailure("StatusList subscript out of range: \(index)")
            }
            return StatusEntry(raw: raw.pointee)
        }
    }
}
