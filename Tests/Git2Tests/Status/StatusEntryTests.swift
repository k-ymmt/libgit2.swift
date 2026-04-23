import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct StatusEntryTests {
        /// A synthetic `git_status_entry` with both sides NULL exercises the
        /// path-resolution fallback ("" when libgit2 returns no delta).
        @Test
        func init_bothDeltasNull_pathEmpty_flagsCurrent() {
            var raw = git_status_entry()
            raw.status = GIT_STATUS_CURRENT
            raw.head_to_index = nil
            raw.index_to_workdir = nil

            let entry = StatusEntry(raw: raw)
            #expect(entry.path == "")
            #expect(entry.flags.isCurrent)
            #expect(entry.headToIndex == nil)
            #expect(entry.indexToWorkdir == nil)
        }

        @Test
        func init_wrapsStatusBits() {
            var raw = git_status_entry()
            raw.status = git_status_t(
                GIT_STATUS_INDEX_MODIFIED.rawValue
                | GIT_STATUS_WT_MODIFIED.rawValue
            )
            raw.head_to_index = nil
            raw.index_to_workdir = nil

            let entry = StatusEntry(raw: raw)
            #expect(entry.flags.contains(.indexModified))
            #expect(entry.flags.contains(.wtModified))
        }
    }
}
