import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct MergePorcelainTests {
        @Test
        func upToDate_returnsUpToDate_andDoesNothing() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "A\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()

                let result = try repo.merge(head)
                #expect(result.contains(.upToDate))
                let mergeHeadURL = fixture.repositoryURL
                    .appendingPathComponent(".git/MERGE_HEAD")
                #expect(!FileManager.default.fileExists(atPath: mergeHeadURL.path))
            }
        }

        @Test
        func fastForward_advancesHead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, aheadOID) = try TestFixture.makeFastForwardable(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                // Materialize HEAD onto disk so checkoutHead doesn't refuse.
                try repo.checkoutHead(options: .init(strategy: [.force]))

                guard let ahead = try repo.reference(named: "refs/heads/ahead") else {
                    Issue.record("ahead ref missing"); return
                }

                let result = try repo.merge(ahead)
                #expect(result.contains(.fastForward))
                #expect(try repo.head().target == aheadOID)
                let mergeHeadURL = fx.repositoryURL
                    .appendingPathComponent(".git/MERGE_HEAD")
                #expect(!FileManager.default.fileExists(atPath: mergeHeadURL.path))
            }
        }

        @Test
        func normal_writesMergeHead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, _) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                // Materialize HEAD onto disk first (fixture writes ODB only).
                try repo.checkoutHead(options: .init(strategy: [.force]))

                guard let theirs = try repo.reference(named: "refs/heads/theirs") else {
                    Issue.record("theirs ref missing"); return
                }

                let result = try repo.merge(theirs)
                #expect(result.contains(.normal))
                let mergeHeadURL = fx.repositoryURL
                    .appendingPathComponent(".git/MERGE_HEAD")
                #expect(FileManager.default.fileExists(atPath: mergeHeadURL.path))
            }
        }

        @Test
        func branchNamed_resolvesLocalBranch() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, aheadOID) = try TestFixture.makeFastForwardable(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let result = try repo.merge(branchNamed: "ahead")
                #expect(result.contains(.fastForward))
                #expect(try repo.head().target == aheadOID)
            }
        }

        @Test
        func branchNamed_unknownBranch_throwsNotFound() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "A\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                do {
                    _ = try repo.merge(branchNamed: "nope")
                    Issue.record("expected throw")
                } catch let e as GitError {
                    #expect(e.code == .notFound)
                }
            }
        }
    }
}
