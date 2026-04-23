import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct StatusForPathTests {
        @Test
        func existingTrackedFile_returnsCurrent() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "t.txt", contents: "hi", in: dir
                )
                let flags = try repo.status(forPath: "t.txt")
                #expect(flags.isCurrent)
            }
        }

        @Test
        func untrackedPath_returnsWtNew() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("u.txt", contents: "x", in: dir)
                let flags = try repo.status(forPath: "u.txt")
                #expect(flags.contains(.wtNew))
            }
        }

        @Test
        func stagedPath_returnsIndexNew() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("s.txt", contents: "x", in: dir)
                let index = try repo.index()
                try index.addPath("s.txt")
                try index.save()

                let flags = try repo.status(forPath: "s.txt")
                #expect(flags.contains(.indexNew))
            }
        }

        @Test
        func unknownPath_throwsNotFound() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                #expect {
                    _ = try repo.status(forPath: "nope.txt")
                } throws: { error in
                    guard let e = error as? GitError else { return false }
                    return e.code == .notFound
                }
            }
        }

        @Test
        func directoryPath_throwsAmbiguous() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("sub/a.txt", contents: "a", in: dir)
                try TestFixture.writeWorkdirFile("sub/b.txt", contents: "b", in: dir)

                #expect {
                    _ = try repo.status(forPath: "sub")
                } throws: { error in
                    guard let e = error as? GitError else { return false }
                    return e.code == .ambiguous
                }
            }
        }

        @Test
        func bareRepo_throwsBareRepo() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try initBareRepo(at: dir)
                #expect {
                    _ = try repo.status(forPath: "anything")
                } throws: { error in
                    guard let e = error as? GitError else { return false }
                    return e.code == .bareRepo
                }
            }
        }
    }
}
