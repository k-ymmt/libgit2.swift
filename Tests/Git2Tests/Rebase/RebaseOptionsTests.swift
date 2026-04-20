import Testing
@testable import Git2
import Cgit2

@Suite
struct RebaseOptionsTests {
    @Test
    func defaultsMatchLibgit2Defaults() throws {
        let opts = Repository.RebaseOptions()
        #expect(opts.quiet == false)
        #expect(opts.inMemory == false)
        #expect(opts.rewriteNotesRef == nil)
        #expect(opts.merge == Repository.MergeOptions())
        #expect(opts.checkout == Repository.CheckoutOptions())
    }

    @Test
    func withCOptions_populatesCStruct() throws {
        let opts = Repository.RebaseOptions(
            quiet: true,
            inMemory: true,
            rewriteNotesRef: "refs/notes/commits"
        )
        try opts.withCOptions { ptr throws(GitError) in
            #expect(ptr.pointee.version == UInt32(GIT_REBASE_OPTIONS_VERSION))
            #expect(ptr.pointee.quiet == 1)
            #expect(ptr.pointee.inmemory == 1)
            #expect(ptr.pointee.rewrite_notes_ref != nil)
            let notes = String(cString: ptr.pointee.rewrite_notes_ref!)
            #expect(notes == "refs/notes/commits")
        }
    }

    @Test
    func withCOptions_nilNotesRef_passesThroughAsNull() throws {
        let opts = Repository.RebaseOptions(rewriteNotesRef: nil)
        try opts.withCOptions { ptr throws(GitError) in
            #expect(ptr.pointee.rewrite_notes_ref == nil)
        }
    }
}
