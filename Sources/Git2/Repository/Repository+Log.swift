extension Repository {
    public func log(from start: Commit) -> CommitSequence {
        CommitSequence(repository: self, startOID: start.oid)
    }
}

public struct CommitSequence: Sequence {
    public typealias Element = Commit

    internal let repository: Repository
    internal let startOID: OID

    public func makeIterator() -> CommitIterator {
        CommitIterator(repository: repository, startOID: startOID)
    }
}

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
