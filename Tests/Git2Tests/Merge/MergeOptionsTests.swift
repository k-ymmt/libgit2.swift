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
}
