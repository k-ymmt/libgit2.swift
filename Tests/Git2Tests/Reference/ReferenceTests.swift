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
    struct ReferenceTests {
        @Test
        func referenceResolvesToCommit() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "only", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let commit = try head.resolveToCommit()
                #expect(commit.summary == "only")
            }
        }

        @Test
        func referenceToAnnotatedTagPeelsToCommit() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "only", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tipOID = try repo.head().target

                _ = try TestFixture.makeAnnotatedTag(
                    name: "v0.0.1",
                    pointingAt: tipOID.raw,
                    message: "release",
                    in: fixture.repositoryURL
                )

                // refs/tags/v0.0.1 is a reference to an annotated tag object.
                // resolveToCommit() must peel through the tag to the commit.
                let tagRef = try #require(try repo.reference(named: "refs/tags/v0.0.1"))
                let commit = try tagRef.resolveToCommit()
                #expect(commit.oid == tipOID)
            }
        }
    }
}
