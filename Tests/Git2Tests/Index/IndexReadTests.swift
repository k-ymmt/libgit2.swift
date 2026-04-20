import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct IndexReadTests {
        @Test
        func repositoryIndex_returnsHandleWithSameRepo() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                let index = try repo.index()
                #expect(index.repository === repo)
            }
        }

        @Test
        func hasConflicts_isFalseOnFreshRepo() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                let index = try repo.index()
                #expect(index.hasConflicts == false)
            }
        }

        @Test
        func entries_isEmptyOnFreshRepo() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                let index = try repo.index()
                #expect(index.entries.isEmpty)
            }
        }

        @Test
        func entryAt_returnsNilOnFreshRepo() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                let index = try repo.index()
                #expect(index.entry(at: "missing.txt") == nil)
                #expect(index.entry(at: "missing.txt", stage: .ours) == nil)
            }
        }
    }
}
