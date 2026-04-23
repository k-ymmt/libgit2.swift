import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct StatusListTests {
        @Test
        func count_matchesStatusEntries() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("a.txt", contents: "a", in: dir)
                try TestFixture.writeWorkdirFile("b.txt", contents: "b", in: dir)

                let list = try repo.statusList()
                let entries = try repo.statusEntries()
                #expect(list.count == entries.count)
            }
        }

        @Test
        func subscript_returnsExpectedEntry() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("one.txt", contents: "1", in: dir)

                let list = try repo.statusList()
                #expect(list.count == 1)
                let entry = list[0]
                #expect(entry.path == "one.txt")
                #expect(entry.flags.contains(.wtNew))
            }
        }

        @Test
        func handle_frozenAtCreationTime() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("a.txt", contents: "a", in: dir)

                let list = try repo.statusList()
                let initialCount = list.count

                // Mutate the workdir after the list is created.
                try TestFixture.writeWorkdirFile("b.txt", contents: "b", in: dir)

                #expect(list.count == initialCount)
                // A fresh list sees the new file.
                let fresh = try repo.statusList()
                #expect(fresh.count == initialCount + 1)
            }
        }
    }
}
