import Testing
@testable import Git2

struct FetchOptionsTests {
    @Test func defaultsAreEmpty() {
        let opts = Repository.FetchOptions()
        #expect(opts.credentials      == nil)
        #expect(opts.certificateCheck == nil)
        #expect(opts.transferProgress == nil)
        #expect(opts.prune            == .unspecified)
        #expect(opts.updateFetchHead  == true)
        #expect(opts.downloadTags     == .unspecified)
        #expect(opts.depth            == 0)
        #expect(opts.followRedirects  == .initial)
        #expect(opts.customHeaders    == [])
    }

    @Test func closureFieldsAreAssignable() {
        var opts = Repository.FetchOptions()
        opts.credentials      = { _, _, _ in .default }
        opts.certificateCheck = { _, _ in .accept }
        opts.transferProgress = { _ in true }
        #expect(opts.credentials      != nil)
        #expect(opts.certificateCheck != nil)
        #expect(opts.transferProgress != nil)
    }

    @Test func pruneSetting_cases() {
        let all: [Repository.FetchOptions.PruneSetting] = [.unspecified, .prune, .noPrune]
        #expect(Set(all).count == 3)
    }

    @Test func autotagOption_cases() {
        let all: [Repository.FetchOptions.AutotagOption] = [.unspecified, .auto, .none, .all]
        #expect(Set(all).count == 4)
    }

    @Test func redirectPolicy_cases() {
        let all: [Repository.FetchOptions.RedirectPolicy] = [.none, .initial, .all]
        #expect(Set(all).count == 3)
    }

    @Test func isSendable() {
        // Compile-time assertion — the file would fail to compile otherwise.
        func takeSendable<T: Sendable>(_: T) {}
        takeSendable(Repository.FetchOptions())
    }
}
