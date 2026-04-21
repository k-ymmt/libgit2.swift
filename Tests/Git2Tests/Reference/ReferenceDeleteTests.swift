import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct ReferenceDeleteTests {
        private func makeRepoWithInitialCommit(_ dir: URL) throws -> (Repository, Commit) {
            let repo = try Repository.create(at: dir)
            let blobOID = try repo.createBlob(data: Data("x".utf8))
            let tree = try repo.tree(entries: [.init(name: "x", oid: blobOID, filemode: .blob)])
            let commit = try repo.commit(
                tree: tree, parents: [],
                author: .test, message: "initial\n",
                updatingRef: "HEAD"
            )
            return (repo, commit)
        }

        /// Create a non-branch, non-tag ref by calling git_reference_create
        /// directly — that's the v0.4a scope gap Reference.delete() fills.
        private func createCustomRef(
            repo: Repository,
            fullName: String,
            target: OID
        ) throws -> Reference {
            try repo.lock.withLock { () throws(GitError) -> Reference in
                var out: OpaquePointer?
                var oid = target.raw
                let result: Int32 = fullName.withCString { namePtr in
                    git_reference_create(&out, repo.handle, namePtr, &oid, /* force */ 0, /* log_message */ nil)
                }
                try check(result)
                return Reference(handle: out!, repository: repo)
            }
        }

        @Test
        func deletesCustomRef() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, commit) = try makeRepoWithInitialCommit(dir)
                let ref = try createCustomRef(
                    repo: repo,
                    fullName: "refs/notes/custom",
                    target: commit.oid
                )
                try ref.delete()
                #expect(try repo.reference(named: "refs/notes/custom") == nil)
            }
        }

        @Test
        func secondDeleteThrows() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, commit) = try makeRepoWithInitialCommit(dir)
                let ref = try createCustomRef(
                    repo: repo,
                    fullName: "refs/notes/twice",
                    target: commit.oid
                )
                try ref.delete()
                do {
                    try ref.delete()
                    Issue.record("second delete should throw")
                } catch is GitError {
                    // expected — libgit2 reports the ref is gone
                }
            }
        }
    }
}
