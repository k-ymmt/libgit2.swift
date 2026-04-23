import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RepositoryStatusConcurrencyTests {
        @Test
        func statusEntries_runsConcurrently_noRace() async throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try await withTemporaryDirectoryAsync { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("a.txt", contents: "a", in: dir)
                try TestFixture.writeWorkdirFile("b.txt", contents: "b", in: dir)

                try await withThrowingTaskGroup(of: Void.self) { group in
                    for _ in 0..<32 {
                        group.addTask {
                            let entries = try repo.statusEntries()
                            #expect(entries.count >= 1)
                        }
                    }
                    try await group.waitForAll()
                }
            }
        }

        @Test
        func statusList_subscript_andStatusForPath_runConcurrently() async throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try await withTemporaryDirectoryAsync { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("a.txt", contents: "a", in: dir)
                let list = try repo.statusList()

                try await withThrowingTaskGroup(of: Void.self) { group in
                    for _ in 0..<16 {
                        group.addTask {
                            for i in 0..<list.count {
                                _ = list[i]
                            }
                        }
                        group.addTask {
                            _ = try? repo.status(forPath: "a.txt")
                        }
                    }
                    try await group.waitForAll()
                }
            }
        }

        @Test
        func shouldIgnore_runsConcurrently() async throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try await withTemporaryDirectoryAsync { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeGitignore("*.log\n", in: dir)

                try await withThrowingTaskGroup(of: Void.self) { group in
                    for _ in 0..<32 {
                        group.addTask {
                            let ignoredLog = try repo.shouldIgnore(path: "x.log")
                            let ignoredTxt = try repo.shouldIgnore(path: "x.txt")
                            #expect(ignoredLog)
                            #expect(!ignoredTxt)
                        }
                    }
                    try await group.waitForAll()
                }
            }
        }
    }
}
