import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct CheckoutBranchTests {
        /// Build a repo with two commits on HEAD and an additional branch
        /// `feature` pointing at the **first** commit. HEAD starts at the
        /// second commit.
        private func makeRepoWithFeatureBranch(in dir: URL) throws -> (Repository, firstCommit: Commit, secondCommit: Commit, featureRef: Reference) {
            let fixture = try TestFixture.makeLinearHistory(
                commits: [
                    (message: "first\n",  author: .test),
                    (message: "second\n", author: .test),
                ],
                in: dir
            )
            let repo = try Repository.open(at: fixture.repositoryURL)
            let head = try repo.head()
            let second = try repo.commit(for: head.target)
            let first = try #require(second.parents().first)
            let featureRef = try repo.createBranch(named: "feature", at: first, force: false)
            return (repo, first, second, featureRef)
        }

        @Test
        func checkoutBranchReference_updatesWorkdirAndHEAD() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, first, _, featureRef) = try makeRepoWithFeatureBranch(in: dir)

                try repo.checkout(
                    branch: featureRef,
                    options: Repository.CheckoutOptions(strategy: [.force])
                )

                let content = try String(
                    contentsOf: dir.appendingPathComponent("README.md"),
                    encoding: .utf8
                )
                #expect(content == "first\n")
                #expect(try repo.head().name == "refs/heads/feature")
                #expect(try repo.head().target == first.oid)
            }
        }

        @Test
        func checkoutBranchNamed_matchesReferenceOverload() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, first, _, _) = try makeRepoWithFeatureBranch(in: dir)

                try repo.checkout(
                    branchNamed: "feature",
                    options: Repository.CheckoutOptions(strategy: [.force])
                )

                let content = try String(
                    contentsOf: dir.appendingPathComponent("README.md"),
                    encoding: .utf8
                )
                #expect(content == "first\n")
                #expect(try repo.head().target == first.oid)
            }
        }

        @Test
        func checkoutBranchNamed_missingBranchThrowsNotFound() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, _, _, _) = try makeRepoWithFeatureBranch(in: dir)
                do {
                    try repo.checkout(branchNamed: "does-not-exist")
                    Issue.record("expected GitError.Code.notFound")
                } catch let e as GitError {
                    #expect(e.code == .notFound)
                }
            }
        }

        @Test
        func checkoutBranch_tagReferenceThrowsInvalidSpec_beforeTouchingWorkdir() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, first, _, _) = try makeRepoWithFeatureBranch(in: dir)

                // Create a lightweight tag at `first`.
                _ = try repo.createLightweightTag(named: "v1", target: first, force: false)

                // Look up the tag reference (via `references` sequence).
                var tagRef: Reference?
                for ref in try repo.references() {
                    if ref.name == "refs/tags/v1" {
                        tagRef = ref
                        break
                    }
                }
                let tag = try #require(tagRef)

                // Snapshot HEAD + workdir before.
                let headBefore = try repo.head().name
                // Materialize README.md on disk to check it's not touched on
                // failure. makeLinearHistory writes only to the ODB.
                let readme = dir.appendingPathComponent("README.md")
                try Data("second\n".utf8).write(to: readme)

                do {
                    try repo.checkout(
                        branch: tag,
                        options: Repository.CheckoutOptions(strategy: [.force])
                    )
                    Issue.record("expected GitError.Code.invalidSpec for non-branch reference")
                } catch let e as GitError {
                    #expect(e.code == .invalidSpec)
                    #expect(e.class == .reference)
                }

                // HEAD and workdir must be unchanged.
                #expect(try repo.head().name == headBefore)
                #expect(try String(contentsOf: readme, encoding: .utf8) == "second\n")
            }
        }

        @Test
        func checkoutBranch_dirtyWorkdirSafeThrows_HEADUnchanged() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, _, _, featureRef) = try makeRepoWithFeatureBranch(in: dir)

                // Materialize + make the workdir dirty vs. both HEAD and feature.
                try Data("DIRTY\n".utf8).write(
                    to: dir.appendingPathComponent("README.md")
                )
                let headBefore = try repo.head().name

                do {
                    try repo.checkout(branch: featureRef)   // default safe
                    Issue.record("expected GitError with Class.checkout")
                } catch let e as GitError {
                    #expect(e.class == .checkout)
                }

                #expect(try repo.head().name == headBefore)
            }
        }

        @Test
        func checkoutBranch_dirtyWorkdirForceSucceeds() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, first, _, featureRef) = try makeRepoWithFeatureBranch(in: dir)

                try Data("DIRTY\n".utf8).write(
                    to: dir.appendingPathComponent("README.md")
                )

                try repo.checkout(
                    branch: featureRef,
                    options: Repository.CheckoutOptions(strategy: [.force])
                )

                let content = try String(
                    contentsOf: dir.appendingPathComponent("README.md"),
                    encoding: .utf8
                )
                #expect(content == "first\n")
                #expect(try repo.head().target == first.oid)
            }
        }
    }
}
