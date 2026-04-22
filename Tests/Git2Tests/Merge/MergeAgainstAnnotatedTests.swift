import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct MergeAgainstAnnotatedTests {
        @Test
        func mergeAgainst_upToDate_returnsUpToDate() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "A\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let annotated = try repo.annotatedCommit(for: head)

                let result = try repo.merge(against: annotated)
                #expect(result.contains(.upToDate))
            }
        }

        @Test
        func mergeAgainst_fastForward_viaRefProvenance() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, aheadOID) = try TestFixture.makeFastForwardable(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.checkoutHead(options: .init(strategy: [.force]))

                guard let ahead = try repo.reference(named: "refs/heads/ahead") else {
                    Issue.record("ahead ref missing"); return
                }
                let annotated = try repo.annotatedCommit(for: ahead)

                let result = try repo.merge(against: annotated)
                #expect(result.contains(.fastForward))
                #expect(try repo.head().target == aheadOID)
                let mergeHeadURL = fx.repositoryURL
                    .appendingPathComponent(".git/MERGE_HEAD")
                #expect(!FileManager.default.fileExists(atPath: mergeHeadURL.path))
            }
        }

        @Test
        func mergeAgainst_fastForward_viaOIDProvenance_detachesHead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, aheadOID) = try TestFixture.makeFastForwardable(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.checkoutHead(options: .init(strategy: [.force]))

                // OID-only AnnotatedCommit (no ref provenance) — FF path
                // must detach HEAD at the target OID.
                let annotated = try repo.annotatedCommit(for: aheadOID)

                let result = try repo.merge(against: annotated)
                #expect(result.contains(.fastForward))
                #expect(try repo.head().target == aheadOID)
                #expect(git_repository_head_detached(repo.handle) == 1)
            }
        }

        @Test
        func mergeAgainst_normal_writesMergeHead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, _) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.checkoutHead(options: .init(strategy: [.force]))

                guard let theirs = try repo.reference(named: "refs/heads/theirs") else {
                    Issue.record("theirs ref missing"); return
                }
                let annotated = try repo.annotatedCommit(for: theirs)

                let result = try repo.merge(against: annotated)
                #expect(result.contains(.normal))
                let mergeHeadURL = fx.repositoryURL
                    .appendingPathComponent(".git/MERGE_HEAD")
                #expect(FileManager.default.fileExists(atPath: mergeHeadURL.path))
            }
        }

        @Test
        func mergeAgainst_fromFetchHead_reflogsFetchHeadProvenance() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fx = try LocalRemoteFixture.make(in: dir)
                let repo = try Repository.open(at: fx.downstreamURL)
                let remote = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
                try remote.fetch()

                // Build FETCH_HEAD-provenance AnnotatedCommit + merge.
                // Downstream was empty; analysis should be `.unborn`.
                let upstreamTip = fx.seedOIDs.last!
                let annotated = try repo.annotatedCommit(
                    fromFetchHead: "main",
                    remoteURL: fx.upstreamURLString,
                    oid: upstreamTip
                )

                let result = try repo.merge(against: annotated)
                #expect(result.contains(.unborn))
                #expect(try repo.head().target == upstreamTip)
            }
        }
    }
}
