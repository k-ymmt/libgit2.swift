import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct MergeCommitsTests {
        @Test
        func diverged_produces_cleanIndex() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, oursOID, theirsOID) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                let ours = try repo.commit(for: oursOID)
                let theirs = try repo.commit(for: theirsOID)

                let idx = try repo.mergeCommits(ours: ours, theirs: theirs)
                #expect(idx.hasConflicts == false)
            }
        }

        @Test
        func conflicting_populatesConflicts() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, oursOID, theirsOID) = try TestFixture.makeConflictingBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                let ours = try repo.commit(for: oursOID)
                let theirs = try repo.commit(for: theirsOID)

                let idx = try repo.mergeCommits(ours: ours, theirs: theirs)
                #expect(idx.hasConflicts)
            }
        }
    }
}
