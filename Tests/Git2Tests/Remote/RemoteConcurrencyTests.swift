import Testing
import Foundation
@testable import Git2

struct RemoteConcurrencyTests {
    @Test func concurrentFetches_onSameRepo_serialize() async throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try await withTemporaryDirectoryAsync { dir in
            let fx = try LocalRemoteFixture.make(in: dir, seedCommitCount: 10)
            let repo = try Repository.open(at: fx.downstreamURL)
            _ = try repo.createRemote(named: "origin", url: fx.upstreamURLString)

            // Two concurrent fetches — lock must serialize them. Under
            // TSan no race is reported; the second fetch is a no-op
            // but still exercises the call path.
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<2 {
                    group.addTask {
                        try repo.fetch(remoteNamed: "origin")
                    }
                }
                try await group.waitForAll()
            }

            let ref = try #require(try repo.reference(named: "refs/remotes/origin/main"))
            #expect(try ref.target == fx.seedOIDs.last!)
        }
    }
}
