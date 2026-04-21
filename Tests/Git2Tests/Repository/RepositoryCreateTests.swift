import Testing
import Foundation
@testable import Git2

// These tests call `Git.bootstrap()` / `Git.shutdown()` and so must run serially
// with any other test that touches the runtime lifecycle. Nested under
// `RuntimeSensitiveTests` for mutual exclusion with the lifecycle tests —
// otherwise the global refcount can drop to 0 mid-call.
extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RepositoryCreateTests {
        @Test
        func create_default_producesNonBareUnbornRepo() throws {
            try Git.bootstrap(); defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let target = dir.appendingPathComponent("repo")
                let repo = try Repository.create(at: target)

                #expect(repo.isBare == false)
                #expect(repo.isHeadUnborn == true)
                #expect(repo.workingDirectory != nil)
                #expect(repo.gitDirectory.lastPathComponent == ".git"
                        || repo.gitDirectory.path.hasSuffix(".git/"))
            }
        }

        @Test
        func create_bare_true_producesBareRepo() throws {
            try Git.bootstrap(); defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let target = dir.appendingPathComponent("bare.git")
                let repo = try Repository.create(at: target, bare: true)

                #expect(repo.isBare == true)
                #expect(repo.workingDirectory == nil)
            }
        }
    }
}
