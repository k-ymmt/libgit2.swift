import Testing
import Foundation
@testable import Git2

struct RemoteCrudTests {
    @Test func createRemote_roundTripsNameAndURL() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            let remote = try repo.createRemote(named: "origin", url: "https://example.com/foo.git")
            #expect(remote.name == "origin")
            #expect(remote.url  == "https://example.com/foo.git")
            #expect(remote.pushURL == nil)
        }
    }

    @Test func createRemote_defaultFetchspecIsInstalled() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            let remote = try repo.createRemote(named: "origin", url: "https://example.com/foo.git")
            let specs = try remote.fetchRefspecs
            #expect(specs == [Refspec("+refs/heads/*:refs/remotes/origin/*")])
        }
    }

    @Test func createRemote_withFetchspec_usesCustomSpec() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            let remote = try repo.createRemote(
                named: "upstream",
                url: "https://example.com/foo.git",
                fetchspec: "+refs/heads/main:refs/remotes/upstream/main"
            )
            #expect(try remote.fetchRefspecs == [Refspec("+refs/heads/main:refs/remotes/upstream/main")])
        }
    }

    @Test func createRemote_duplicateNameThrowsExists() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            _ = try repo.createRemote(named: "origin", url: "https://example.com/a.git")
            do {
                _ = try repo.createRemote(named: "origin", url: "https://example.com/b.git")
                Issue.record("expected throw")
            } catch let error as GitError {
                #expect(error.code == .exists)
            }
        }
    }

    @Test func createRemote_invalidNameThrowsInvalidSpec() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            do {
                _ = try repo.createRemote(named: "bad name with spaces", url: "https://example.com/a.git")
                Issue.record("expected throw")
            } catch let error as GitError {
                #expect(error.code == .invalidSpec)
            }
        }
    }

    @Test func lookupRemote_returnsExisting() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            _ = try repo.createRemote(named: "origin", url: "https://example.com/a.git")
            let looked = try repo.lookupRemote(named: "origin")
            #expect(looked.name == "origin")
            #expect(looked.url  == "https://example.com/a.git")
        }
    }

    @Test func lookupRemote_unknownThrowsNotFound() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            do {
                _ = try repo.lookupRemote(named: "missing")
                Issue.record("expected throw")
            } catch let error as GitError {
                #expect(error.code == .notFound)
            }
        }
    }

    @Test func remotes_listsInstalledNames() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            _ = try repo.createRemote(named: "origin",   url: "https://example.com/a.git")
            _ = try repo.createRemote(named: "upstream", url: "https://example.com/b.git")
            let names = try repo.remotes().sorted()
            #expect(names == ["origin", "upstream"])
        }
    }

    @Test func remotes_emptyRepoIsEmpty() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            #expect(try repo.remotes() == [])
        }
    }

    @Test func isValidRemoteName_acceptsSimple() {
        #expect(Repository.isValidRemoteName("origin"))
        #expect(Repository.isValidRemoteName("upstream"))
    }

    @Test func isValidRemoteName_rejectsSpaces() {
        #expect(!Repository.isValidRemoteName("has space"))
    }

    @Test func isValidRemoteName_rejectsEmpty() {
        #expect(!Repository.isValidRemoteName(""))
    }

    @Test func deleteRemote_removesEntry() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            _ = try repo.createRemote(named: "origin", url: "https://example.com/a.git")
            try repo.deleteRemote(named: "origin")
            #expect(try repo.remotes() == [])
        }
    }

    @Test func deleteRemote_missingThrowsNotFound() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            do {
                try repo.deleteRemote(named: "missing")
                Issue.record("expected throw")
            } catch let error as GitError {
                #expect(error.code == .notFound)
            }
        }
    }

    @Test func renameRemote_updatesConfigEntry() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            _ = try repo.createRemote(named: "origin", url: "https://example.com/a.git")
            let problems = try repo.renameRemote(from: "origin", to: "upstream")
            #expect(problems == [])
            #expect(try repo.remotes() == ["upstream"])
        }
    }

    @Test func renameRemote_nonstandardRefspecReturnsProblemList() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            // A refspec that does not mention the remote name cannot be
            // auto-rewritten; libgit2 returns it in the problems array.
            _ = try repo.createRemote(
                named: "origin",
                url: "https://example.com/a.git",
                fetchspec: "+refs/heads/main:refs/heads/main"
            )
            let problems = try repo.renameRemote(from: "origin", to: "upstream")
            #expect(problems.contains("+refs/heads/main:refs/heads/main"))
        }
    }

    @Test func renameRemote_collidesThrowsExists() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let repo = try initRepo(at: dir)
            _ = try repo.createRemote(named: "origin",   url: "https://example.com/a.git")
            _ = try repo.createRemote(named: "upstream", url: "https://example.com/b.git")
            do {
                _ = try repo.renameRemote(from: "origin", to: "upstream")
                Issue.record("expected throw")
            } catch let error as GitError {
                #expect(error.code == .exists)
            }
        }
    }
}
