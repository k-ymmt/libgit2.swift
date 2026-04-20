import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct AnnotatedCommitTests {
        @Test
        func fromReference_carriesRefName() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "A\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()

                let headTarget = try head.target
                let ac = try repo.annotatedCommit(for: head)
                #expect(ac.oid == headTarget)
                // HEAD resolved to either refs/heads/main or refs/heads/master.
                let refName = ac.refName
                #expect(refName != nil)
                #expect(refName?.hasPrefix("refs/heads/") == true)
            }
        }

        @Test
        func fromOID_hasNoRefName() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "A\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()

                let headTarget = try head.target
                let ac = try repo.annotatedCommit(for: headTarget)
                #expect(ac.oid == headTarget)
                #expect(ac.refName == nil)
            }
        }

        @Test
        func fromCommit_hasNoRefName() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "A\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let commit = try repo.commit(for: head.target)

                let ac = try repo.annotatedCommit(from: commit)
                #expect(ac.oid == commit.oid)
                #expect(ac.refName == nil)
            }
        }

        @Test
        func oidLookup_forUnknownOIDThrowsNotFound() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                let zero = try OID(hex: String(repeating: "0", count: 40))
                do {
                    _ = try repo.annotatedCommit(for: zero)
                    Issue.record("expected throw for unknown OID")
                } catch let e as GitError {
                    // Empirical: libgit2 1.9.x returns GIT_ENOTFOUND / ODB.
                    #expect(e.code == .notFound)
                }
            }
        }
    }
}
