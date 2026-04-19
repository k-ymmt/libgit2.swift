import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RepositoryDiscoverTests {
        @Test
        func discoverFromRepoRootReturnsDotGit() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "m", author: .test)],
                    in: dir
                )
                let discovered = try Repository.discover(startingAt: fixture.repositoryURL)
                #expect(discovered.path.hasSuffix(".git") || discovered.path.hasSuffix(".git/"))
            }
        }

        @Test
        func discoverFromSubdirectoryWalksUp() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "m", author: .test)],
                    in: dir
                )
                let sub = fixture.repositoryURL
                    .appendingPathComponent("a", isDirectory: true)
                    .appendingPathComponent("b", isDirectory: true)
                try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)

                let discovered = try Repository.discover(startingAt: sub)
                #expect(discovered.path.contains(".git"))
            }
        }

        @Test
        func discoverFromOutsideRepositoryThrowsNotFound() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                // Empty dir, no .git anywhere up the tree (tmp).
                #expect(throws: GitError.self) {
                    _ = try Repository.discover(startingAt: dir)
                }
            }
        }

        @Test
        func ceilingDirectoriesHaltsSearch() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "m", author: .test)],
                    in: dir
                )
                let sub = fixture.repositoryURL.appendingPathComponent("child", isDirectory: true)
                try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)

                #expect(throws: GitError.self) {
                    _ = try Repository.discover(
                        startingAt: sub,
                        ceilingDirectories: [fixture.repositoryURL]
                    )
                }
            }
        }

        @Test
        func openDiscoveringFromWorksFromSubdirectory() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "m", author: .test)],
                    in: dir
                )
                let sub = fixture.repositoryURL.appendingPathComponent("x", isDirectory: true)
                try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)

                let repo = try Repository.open(discoveringFrom: sub)
                _ = try repo.head()  // proves it opened successfully
            }
        }
    }
}
