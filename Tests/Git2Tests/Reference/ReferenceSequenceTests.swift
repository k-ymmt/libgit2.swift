import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct ReferenceSequenceTests {
        @Test
        func referencesListsEveryReference() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "m", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tipOID = try repo.head().target
                try TestFixture.makeBranches(
                    names: ["feature-a", "feature-b"],
                    pointingAt: tipOID.raw,
                    in: fixture.repositoryURL
                )

                let names = Set(repo.references().map(\.name))
                #expect(names.contains("refs/heads/feature-a"))
                #expect(names.contains("refs/heads/feature-b"))
                // The fixture creates its history on HEAD, so the default
                // branch ref is also present.
                #expect(names.contains { $0.hasPrefix("refs/heads/") && !$0.contains("feature-") })
            }
        }

        @Test
        func emptyRepositoryReferencesIterationStillWorks() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try Repository.create(at: dir)
                let names = repo.references().map(\.name)
                #expect(names.isEmpty)
            }
        }
    }
}
