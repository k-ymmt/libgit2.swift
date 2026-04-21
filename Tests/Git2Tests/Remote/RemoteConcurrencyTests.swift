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

// Until the hoisted `withTemporaryDirectoryAsync` TODO is addressed
// (see TODO.md deferred list), mirror the private helper used by
// CheckoutConcurrencyTests / MergeConcurrencyTests / RebaseConcurrencyTests.
private func withTemporaryDirectoryAsync<R>(
    _ body: (URL) async throws -> R
) async throws -> R {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}
