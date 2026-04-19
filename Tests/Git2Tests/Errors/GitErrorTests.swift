import Testing
@testable import Git2
import Cgit2

@Test
func gitErrorEqualityIgnoresNothing() {
    let a = GitError(code: .notFound, class: .reference, message: "hi")
    let b = GitError(code: .notFound, class: .reference, message: "hi")
    let c = GitError(code: .notFound, class: .reference, message: "different")
    #expect(a == b)
    #expect(a != c)
}

@Test
func gitErrorDescriptionIncludesAllFields() {
    let e = GitError(code: .notFound, class: .reference, message: "no ref")
    #expect(e.description == "GitError(notFound, reference): no ref")
}

@Test
func gitErrorCodeUnknownIsDistinctPerRawValue() {
    #expect(GitError.Code.unknown(7) != GitError.Code.unknown(8))
    #expect(GitError.Code.unknown(7) == GitError.Code.unknown(7))
}

@Test
func codeFromMapsKnownLibgit2Constants() {
    #expect(GitError.Code.from(GIT_OK.rawValue) == .ok)
    #expect(GitError.Code.from(GIT_ENOTFOUND.rawValue) == .notFound)
    #expect(GitError.Code.from(GIT_EEXISTS.rawValue) == .exists)
    #expect(GitError.Code.from(GIT_EUNBORNBRANCH.rawValue) == .unbornBranch)
    #expect(GitError.Code.from(GIT_EINVALIDSPEC.rawValue) == .invalidSpec)
    #expect(GitError.Code.from(GIT_ITEROVER.rawValue) == .iterationOver)
}

@Test
func codeFromFallsThroughToUnknown() {
    // Pick an Int32 that's not a libgit2 code.
    #expect(GitError.Code.from(-9999) == .unknown(-9999))
}

@Test
func classFromMapsKnownLibgit2Classes() {
    #expect(GitError.Class.from(Int32(GIT_ERROR_NONE.rawValue)) == .none)
    #expect(GitError.Class.from(Int32(GIT_ERROR_REFERENCE.rawValue)) == .reference)
    #expect(GitError.Class.from(Int32(GIT_ERROR_ODB.rawValue)) == .odb)
}

@Test
func classFromFallsThroughToUnknown() {
    #expect(GitError.Class.from(9999) == .unknown(9999))
}

@Test
func fromLibgit2ProducesUnknownWhenNoErrorIsSet() {
    // libgit2 intentionally fails allocations (including git_error_last's TLS
    // storage) until git_libgit2_init is called, so make sure we're initialized.
    #expect(git_libgit2_init() >= 0)
    defer { _ = git_libgit2_shutdown() }

    // git_error_clear() lives in git2/sys/errors.h which isn't in the umbrella
    // header; the deprecated alias giterr_clear() is exposed via git2/deprecated.h.
    giterr_clear()
    let error = GitError.fromLibgit2(-9999)
    #expect(error.code == .unknown(-9999))
    #expect(error.class == .none)
    #expect(error.message.isEmpty)
}

@Test
func checkReturnsOnSuccess() throws {
    try check(0)
    try check(1)
    try check(Int32.max)
}

@Test
func checkThrowsOnFailure() {
    // libgit2 intentionally fails allocations until git_libgit2_init is called.
    #expect(git_libgit2_init() >= 0)
    defer { _ = git_libgit2_shutdown() }

    // Force a real libgit2 error (invalid OID hex) before calling check.
    var oid = git_oid()
    let result = git_oid_fromstr(&oid, "not-a-real-oid-string")
    #expect(result < 0)

    var thrown: GitError?
    do {
        try check(result)
    } catch let e as GitError {
        thrown = e
    } catch {
        Issue.record("unexpected error type")
    }

    // git_oid_fromstr returns GIT_ERROR (-1) for malformed OIDs, which our
    // mapping surfaces as `.unknown(-1)`. Accept any of the related codes that
    // libgit2 might produce for an invalid-OID-like failure.
    #expect(
        thrown?.code == .invalid ||
        thrown?.code == .ambiguous ||
        thrown?.code == .invalidSpec ||
        thrown?.code == .unknown(-1)
    )
    #expect(thrown?.class == .invalid)
    #expect(thrown?.message.isEmpty == false)
}
