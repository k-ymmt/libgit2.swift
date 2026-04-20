import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RepositoryBranchesTests {
        /// Create an empty repo, make one commit on HEAD, return (repo, commit).
        private func makeRepoWithInitialCommit(_ dir: URL) throws -> (Repository, Commit) {
            var raw: OpaquePointer?
            dir.withUnsafeFileSystemRepresentation { path in
                _ = git_repository_init(&raw, path, 0)
            }
            guard let raw else { throw GitError(code: .invalid, class: .invalid, message: "init failed") }
            git_repository_free(raw)

            let repo = try Repository.open(at: dir)
            let blobOID = try repo.createBlob(data: Data("x".utf8))
            let tree = try repo.tree(entries: [.init(name: "x", oid: blobOID, filemode: .blob)])
            let commit = try repo.commit(
                tree: tree, parents: [],
                author: .test, message: "initial\n",
                updatingRef: "HEAD"
            )
            return (repo, commit)
        }

        @Test
        func createBranchPlacesRefAtTarget() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, commit) = try makeRepoWithInitialCommit(dir)
                let branch = try repo.createBranch(named: "feature", at: commit)
                #expect(branch.name == "refs/heads/feature")
                #expect(try branch.target == commit.oid)
            }
        }

        @Test
        func createBranchWithoutForceRejectsDuplicate() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, commit) = try makeRepoWithInitialCommit(dir)
                _ = try repo.createBranch(named: "feature", at: commit)
                do {
                    _ = try repo.createBranch(named: "feature", at: commit)
                    Issue.record("expected .exists")
                } catch let error as GitError {
                    #expect(error.code == .exists)
                }
            }
        }

        @Test
        func createBranchWithForceOverwrites() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, commit) = try makeRepoWithInitialCommit(dir)
                _ = try repo.createBranch(named: "feature", at: commit)
                let again = try repo.createBranch(named: "feature", at: commit, force: true)
                #expect(again.name == "refs/heads/feature")
            }
        }

        @Test
        func deleteBranchRemovesRef() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, commit) = try makeRepoWithInitialCommit(dir)
                _ = try repo.createBranch(named: "feature", at: commit)
                try repo.deleteBranch(named: "feature")
                #expect(try repo.reference(named: "refs/heads/feature") == nil)
            }
        }

        @Test
        func deleteMissingBranchThrowsNotFound() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, _) = try makeRepoWithInitialCommit(dir)
                do {
                    try repo.deleteBranch(named: "no-such-branch")
                    Issue.record("expected .notFound")
                } catch let error as GitError {
                    #expect(error.code == .notFound)
                }
            }
        }

        @Test
        func deleteCurrentBranchThrows() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, _) = try makeRepoWithInitialCommit(dir)
                // HEAD is on refs/heads/main (or master, depending on defaults).
                let head = try repo.head()
                let shortName = head.shorthand
                do {
                    try repo.deleteBranch(named: shortName)
                    Issue.record("libgit2 should refuse to delete the current branch")
                } catch is GitError {
                    // Accept any GitError — libgit2's exact code depends on
                    // version; behavior is what matters.
                }
            }
        }
    }
}
