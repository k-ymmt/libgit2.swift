import Testing
import Foundation
import Cgit2
@testable import Git2

struct RepositoryPullTests {
    /// Set up downstream on local `main` at upstream tip, with origin
    /// configured. Returns (fixture, downstream Repository).
    static func makeSyncedDownstream(in dir: URL) throws -> (LocalRemoteFixture, Repository) {
        let fx = try LocalRemoteFixture.make(in: dir)
        let repo = try Repository.open(at: fx.downstreamURL)
        _ = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
        try repo.fetch(remoteNamed: "origin")
        let tipCommit = try repo.commit(for: fx.seedOIDs.last!)
        _ = try repo.createBranch(named: "main", at: tipCommit, force: false)
        try repo.setHead(referenceName: "refs/heads/main")
        try repo.checkoutHead(options: .init(strategy: [.force]))
        return (fx, repo)
    }

    @Test func pull_upToDate_returnsUpToDate() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let (fx, repo) = try Self.makeSyncedDownstream(in: dir)
            let before = try repo.head().target

            let result = try repo.pull(remoteNamed: "origin", branchNamed: "main")

            #expect(result.contains(.upToDate))
            #expect(try repo.head().target == before)
            #expect(try repo.head().target == fx.seedOIDs.last!)
            let mergeHeadURL = fx.downstreamURL.appendingPathComponent(".git/MERGE_HEAD")
            #expect(!FileManager.default.fileExists(atPath: mergeHeadURL.path))
        }
    }

    @Test func pull_fastForward_movesHead() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let (fx, repo) = try Self.makeSyncedDownstream(in: dir)
            let originalTip = fx.seedOIDs.last!

            // Advance upstream by one commit.
            let upRepo = try Repository.open(at: fx.upstreamURL)
            let data = Data("new upstream commit\n".utf8)
            let blobOID = try upRepo.createBlob(data: data)
            let tree = try upRepo.tree(entries: [
                .init(name: "README.md", oid: blobOID, filemode: .blob)
            ])
            let parentCommit = try upRepo.commit(for: originalTip)
            let newCommit = try upRepo.commit(
                tree: tree,
                parents: [parentCommit],
                author: Signature(name: "A", email: "a@example.com", date: Date(timeIntervalSince1970: 1700000100), timeZone: TimeZone(identifier: "UTC")!),
                message: "advance",
                updatingRef: "refs/heads/main"
            )
            let advancedTip = newCommit.oid

            let result = try repo.pull(remoteNamed: "origin", branchNamed: "main")

            #expect(result.contains(.fastForward))
            #expect(try repo.head().target == advancedTip)
            // Confirm the branch ref itself moved (not just HEAD via
            // symbolic follow). Complement of pull_detachedHead_movesHeadOnly,
            // which asserts the branch ref DID NOT move when HEAD was
            // detached.
            let branchRef = try #require(try repo.reference(named: "refs/heads/main"))
            #expect(try branchRef.target == advancedTip)
            let mergeHeadURL = fx.downstreamURL.appendingPathComponent(".git/MERGE_HEAD")
            #expect(!FileManager.default.fileExists(atPath: mergeHeadURL.path))
        }
    }

    @Test func pull_unborn_attachesHead() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            // Downstream has no commits / no local main — HEAD is unborn.
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            _ = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            // No pre-fetch / no local branch creation — leave HEAD unborn.

            let result = try repo.pull(remoteNamed: "origin", branchNamed: "main")

            #expect(result.contains(.unborn))
            #expect(try repo.head().target == fx.seedOIDs.last!)
        }
    }

    @Test func pull_normal_runsMergeAndLeavesMergeHead() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let (fx, repo) = try Self.makeSyncedDownstream(in: dir)
            let sharedTip = fx.seedOIDs.last!

            // Advance upstream: new file upstream-only.txt.
            let upRepo = try Repository.open(at: fx.upstreamURL)
            let upData = Data("upstream only\n".utf8)
            let upBlob = try upRepo.createBlob(data: upData)
            // Carry the existing README.md forward.
            let readmeBlob = try upRepo.createBlob(data: Data("commit 2\n".utf8))
            let upTree = try upRepo.tree(entries: [
                .init(name: "README.md", oid: readmeBlob, filemode: .blob),
                .init(name: "upstream-only.txt", oid: upBlob, filemode: .blob),
            ])
            let upParent = try upRepo.commit(for: sharedTip)
            _ = try upRepo.commit(
                tree: upTree,
                parents: [upParent],
                author: Signature(name: "A", email: "a@example.com", date: Date(timeIntervalSince1970: 1700000100), timeZone: TimeZone(identifier: "UTC")!),
                message: "upstream adds file",
                updatingRef: "refs/heads/main"
            )

            // Advance downstream on its own main: new file downstream-only.txt.
            let dnData = Data("downstream only\n".utf8)
            let dnBlob = try repo.createBlob(data: dnData)
            let readmeBlob2 = try repo.createBlob(data: Data("commit 2\n".utf8))
            let dnTree = try repo.tree(entries: [
                .init(name: "README.md", oid: readmeBlob2, filemode: .blob),
                .init(name: "downstream-only.txt", oid: dnBlob, filemode: .blob),
            ])
            let dnParent = try repo.commit(for: sharedTip)
            _ = try repo.commit(
                tree: dnTree,
                parents: [dnParent],
                author: Signature(name: "B", email: "b@example.com", date: Date(timeIntervalSince1970: 1700000200), timeZone: TimeZone(identifier: "UTC")!),
                message: "downstream adds file",
                updatingRef: "refs/heads/main"
            )
            // Materialize the downstream commit onto disk so git_merge does not
            // refuse due to "uncommitted changes would be overwritten".
            try repo.checkoutHead(options: .init(strategy: [.force]))

            let result = try repo.pull(remoteNamed: "origin", branchNamed: "main")

            #expect(result.contains(.normal))
            let mergeHeadURL = fx.downstreamURL.appendingPathComponent(".git/MERGE_HEAD")
            #expect(FileManager.default.fileExists(atPath: mergeHeadURL.path))
            let index = try repo.index()
            #expect(index.hasConflicts == false)
        }
    }

    @Test func pull_normal_withConflict_leavesConflictInIndex() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let (fx, repo) = try Self.makeSyncedDownstream(in: dir)
            let sharedTip = fx.seedOIDs.last!

            // Both sides edit README.md differently.
            let upRepo = try Repository.open(at: fx.upstreamURL)
            let upBlob = try upRepo.createBlob(data: Data("upstream edit\n".utf8))
            let upTree = try upRepo.tree(entries: [
                .init(name: "README.md", oid: upBlob, filemode: .blob)
            ])
            let upParent = try upRepo.commit(for: sharedTip)
            _ = try upRepo.commit(
                tree: upTree,
                parents: [upParent],
                author: Signature(name: "A", email: "a@example.com", date: Date(timeIntervalSince1970: 1700000100), timeZone: TimeZone(identifier: "UTC")!),
                message: "upstream edits README",
                updatingRef: "refs/heads/main"
            )

            let dnBlob = try repo.createBlob(data: Data("downstream edit\n".utf8))
            let dnTree = try repo.tree(entries: [
                .init(name: "README.md", oid: dnBlob, filemode: .blob)
            ])
            let dnParent = try repo.commit(for: sharedTip)
            _ = try repo.commit(
                tree: dnTree,
                parents: [dnParent],
                author: Signature(name: "B", email: "b@example.com", date: Date(timeIntervalSince1970: 1700000200), timeZone: TimeZone(identifier: "UTC")!),
                message: "downstream edits README",
                updatingRef: "refs/heads/main"
            )
            // Materialize the downstream commit onto disk so git_merge does not
            // refuse due to "uncommitted changes would be overwritten".
            try repo.checkoutHead(options: .init(strategy: [.force]))

            let result = try repo.pull(remoteNamed: "origin", branchNamed: "main")

            #expect(result.contains(.normal))
            let index = try repo.index()
            #expect(index.hasConflicts == true)
        }
    }

    @Test func pull_detachedHead_movesHeadOnly() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let (fx, repo) = try Self.makeSyncedDownstream(in: dir)
            // Detach at current tip.
            let tip = try repo.head().target
            try repo.setHead(detachedAt: tip)
            #expect(git_repository_head_detached(repo.handle) == 1)

            // Advance upstream by one commit.
            let upRepo = try Repository.open(at: fx.upstreamURL)
            let blob = try upRepo.createBlob(data: Data("new\n".utf8))
            let tree = try upRepo.tree(entries: [
                .init(name: "README.md", oid: blob, filemode: .blob)
            ])
            let parentCommit = try upRepo.commit(for: tip)
            let newCommit = try upRepo.commit(
                tree: tree,
                parents: [parentCommit],
                author: Signature(name: "A", email: "a@example.com", date: Date(timeIntervalSince1970: 1700000100), timeZone: TimeZone(identifier: "UTC")!),
                message: "advance",
                updatingRef: "refs/heads/main"
            )

            let result = try repo.pull(remoteNamed: "origin", branchNamed: "main")

            #expect(result.contains(.fastForward))
            #expect(try repo.head().target == newCommit.oid)
            // Local branch ref should still point at the original tip
            // (detached HEAD pull does not touch branch refs).
            let localMain = try #require(try repo.reference(named: "refs/heads/main"))
            #expect(try localMain.target == tip)
            #expect(git_repository_head_detached(repo.handle) == 1)
        }
    }
}
