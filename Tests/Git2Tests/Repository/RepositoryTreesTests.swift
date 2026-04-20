import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RepositoryTreesTests {
        /// Creates an empty repository (no initial commit) and returns an open
        /// Repository plus a `README` blob OID.
        private func makeRepoWithReadmeBlob(_ dir: URL) throws -> (Repository, OID) {
            var raw: OpaquePointer?
            dir.withUnsafeFileSystemRepresentation { path in
                _ = git_repository_init(&raw, path, 0)
            }
            guard let raw else { throw GitError(code: .invalid, class: .invalid, message: "init failed") }
            git_repository_free(raw)

            let repo = try Repository.open(at: dir)
            let blob = try repo.createBlob(data: Data("hello\n".utf8))
            return (repo, blob)
        }

        @Test
        func buildsSingleEntryTree() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, blobOID) = try makeRepoWithReadmeBlob(dir)
                let tree = try repo.tree(entries: [
                    .init(name: "README.md", oid: blobOID, filemode: .blob)
                ])
                #expect(tree.count == 1)
                let entry = try #require(tree[name: "README.md"])
                #expect(entry.oid == blobOID)
                #expect(entry.filemode == .blob)
            }
        }

        @Test
        func buildsEmptyTreeWithCanonicalOID() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, _) = try makeRepoWithReadmeBlob(dir)
                let tree = try repo.tree(entries: [])
                #expect(tree.oid.hex == "4b825dc642cb6eb9a060e54bf8d69288fbee4904")
                #expect(tree.count == 0)
            }
        }

        @Test
        func nestsSubTreeViaOID() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, blobOID) = try makeRepoWithReadmeBlob(dir)
                let inner = try repo.tree(entries: [
                    .init(name: "README.md", oid: blobOID, filemode: .blob)
                ])
                let outer = try repo.tree(entries: [
                    .init(name: "docs", oid: inner.oid, filemode: .tree)
                ])
                let sub = try #require(outer[name: "docs"])
                #expect(sub.filemode == .tree)
                #expect(sub.oid == inner.oid)
            }
        }

        @Test
        func duplicateNamesThrowExists() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, blobOID) = try makeRepoWithReadmeBlob(dir)
                do {
                    _ = try repo.tree(entries: [
                        .init(name: "x", oid: blobOID, filemode: .blob),
                        .init(name: "x", oid: blobOID, filemode: .blob),
                    ])
                    Issue.record("expected throw")
                } catch let error as GitError {
                    #expect(error.code == .exists)
                }
            }
        }
    }
}
