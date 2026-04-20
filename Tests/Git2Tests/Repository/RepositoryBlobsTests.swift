import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RepositoryBlobsTests {
        @Test
        func writesKnownHelloBlob() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                var raw: OpaquePointer?
                dir.withUnsafeFileSystemRepresentation { path in
                    _ = git_repository_init(&raw, path, 0)
                }
                guard let raw else { Issue.record("init failed"); return }
                git_repository_free(raw)

                let repo = try Repository.open(at: dir)
                let oid = try repo.createBlob(data: Data("hello\n".utf8))

                // git hash-object -w --stdin <<< "hello"
                #expect(oid.hex == "ce013625030ba8dba906f756967f9e9ca394464a")
            }
        }

        @Test
        func writesEmptyBlob() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                var raw: OpaquePointer?
                dir.withUnsafeFileSystemRepresentation { path in
                    _ = git_repository_init(&raw, path, 0)
                }
                guard let raw else { Issue.record("init failed"); return }
                git_repository_free(raw)

                let repo = try Repository.open(at: dir)
                let oid = try repo.createBlob(data: Data())

                // Canonical empty-blob OID.
                #expect(oid.hex == "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
            }
        }

        @Test
        func blobIsRetrievableViaObjectLookup() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                var raw: OpaquePointer?
                dir.withUnsafeFileSystemRepresentation { path in
                    _ = git_repository_init(&raw, path, 0)
                }
                guard let raw else { Issue.record("init failed"); return }
                git_repository_free(raw)

                let repo = try Repository.open(at: dir)
                let payload = Data("round-trip".utf8)
                let oid = try repo.createBlob(data: payload)

                guard case .blob(let blob) = try #require(try repo.object(for: oid)) else {
                    Issue.record("expected .blob"); return
                }
                #expect(blob.content == payload)
            }
        }
    }
}
