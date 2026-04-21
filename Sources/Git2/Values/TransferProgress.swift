import Cgit2

/// Snapshot of a fetch's transfer progress reported to the
/// ``Repository/FetchOptions/TransferProgressHandler``.
///
/// Mirrors `git_indexer_progress` with field names normalized to Swift
/// conventions and all counts widened to `Int`.
public struct TransferProgress: Sendable {
    /// Total number of objects the remote advertised.
    public let totalObjects: Int
    /// Objects already written to the local pack index.
    public let indexedObjects: Int
    /// Objects received from the remote (may be ahead of ``indexedObjects``
    /// while the packfile is still being indexed locally).
    public let receivedObjects: Int
    /// Objects already present locally that the remote did not need to
    /// send.
    public let localObjects: Int
    /// Total deltas discovered during indexing.
    public let totalDeltas: Int
    /// Deltas resolved so far.
    public let indexedDeltas: Int
    /// Bytes received on the wire.
    public let receivedBytes: Int

    public init(
        totalObjects: Int,
        indexedObjects: Int,
        receivedObjects: Int,
        localObjects: Int,
        totalDeltas: Int,
        indexedDeltas: Int,
        receivedBytes: Int
    ) {
        self.totalObjects    = totalObjects
        self.indexedObjects  = indexedObjects
        self.receivedObjects = receivedObjects
        self.localObjects    = localObjects
        self.totalDeltas     = totalDeltas
        self.indexedDeltas   = indexedDeltas
        self.receivedBytes   = receivedBytes
    }

    /// Fraction of indexing completed, `indexedObjects / totalObjects`.
    /// Returns `0` when `totalObjects == 0` so the handler can stably
    /// convert to a percentage without guarding.
    public var fractionCompleted: Double {
        guard totalObjects > 0 else { return 0 }
        return Double(indexedObjects) / Double(totalObjects)
    }

    /// Constructs from a libgit2 `git_indexer_progress`.
    internal init(_ raw: git_indexer_progress) {
        self.init(
            totalObjects:    Int(raw.total_objects),
            indexedObjects:  Int(raw.indexed_objects),
            receivedObjects: Int(raw.received_objects),
            localObjects:    Int(raw.local_objects),
            totalDeltas:     Int(raw.total_deltas),
            indexedDeltas:   Int(raw.indexed_deltas),
            receivedBytes:   Int(raw.received_bytes)
        )
    }
}
