import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct IndexConflictTests {
        @Test
        func makeConflictedIndex_populatesThreeStages() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                _ = repo
                try TestFixture.makeConflictedIndex(
                    at: "conflict.txt",
                    ancestor: Data("A".utf8),
                    ours: Data("O".utf8),
                    theirs: Data("T".utf8),
                    in: dir
                )
                let repo2 = try Repository.open(at: dir)
                let index = try repo2.index()
                #expect(index.hasConflicts)
            }
        }

        @Test
        func conflicts_enumeratesAllSides() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                _ = try initRepo(at: dir)
                try TestFixture.makeConflictedIndex(
                    at: "c.txt",
                    ancestor: Data("A".utf8),
                    ours: Data("O".utf8),
                    theirs: Data("T".utf8),
                    in: dir
                )
                let repo = try Repository.open(at: dir)
                let index = try repo.index()
                let conflicts = index.conflicts
                try #require(conflicts.count == 1)
                #expect(conflicts[0].path == "c.txt")
                #expect(conflicts[0].ancestor?.stage == .ancestor)
                #expect(conflicts[0].ours?.stage == .ours)
                #expect(conflicts[0].theirs?.stage == .theirs)

                // Verify the injected OIDs match the content-addressed blobs.
                let expectedAncestor = try repo.createBlob(data: Data("A".utf8))
                let expectedOurs     = try repo.createBlob(data: Data("O".utf8))
                let expectedTheirs   = try repo.createBlob(data: Data("T".utf8))
                #expect(conflicts[0].ancestor?.oid == expectedAncestor)
                #expect(conflicts[0].ours?.oid == expectedOurs)
                #expect(conflicts[0].theirs?.oid == expectedTheirs)
            }
        }

        @Test
        func conflictFor_hitAndMiss() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                _ = try initRepo(at: dir)
                try TestFixture.makeConflictedIndex(
                    at: "c.txt",
                    ancestor: Data("A".utf8),
                    ours: Data("O".utf8),
                    theirs: nil,
                    in: dir
                )
                let repo = try Repository.open(at: dir)
                let index = try repo.index()
                let hit = index.conflict(for: "c.txt")
                try #require(hit != nil)
                #expect(hit!.ancestor != nil)
                #expect(hit!.ours != nil)
                #expect(hit!.theirs == nil)
                #expect(index.conflict(for: "nonexistent") == nil)
            }
        }

        @Test
        func writeTree_onConflictedIndexThrows() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                _ = try initRepo(at: dir)
                try TestFixture.makeConflictedIndex(
                    at: "c.txt",
                    ancestor: Data("A".utf8),
                    ours: Data("O".utf8),
                    theirs: Data("T".utf8),
                    in: dir
                )
                let repo = try Repository.open(at: dir)
                let index = try repo.index()
                #expect(throws: GitError.self) {
                    _ = try index.writeTree()
                }
            }
        }
    }
}

private func initRepo(at dir: URL) throws -> Repository {
    var raw: OpaquePointer?
    let r: Int32 = dir.withUnsafeFileSystemRepresentation { path in
        guard let path else { return -1 }
        return git_repository_init(&raw, path, 0)
    }
    guard r == 0, let raw else { throw GitError.fromLibgit2(r) }
    git_repository_free(raw)
    return try Repository.open(at: dir)
}
