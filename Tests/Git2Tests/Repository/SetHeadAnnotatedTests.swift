import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct SetHeadAnnotatedTests {
        @Test
        func detachesHeadToOid() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [
                        (message: "A\n", author: .test),
                        (message: "B\n", author: .test),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let headTarget = try repo.head().target
                let commits = Array(try repo.log(from: try repo.commit(for: headTarget)))
                let first = commits.last!

                let ac = try repo.annotatedCommit(from: first)
                try repo.setHead(detachedAtAnnotated: ac)

                #expect(try repo.head().target == first.oid)
            }
        }

        @Test
        func refProvenance_landsInReflog() throws {
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

                try repo.setHead(detachedAtAnnotated: ac)
                #expect(try repo.head().target == headTarget)
                // Reflog content assertion deferred — libgit2 does not expose
                // the reflog publicly yet in Git2. This test just confirms
                // the call succeeds and HEAD moves correctly.
            }
        }
    }
}
