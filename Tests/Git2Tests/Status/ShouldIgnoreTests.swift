import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct ShouldIgnoreTests {
        @Test
        func ignoredByGitignore_returnsTrue() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeGitignore("*.log\n", in: dir)
                #expect(try repo.shouldIgnore(path: "a.log"))
            }
        }

        @Test
        func nonIgnoredPath_returnsFalse() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeGitignore("*.log\n", in: dir)
                #expect(try !repo.shouldIgnore(path: "a.txt"))
            }
        }

        @Test
        func nonexistentPath_isConsultedByRulesAlone() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeGitignore("*.log\n", in: dir)
                // Path does not exist on disk — libgit2 still consults rules.
                #expect(try repo.shouldIgnore(path: "phantom.log"))
                #expect(try !repo.shouldIgnore(path: "phantom.txt"))
            }
        }

        @Test
        func trackedFile_matchingGitignore_stillReportsRulesVerdict() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                // Track a file that matches a later-added gitignore rule.
                // libgit2 reports the rules verdict (true), NOT the tracking
                // status — pin this behavior.
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "keep.log", contents: "track me", in: dir
                )
                try TestFixture.writeGitignore("*.log\n", in: dir)
                #expect(try repo.shouldIgnore(path: "keep.log"))
            }
        }
    }
}
