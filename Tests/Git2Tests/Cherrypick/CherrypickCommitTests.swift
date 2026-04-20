import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct CherrypickCommitTests {
        @Test
        func pureCalculation_returnsIndex() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, oursOID, theirsOID) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                let ours = try repo.commit(for: oursOID)
                let theirs = try repo.commit(for: theirsOID)

                let idx = try repo.cherrypickCommit(theirs, onto: ours)
                #expect(idx.hasConflicts == false)
            }
        }

        @Test
        func mergeCommit_withoutMainline_throws() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fx = try TestFixture.makeMergeHistory(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                let mergeCommit = try repo.commit(for: try repo.head().target)
                let first = try mergeCommit.parents().first!

                do {
                    _ = try repo.cherrypickCommit(mergeCommit, onto: first, mainline: 0)
                    Issue.record("expected throw without mainline")
                } catch let e as GitError {
                    // Empirical: libgit2 1.9.x rejects merge-commit cherrypick
                    // with mainline == 0: code = .unknown(-1) / class = .cherrypick
                    // "mainline branch is not specified but <oid> is a merge commit"
                    #expect(e.code == .unknown(-1))
                    #expect(e.class == .cherrypick)
                }
            }
        }

        @Test
        func mergeCommit_withMainline_returnsIndex() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fx = try TestFixture.makeMergeHistory(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                let mergeCommit = try repo.commit(for: try repo.head().target)
                let first = try mergeCommit.parents().first!

                let idx = try repo.cherrypickCommit(mergeCommit, onto: first, mainline: 1)
                _ = idx // either conflicts or clean — just confirm the call succeeds
            }
        }
    }
}
