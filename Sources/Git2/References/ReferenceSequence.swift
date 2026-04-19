import Cgit2

/// A lazy sequence of every reference in a repository.
///
/// Each `makeIterator()` call creates a fresh libgit2 iterator, so the
/// sequence can be iterated multiple times.
public struct ReferenceSequence: Sequence {
    public typealias Element = Reference

    internal let repository: Repository

    public func makeIterator() -> ReferenceIterator {
        ReferenceIterator(repository: repository)
    }
}

/// An iterator over a ``ReferenceSequence``.
///
/// ``next()`` returns `nil` when the walk terminates — including mid-iteration
/// errors, which are swallowed to satisfy the `IteratorProtocol` contract.
/// Callers that need strict error detection should look up references one at
/// a time through ``Repository/reference(named:)``.
public struct ReferenceIterator: IteratorProtocol {
    public typealias Element = Reference

    private let state: State

    internal init(repository: Repository) {
        self.state = State(repository: repository)
    }

    public mutating func next() -> Reference? {
        state.next()
    }

    /// Holds the libgit2 iterator pointer. Wrapped in a class so the iterator's
    /// `deinit` runs at the right time regardless of how the struct is copied.
    private final class State {
        let repository: Repository
        var raw: OpaquePointer?

        init(repository: Repository) {
            self.repository = repository
            var ptr: OpaquePointer?
            // Silent-fail on init, matching the IteratorProtocol contract.
            _ = repository.lock.withLock { () -> Int32 in
                git_reference_iterator_new(&ptr, repository.handle)
            }
            self.raw = ptr
        }

        deinit {
            if let raw {
                git_reference_iterator_free(raw)
            }
        }

        func next() -> Reference? {
            guard let iter = raw else { return nil }
            return repository.lock.withLock { () -> Reference? in
                var outHandle: OpaquePointer?
                let r = git_reference_next(&outHandle, iter)
                if r == GIT_ITEROVER.rawValue || r < 0 {
                    // Iteration is permanently done. Free the underlying libgit2
                    // iterator now rather than waiting for `deinit`, and null out
                    // `raw` so subsequent `next()` calls short-circuit without
                    // re-entering libgit2.
                    git_reference_iterator_free(iter)
                    raw = nil
                    return nil
                }
                return Reference(handle: outHandle!, repository: repository)
            }
        }
    }
}
