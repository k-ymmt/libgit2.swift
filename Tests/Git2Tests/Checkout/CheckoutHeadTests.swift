import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct CheckoutHeadTests {
        @Test
        func restoresDeletedFileFromHead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "hello\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)

                let file = dir.appendingPathComponent("README.md")
                // makeLinearHistory only writes to the ODB; materialize the
                // tracked file on disk so we have something to delete.
                try Data("hello\n".utf8).write(to: file)
                try FileManager.default.removeItem(at: file)
                #expect(!FileManager.default.fileExists(atPath: file.path))

                try repo.checkoutHead(options: Repository.CheckoutOptions(strategy: [.force]))

                #expect(FileManager.default.fileExists(atPath: file.path))
                let restored = try String(contentsOf: file, encoding: .utf8)
                #expect(restored == "hello\n")
            }
        }

        @Test
        func safeStrategyRefusesDirtyWorkdir() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "hello\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)

                let file = dir.appendingPathComponent("README.md")
                try Data("DIRTY\n".utf8).write(to: file)

                // Default (safe) should refuse to overwrite the dirty file.
                do {
                    try repo.checkoutHead()
                    Issue.record("expected GitError under safe strategy")
                } catch let e as GitError {
                    #expect(e.class == .checkout)
                }

                // Dirty content survives the failed checkout.
                #expect(try String(contentsOf: file, encoding: .utf8) == "DIRTY\n")
            }
        }

        @Test
        func forceStrategyOverwritesDirtyWorkdir() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "hello\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)

                let file = dir.appendingPathComponent("README.md")
                try Data("DIRTY\n".utf8).write(to: file)

                try repo.checkoutHead(options: Repository.CheckoutOptions(strategy: [.force]))

                #expect(try String(contentsOf: file, encoding: .utf8) == "hello\n")
            }
        }

        @Test
        func unbornHeadThrowsUnbornBranch() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                do {
                    try repo.checkoutHead(options: Repository.CheckoutOptions(strategy: [.force]))
                    Issue.record("expected GitError.Code.unbornBranch")
                } catch let e as GitError {
                    #expect(e.code == .unbornBranch)
                }
            }
        }

        @Test
        func bareRepoThrows() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initBareRepo(at: dir)
                do {
                    try repo.checkoutHead(options: Repository.CheckoutOptions(strategy: [.force]))
                    Issue.record("expected GitError on bare repo")
                } catch let e as GitError {
                    // libgit2 routes bare-repo rejection through the reference
                    // subsystem (HEAD resolution fails first). Assert both the
                    // code and class so a future libgit2 regression surfaces.
                    #expect(e.code == .unbornBranch)
                    #expect(e.class == .reference)
                }
            }
        }
    }
}
