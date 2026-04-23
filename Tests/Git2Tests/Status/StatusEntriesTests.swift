import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct StatusEntriesTests {
        @Test
        func statusList_onCleanRepo_returnsZeroCount() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                let list = try repo.statusList()
                #expect(list.count == 0)
            }
        }

        @Test
        func statusList_onBareRepo_throwsBareRepo() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try initBareRepo(at: dir)
                #expect {
                    _ = try repo.statusList()
                } throws: { error in
                    guard let gitError = error as? GitError else { return false }
                    return gitError.code == .bareRepo
                }
            }
        }

        @Test
        func statusEntries_onCleanRepo_returnsEmpty() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                let entries = try repo.statusEntries()
                #expect(entries.isEmpty)
            }
        }

        @Test
        func statusEntries_untrackedFile_appearsAsWtNew() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("new.txt", contents: "hi", in: dir)

                let entries = try repo.statusEntries()
                #expect(entries.count == 1)
                let entry = try #require(entries.first)
                #expect(entry.path == "new.txt")
                #expect(entry.flags.contains(.wtNew))
                #expect(entry.flags.hasWorkdirChanges)
                #expect(!entry.flags.hasIndexChanges)
            }
        }

        @Test
        func statusEntries_stagedNewFile_appearsAsIndexNew() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("staged.txt", contents: "hi", in: dir)
                let index = try repo.index()
                try index.addPath("staged.txt")
                try index.save()

                let entries = try repo.statusEntries()
                #expect(entries.contains { $0.path == "staged.txt" && $0.flags.contains(.indexNew) })
            }
        }

        @Test
        func statusEntries_modifiedTrackedFile_appearsAsWtModified() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "tracked.txt", contents: "v1", in: dir
                )
                try TestFixture.writeWorkdirFile("tracked.txt", contents: "v2", in: dir)

                let entries = try repo.statusEntries()
                let entry = try #require(entries.first { $0.path == "tracked.txt" })
                #expect(entry.flags.contains(.wtModified))
            }
        }

        @Test
        func statusEntries_deletedFromWorkdir_appearsAsWtDeleted() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "keep.txt", contents: "x", in: dir
                )
                try TestFixture.deleteWorkdirFile("keep.txt", in: dir)

                let entries = try repo.statusEntries()
                let entry = try #require(entries.first { $0.path == "keep.txt" })
                #expect(entry.flags.contains(.wtDeleted))
            }
        }

        @Test
        func statusEntries_stagedAndThenModified_hasBothFlags() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "rw.txt", contents: "v1", in: dir
                )
                try TestFixture.writeWorkdirFile("rw.txt", contents: "v2", in: dir)
                let index = try repo.index()
                try index.addPath("rw.txt")
                try index.save()
                try TestFixture.writeWorkdirFile("rw.txt", contents: "v3", in: dir)

                let entries = try repo.statusEntries()
                let entry = try #require(entries.first { $0.path == "rw.txt" })
                #expect(entry.flags.contains(.indexModified))
                #expect(entry.flags.contains(.wtModified))
            }
        }

        @Test
        func statusEntries_unbornHead_listsWorkdirAgainstEmptyTree() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                try TestFixture.writeWorkdirFile("a.txt", contents: "a", in: dir)

                let entries = try repo.statusEntries()
                #expect(entries.contains { $0.path == "a.txt" && $0.flags.contains(.wtNew) })
            }
        }

        @Test
        func statusEntries_onBareRepo_throwsBareRepo() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try initBareRepo(at: dir)
                #expect {
                    _ = try repo.statusEntries()
                } throws: { error in
                    guard let gitError = error as? GitError else { return false }
                    return gitError.code == .bareRepo
                }
            }
        }

        @Test
        func statusEntries_exposesDiffDelta_forHeadToIndex_andIndexToWorkdir() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "x.txt", contents: "v1", in: dir
                )
                // Stage v2 (headToIndex) then overwrite workdir with v3 (indexToWorkdir).
                try TestFixture.writeWorkdirFile("x.txt", contents: "v2", in: dir)
                let index = try repo.index()
                try index.addPath("x.txt")
                try index.save()
                try TestFixture.writeWorkdirFile("x.txt", contents: "v3", in: dir)

                let entries = try repo.statusEntries()
                let entry = try #require(entries.first { $0.path == "x.txt" })
                #expect(entry.headToIndex != nil)
                #expect(entry.headToIndex?.status == .modified)
                #expect(entry.indexToWorkdir != nil)
                #expect(entry.indexToWorkdir?.status == .modified)
            }
        }

        @Test
        func statusEntries_stagedDelete_appearsAsIndexDeleted() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "doomed.txt", contents: "bye", in: dir
                )
                let index = try repo.index()
                try index.removePath("doomed.txt")
                try index.save()

                let entries = try repo.statusEntries()
                let entry = try #require(entries.first { $0.path == "doomed.txt" })
                #expect(entry.flags.contains(.indexDeleted))
            }
        }
    }
}
