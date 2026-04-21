import Testing
import Foundation
@testable import Git2

struct RemoteFetchTests {
    @Test func fetch_downloadsSeedCommitsIntoDownstream() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            let remote = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            try remote.fetch()

            // Seed commits must be resolvable now.
            for oid in fx.seedOIDs {
                let c = try repo.commit(for: oid)
                #expect(c.oid == oid)
            }

            // Remote-tracking ref must point at the tip.
            let ref = try #require(try repo.reference(named: "refs/remotes/origin/main"))
            #expect(try ref.target == fx.seedOIDs.last!)
        }
    }

    @Test func fetch_writesFETCH_HEAD() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            let remote = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            try remote.fetch()

            let fetchHead = fx.downstreamURL
                .appendingPathComponent(".git")
                .appendingPathComponent("FETCH_HEAD")
            let contents = try String(contentsOf: fetchHead, encoding: .utf8)
            #expect(contents.contains(fx.seedOIDs.last!.hex))
            #expect(contents.contains("'main'"))
        }
    }

    @Test func fetch_reFetchIsIdempotent() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            let remote = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            try remote.fetch()
            try remote.fetch()   // second call should succeed with no changes
            let ref = try #require(try repo.reference(named: "refs/remotes/origin/main"))
            #expect(try ref.target == fx.seedOIDs.last!)
        }
    }
}
