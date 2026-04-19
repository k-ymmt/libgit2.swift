import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct TagTests {
        @Test
        func annotatedTagExposesNameMessageTaggerTarget() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "initial", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tipOID = try repo.head().target
                let tagOID = try TestFixture.makeAnnotatedTag(
                    name: "v0.0.1",
                    pointingAt: tipOID.raw,
                    message: "release notes",
                    in: fixture.repositoryURL
                )

                guard case .tag(let tag) = try #require(try repo.object(for: OID(raw: tagOID))) else {
                    Issue.record("expected tag object")
                    return
                }
                #expect(tag.name == "v0.0.1")
                #expect(tag.message.trimmingCharacters(in: .newlines) == "release notes")
                #expect(tag.tagger?.name == Signature.test.name)
                #expect(tag.targetOID == tipOID)
                #expect(tag.targetKind == .commit)

                let target = try tag.target()
                guard case .commit(let commit) = target else {
                    Issue.record("expected commit target")
                    return
                }
                #expect(commit.oid == tipOID)
            }
        }
    }
}
