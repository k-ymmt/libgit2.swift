import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct ObjectLookupTests {
        @Test
        func objectForCommitReturnsCommitCase() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "m", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let oid = try repo.head().target
                let obj = try #require(try repo.object(for: oid))
                if case .commit(let commit) = obj {
                    #expect(commit.oid == oid)
                    #expect(obj.kind == .commit)
                } else {
                    Issue.record("expected .commit, got \(obj)")
                }
            }
        }

        @Test
        func objectForUnknownOidReturnsNil() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "m", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let missing = try OID(hex: "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef")
                #expect(try repo.object(for: missing) == nil)
            }
        }

        @Test
        func objectKindOidAccessorsMatch() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "m", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let oid = try repo.head().target
                let obj = try #require(try repo.object(for: oid))
                #expect(obj.oid == oid)
                #expect(obj.kind == .commit)
            }
        }
    }
}

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
