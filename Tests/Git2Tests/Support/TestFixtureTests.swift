import Testing
import Foundation
@testable import Git2
import Cgit2

@Test
func withTemporaryDirectoryCreatesAndRemovesDirectory() throws {
    var capturedURL: URL?
    try withTemporaryDirectory { url in
        capturedURL = url
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }
    let url = try #require(capturedURL)
    #expect(FileManager.default.fileExists(atPath: url.path) == false)
}

// Nested under `RuntimeSensitiveTests` because it calls
// `Git.bootstrap()` / `Git.shutdown()`. Leaving it free-standing caused
// intermittent flakes once other suites (e.g. `RepositoryOpenTests`) started
// touching the runtime lifecycle — the refcount could drop to 0 mid-test.
extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct TestFixtureRuntimeTests {
        @Test
        func makeLinearHistoryCreatesGitDirectoryWithCommits() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [
                        (message: "first",  author: .test),
                        (message: "second", author: .test),
                        (message: "third",  author: .test),
                    ],
                    in: dir
                )

                let gitDir = fixture.repositoryURL.appendingPathComponent(".git")
                var isDir: ObjCBool = false
                #expect(FileManager.default.fileExists(atPath: gitDir.path, isDirectory: &isDir))
                #expect(isDir.boolValue)
            }
        }
    }
}

extension Signature {
    /// Convenience for fixtures.
    static let test = Signature(
        name: "Tester",
        email: "tester@example.com",
        date: Date(timeIntervalSince1970: 1_700_000_000),
        timeZone: TimeZone(secondsFromGMT: 0)!
    )
}
