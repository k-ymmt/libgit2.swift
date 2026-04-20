import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct CheckoutConcurrencyTests {
        @Test
        func parallelCheckoutAndIndexReadsDoNotRaceOrCrash() async throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try await withTemporaryDirectoryAsync { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [
                        (message: "first\n",  author: .test),
                        (message: "second\n", author: .test),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)

                let head = try repo.head()
                let tip = try repo.commit(for: head.target)
                let first = try #require(tip.parents().first)
                _ = try repo.createBranch(named: "feature", at: first, force: false)

                let forceOpts = Repository.CheckoutOptions(strategy: [.force])

                try await withThrowingTaskGroup(of: Void.self) { group in
                    for i in 0..<16 {
                        let target = (i % 2 == 0) ? "feature" : "main"
                        group.addTask {
                            // Tolerate "main" not existing on some hosts
                            // (fixture may be on master) by falling back.
                            do {
                                try repo.checkout(branchNamed: target, options: forceOpts)
                            } catch let e as GitError where e.code == .notFound && target == "main" {
                                try repo.checkout(branchNamed: "master", options: forceOpts)
                            }
                        }
                        group.addTask {
                            try repo.checkoutHead(options: forceOpts)
                        }
                        group.addTask {
                            _ = try repo.index().entries
                        }
                    }
                    try await group.waitForAll()
                }

                // Final HEAD must be a valid branch name (no corruption).
                let finalHead = try repo.head()
                #expect(
                    finalHead.name == "refs/heads/feature" ||
                    finalHead.name == "refs/heads/main"    ||
                    finalHead.name == "refs/heads/master"
                )
            }
        }
    }
}

private func withTemporaryDirectoryAsync<T>(_ body: (URL) async throws -> T) async rethrows -> T {
    let base = URL.temporaryDirectory
        .appendingPathComponent("Git2Tests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }
    return try await body(base)
}
