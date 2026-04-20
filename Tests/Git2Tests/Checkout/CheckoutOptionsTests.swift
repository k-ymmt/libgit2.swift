import Testing
@testable import Git2
import Cgit2

@Suite
struct CheckoutOptionsTests {
    @Test
    func defaultOptionsAreSafeWithNoPaths() {
        let opts = Repository.CheckoutOptions()
        #expect(opts.strategy == [])
        #expect(opts.paths.isEmpty)
    }

    @Test
    func strategyRawValuesMatchLibgit2() {
        #expect(Repository.CheckoutOptions.Strategy.force.rawValue == UInt32(GIT_CHECKOUT_FORCE.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.recreateMissing.rawValue == UInt32(GIT_CHECKOUT_RECREATE_MISSING.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.allowConflicts.rawValue == UInt32(GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.removeUntracked.rawValue == UInt32(GIT_CHECKOUT_REMOVE_UNTRACKED.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.removeIgnored.rawValue == UInt32(GIT_CHECKOUT_REMOVE_IGNORED.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.updateOnly.rawValue == UInt32(GIT_CHECKOUT_UPDATE_ONLY.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.dontUpdateIndex.rawValue == UInt32(GIT_CHECKOUT_DONT_UPDATE_INDEX.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.noRefresh.rawValue == UInt32(GIT_CHECKOUT_NO_REFRESH.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.disablePathspecMatch.rawValue == UInt32(GIT_CHECKOUT_DISABLE_PATHSPEC_MATCH.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.skipLockedDirectories.rawValue == UInt32(GIT_CHECKOUT_SKIP_LOCKED_DIRECTORIES.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.dontOverwriteIgnored.rawValue == UInt32(GIT_CHECKOUT_DONT_OVERWRITE_IGNORED.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.conflictStyleMerge.rawValue == UInt32(GIT_CHECKOUT_CONFLICT_STYLE_MERGE.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.conflictStyleDiff3.rawValue == UInt32(GIT_CHECKOUT_CONFLICT_STYLE_DIFF3.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.dontRemoveExisting.rawValue == UInt32(GIT_CHECKOUT_DONT_REMOVE_EXISTING.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.dontWriteIndex.rawValue == UInt32(GIT_CHECKOUT_DONT_WRITE_INDEX.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.dryRun.rawValue == UInt32(GIT_CHECKOUT_DRY_RUN.rawValue))
        #expect(Repository.CheckoutOptions.Strategy.conflictStyleZdiff3.rawValue == UInt32(GIT_CHECKOUT_CONFLICT_STYLE_ZDIFF3.rawValue))
    }

    @Test
    func optionSetBasics() {
        var s: Repository.CheckoutOptions.Strategy = [.force, .allowConflicts]
        #expect(s.contains(.force))
        #expect(s.contains(.allowConflicts))
        #expect(!s.contains(.dryRun))

        s.insert(.dryRun)
        #expect(s.contains(.dryRun))

        let removed = s.intersection([.force, .dryRun])
        #expect(removed.contains(.force))
        #expect(removed.contains(.dryRun))
        #expect(!removed.contains(.allowConflicts))
    }

    @Test
    func equatableRoundTrip() {
        let a = Repository.CheckoutOptions(strategy: [.force], paths: ["a", "b"])
        let b = Repository.CheckoutOptions(strategy: [.force], paths: ["a", "b"])
        let c = Repository.CheckoutOptions(strategy: [.force], paths: ["a"])
        #expect(a == b)
        #expect(a != c)
    }
}
