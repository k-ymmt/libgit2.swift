import Testing
@testable import Git2

struct PushOptionsTests {
    @Test func defaultsAreEmpty() {
        let opts = Repository.PushOptions()
        #expect(opts.credentials          == nil)
        #expect(opts.certificateCheck     == nil)
        #expect(opts.pushTransferProgress == nil)
        #expect(opts.pushUpdateReference  == nil)
        #expect(opts.followRedirects      == .initial)
        #expect(opts.customHeaders        == [])
    }

    @Test func closureFieldsAreAssignable() {
        var opts = Repository.PushOptions()
        opts.credentials          = { _, _, _ in .default }
        opts.certificateCheck     = { _, _ in .accept }
        opts.pushTransferProgress = { _, _, _ in true }
        opts.pushUpdateReference  = { _, _ in }
        #expect(opts.credentials          != nil)
        #expect(opts.certificateCheck     != nil)
        #expect(opts.pushTransferProgress != nil)
        #expect(opts.pushUpdateReference  != nil)
    }

    @Test func credentialsTypealiasMatchesFetch() {
        // Typealias identity: a CredentialsHandler value built for
        // FetchOptions must be assignable to PushOptions without cast.
        let h: Repository.FetchOptions.CredentialsHandler = { _, _, _ in .default }
        var opts = Repository.PushOptions()
        opts.credentials = h
        #expect(opts.credentials != nil)
    }

    @Test func isSendable() {
        func takeSendable<T: Sendable>(_: T) {}
        takeSendable(Repository.PushOptions())
    }
}
