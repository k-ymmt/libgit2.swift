import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct StatusOptionsTests {
        @Test
        func show_allThreeCasesExist() {
            let cases: [Repository.StatusOptions.Show] = [.indexAndWorkdir, .indexOnly, .workdirOnly]
            #expect(cases.count == 3)
        }

        @Test
        func flags_defaultsMatchesLibgit2() {
            // GIT_STATUS_OPT_DEFAULTS = INCLUDE_IGNORED | INCLUDE_UNTRACKED | RECURSE_UNTRACKED_DIRS
            let defaults: Repository.StatusOptions.Flags = .defaults
            #expect(defaults.contains(.includeUntracked))
            #expect(defaults.contains(.includeIgnored))
            #expect(defaults.contains(.recurseUntrackedDirs))
            #expect(!defaults.contains(.excludeSubmodules))
            #expect(!defaults.contains(.includeUnmodified))
        }

        @Test
        func flags_rawValues_matchLibgit2() {
            #expect(Repository.StatusOptions.Flags.includeUntracked.rawValue             == 1 << 0)
            #expect(Repository.StatusOptions.Flags.includeIgnored.rawValue               == 1 << 1)
            #expect(Repository.StatusOptions.Flags.includeUnmodified.rawValue            == 1 << 2)
            #expect(Repository.StatusOptions.Flags.excludeSubmodules.rawValue            == 1 << 3)
            #expect(Repository.StatusOptions.Flags.recurseUntrackedDirs.rawValue         == 1 << 4)
            #expect(Repository.StatusOptions.Flags.disablePathspecMatch.rawValue         == 1 << 5)
            #expect(Repository.StatusOptions.Flags.recurseIgnoredDirs.rawValue           == 1 << 6)
            #expect(Repository.StatusOptions.Flags.renamesHeadToIndex.rawValue           == 1 << 7)
            #expect(Repository.StatusOptions.Flags.renamesIndexToWorkdir.rawValue        == 1 << 8)
            #expect(Repository.StatusOptions.Flags.sortCaseSensitively.rawValue          == 1 << 9)
            #expect(Repository.StatusOptions.Flags.sortCaseInsensitively.rawValue        == 1 << 10)
            #expect(Repository.StatusOptions.Flags.renamesFromRewrites.rawValue          == 1 << 11)
            #expect(Repository.StatusOptions.Flags.noRefresh.rawValue                    == 1 << 12)
            #expect(Repository.StatusOptions.Flags.updateIndex.rawValue                  == 1 << 13)
            #expect(Repository.StatusOptions.Flags.includeUnreadable.rawValue            == 1 << 14)
            #expect(Repository.StatusOptions.Flags.includeUnreadableAsUntracked.rawValue == 1 << 15)
        }
    }
}
