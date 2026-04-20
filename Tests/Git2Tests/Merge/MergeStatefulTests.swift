import Testing
import Foundation
@testable import Git2
import Cgit2

// Empirical: libgit2 1.9.x returns code=.mergeConflict / class=.merge when
// MergeOptions.Flags.failOnConflict is set and the merge produces conflicts.
extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct MergeStatefulTests {
        @Test
        func setsMergeStateAndWritesMergeHead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, theirsOID) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)

                guard let theirsRef = try repo.reference(named: "refs/heads/theirs") else {
                    Issue.record("theirs ref not found")
                    return
                }
                // makeDivergedBranches only writes to the ODB; materialize HEAD on disk.
                try repo.checkoutHead(options: .init(strategy: [.force]))
                let ac = try repo.annotatedCommit(for: theirsRef)
                try repo.merge([ac])

                // Post-conditions: MERGE_HEAD file exists (repo is in merge state).
                let mergeHeadURL = fx.repositoryURL
                    .appendingPathComponent(".git/MERGE_HEAD")
                #expect(FileManager.default.fileExists(atPath: mergeHeadURL.path))
                _ = theirsOID // silence
            }
        }

        @Test
        func rejectsEmptyHeads() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "A\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                do {
                    try repo.merge([])
                    Issue.record("expected throw for empty heads")
                } catch let e as GitError {
                    #expect(e.code == .invalid)
                }
            }
        }

        @Test
        func rejectsMoreThanOneHead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, oursOID, theirsOID) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                let a1 = try repo.annotatedCommit(for: oursOID)
                let a2 = try repo.annotatedCommit(for: theirsOID)
                do {
                    try repo.merge([a1, a2])
                    Issue.record("expected throw for octopus merge")
                } catch let e as GitError {
                    #expect(e.code == .invalid)
                    #expect(e.class == .invalid)
                }
            }
        }

        @Test
        func failOnConflict_throwsOnConflict() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, theirsOID) = try TestFixture.makeConflictingBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                let ac = try repo.annotatedCommit(for: theirsOID)

                var opts = Repository.MergeOptions()
                opts.flags = [.failOnConflict]
                do {
                    try repo.merge([ac], mergeOptions: opts)
                    Issue.record("expected throw with failOnConflict")
                } catch let e as GitError {
                    // Empirical: libgit2 1.9.x returns .mergeConflict / .merge for .failOnConflict
                    #expect(e.code == .mergeConflict)
                    #expect(e.class == .merge)
                }
            }
        }
    }
}
