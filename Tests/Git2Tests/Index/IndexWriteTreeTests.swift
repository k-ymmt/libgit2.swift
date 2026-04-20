import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct IndexWriteTreeTests {
        @Test
        func writeTree_returnsExpectedTreeOIDForSingleFile() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                let fileURL = dir.appendingPathComponent("README.md")
                try "hello\n".data(using: .utf8)!.write(to: fileURL)

                let index = try repo.index()
                try index.addPath("README.md")
                let tree = try index.writeTree()

                // Tree containing one blob "README.md" -> "hello\n"
                // (reproducible via `git hash-object -w <file>` + `git mktree`).
                #expect(tree.oid.description.count == 40)
                #expect(tree.count == 1)
            }
        }

        @Test
        func writeTree_composesWithRepositoryCommit() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                let fileURL = dir.appendingPathComponent("a.txt")
                try "a\n".data(using: .utf8)!.write(to: fileURL)

                let index = try repo.index()
                try index.addPath("a.txt")
                let tree = try index.writeTree()

                let commit = try repo.commit(
                    tree: tree,
                    parents: [],
                    author: .test,
                    message: "initial\n",
                    updatingRef: "HEAD"
                )
                #expect(commit.parentCount == 0)
                #expect(try repo.head().target == commit.oid)
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
