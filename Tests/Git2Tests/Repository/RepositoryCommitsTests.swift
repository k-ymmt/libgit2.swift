import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RepositoryCommitsTests {
        /// Initialize an empty repo, open it, and create a README blob + tree.
        private func makeRepoWithReadmeTree(_ dir: URL) throws -> (Repository, Tree) {
            let repo = try Repository.create(at: dir)
            let blobOID = try repo.createBlob(data: Data("hello\n".utf8))
            let tree = try repo.tree(entries: [
                .init(name: "README.md", oid: blobOID, filemode: .blob)
            ])
            return (repo, tree)
        }

        @Test
        func initialCommitAdvancesHead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, tree) = try makeRepoWithReadmeTree(dir)

                #expect(repo.isHeadUnborn == true)

                let commit = try repo.commit(
                    tree: tree,
                    parents: [],
                    author: .test,
                    message: "initial\n",
                    updatingRef: "HEAD"
                )

                #expect(repo.isHeadUnborn == false)
                let head = try repo.head().resolveToCommit()
                #expect(head.oid == commit.oid)
                #expect(commit.summary == "initial")
                #expect(commit.parentCount == 0)
            }
        }

        @Test
        func chainedCommitLinksParent() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, tree) = try makeRepoWithReadmeTree(dir)
                let first = try repo.commit(
                    tree: tree, parents: [],
                    author: .test, message: "a\n",
                    updatingRef: "HEAD"
                )
                let second = try repo.commit(
                    tree: tree, parents: [first],
                    author: .test, message: "b\n",
                    updatingRef: "HEAD"
                )
                #expect(second.parentCount == 1)
                let parents = try second.parents()
                #expect(parents.count == 1)
                #expect(parents[0].oid == first.oid)
            }
        }

        @Test
        func mergeCommitHasTwoParents() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, tree) = try makeRepoWithReadmeTree(dir)
                let a = try repo.commit(tree: tree, parents: [],   author: .test, message: "a\n", updatingRef: "HEAD")
                let b = try repo.commit(tree: tree, parents: [a],  author: .test, message: "b\n", updatingRef: "HEAD")
                let c = try repo.commit(tree: tree, parents: [a],  author: .test, message: "c\n", updatingRef: "refs/heads/side")
                let merge = try repo.commit(
                    tree: tree, parents: [b, c],
                    author: .test, message: "merge\n",
                    updatingRef: "HEAD"
                )
                #expect(merge.parentCount == 2)
                let parents = try merge.parents()
                #expect(parents.map(\.oid) == [b.oid, c.oid])
            }
        }

        @Test
        func danglingCommitDoesNotMoveHead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, tree) = try makeRepoWithReadmeTree(dir)
                let first = try repo.commit(
                    tree: tree, parents: [],
                    author: .test, message: "first\n",
                    updatingRef: "HEAD"
                )
                let dangling = try repo.commit(
                    tree: tree, parents: [first],
                    author: .test, message: "dangling\n",
                    updatingRef: nil
                )
                // HEAD still points at `first`.
                let head = try repo.head().resolveToCommit()
                #expect(head.oid == first.oid)
                // Dangling commit is still reachable by OID.
                let re = try repo.commit(for: dangling.oid)
                #expect(re.oid == dangling.oid)
            }
        }

        @Test
        func committerDefaultsToAuthor() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (repo, tree) = try makeRepoWithReadmeTree(dir)
                let author = Signature(
                    name: "Author", email: "a@example.com",
                    date: Date(timeIntervalSince1970: 1_700_000_000),
                    timeZone: TimeZone(secondsFromGMT: 0)!
                )
                let commit = try repo.commit(
                    tree: tree, parents: [],
                    author: author,
                    message: "x\n",
                    updatingRef: "HEAD"
                )
                #expect(commit.author == commit.committer)
            }
        }
    }
}
