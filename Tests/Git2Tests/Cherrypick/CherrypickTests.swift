import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct CherrypickTests {
        @Test
        func setsCherrypickState() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, theirsOID) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                // Materialize HEAD on disk first (fixture writes ODB only).
                try repo.checkoutHead(options: .init(strategy: [.force]))
                let theirs = try repo.commit(for: theirsOID)

                try repo.cherrypick(theirs)

                let chpHead = fx.repositoryURL.appendingPathComponent(".git/CHERRY_PICK_HEAD")
                #expect(FileManager.default.fileExists(atPath: chpHead.path))
            }
        }

        @Test
        func conflicting_leavesConflictsInIndex() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, theirsOID) = try TestFixture.makeConflictingBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.checkoutHead(options: .init(strategy: [.force]))
                let theirs = try repo.commit(for: theirsOID)

                try repo.cherrypick(theirs)
                let idx = try repo.index()
                #expect(idx.hasConflicts)
            }
        }
    }
}
