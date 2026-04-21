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

        @Test
        func create_initialBranch_writesSymbolicRef() throws {
            try Git.bootstrap(); defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let target = dir.appendingPathComponent("repo")
                let repo = try Repository.create(
                    at: target,
                    initialBranch: "main"
                )

                let headURL = repo.gitDirectory.appendingPathComponent("HEAD")
                let head = try String(contentsOf: headURL, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(head == "ref: refs/heads/main")
            }
        }

        @Test
        func create_defaultInitialBranch_respectsLibgit2Default() throws {
            try Git.bootstrap(); defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let target = dir.appendingPathComponent("repo")
                let repo = try Repository.create(at: target)

                let headURL = repo.gitDirectory.appendingPathComponent("HEAD")
                let head = try String(contentsOf: headURL, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                // Exact branch name depends on init.defaultBranch in the
                // environment's gitconfig. Accept any refs/heads/<x> that
                // libgit2 chose.
                #expect(head.hasPrefix("ref: refs/heads/"))
            }
        }

        @Test
        func create_nonExistentParentPath_mkpath_createsIntermediates() throws {
            try Git.bootstrap(); defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                // Build a nested target whose parents do not yet exist.
                let deep = dir
                    .appendingPathComponent("a")
                    .appendingPathComponent("b")
                    .appendingPathComponent("c")

                let repo = try Repository.create(at: deep)
                #expect(repo.isBare == false)

                // Verify intermediate components actually exist on disk.
                let fm = FileManager.default
                #expect(fm.fileExists(atPath: dir.appendingPathComponent("a").path))
                #expect(fm.fileExists(atPath: dir.appendingPathComponent("a/b").path))
                #expect(fm.fileExists(atPath: deep.path))
            }
        }

        @Test
        func create_onExistingRepo_isIdempotentReinit() throws {
            try Git.bootstrap(); defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let target = dir.appendingPathComponent("repo")
                let headURL = target.appendingPathComponent(".git/HEAD")

                // First create: fresh repo.
                _ = try Repository.create(at: target)
                let firstHEAD = try String(contentsOf: headURL, encoding: .utf8)

                // Second create on the same path: must succeed, HEAD unchanged.
                _ = try Repository.create(at: target)
                let secondHEAD = try String(contentsOf: headURL, encoding: .utf8)

                #expect(firstHEAD == secondHEAD)
            }
        }

        @Test
        func create_onExistingRepo_newInitialBranch_retargetsHead() throws {
            try Git.bootstrap(); defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let target = dir.appendingPathComponent("repo")
                let headURL = target.appendingPathComponent(".git/HEAD")

                _ = try Repository.create(at: target, initialBranch: "main")
                let beforeHEAD = try String(contentsOf: headURL, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(beforeHEAD == "ref: refs/heads/main")

                // Reinit with a new initial branch — libgit2 retargets HEAD.
                _ = try Repository.create(at: target, initialBranch: "trunk")
                let afterHEAD = try String(contentsOf: headURL, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(afterHEAD == "ref: refs/heads/trunk")
            }
        }

        @Test
        func create_unusualInitialBranch_isAcceptedVerbatim() throws {
            try Git.bootstrap(); defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let target = dir.appendingPathComponent("repo")
                // libgit2 1.9.x performs NO validation on `initial_head`
                // in git_repository_init_ext — it writes any supplied
                // string directly to HEAD. This test locks in that
                // thin-wrapper behavior: if a future libgit2 version
                // adds validation, this test fails visibly and we
                // decide whether to surface the new error or update
                // the test.
                let repo = try Repository.create(
                    at: target,
                    initialBranch: "foo bar"
                )

                let headURL = repo.gitDirectory.appendingPathComponent("HEAD")
                let head = try String(contentsOf: headURL, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(head == "ref: refs/heads/foo bar")
            }
        }
    }
}
