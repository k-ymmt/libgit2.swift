import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct CheckoutTreeTests {
        @Test
        func treeOverload_restoresTreeContent() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "hello\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)

                // Build a brand-new tree containing README.md="custom\n".
                // Using the v0.4a ODB-write API because Commit.tree() is not
                // part of the current public surface; `tree(entries:)` is
                // the shipped path to obtain a Tree handle in v0.4b-ii.
                let customBlob = try repo.createBlob(data: Data("custom\n".utf8))
                let customTree = try repo.tree(entries: [
                    .init(name: "README.md", oid: customBlob, filemode: .blob)
                ])

                let headBefore = try repo.head().target

                try repo.checkoutTree(
                    customTree,
                    options: Repository.CheckoutOptions(strategy: [.force])
                )

                let content = try String(
                    contentsOf: dir.appendingPathComponent("README.md"),
                    encoding: .utf8
                )
                #expect(content == "custom\n")

                // HEAD is unchanged.
                #expect(try repo.head().target == headBefore)
            }
        }

        @Test
        func commitOverload_peelsToTree() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [
                        (message: "first\n",  author: .test),
                        (message: "second\n", author: .test),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)

                // Walk HEAD -> parent to get the first commit.
                let head = try repo.head()
                let tip = try repo.commit(for: head.target)
                let first = try #require(tip.parents().first)

                try repo.checkoutTree(
                    first,
                    options: Repository.CheckoutOptions(strategy: [.force])
                )

                // First commit's tree held README.md="first\n".
                let content = try String(
                    contentsOf: dir.appendingPathComponent("README.md"),
                    encoding: .utf8
                )
                #expect(content == "first\n")

                // HEAD is unchanged.
                #expect(try repo.head().target == head.target)
            }
        }
    }
}
