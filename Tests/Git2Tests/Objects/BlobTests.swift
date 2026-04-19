import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct BlobTests {
        @Test
        func textBlobSizeAndContentMatch() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let text = "hello world"
                let made = try TestFixture.makeCommitWithTree(
                    entries: [.init(path: "greeting.txt", content: text, mode: GIT_FILEMODE_BLOB)],
                    in: dir
                )
                let repo = try Repository.open(at: made.fixture.repositoryURL)
                guard case .tree(let tree) = try repo.object(for: OID(raw: made.treeOID)) else {
                    Issue.record("expected tree")
                    return
                }
                let entry = try #require(tree[name: "greeting.txt"])
                guard case .blob(let blob) = try #require(try repo.object(for: entry.oid)) else {
                    Issue.record("expected blob")
                    return
                }
                #expect(blob.size == Int64(text.utf8.count))
                #expect(blob.content == Data(text.utf8))
                #expect(blob.isBinary == false)
            }
        }

        @Test
        func binaryBlobIsBinary() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                // A NUL byte in the first 8000 bytes is libgit2's binary marker.
                // Write the blob directly with raw bytes to preserve the NUL byte
                // (String content + strlen would truncate at the NUL).
                var repoHandle: OpaquePointer?
                let rInit: Int32 = dir.withUnsafeFileSystemRepresentation { path in
                    guard let path else { return -1 }
                    return git_repository_init(&repoHandle, path, 0)
                }
                guard rInit == 0, let repo = repoHandle else {
                    Issue.record("failed to init repo: \(rInit)")
                    return
                }
                defer { git_repository_free(repo) }

                var bytes: [UInt8] = Array("before".utf8) + [0x00] + Array("after".utf8)
                var blobOID = git_oid()
                let rBlob = bytes.withUnsafeMutableBytes { buf in
                    git_blob_create_from_buffer(&blobOID, repo, buf.baseAddress!, buf.count)
                }
                guard rBlob == 0 else {
                    Issue.record("failed to create blob: \(rBlob)")
                    return
                }

                // Re-open via Repository wrapper to exercise the public API.
                let wRepo = try Repository.open(at: dir)
                guard case .blob(let blob) = try #require(try wRepo.object(for: OID(raw: blobOID))) else {
                    Issue.record("expected blob")
                    return
                }
                #expect(blob.isBinary == true)
            }
        }

        @Test
        func emptyBlobHasZeroSize() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let made = try TestFixture.makeCommitWithTree(
                    entries: [.init(path: "empty", content: "", mode: GIT_FILEMODE_BLOB)],
                    in: dir
                )
                let repo = try Repository.open(at: made.fixture.repositoryURL)
                guard case .tree(let tree) = try repo.object(for: OID(raw: made.treeOID)) else {
                    Issue.record("expected tree")
                    return
                }
                let entry = try #require(tree[name: "empty"])
                guard case .blob(let blob) = try #require(try repo.object(for: entry.oid)) else {
                    Issue.record("expected blob")
                    return
                }
                #expect(blob.size == 0)
                #expect(blob.content.isEmpty)
            }
        }
    }
}
