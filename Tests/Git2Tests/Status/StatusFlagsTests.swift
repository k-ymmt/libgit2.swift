import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct StatusFlagsTests {
        @Test
        func empty_isCurrent() {
            let flags: StatusFlags = []
            #expect(flags.isCurrent)
            #expect(!flags.hasIndexChanges)
            #expect(!flags.hasWorkdirChanges)
            #expect(!flags.isConflicted)
            #expect(!flags.isIgnored)
        }

        @Test
        func indexNew_setsHasIndexChanges() {
            let flags: StatusFlags = [.indexNew]
            #expect(!flags.isCurrent)
            #expect(flags.hasIndexChanges)
            #expect(!flags.hasWorkdirChanges)
        }

        @Test
        func wtModified_setsHasWorkdirChanges() {
            let flags: StatusFlags = [.wtModified]
            #expect(flags.hasWorkdirChanges)
            #expect(!flags.hasIndexChanges)
        }

        @Test
        func both_sides_canCoexist() {
            let flags: StatusFlags = [.indexModified, .wtModified]
            #expect(flags.hasIndexChanges)
            #expect(flags.hasWorkdirChanges)
            #expect(flags.contains(.indexModified))
            #expect(flags.contains(.wtModified))
        }

        @Test
        func conflicted_isConflicted() {
            let flags: StatusFlags = [.conflicted]
            #expect(flags.isConflicted)
        }

        @Test
        func ignored_isIgnored() {
            let flags: StatusFlags = [.ignored]
            #expect(flags.isIgnored)
        }

        @Test
        func rawValues_matchLibgit2() {
            // Bit positions from git_status_t (libgit2/include/git2/status.h).
            #expect(StatusFlags.indexNew.rawValue        == 1 << 0)
            #expect(StatusFlags.indexModified.rawValue   == 1 << 1)
            #expect(StatusFlags.indexDeleted.rawValue    == 1 << 2)
            #expect(StatusFlags.indexRenamed.rawValue    == 1 << 3)
            #expect(StatusFlags.indexTypeChange.rawValue == 1 << 4)
            #expect(StatusFlags.wtNew.rawValue           == 1 << 7)
            #expect(StatusFlags.wtModified.rawValue      == 1 << 8)
            #expect(StatusFlags.wtDeleted.rawValue       == 1 << 9)
            #expect(StatusFlags.wtTypeChange.rawValue    == 1 << 10)
            #expect(StatusFlags.wtRenamed.rawValue       == 1 << 11)
            #expect(StatusFlags.wtUnreadable.rawValue    == 1 << 12)
            #expect(StatusFlags.ignored.rawValue         == 1 << 14)
            #expect(StatusFlags.conflicted.rawValue      == 1 << 15)
        }
    }
}
