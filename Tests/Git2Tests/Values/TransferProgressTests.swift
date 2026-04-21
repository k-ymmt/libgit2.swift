import Testing
@testable import Git2
import Cgit2

struct TransferProgressTests {
    @Test func initializer_storesFields() {
        let p = TransferProgress(
            totalObjects: 100,
            indexedObjects: 40,
            receivedObjects: 60,
            localObjects: 5,
            totalDeltas: 10,
            indexedDeltas: 3,
            receivedBytes: 12_345
        )
        #expect(p.totalObjects     == 100)
        #expect(p.indexedObjects   == 40)
        #expect(p.receivedObjects  == 60)
        #expect(p.localObjects     == 5)
        #expect(p.totalDeltas      == 10)
        #expect(p.indexedDeltas    == 3)
        #expect(p.receivedBytes    == 12_345)
    }

    @Test func fractionCompleted_computedFromIndexed() {
        let p = TransferProgress(totalObjects: 200, indexedObjects: 50, receivedObjects: 100,
                                 localObjects: 0, totalDeltas: 0, indexedDeltas: 0, receivedBytes: 0)
        #expect(p.fractionCompleted == 0.25)
    }

    @Test func fractionCompleted_zeroTotalIsZero() {
        let p = TransferProgress(totalObjects: 0, indexedObjects: 0, receivedObjects: 0,
                                 localObjects: 0, totalDeltas: 0, indexedDeltas: 0, receivedBytes: 0)
        #expect(p.fractionCompleted == 0)
    }

    @Test func initFromGitIndexerProgress_bridgesFields() {
        var raw = git_indexer_progress()
        raw.total_objects    = 100
        raw.indexed_objects  = 40
        raw.received_objects = 60
        raw.local_objects    = 5
        raw.total_deltas     = 10
        raw.indexed_deltas   = 3
        raw.received_bytes   = 12_345
        let p = TransferProgress(raw)
        #expect(p.totalObjects     == 100)
        #expect(p.indexedObjects   == 40)
        #expect(p.receivedObjects  == 60)
        #expect(p.localObjects     == 5)
        #expect(p.totalDeltas      == 10)
        #expect(p.indexedDeltas    == 3)
        #expect(p.receivedBytes    == 12_345)
    }
}
