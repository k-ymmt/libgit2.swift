import Testing
import Foundation
import os
@testable import Git2

struct RemotePushCallbackTests {
    // Helper: seed upstream, fetch into downstream, create a local branch
    // and one additional commit ready for push. Returns the downstream
    // repo and the remote.
    private func makePushable(dir: URL, seedCount: Int = 3, extraPayload: String = "pushed")
        throws -> (Repository, Remote, newCommit: Commit, fixture: LocalRemoteFixture)
    {
        let fx = try LocalRemoteFixture.make(in: dir, seedCommitCount: seedCount)
        let down = try Repository.open(at: fx.downstreamURL)
        let remote = try down.createRemote(named: "origin", url: fx.upstreamURLString)
        try remote.fetch()
        let tip = try down.commit(for: fx.seedOIDs.last!)
        try down.createBranch(named: "main", at: tip, force: false)
        try down.setHead(referenceName: "refs/heads/main")
        let blobOID = try down.createBlob(data: Data("\(extraPayload)\n".utf8))
        let tree = try down.tree(entries: [
            .init(name: "README.md", oid: blobOID, filemode: .blob)
        ])
        let newCommit = try down.commit(
            tree: tree,
            parents: [tip],
            author: Signature(
                name: "A", email: "a@example.com",
                date: Date(timeIntervalSince1970: 1_700_001_000),
                timeZone: TimeZone(identifier: "UTC")!
            ),
            message: extraPayload,
            updatingRef: "refs/heads/main"
        )
        return (down, remote, newCommit, fx)
    }

    @Test func pushTransferProgress_firesAtLeastOnce() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let (_, remote, _, _) = try makePushable(dir: dir, seedCount: 20)
            let counter = PushProgressCounter()
            var opts = Repository.PushOptions()
            opts.pushTransferProgress = { current, total, bytes in
                counter.increment(current: current, total: total, bytes: bytes)
                return true
            }
            try remote.push(
                refspecs: [Refspec("refs/heads/main:refs/heads/main")],
                options: opts
            )
            #expect(counter.calls >= 1)
            #expect(counter.maxTotal > 0)
        }
    }

    @Test func pushTransferProgress_returningFalseCancelsWithUserError() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let (_, remote, _, _) = try makePushable(dir: dir, seedCount: 50)
            var opts = Repository.PushOptions()
            opts.pushTransferProgress = { _, _, _ in false }
            do {
                try remote.push(
                    refspecs: [Refspec("refs/heads/main:refs/heads/main")],
                    options: opts
                )
                Issue.record("expected push to throw")
            } catch let error as GitError {
                #expect(error.code == .user)
            }
        }
    }
}

// MARK: - test support

private final class PushProgressCounter: @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: (calls: 0, maxTotal: 0))
    var calls: Int    { state.withLock { $0.calls } }
    var maxTotal: Int { state.withLock { $0.maxTotal } }
    func increment(current: Int, total: Int, bytes: Int) {
        state.withLock { s in
            s.calls += 1
            if total > s.maxTotal { s.maxTotal = total }
        }
    }
}
