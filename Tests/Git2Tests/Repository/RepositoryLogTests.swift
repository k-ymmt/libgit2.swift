import Testing
import Foundation
@testable import Git2

// These tests call `Git.bootstrap()` / `Git.shutdown()` and so must run serially
// with any other test that touches the runtime lifecycle. They are nested under
// the serialized root suite `RuntimeSensitiveTests` (declared in
// `RuntimeSensitiveTests.swift`) to guarantee mutual exclusion with the
// lifecycle tests — otherwise the global refcount can drop to 0 while these
// tests are mid-call and trip `requireBootstrapped()`.
extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RepositoryLogTests {
        @Test
        func logWalksLinearHistoryNewestFirst() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [
                        (message: "first",  author: .test),
                        (message: "second", author: .test),
                        (message: "third",  author: .test),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tip = try repo.head().resolveToCommit()
                let summaries = repo.log(from: tip).map(\.summary)
                #expect(summaries == ["third", "second", "first"])
            }
        }

        @Test
        func logCanBeIteratedTwice() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [
                        (message: "a", author: .test),
                        (message: "b", author: .test),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tip = try repo.head().resolveToCommit()
                let sequence = repo.log(from: tip)
                #expect(sequence.map(\.summary) == ["b", "a"])
                #expect(sequence.map(\.summary) == ["b", "a"])
            }
        }

        @Test
        func logOnMergeReachesAllAncestors() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeMergeHistory(in: dir)
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tip = try repo.head().resolveToCommit()
                let summaries = Set(repo.log(from: tip).map(\.summary))
                #expect(summaries == Set(["A", "B", "C", "D (merge)"]))
            }
        }

        @Test
        func logPrefixWorks() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [
                        (message: "one",   author: .test),
                        (message: "two",   author: .test),
                        (message: "three", author: .test),
                        (message: "four",  author: .test),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tip = try repo.head().resolveToCommit()
                let first2 = repo.log(from: tip).prefix(2).map(\.summary)
                #expect(first2 == ["four", "three"])
            }
        }
    }
}
