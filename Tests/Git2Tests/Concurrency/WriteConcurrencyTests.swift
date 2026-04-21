import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct WriteConcurrencyTests {
        @Test
        func parallelWritesDoNotRaceOrCrash() async throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try await withTemporaryDirectory { dir in
                let repo = try Repository.create(at: dir)

                // Seed an initial commit so parents: [seed] works in tasks.
                let seedBlob = try repo.createBlob(data: Data("seed".utf8))
                let seedTree = try repo.tree(entries: [
                    .init(name: "seed", oid: seedBlob, filemode: .blob)
                ])
                let seed = try repo.commit(
                    tree: seedTree, parents: [],
                    author: .test, message: "seed\n",
                    updatingRef: "HEAD"
                )

                try await withThrowingTaskGroup(of: OID.self) { group in
                    for i in 0..<32 {
                        group.addTask {
                            let blob = try repo.createBlob(data: Data("payload-\(i)".utf8))
                            let tree = try repo.tree(entries: [
                                .init(name: "f-\(i)", oid: blob, filemode: .blob)
                            ])
                            let commit = try repo.commit(
                                tree: tree, parents: [seed],
                                author: .test, message: "m\(i)\n",
                                updatingRef: nil   // dangling: avoid HEAD contention
                            )
                            return commit.oid
                        }
                    }
                    var committed: [OID] = []
                    for try await oid in group { committed.append(oid) }

                    // Every commit must re-hydrate via object(for:).
                    for oid in committed {
                        guard case .commit = try #require(try repo.object(for: oid)) else {
                            Issue.record("expected commit for \(oid)"); continue
                        }
                    }
                    #expect(committed.count == 32)
                }
            }
        }
    }
}

/// Async-friendly overload of the fixture helper — mirrors the sync one.
private func withTemporaryDirectory<T>(_ body: (URL) async throws -> T) async rethrows -> T {
    let base = URL.temporaryDirectory
        .appendingPathComponent("Git2Tests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }
    return try await body(base)
}
