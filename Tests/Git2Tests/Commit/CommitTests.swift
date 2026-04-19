import Testing
import Foundation
@testable import Git2

// These tests call `Git.bootstrap()` / `Git.shutdown()` and so must run serially
// with any other test that touches the runtime lifecycle. They are nested under
// the serialized root suite `RuntimeSensitiveTests` (declared in
// `RuntimeSensitiveTests.swift`) to guarantee mutual exclusion with the
// lifecycle tests.
extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct CommitTests {
        @Test
        func commitExposesOIDMessageAuthorCommitter() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let author = Signature.test
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "hello\n\nbody text here", author: author)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let tipOID = try head.target
                let commit = try repo.commit(for: tipOID)

                #expect(commit.oid == tipOID)
                #expect(commit.message.hasPrefix("hello"))
                #expect(commit.summary == "hello")
                #expect(commit.body == "body text here")
                #expect(commit.author.name == author.name)
                #expect(commit.author.email == author.email)
                #expect(commit.committer.name == author.name)
                #expect(commit.parentCount == 0)
            }
        }

        @Test
        func commitWithoutBodyHasNilBody() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "single line", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let commit = try repo.commit(for: try head.target)
                #expect(commit.body == nil)
            }
        }

        @Test
        func commitParentsForLinearHistory() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [
                        (message: "first",  author: .test),
                        (message: "second", author: .test),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tip = try repo.head().resolveToCommit()
                let parents = try tip.parents()
                #expect(parents.count == 1)
                #expect(parents[0].summary == "first")
            }
        }

        @Test
        func commitParentsForMergeHistory() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeMergeHistory(in: dir)
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tip = try repo.head().resolveToCommit()
                let parents = try tip.parents()
                #expect(parents.count == 2)
            }
        }
    }
}
