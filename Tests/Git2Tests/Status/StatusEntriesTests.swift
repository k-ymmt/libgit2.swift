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
    }
}
