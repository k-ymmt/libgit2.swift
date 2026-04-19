import Cgit2

extension Repository {
    /// Returns a sequence of commits reachable from `start`, walking toward ancestors.
    ///
    /// Uses libgit2's default (insertion) order.
    ///
    /// ```swift
    /// let tip = try repo.head().resolveToCommit()
    /// for commit in repo.log(from: tip).prefix(10) {
    ///     print(commit.oid.hex.prefix(7), commit.summary)
    /// }
    /// ```
    ///
    /// The returned sequence can be iterated multiple times; each iteration
    /// creates a fresh walker.
    public func log(from start: Commit) -> CommitSequence {
        CommitSequence(repository: self, startOID: start.oid, sorting: .none)
    }

    /// Returns a sequence of commits reachable from `start`, applying the
    /// given sort order.
    ///
    /// - Parameters:
    ///   - start: The commit to start walking from.
    ///   - sorting: Sort flags. `.none` matches ``log(from:)``.
    public func log(from start: Commit, sorting: CommitSequence.Sorting) -> CommitSequence {
        CommitSequence(repository: self, startOID: start.oid, sorting: sorting)
    }
}

/// A lazy sequence of commits produced by ``Repository/log(from:)``.
///
/// Conforms to `Sequence`, so it composes naturally with `prefix`, `filter`,
/// `map`, and other standard-library operators.
///
/// Each call to `makeIterator()` creates a fresh walker, so iterating the same
/// sequence twice produces the same elements.
public struct CommitSequence: Sequence {
    public typealias Element = Commit

    internal let repository: Repository
    internal let startOID: OID
    internal let sorting: Sorting

    public func makeIterator() -> CommitIterator {
        CommitIterator(repository: repository, startOID: startOID, sorting: sorting)
    }
}

/// An iterator over a ``CommitSequence``.
///
/// ``next()`` returns `nil` when the walk terminates — including when libgit2
/// reports an error part-way through. Callers that need to distinguish
/// successful termination from a mid-walk failure should use ``RevWalk``
/// directly.
public struct CommitIterator: IteratorProtocol {
    public typealias Element = Commit

    private let walker: RevWalk?

    internal init(repository: Repository, startOID: OID, sorting: CommitSequence.Sorting) {
        // Silent-fail tradeoff: we can't throw from an IteratorProtocol init,
        // so any setup error leaves `walker == nil` and `next()` returns nil.
        // Callers who need strict error detection use RevWalk directly.
        let walk: RevWalk? = try? RevWalk(repository: repository)
        if let walk {
            if sorting != .none {
                try? walk.setSorting(sorting)
            }
            try? walk.push(oid: startOID)
        }
        self.walker = walk
    }

    public mutating func next() -> Commit? {
        guard let walker else { return nil }
        do {
            return try walker.next()
        } catch {
            return nil
        }
    }
}
