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
    struct RepositoryHeadTests {
        @Test
        func headReturnsReferenceOnPopulatedRepo() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "one", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                #expect(head.name.hasPrefix("refs/heads/"))
                #expect(["main", "master"].contains(head.shorthand))
            }
        }

        @Test
        func headOnUnbornBranchThrows() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                _ = try Repository.create(at: dir)

                let repo = try Repository.open(at: dir)
                do {
                    _ = try repo.head()
                    Issue.record("expected GitError")
                } catch let e as GitError {
                    #expect(e.code == .unbornBranch)
                }
            }
        }

        @Test
        func referenceTargetReturnsOID() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "solo", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let oid = try head.target
                #expect(oid.hex.count == 40)
            }
        }
    }
}
