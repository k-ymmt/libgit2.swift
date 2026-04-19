import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct DiffTests {
        @Test
        func diffNilToTreeReportsAllAdded() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let made = try TestFixture.makeCommitWithTree(
                    entries: [
                        .init(path: "a.txt", content: "a", mode: GIT_FILEMODE_BLOB),
                        .init(path: "b.txt", content: "b", mode: GIT_FILEMODE_BLOB),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: made.fixture.repositoryURL)
                guard case .tree(let tree) = try #require(try repo.object(for: OID(raw: made.treeOID))) else {
                    Issue.record("expected tree"); return
                }
                let diff = try repo.diff(from: nil, to: tree)
                #expect(diff.count == 2)
                for i in 0..<diff.count {
                    #expect(diff[i].status == .added)
                }
            }
        }

        @Test
        func diffSameTreeIsEmpty() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let made = try TestFixture.makeCommitWithTree(
                    entries: [.init(path: "a.txt", content: "a", mode: GIT_FILEMODE_BLOB)],
                    in: dir
                )
                let repo = try Repository.open(at: made.fixture.repositoryURL)
                guard case .tree(let tree) = try #require(try repo.object(for: OID(raw: made.treeOID))) else {
                    Issue.record("expected tree"); return
                }
                let diff = try repo.diff(from: tree, to: tree)
                #expect(diff.count == 0)
            }
        }

        @Test
        func diffWithBothNilThrowsInvalid() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "m", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                #expect(throws: GitError.self) {
                    _ = try repo.diff(from: nil, to: nil)
                }
            }
        }

        @Test
        func diffDetectsModificationAndDeletion() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                // First tree: two files.
                let first = try TestFixture.makeCommitWithTree(
                    entries: [
                        .init(path: "keep",   content: "v1", mode: GIT_FILEMODE_BLOB),
                        .init(path: "remove", content: "x",  mode: GIT_FILEMODE_BLOB),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: first.fixture.repositoryURL)

                // Second tree: modify "keep", drop "remove", add "new". Build it
                // directly via libgit2 without a new commit.
                var keepBlob = git_oid()
                "v2".withCString { bytes in
                    _ = git_blob_create_from_buffer(&keepBlob, repo.handle, UnsafeRawPointer(bytes), strlen(bytes))
                }
                var newBlob = git_oid()
                "n".withCString { bytes in
                    _ = git_blob_create_from_buffer(&newBlob, repo.handle, UnsafeRawPointer(bytes), strlen(bytes))
                }
                var tb: OpaquePointer?
                #expect(git_treebuilder_new(&tb, repo.handle, nil) == 0)
                defer { git_treebuilder_free(tb) }
                _ = git_treebuilder_insert(nil, tb, "keep", &keepBlob, GIT_FILEMODE_BLOB)
                _ = git_treebuilder_insert(nil, tb, "new",  &newBlob,  GIT_FILEMODE_BLOB)
                var secondTreeOID = git_oid()
                #expect(git_treebuilder_write(&secondTreeOID, tb) == 0)

                guard case .tree(let firstTree) = try #require(try repo.object(for: OID(raw: first.treeOID))) else {
                    Issue.record("expected first tree"); return
                }
                guard case .tree(let secondTree) = try #require(try repo.object(for: OID(raw: secondTreeOID))) else {
                    Issue.record("expected second tree"); return
                }

                let diff = try repo.diff(from: firstTree, to: secondTree)
                #expect(diff.count == 3)

                var statusByPath: [String: DiffDelta.Status] = [:]
                for i in 0..<diff.count {
                    let d = diff[i]
                    let path = d.status == .added ? d.newFile.path : d.oldFile.path
                    statusByPath[path] = d.status
                }
                #expect(statusByPath["keep"]   == .modified)
                #expect(statusByPath["remove"] == .deleted)
                #expect(statusByPath["new"]    == .added)
            }
        }
    }
}
