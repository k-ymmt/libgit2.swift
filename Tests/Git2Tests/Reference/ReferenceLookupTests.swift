import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct ReferenceLookupTests {
        @Test
        func existingReferenceReturnsReference() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "m", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let ref = try #require(try repo.reference(named: head.name))
                #expect(ref.name == head.name)
            }
        }

        @Test
        func missingReferenceReturnsNil() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "m", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                #expect(try repo.reference(named: "refs/heads/does-not-exist") == nil)
            }
        }

        @Test
        func invalidRefSpecThrows() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "m", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                // An empty string is always rejected by libgit2 with GIT_EINVALIDSPEC.
                #expect(throws: GitError.self) {
                    _ = try repo.reference(named: "")
                }
            }
        }
    }
}
