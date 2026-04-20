import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RepositoryTagsTests {
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
        func lightweightTagPointsAtTarget() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, commit) = try makeRepoWithInitialCommit(dir)
                let ref = try repo.createLightweightTag(named: "v1", target: commit)
                #expect(ref.name == "refs/tags/v1")
                #expect(try ref.target == commit.oid)
            }
        }

        @Test
        func annotatedTagExposesMessageAndTagger() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, commit) = try makeRepoWithInitialCommit(dir)
                let tag = try repo.createAnnotatedTag(
                    named: "v2",
                    target: commit,
                    tagger: .test,
                    message: "release v2\n"
                )
                #expect(tag.name == "v2")
                #expect(tag.message == "release v2\n")
                #expect(tag.tagger == .test)
                #expect(tag.targetOID == commit.oid)
                #expect(tag.targetKind == .commit)
            }
        }

        @Test
        func createTagRejectsDuplicateWithoutForce() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, commit) = try makeRepoWithInitialCommit(dir)
                _ = try repo.createLightweightTag(named: "v1", target: commit)
                do {
                    _ = try repo.createLightweightTag(named: "v1", target: commit)
                    Issue.record("expected .exists")
                } catch let error as GitError {
                    #expect(error.code == .exists)
                }
            }
        }

        @Test
        func createTagAcceptsDuplicateWithForce() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, commit) = try makeRepoWithInitialCommit(dir)
                _ = try repo.createAnnotatedTag(named: "v1", target: commit, tagger: .test, message: "a\n")
                _ = try repo.createAnnotatedTag(named: "v1", target: commit, tagger: .test, message: "b\n", force: true)
            }
        }

        @Test
        func deleteTagRemovesLightweightRef() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, commit) = try makeRepoWithInitialCommit(dir)
                _ = try repo.createLightweightTag(named: "v1", target: commit)
                try repo.deleteTag(named: "v1")
                #expect(try repo.reference(named: "refs/tags/v1") == nil)
            }
        }

        @Test
        func deleteTagRemovesAnnotatedRef() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, commit) = try makeRepoWithInitialCommit(dir)
                _ = try repo.createAnnotatedTag(named: "v1", target: commit, tagger: .test, message: "a\n")
                try repo.deleteTag(named: "v1")
                #expect(try repo.reference(named: "refs/tags/v1") == nil)
            }
        }

        @Test
        func deleteTagOnMissingThrowsNotFound() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, _) = try makeRepoWithInitialCommit(dir)
                do {
                    try repo.deleteTag(named: "nonexistent")
                    Issue.record("expected .notFound")
                } catch let error as GitError {
                    #expect(error.code == .notFound)
                }
            }
        }
    }
}
