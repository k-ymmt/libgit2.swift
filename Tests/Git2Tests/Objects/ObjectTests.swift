import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct ObjectHandleInternalTests {
        @Test
        func lookupAnyResolvesACommit() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "only", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let oid = try head.target

                // Exercise ObjectHandle.lookup with GIT_OBJECT_ANY — should
                // succeed and report the actual type.
                let handle = try repo.lock.withLock { () throws(GitError) -> OpaquePointer in
                    try ObjectHandle.lookup(repository: repo, oid: oid, kind: GIT_OBJECT_ANY)
                }
                defer { git_object_free(handle) }

                #expect(git_object_type(handle) == GIT_OBJECT_COMMIT)
            }
        }
    }
}
