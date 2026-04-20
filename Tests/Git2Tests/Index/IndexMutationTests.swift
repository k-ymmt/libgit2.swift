import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct IndexMutationTests {
        @Test
        func addPath_stagesExistingFile() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                let fileURL = dir.appendingPathComponent("README.md")
                try "hello\n".data(using: .utf8)!.write(to: fileURL)

                let index = try repo.index()
                try index.addPath("README.md")

                let snapshot = index.entries
                try #require(snapshot.count == 1)
                #expect(snapshot[0].path == "README.md")
                #expect(snapshot[0].filemode == .blob)
                #expect(snapshot[0].stage == .normal)
                // Known OID for the blob storing "hello\n"
                #expect(String(snapshot[0].oid.description.prefix(8)) == "ce013625")
            }
        }

        @Test
        func addPath_missingFileThrowsNotFound() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                let index = try repo.index()
                #expect(throws: GitError.self) {
                    try index.addPath("nonexistent.txt")
                }
            }
        }

        @Test
        func addPath_onBareRepoThrows() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initBareRepo(at: dir)
                let index = try repo.index()
                #expect(throws: GitError.self) {
                    try index.addPath("any.txt")
                }
            }
        }
        @Test
        func removePath_undoesAddPath() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                let fileURL = dir.appendingPathComponent("x.txt")
                try "x\n".data(using: .utf8)!.write(to: fileURL)

                let index = try repo.index()
                try index.addPath("x.txt")
                #expect(index.entries.count == 1)

                try index.removePath("x.txt")
                #expect(index.entries.isEmpty)
            }
        }

        @Test
        func save_persistsIndexAcrossRepoReopen() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                do {
                    let repo = try initRepo(at: dir)
                    let fileURL = dir.appendingPathComponent("persist.txt")
                    try "persist\n".data(using: .utf8)!.write(to: fileURL)
                    let index = try repo.index()
                    try index.addPath("persist.txt")
                    try index.save()
                }
                // Fresh Repository + fresh Index — forces libgit2 to re-read .git/index
                let repo2 = try Repository.open(at: dir)
                let index2 = try repo2.index()
                try #require(index2.entries.count == 1)
                #expect(index2.entries[0].path == "persist.txt")
            }
        }
        @Test
        func reload_discardsUnsavedInMemoryChanges() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                let fileURL = dir.appendingPathComponent("later.txt")
                try "later\n".data(using: .utf8)!.write(to: fileURL)

                let index = try repo.index()
                try index.addPath("later.txt")
                #expect(index.entries.count == 1)

                // Don't save — just reload. In-memory stage is discarded.
                try index.reload()
                #expect(index.entries.isEmpty)
            }
        }
    }
}
