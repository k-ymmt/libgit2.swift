import Cgit2

/// A file-level diff between two trees.
///
/// Each delta describes one file's transition from ``DiffDelta/oldFile`` to
/// ``DiffDelta/newFile``. Hunk- and line-level granularity are not included
/// in this slice.
public final class Diff: @unchecked Sendable {
    internal let handle: OpaquePointer

    /// The repository the diff was computed against.
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_diff_free(handle)
    }

    /// The number of file-level deltas in this diff.
    public var count: Int {
        repository.lock.withLock {
            git_diff_num_deltas(handle)
        }
    }

    /// Returns the delta at `index` (0-based). Out-of-range access traps.
    public subscript(index: Int) -> DiffDelta {
        repository.lock.withLock {
            guard let rawPtr = git_diff_get_delta(handle, index) else {
                preconditionFailure("Diff subscript out of range: \(index)")
            }
            return DiffDelta(raw: rawPtr.pointee)
        }
    }
}
