import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct TreeTests {
        @Test
        func treeCountMatchesEntryCount() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let made = try TestFixture.makeCommitWithTree(
                    entries: [
                        .init(path: "a.txt", content: "a", mode: GIT_FILEMODE_BLOB),
                        .init(path: "b.txt", content: "bb", mode: GIT_FILEMODE_BLOB),
                        .init(path: "run",   content: "#!",  mode: GIT_FILEMODE_BLOB_EXECUTABLE),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: made.fixture.repositoryURL)
                let treeObj = try repo.object(for: OID(raw: made.treeOID))
                guard case .tree(let tree) = treeObj else {
                    Issue.record("expected .tree case, got \(String(describing: treeObj))")
                    return
                }
                #expect(tree.count == 3)
            }
        }

        @Test
        func treeSubscriptByIndexReturnsEntries() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let made = try TestFixture.makeCommitWithTree(
                    entries: [
                        .init(path: "a.txt", content: "a",  mode: GIT_FILEMODE_BLOB),
                        .init(path: "b.txt", content: "bb", mode: GIT_FILEMODE_BLOB),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: made.fixture.repositoryURL)
                guard case .tree(let tree) = try repo.object(for: OID(raw: made.treeOID)) else {
                    Issue.record("expected tree")
                    return
                }
                // Trees are name-sorted — a.txt before b.txt.
                #expect(tree[0].name == "a.txt")
                #expect(tree[1].name == "b.txt")
                #expect(tree[0].kind == .blob)
                #expect(tree[0].filemode == .blob)
            }
        }

        @Test
        func treeSubscriptByNameHitsAndMisses() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let made = try TestFixture.makeCommitWithTree(
                    entries: [
                        .init(path: "hello.txt", content: "hello", mode: GIT_FILEMODE_BLOB),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: made.fixture.repositoryURL)
                guard case .tree(let tree) = try repo.object(for: OID(raw: made.treeOID)) else {
                    Issue.record("expected tree")
                    return
                }
                #expect(tree[name: "hello.txt"]?.name == "hello.txt")
                #expect(tree[name: "missing.txt"] == nil)
            }
        }

        @Test
        func treeEntryFileModeCoversBlobAndExecutable() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let made = try TestFixture.makeCommitWithTree(
                    entries: [
                        .init(path: "plain",      content: "x", mode: GIT_FILEMODE_BLOB),
                        .init(path: "executable", content: "x", mode: GIT_FILEMODE_BLOB_EXECUTABLE),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: made.fixture.repositoryURL)
                guard case .tree(let tree) = try repo.object(for: OID(raw: made.treeOID)) else {
                    Issue.record("expected tree")
                    return
                }
                #expect(tree[name: "plain"]?.filemode      == .blob)
                #expect(tree[name: "executable"]?.filemode == .blobExecutable)
            }
        }

        @Test
        func treeOidIsAccessible() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let made = try TestFixture.makeCommitWithTree(
                    entries: [.init(path: "x", content: "x", mode: GIT_FILEMODE_BLOB)],
                    in: dir
                )
                let repo = try Repository.open(at: made.fixture.repositoryURL)
                guard case .tree(let tree) = try repo.object(for: OID(raw: made.treeOID)) else {
                    Issue.record("expected tree")
                    return
                }
                #expect(tree.oid == OID(raw: made.treeOID))
            }
        }
    }
}
