import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RepositoryHeadManipulationTests {
        @Test
        func setHeadByRefName_movesHEAD() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "a\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let oid = try head.target
                let commit = try repo.commit(for: oid)
                _ = try repo.createBranch(named: "feature", at: commit, force: false)

                try repo.setHead(referenceName: "refs/heads/feature")

                let after = try repo.head()
                #expect(after.name == "refs/heads/feature")
            }
        }

        @Test
        func setHeadByRefName_acceptsNonExistentBranch_asUnborn() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "a\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)

                // Does not throw — HEAD attaches to the unborn branch.
                try repo.setHead(referenceName: "refs/heads/orphan")

                #expect(repo.isHeadUnborn)
            }
        }

        @Test
        func setHeadDetachedAt_pointsAtCommitDirectly() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "a\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let oid = try head.target

                try repo.setHead(detachedAt: oid)

                // Verify detached via libgit2.
                let detached = repo.lock.withLock {
                    git_repository_head_detached(repo.handle)
                }
                #expect(detached == 1)
            }
        }

        @Test
        func setHeadDetachedAt_treeOidThrowsInvalidSpec() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "a\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)

                // Build a fresh tree via the v0.4a ODB-write API so we have a
                // non-commit OID to feed `setHead(detachedAt:)`. The OID is in
                // the ODB but peels to a tree, not a commit — libgit2
                // surfaces that as .invalidSpec / .object (not .notFound,
                // which is reserved for "no object with that OID exists at
                // all").
                let blob = try repo.createBlob(data: Data("x\n".utf8))
                let tree = try repo.tree(entries: [
                    .init(name: "x.txt", oid: blob, filemode: .blob)
                ])

                do {
                    try repo.setHead(detachedAt: tree.oid)
                    Issue.record("expected GitError on non-commit OID")
                } catch let e as GitError {
                    #expect(e.code == .invalidSpec)
                    #expect(e.class == .object)
                }
            }
        }

        @Test
        func setHeadToReference_matchesRefNameOverload() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "a\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let commit = try repo.commit(for: head.target)
                let featureRef = try repo.createBranch(named: "feature", at: commit, force: false)

                try repo.setHead(to: featureRef)

                #expect(try repo.head().name == "refs/heads/feature")
            }
        }

        @Test
        func setHeadToCommit_matchesDetachedAtOverload() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "a\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let commit = try repo.commit(for: head.target)

                try repo.setHead(to: commit)

                let detached = repo.lock.withLock {
                    git_repository_head_detached(repo.handle)
                }
                #expect(detached == 1)
            }
        }
    }
}
