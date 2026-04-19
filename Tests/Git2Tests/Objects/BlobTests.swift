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
                let payload = Data([0x62, 0x65, 0x66, 0x6f, 0x72, 0x65,   // "before"
                                    0x00,
                                    0x61, 0x66, 0x74, 0x65, 0x72])        // "after"
                let made = try TestFixture.makeCommitWithTree(
                    entries: [.init(path: "bin", content: payload, mode: GIT_FILEMODE_BLOB)],
                    in: dir
                )
                let repo = try Repository.open(at: made.fixture.repositoryURL)
                guard case .tree(let tree) = try repo.object(for: OID(raw: made.treeOID)) else {
                    Issue.record("expected tree")
                    return
                }
                let entry = try #require(tree[name: "bin"])
                guard case .blob(let blob) = try #require(try repo.object(for: entry.oid)) else {
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
