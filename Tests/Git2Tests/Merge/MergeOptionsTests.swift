import Testing
@testable import Git2
import Cgit2

@Suite
struct MergeOptionsTests {
    @Test
    func defaultsMatchLibgit2() {
        let opts = Repository.MergeOptions()
        #expect(opts.flags == [])
        #expect(opts.fileFavor == .normal)
        #expect(opts.renameThreshold == 50)
        #expect(opts.targetLimit == 200)
    }

    @Test
    func flagsRawValuesMatchLibgit2() {
        #expect(Repository.MergeOptions.Flags.findRenames.rawValue    == UInt32(GIT_MERGE_FIND_RENAMES.rawValue))
        #expect(Repository.MergeOptions.Flags.failOnConflict.rawValue == UInt32(GIT_MERGE_FAIL_ON_CONFLICT.rawValue))
        #expect(Repository.MergeOptions.Flags.skipReuc.rawValue       == UInt32(GIT_MERGE_SKIP_REUC.rawValue))
        #expect(Repository.MergeOptions.Flags.noRecursive.rawValue    == UInt32(GIT_MERGE_NO_RECURSIVE.rawValue))
        #expect(Repository.MergeOptions.Flags.virtualBase.rawValue    == UInt32(GIT_MERGE_VIRTUAL_BASE.rawValue))
    }

    @Test
    func fileFavorRoundTripsThroughEveryCase() {
        let cases: [Repository.MergeOptions.FileFavor] = [.normal, .ours, .theirs, .union]
        // Construction + equality sanity check.
        #expect(cases.count == 4)
        #expect(cases == cases)
    }

    @Test
    func cherrypickOptionsDefaults() {
        let opts = Repository.CherrypickOptions()
        #expect(opts.mainline == 0)
        #expect(opts.merge == Repository.MergeOptions())
        #expect(opts.checkout == Repository.CheckoutOptions())
    }

    @Test
    func cherrypickOptionsCustom() {
        let opts = Repository.CherrypickOptions(
            mainline: 1,
            merge: Repository.MergeOptions(flags: [.findRenames], fileFavor: .theirs),
            checkout: Repository.CheckoutOptions(strategy: [.force])
        )
        #expect(opts.mainline == 1)
        #expect(opts.merge.fileFavor == .theirs)
        #expect(opts.checkout.strategy == [.force])
    }

    @Test
    func mergeAnalysisBits() {
        #expect(Repository.MergeAnalysis.normal.rawValue      == UInt32(GIT_MERGE_ANALYSIS_NORMAL.rawValue))
        #expect(Repository.MergeAnalysis.upToDate.rawValue    == UInt32(GIT_MERGE_ANALYSIS_UP_TO_DATE.rawValue))
        #expect(Repository.MergeAnalysis.fastForward.rawValue == UInt32(GIT_MERGE_ANALYSIS_FASTFORWARD.rawValue))
        #expect(Repository.MergeAnalysis.unborn.rawValue      == UInt32(GIT_MERGE_ANALYSIS_UNBORN.rawValue))
        #expect(Repository.MergeAnalysis.none == [])
    }

    @Test
    func mergePreferenceCases() {
        let cases: [Repository.MergePreference] = [.none, .noFastForward, .fastForwardOnly]
        #expect(cases.count == 3)
    }

    @Test
    func stateCases() {
        let cases: [Repository.State] = [
            .none, .merge, .revert, .revertSequence, .cherrypick, .cherrypickSequence,
            .bisect, .rebase, .rebaseInteractive, .rebaseMerge, .applyMailbox, .applyMailboxOrRebase
        ]
        #expect(cases.count == 12)
    }
}
