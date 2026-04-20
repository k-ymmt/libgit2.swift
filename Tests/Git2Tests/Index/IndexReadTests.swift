import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct IndexReadTests {
        @Test
        func repositoryIndex_returnsHandleWithSameRepo() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                let index = try repo.index()
                #expect(index.repository === repo)
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
    precondition(r == 0)
    git_repository_free(raw)
    return try Repository.open(at: dir)
}
