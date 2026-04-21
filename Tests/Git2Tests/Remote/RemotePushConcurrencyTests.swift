import Testing
import Foundation
@testable import Git2

struct RemotePushConcurrencyTests {
    @Test func concurrentPushes_onSameRepo_serialize() async throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try await withTemporaryDirectoryAsync { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let down = try Repository.open(at: fx.downstreamURL)
            _ = try down.createRemote(named: "origin", url: fx.upstreamURLString)
            try down.fetch(remoteNamed: "origin")
            let tip = try down.commit(for: fx.seedOIDs.last!)
            try down.createBranch(named: "main", at: tip, force: false)
            try down.setHead(referenceName: "refs/heads/main")

            // Two parallel pushes of the same current state. The lock
            // serializes them; both calls should return without crashing.
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<2 {
                    group.addTask {
                        try down.push(
                            remoteNamed: "origin",
                            refspecs: [Refspec("refs/heads/main:refs/heads/main")]
                        )
                    }
                }
                try await group.waitForAll()
            }

            let up = try Repository.open(at: fx.upstreamURL)
            let ref = try #require(try up.reference(named: "refs/heads/main"))
            #expect(try ref.target == tip.oid)
        }
    }
}

// Until the hoisted `withTemporaryDirectoryAsync` TODO is addressed in
// Task 11 (see plan), mirror the private helper used by
// CheckoutConcurrencyTests / MergeConcurrencyTests / RebaseConcurrencyTests /
// RemoteConcurrencyTests.
private func withTemporaryDirectoryAsync<R>(
    _ body: (URL) async throws -> R
) async throws -> R {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}
