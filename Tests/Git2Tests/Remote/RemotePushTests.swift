import Testing
import Foundation
@testable import Git2
import Cgit2

struct RemotePushTests {
    @Test func push_advancesUpstreamMain() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            // upstream seeded with 3 commits; downstream cloned & advanced.
            let fx = try LocalRemoteFixture.make(in: dir)
            let down = try Repository.open(at: fx.downstreamURL)
            let remote = try down.createRemote(named: "origin", url: fx.upstreamURLString)
            try remote.fetch()

            // Move downstream main to origin/main so we have a local branch.
            let tipOID = fx.seedOIDs.last!
            try down.createBranch(named: "main", at: try down.commit(for: tipOID), force: false)
            try down.setHead(referenceName: "refs/heads/main")

            // Build a new commit on top of tip.
            let tipCommit = try down.commit(for: tipOID)
            let blobOID = try down.createBlob(data: Data("pushed\n".utf8))
            let tree = try down.tree(entries: [
                .init(name: "README.md", oid: blobOID, filemode: .blob)
            ])
            let newCommit = try down.commit(
                tree: tree,
                parents: [tipCommit],
                author: Signature(
                    name: "A", email: "a@example.com",
                    date: Date(timeIntervalSince1970: 1_700_000_100),
                    timeZone: TimeZone(identifier: "UTC")!
                ),
                message: "pushed commit",
                updatingRef: "refs/heads/main"
            )

            // Push.
            try remote.push(refspecs: [Refspec("refs/heads/main:refs/heads/main")])

            // Open upstream and verify it advanced.
            let up = try Repository.open(at: fx.upstreamURL)
            let ref = try #require(try up.reference(named: "refs/heads/main"))
            #expect(try ref.target == newCommit.oid)
        }
    }
}
