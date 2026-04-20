import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct MergeTreesTests {
        @Test
        func threeWayMerge_nonConflicting_producesCleanIndex() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, oursOID, theirsOID) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)

                let ours = try repo.commit(for: oursOID)
                let theirs = try repo.commit(for: theirsOID)
                let base = try repo.mergeBase(of: oursOID, and: theirsOID)
                let baseCommit = try repo.commit(for: base)

                let idx = try repo.mergeTrees(
                    ancestor: try baseCommit.tree(),
                    ours: try ours.tree(),
                    theirs: try theirs.tree()
                )
                #expect(idx.hasConflicts == false)
            }
        }

        @Test
        func threeWayMerge_conflicting_populatesIndexConflicts() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, oursOID, theirsOID) = try TestFixture.makeConflictingBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)

                let ours = try repo.commit(for: oursOID)
                let theirs = try repo.commit(for: theirsOID)
                let base = try repo.mergeBase(of: oursOID, and: theirsOID)
                let baseCommit = try repo.commit(for: base)

                let idx = try repo.mergeTrees(
                    ancestor: try baseCommit.tree(),
                    ours: try ours.tree(),
                    theirs: try theirs.tree()
                )
                #expect(idx.hasConflicts)
                #expect(idx.conflicts.contains { $0.ours?.path == "file.txt" || $0.theirs?.path == "file.txt" })
            }
        }

        @Test
        func twoWayMerge_nilAncestor_reportsConflictOnDifference() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, oursOID, theirsOID) = try TestFixture.makeConflictingBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)

                let ours = try repo.commit(for: oursOID)
                let theirs = try repo.commit(for: theirsOID)

                let idx = try repo.mergeTrees(
                    ancestor: nil,
                    ours: try ours.tree(),
                    theirs: try theirs.tree()
                )
                // Two-way diff of differing blobs == conflict.
                #expect(idx.hasConflicts)
            }
        }

        @Test
        func fileFavorOurs_resolvesConflictInFavorOfOurs() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, oursOID, theirsOID) = try TestFixture.makeConflictingBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)

                let ours = try repo.commit(for: oursOID)
                let theirs = try repo.commit(for: theirsOID)
                let base = try repo.mergeBase(of: oursOID, and: theirsOID)
                let baseCommit = try repo.commit(for: base)

                var opts = Repository.MergeOptions()
                opts.fileFavor = .ours
                let idx = try repo.mergeTrees(
                    ancestor: try baseCommit.tree(),
                    ours: try ours.tree(),
                    theirs: try theirs.tree(),
                    options: opts
                )
                #expect(idx.hasConflicts == false)
            }
        }
    }
}
