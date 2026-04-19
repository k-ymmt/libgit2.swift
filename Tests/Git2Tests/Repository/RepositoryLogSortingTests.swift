import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RepositoryLogSortingTests {
        @Test
        func noneSortingMatchesDefaultLog() throws {
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

                let plain  = repo.log(from: tip).map(\.summary)
                let sorted = repo.log(from: tip, sorting: .none).map(\.summary)
                #expect(plain == sorted)
            }
        }

        @Test
        func reverseSortingInvertsLinearHistory() throws {
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
                let summaries = repo.log(from: tip, sorting: .reverse).map(\.summary)
                #expect(summaries == ["first", "second", "third"])
            }
        }

        @Test
        func topologicalSortingEmitsMergeAfterAllAncestors() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeMergeHistory(in: dir)
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tip = try repo.head().resolveToCommit()
                let summaries = repo.log(from: tip, sorting: [.topological, .time]).map(\.summary)
                #expect(summaries.first == "D (merge)")
                #expect(summaries.last  == "A")
                #expect(summaries.count == 4)
            }
        }

        @Test
        func optionSetLiteralAndNoneAreEquivalent() {
            let empty: CommitSequence.Sorting = []
            #expect(empty == CommitSequence.Sorting.none)
        }
    }
}
