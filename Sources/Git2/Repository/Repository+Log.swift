extension Repository {
    /// Returns a sequence of commits reachable from `start`, walking toward ancestors.
    ///
    /// Iteration uses libgit2's default sort order (insertion order from the push
    /// point). More control — topological sorting, reversing, hiding branches —
    /// will ship in v0.3 via a dedicated `RevWalk` type.
    ///
    /// ```swift
    /// let tip = try repo.head().resolveToCommit()
    /// for commit in repo.log(from: tip).prefix(10) {
    ///     print(commit.oid.hex.prefix(7), commit.summary)
    /// }
    /// ```
    ///
    /// The returned sequence can be iterated multiple times; each iteration
    /// creates a fresh libgit2 revwalk.
    ///
    /// - Parameter start: The commit to start walking from. Ancestors of this
    ///   commit are emitted; `start` itself is the first element.
    /// - Returns: A ``CommitSequence`` that lazily yields commits.
    public func log(from start: Commit) -> CommitSequence {
        CommitSequence(repository: self, startOID: start.oid)
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

    public func makeIterator() -> CommitIterator {
        CommitIterator(repository: repository, startOID: startOID)
    }
}

/// An iterator over a ``CommitSequence``.
///
/// ``next()`` returns `nil` when the walk terminates, including when libgit2
/// reports an error part-way through. Callers that need to distinguish
/// successful termination from a mid-walk failure should wait for the v0.3
/// `RevWalk` type, which surfaces errors explicitly.
public struct CommitIterator: IteratorProtocol {
    public typealias Element = Commit

    private let walker: RevWalkHandle

    internal init(repository: Repository, startOID: OID) {
        self.walker = RevWalkHandle(repository: repository, startOID: startOID)
    }

    public mutating func next() -> Commit? {
        walker.nextCommit()
    }
}
