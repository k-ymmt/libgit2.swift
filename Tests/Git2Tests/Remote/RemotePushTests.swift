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

    @Test func pushSugar_advancesUpstreamMain() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let down = try Repository.open(at: fx.downstreamURL)
            _ = try down.createRemote(named: "origin", url: fx.upstreamURLString)
            try down.fetch(remoteNamed: "origin")

            let tipOID = fx.seedOIDs.last!
            try down.createBranch(named: "main", at: try down.commit(for: tipOID), force: false)
            try down.setHead(referenceName: "refs/heads/main")

            let tipCommit = try down.commit(for: tipOID)
            let blobOID = try down.createBlob(data: Data("via-sugar\n".utf8))
            let tree = try down.tree(entries: [
                .init(name: "README.md", oid: blobOID, filemode: .blob)
            ])
            let newCommit = try down.commit(
                tree: tree,
                parents: [tipCommit],
                author: Signature(
                    name: "A", email: "a@example.com",
                    date: Date(timeIntervalSince1970: 1_700_000_200),
                    timeZone: TimeZone(identifier: "UTC")!
                ),
                message: "via sugar",
                updatingRef: "refs/heads/main"
            )

            try down.push(
                remoteNamed: "origin",
                refspecs: [Refspec("refs/heads/main:refs/heads/main")]
            )

            let up = try Repository.open(at: fx.upstreamURL)
            let ref = try #require(try up.reference(named: "refs/heads/main"))
            #expect(try ref.target == newCommit.oid)
        }
    }

    @Test func push_deleteRemoteRef_removesRefOnUpstream() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let down = try Repository.open(at: fx.downstreamURL)
            let remote = try down.createRemote(named: "origin", url: fx.upstreamURLString)
            try remote.fetch()

            // Set up a local branch + push to create refs/heads/feature
            // on the upstream.
            let tip = try down.commit(for: fx.seedOIDs.last!)
            try down.createBranch(named: "feature", at: tip, force: false)
            try remote.push(refspecs: [Refspec("refs/heads/feature:refs/heads/feature")])

            // Precondition: feature exists on upstream.
            let up = try Repository.open(at: fx.upstreamURL)
            #expect(try up.reference(named: "refs/heads/feature") != nil)

            // Delete via :refname refspec.
            try remote.push(refspecs: [Refspec(":refs/heads/feature")])

            let up2 = try Repository.open(at: fx.upstreamURL)
            #expect(try up2.reference(named: "refs/heads/feature") == nil)
        }
    }

    @Test func push_forcePush_rewritesUpstream() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let down = try Repository.open(at: fx.downstreamURL)
            let remote = try down.createRemote(named: "origin", url: fx.upstreamURLString)
            try remote.fetch()

            // Rewind downstream main to the root commit, then create a
            // divergent commit. The new OID will not be a descendant of
            // upstream's tip, so a non-force push would be rejected.
            let rootOID = fx.seedOIDs.first!
            let root = try down.commit(for: rootOID)
            try down.createBranch(named: "main", at: root, force: false)
            try down.setHead(referenceName: "refs/heads/main")

            let blobOID = try down.createBlob(data: Data("forced\n".utf8))
            let tree = try down.tree(entries: [
                .init(name: "README.md", oid: blobOID, filemode: .blob)
            ])
            let forcedCommit = try down.commit(
                tree: tree,
                parents: [root],
                author: Signature(
                    name: "A", email: "a@example.com",
                    date: Date(timeIntervalSince1970: 1_700_000_300),
                    timeZone: TimeZone(identifier: "UTC")!
                ),
                message: "forced commit",
                updatingRef: "refs/heads/main"
            )

            // Force push.
            try remote.push(refspecs: [Refspec("+refs/heads/main:refs/heads/main")])

            let up = try Repository.open(at: fx.upstreamURL)
            let ref = try #require(try up.reference(named: "refs/heads/main"))
            #expect(try ref.target == forcedCommit.oid)
        }
    }
}
