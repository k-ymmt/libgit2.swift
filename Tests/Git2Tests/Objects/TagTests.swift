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

        @Test
        func tagOfTagChainResolvesThroughTwoTargetCalls() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "initial", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tipOID = try repo.head().target

                // First-level annotated tag: v1 → commit.
                let innerTagOID = try TestFixture.makeAnnotatedTag(
                    name: "v1",
                    pointingAt: tipOID.raw,
                    message: "inner",
                    in: fixture.repositoryURL
                )

                // Second-level annotated tag: v1-alias → v1 (tag-of-tag).
                let outerTagOID = try TestFixture.makeAnnotatedTag(
                    name: "v1-alias",
                    pointingAt: innerTagOID,
                    targetKind: GIT_OBJECT_TAG,
                    message: "outer",
                    in: fixture.repositoryURL
                )

                // First target() call: outer tag → inner tag.
                guard case .tag(let outer) = try #require(try repo.object(for: OID(raw: outerTagOID))) else {
                    Issue.record("expected outer tag"); return
                }
                #expect(outer.targetKind == .tag)
                let firstTarget = try outer.target()
                guard case .tag(let inner) = firstTarget else {
                    Issue.record("expected inner tag from first target() call"); return
                }

                // Second target() call: inner tag → commit.
                #expect(inner.targetKind == .commit)
                let secondTarget = try inner.target()
                guard case .commit(let commit) = secondTarget else {
                    Issue.record("expected commit from second target() call"); return
                }
                #expect(commit.oid == tipOID)
            }
        }
    }
}
