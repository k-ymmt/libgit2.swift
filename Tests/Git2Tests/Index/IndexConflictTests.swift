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
